import Foundation
import os

/// What Pro unlocks. Free: file search (keyword + meaning) and the last 7 days of clipboard history.
/// Pro: screenshot search, full clipboard history, longer retention and extra folders.
/// Nothing is deleted when Pro is off: it's hidden, so activating brings it straight back.
enum Pro {
    static let freeClipboardDays = 7

    /// Thread-safe: read from search and indexing threads.
    static var isActive: Bool { flag.withLock { $0 } }
    fileprivate static let flag = OSAllocatedUnfairLock(initialState: false)
}

extension Notification.Name {
    static let licenseChanged = Notification.Name("licenseChanged")
}

/// Activation, monthly re-check and deactivation against the license server.
///
/// Network use: only when the user activates or deactivates, and when a Pro token is due for its
/// ~30-day re-check (at most one request every few hours until it succeeds). Free users never
/// contact the server. Requests carry the license key and the anonymous device ID, nothing else.
/// The server checks the key with Dodo Payments (where it was bought) and returns a signed token.
/// Offline, or if the server is down, Pro keeps working; only an explicit "revoked" or
/// "not activated" answer turns it off.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var token: LicenseToken?
    @Published private(set) var key: String?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var busy = false

    var isPro: Bool { token != nil }

    /// Set at build time (RECALL_LICENSE_SERVER in project.yml).
    static var serverURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "RecallLicenseServer") as? String,
              let url = URL(string: s), url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost"
        else { return nil }
        return url
    }

    private static var fileURL: URL { AppDatabase.supportDirectory.appendingPathComponent("license.json") }
    private var timer: Timer?

    private init() {}

    /// Loads the saved token (no network) and starts the background re-check timer.
    func start() {
        load()
        refreshIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in LicenseManager.shared.refreshIfDue() }
        }
    }

    // MARK: - Actions

    enum ActivationError: LocalizedError {
        case invalidKey, revoked, deviceLimit, notActivated, server(String), offline, notConfigured

        var errorDescription: String? {
            switch self {
            case .invalidKey: "That license key wasn't recognised. Check it for typos."
            case .revoked: "This license key has been turned off (refunded or revoked)."
            case .deviceLimit: "This key is already active on the maximum number of Macs. Deactivate it on one of them first (Settings → License), or contact support."
            case .notActivated: "This Mac isn't activated for that key."
            case .server(let s): "The license server had a problem (\(s)). Try again later."
            case .offline: "Couldn't reach the license server. Check your internet connection and try again."
            case .notConfigured: "This build has no license server configured."
            }
        }
    }

    func activate(key rawKey: String) async throws {
        // Keys are case-sensitive (Dodo Payments issues them), so only trim whitespace.
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ActivationError.invalidKey }
        busy = true
        defer { busy = false }
        let tokenString = try await request("v1/activate", key: key)
        guard let token = LicenseToken(tokenString) else { throw ActivationError.server("bad token") }
        save(key: key, token: token)
    }

    /// Frees this Mac's slot on the server, then turns Pro off here.
    func deactivate() async throws {
        guard let key else { return }
        busy = true
        defer { busy = false }
        do {
            _ = try await request("v1/deactivate", key: key)
        } catch ActivationError.invalidKey, ActivationError.notActivated {
            // Already gone on the server: just clear it here.
        }
        clear()
    }

    /// Re-checks with the server when the token's re-check date has passed. Never blocks Pro:
    /// network or server errors leave everything as it is, and it tries again later.
    func refreshIfDue(force: Bool = false) {
        guard let key, let token, !busy, force || Date() >= token.recheckAfter else { return }
        Task {
            do {
                let fresh = try await request("v1/validate", key: key)
                if let t = LicenseToken(fresh) { save(key: key, token: t) }
            } catch ActivationError.invalidKey, ActivationError.revoked, ActivationError.notActivated {
                clear()
            } catch {
                // Offline or server trouble: keep Pro, try again on the next timer tick.
            }
        }
    }

    // MARK: - Networking

    private func request(_ path: String, key: String) async throws -> String {
        guard let base = Self.serverURL else { throw ActivationError.notConfigured }
        var req = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["key": key, "device": DeviceID.current])
        let config = URLSessionConfiguration.ephemeral // no cookies, no cache
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: req) } catch { throw ActivationError.offline }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        lastChecked = Date()
        if status == 200 {
            if let token = json["token"] as? String { return token }
            if json["ok"] as? Bool == true { return "" }
        }
        switch json["error"] as? String {
        case "invalid_key", "bad_key": throw ActivationError.invalidKey
        case "revoked": throw ActivationError.revoked
        case "not_activated": throw ActivationError.notActivated
        case "device_limit": throw ActivationError.deviceLimit
        default: throw ActivationError.server("HTTP \(status)")
        }
    }

    // MARK: - Storage (~/Library/Application Support/Recall/license.json)

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["key"] as? String, let raw = json["token"] as? String
        else { return }
        // A token copied from another Mac, or edited, fails here and the app stays Free.
        guard let token = LicenseToken(raw) else { return }
        self.key = key
        apply(token)
    }

    private func save(key: String, token: LicenseToken) {
        self.key = key
        let json: [String: Any] = ["key": key, "token": token.raw]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: Self.fileURL, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
        }
        apply(token)
    }

    private func clear() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        key = nil
        apply(nil)
    }

    private func apply(_ token: LicenseToken?) {
        let wasPro = Pro.isActive
        self.token = token
        Pro.flag.withLock { $0 = token != nil }
        if wasPro != (token != nil) {
            NotificationCenter.default.post(name: .licenseChanged, object: nil)
        }
    }
}
