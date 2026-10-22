#if DEBUG
import AppKit

/// Debug-only test hook so the app can be driven from the terminal
/// (`swift scripts/recall-debug.swift <command> [arg]`). Not compiled into Release builds.
/// Commands: toggle | show | hide | esc | query <text> | key <down|up|enter|cmdenter|cmdc|space> | snapshot <png path> | state <json path>
final class DebugBridge {
    static let notification = Notification.Name("dev.recall.debug")
    private let panel: SearchPanelController

    init(panel: SearchPanelController) {
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
        case "snapshot": panel.debugSnapshot(to: URL(fileURLWithPath: arg))
        case "state": panel.debugState(to: URL(fileURLWithPath: arg))
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
