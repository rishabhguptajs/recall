import CryptoKit
import Foundation

/// A 14-day Pro trial token issued by the license server: same "<base64url(JSON)>.<base64url(signature)>"
/// format and signing key as a Pro token, but with plan "trial", so one can't pass for the other.
/// The server remembers each Mac (by its anonymous device ID) and the day its trial started, so deleting
/// Recall's files or reinstalling can't restart the trial: the server hands back the same dates.
struct TrialToken: Equatable {
    let raw: String
    let issuedAt: Date
    let start: Date
    let end: Date

    /// Returns nil unless the signature is valid and the token is a trial token for this Mac.
    init?(_ raw: String, device expectedDevice: String = DeviceID.current) {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let keyData = Data(base64Encoded: LicenseToken.publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let signature = LicenseToken.base64URLDecode(parts[1]),
              key.isValidSignature(signature, for: Data(parts[0].utf8)),
              let payload = LicenseToken.base64URLDecode(parts[0]),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              json["v"] as? Int == 1, json["plan"] as? String == "trial",
              let dev = json["dev"] as? String, dev == expectedDevice,
              let iat = json["iat"] as? Double, let tst = json["tst"] as? Double, let tnd = json["tnd"] as? Double,
              tnd > tst
        else { return nil }
        self.raw = raw
        issuedAt = Date(timeIntervalSince1970: iat)
        start = Date(timeIntervalSince1970: tst)
        end = Date(timeIntervalSince1970: tnd)
    }
}

/// Where the trial token and the latest date Recall has seen are kept on this Mac, and how "now" is judged.
///
/// "Now" is the latest of the system clock, the newest date seen on a previous run, and the date the
/// server last signed into the token, so turning the clock back doesn't stretch the trial. The server's
/// record is what stops a restart; the local files only cache the token for offline use.
enum Trial {
    private static let seenKey = "trialLastSeen"
    private static var fileURL: URL { AppDatabase.supportDirectory.appendingPathComponent("trial.json") }

    static func loadToken() -> TrialToken? {
        guard let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["token"] as? String else { return nil }
        return TrialToken(raw)
    }

    static func save(_ token: TrialToken) {
        if let data = try? JSONSerialization.data(withJSONObject: ["token": token.raw]) {
            try? data.write(to: fileURL, options: [.atomic])
        }
        noteSeen(token.issuedAt)
    }

    /// The latest date known to have really happened (see above).
    static func now(token: TrialToken?) -> Date {
        let seen = UserDefaults.standard.double(forKey: seenKey)
        return [Date(), seen > 0 ? Date(timeIntervalSince1970: seen) : nil, token?.issuedAt].compactMap { $0 }.max() ?? Date()
    }

    static func noteSeen(_ date: Date = Date()) {
        let current = UserDefaults.standard.double(forKey: seenKey)
        if date.timeIntervalSince1970 > current { UserDefaults.standard.set(date.timeIntervalSince1970, forKey: seenKey) }
    }

    /// Whole days left, rounded up (the last day shows "1 day left"); 0 once it has ended.
    static func daysLeft(end: Date, now: Date) -> Int {
        max(0, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))
    }
}
