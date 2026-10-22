#if DEBUG
import AppKit
import ServiceManagement

/// Debug-only test hook so the app can be driven from the terminal
/// (`swift scripts/recall-debug.swift <command> [arg]`). Not compiled into Release builds, and only active
/// when launched with `open --env RECALL_DEBUG_BRIDGE=1`. Output files go to
/// ~/Library/Application Support/Recall/debug/ (the argument is a plain file name, never a path).
/// Commands: toggle | show | hide | esc | query <text> | key <name> | snapshot <name.png> | state <name.json>
@MainActor
final class DebugBridge {
    static let notification = Notification.Name("dev.recall.debug")
    private let panel: SearchPanelController

    static var isEnabled: Bool { ProcessInfo.processInfo.environment["RECALL_DEBUG_BRIDGE"] == "1" }

    static var outputDirectory: URL {
        let dir = AppDatabase.supportDirectory.appendingPathComponent("debug", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Accepts only a bare file name (no slashes, no "..").
    static func outputURL(_ name: String) -> URL? {
        guard !name.isEmpty, !name.contains("/"), !name.contains(".."), !name.hasPrefix(".") else { return nil }
        return outputDirectory.appendingPathComponent(name)
    }

    init?(panel: SearchPanelController) {
        guard Self.isEnabled else { return nil }
        self.panel = panel
        DistributedNotificationCenter.default().addObserver(
            forName: Self.notification, object: nil, queue: .main
        ) { [weak self] note in
            guard let raw = note.object as? String else { return }
            self?.handle(raw)
        }
    }

    private func handle(_ raw: String) {
        let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts.first ?? ""
        let arg = parts.count > 1 ? parts[1] : ""
        switch cmd {
        case "toggle": panel.toggle()
        case "show": panel.show()
        case "hide": panel.hide()
        case "esc": panel.debugEscape()
        case "query": panel.model.query = arg
        case "key": panel.debugKey(arg)
        case "snapshot": if let url = Self.outputURL(arg) { panel.debugSnapshot(to: url) }
        case "state": if let url = Self.outputURL(arg) { panel.debugState(to: url) }
        case "filter": panel.model.filter = ItemSource(rawValue: arg)
        case "settings":
            let delegate = NSApp.delegate as? AppDelegate
            if let tab = SettingsTab(rawValue: arg) { delegate?.showSettings(on: tab) } else { delegate?.openSettings() }
        case "settingsSnapshot":
            if let url = Self.outputURL(arg), let w = NSApp.windows.first(where: { $0.title == "Recall Settings" }),
               let view = w.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
        case "login": // login on|off|status <file.json>
            let p = arg.split(separator: " ").map(String.init)
            if p.first == "on" { try? SMAppService.mainApp.register() }
            if p.first == "off" { try? SMAppService.mainApp.unregister() }
            if p.count == 2, let url = Self.outputURL(p[1]) {
                try? "\(SMAppService.mainApp.status.rawValue)".write(to: url, atomically: true, encoding: .utf8)
            }
        case "bench": // bench <file.json> <query>: times full searches (keyword + meaning + load)
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard p.count == 2, let url = Self.outputURL(p[0]) else { break }
            let query = p[1]
            DispatchQueue.global(qos: .userInitiated).async {
                _ = SearchEngine.shared.search(query) // warm-up
                var times: [Double] = []
                for _ in 0..<20 {
                    let t = CFAbsoluteTimeGetCurrent()
                    _ = SearchEngine.shared.search(query)
                    times.append((CFAbsoluteTimeGetCurrent() - t) * 1000)
                }
                times.sort()
                let out: [String: Any] = ["query": query, "median_ms": times[10], "max_ms": times[19],
                                          "vectors": VectorIndex.shared.count]
                if let data = try? JSONSerialization.data(withJSONObject: out) { try? data.write(to: url) }
            }
        case "benchvec": // benchvec <file.json>: meaning search over 50k / 200k synthetic vectors
            guard let url = Self.outputURL(arg) else { break }
            DispatchQueue.global(qos: .userInitiated).async {
                var out: [String: Any] = [:]
                for n in [50_000, 200_000] {
                    let index = VectorIndex()
                    index.loadRandom(count: n, dimension: 300)
                    var q = (0..<300).map { _ in Float.random(in: -1...1) }
                    let norm = sqrt(q.reduce(0) { $0 + $1 * $1 }); q = q.map { $0 / norm }
                    var times: [Double] = []
                    for _ in 0..<10 {
                        let t = CFAbsoluteTimeGetCurrent()
                        _ = index.search(q, source: nil, limit: 40, minScore: 0.25)
                        times.append((CFAbsoluteTimeGetCurrent() - t) * 1000)
                    }
                    times.sort()
                    out["\(n)_median_ms"] = times[5]
                }
                if let data = try? JSONSerialization.data(withJSONObject: out) { try? data.write(to: url) }
            }
        case "embed": // embed <file.json> <text>: embedder id, token ids (MiniLM) and vector
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard p.count == 2, let url = Self.outputURL(p[0]), let e = Embedding.shared else { break }
            let text = p[1].replacingOccurrences(of: "\\n", with: "\n")
            var out: [String: Any] = ["id": e.id, "embedding": (e.embed(text) ?? []).map(Double.init)]
            if let m = e as? MiniLMEmbedder { out["ids"] = m.tokenIds(text).map(Int.init) }
            let t = CFAbsoluteTimeGetCurrent()
            for _ in 0..<20 { _ = e.embed(text) }
            out["ms_per_embed"] = (CFAbsoluteTimeGetCurrent() - t) * 1000 / 20
            if let data = try? JSONSerialization.data(withJSONObject: out) { try? data.write(to: url) }
        case "status": // status <file.json>: folders the app sees + indexing state
            guard let url = Self.outputURL(arg) else { break }
            let st = IndexStatus.shared
            let out: [String: Any] = [
                "folders": Preferences.indexedFolders.map(\.path),
                "isIndexing": st.isIndexing, "phase": st.phase, "done": st.done, "total": st.total,
                "denied": st.deniedFolders.map(\.path), "items": st.itemCount,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: out, options: .prettyPrinted) { try? data.write(to: url) }
        case "explain": // explain <file.json> <query>
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            if p.count == 2, let url = Self.outputURL(p[0]),
               let data = try? JSONSerialization.data(withJSONObject: SearchEngine.shared.explain(p[1]), options: .prettyPrinted) {
                try? data.write(to: url)
            }
        case "license": // license <file.json>: Pro state as the app sees it
            guard let url = Self.outputURL(arg) else { break }
            let lm = LicenseManager.shared
            var out: [String: Any] = ["pro": Pro.isActive, "device": DeviceID.current,
                                      "server": LicenseManager.serverURL?.absoluteString ?? "none",
                                      "activeFolders": Preferences.activeFolders.map(\.path),
                                      "savedFolders": Preferences.indexedFolders.map(\.path)]
            if let t = lm.token {
                out["licenseId"] = t.licenseId
                out["recheckAfter"] = t.recheckAfter.timeIntervalSince1970
            }
            if let data = try? JSONSerialization.data(withJSONObject: out, options: .prettyPrinted) { try? data.write(to: url) }
        case "activate": // activate <file.json> <key>: writes "ok" or the error message
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard p.count == 2, let url = Self.outputURL(p[0]) else { break }
            Task { @MainActor in
                var result = "ok"
                do { try await LicenseManager.shared.activate(key: p[1]) } catch { result = error.localizedDescription }
                try? result.write(to: url, atomically: true, encoding: .utf8)
            }
        case "deactivate": // deactivate <file.txt>
            guard let url = Self.outputURL(arg) else { break }
            Task { @MainActor in
                var result = "ok"
                do { try await LicenseManager.shared.deactivate() } catch { result = error.localizedDescription }
                try? result.write(to: url, atomically: true, encoding: .utf8)
            }
        case "recheck": LicenseManager.shared.refreshIfDue(force: true)
        case "update": Updates.shared.checkNow() // interactive check (Sparkle window)
        case "update-silent": Updates.shared.debugSilentUpdate() // download now, install on quit
        case "version": // version <file.txt>
            if let url = Self.outputURL(arg) {
                let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
                try? v.write(to: url, atomically: true, encoding: .utf8)
            }
        case "search": // search <file.json> <query>: titles + sources of what the panel would show
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard p.count == 2, let url = Self.outputURL(p[0]) else { break }
            let results = SearchEngine.shared.search(p[1]).map { "\($0.source.rawValue): \($0.title)" }
            let out: [String: Any] = ["results": results, "locked": SearchEngine.isLockedQuery(p[1], filter: nil)]
            if let data = try? JSONSerialization.data(withJSONObject: out, options: .prettyPrinted) { try? data.write(to: url) }
        default: NSLog("DebugBridge: unknown command \(raw)")
        }
    }
}

extension SearchPanelController {
    func debugSnapshot(to url: URL) {
        guard let view = panelView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    func debugState(to url: URL) {
        let state = debugStateDictionary()
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }
}
#endif
