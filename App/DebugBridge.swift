#if DEBUG
import AppKit

/// Debug-only test hook so the app can be driven from the terminal
/// (`swift scripts/recall-debug.swift <command> [arg]`). Not compiled into Release builds, and only active
/// when launched with `open --env RECALL_DEBUG_BRIDGE=1`. Output files go to
/// ~/Library/Application Support/Recall/debug/ (the argument is a plain file name, never a path).
/// Commands: toggle | show | hide | esc | query <text> | key <name> | snapshot <name.png> | state <name.json>
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
        case "explain": // explain <file.json> <query>
            let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
            if p.count == 2, let url = Self.outputURL(p[0]),
               let data = try? JSONSerialization.data(withJSONObject: SearchEngine.shared.explain(p[1]), options: .prettyPrinted) {
                try? data.write(to: url)
            }
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
