import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleSearch = Self("toggleSearch", default: .init(.space, modifiers: [.option]))
}

@main
enum RecallMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu-bar only, backs up LSUIElement
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let panel = SearchPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Recall")
        statusItem.menu = buildMenu()

        KeyboardShortcuts.onKeyUp(for: .toggleSearch) { [weak self] in
            self?.panel.toggle()
        }
        #if DEBUG
        debugBridge = DebugBridge(panel: panel)
        #endif
    }

    #if DEBUG
    private var debugBridge: DebugBridge?
    #endif

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Search…", action: #selector(openSearch), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Recall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func openSearch() { panel.show() }
}
