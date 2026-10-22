import AppKit
import Combine
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let panel = SearchPanelController()
    private let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseMenuItem = NSMenuItem(title: "Pause Indexing", action: #selector(togglePause), keyEquivalent: "")
    #if DEBUG
    private var debugBridge: DebugBridge?
    #endif

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

        IndexStatus.shared.itemCount = AppDatabase.shared.itemCount()
        startWatching()
        NotificationCenter.default.addObserver(self, selector: #selector(foldersChanged), name: .indexedFoldersChanged, object: nil)
        startClipboard()
        Task.detached(priority: .utility) {
            await EmbeddingWorker.shared.updatePendingCount()
            await EmbeddingWorker.shared.kick()
            await Indexer.shared.fullScan()
            VectorIndex.shared.reload() // drops vectors of deleted items
            await EmbeddingWorker.shared.kick()
        }
    }

    private lazy var watcher = FolderWatcher { [weak self] paths in
        Task.detached(priority: .utility) {
            if await Indexer.shared.handleChanges(paths) {
                await EmbeddingWorker.shared.kick()
                await MainActor.run { self?.panel.indexDidChange() }
            }
        }
    }

    /// Watches every indexed folder (plus the screenshot folder) for live updates.
    private func startWatching() {
        var folders = Preferences.indexedFolders
        if !folders.contains(where: { $0.path == Preferences.screenshotFolder.path }) {
            folders.append(Preferences.screenshotFolder)
        }
        watcher.start(folders: folders)
    }

    /// Called when the folder list changes in Settings.
    @objc private func foldersChanged() {
        startWatching()
        Task.detached(priority: .utility) {
            await Indexer.shared.fullScan()
            await Indexer.shared.removeItemsOutsideIndexedFolders()
            VectorIndex.shared.reload()
            await EmbeddingWorker.shared.kick()
        }
    }

    // MARK: - Clipboard

    private let clipboard = ClipboardWatcher()
    private var retentionTimer: Timer?

    func updateClipboardWatching() {
        if Preferences.clipboardEnabled {
            clipboard.onStored = { [weak self] in
                Task { await EmbeddingWorker.shared.kick() }
                IndexStatus.shared.itemCount = AppDatabase.shared.itemCount()
                self?.panel.indexDidChange()
            }
            clipboard.start()
        } else {
            clipboard.stop()
        }
    }

    private func startClipboard() {
        updateClipboardWatching()
        let cleanup = { DispatchQueue.global(qos: .utility).async {
            ClipboardStore.applyRetention(days: Preferences.clipboardRetentionDays)
            AppDatabase.shared.sweepOrphanFiles()
        } }
        cleanup()
        retentionTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in cleanup() }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Search…", action: #selector(openSearch), keyEquivalent: "").target = self
        menu.addItem(.separator())
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Recall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let status = IndexStatus.shared
        statusMenuItem.title = status.summary
        pauseMenuItem.title = status.isPaused ? "Resume Indexing" : "Pause Indexing"
    }

    @objc private func openSearch() { panel.show() }

    @objc private func togglePause() {
        let paused = !IndexStatus.shared.isPaused
        Task {
            await Indexer.shared.setPaused(paused)
            await EmbeddingWorker.shared.setPaused(paused)
        }
    }
}
