import AppKit
import Quartz
import SwiftUI

/// Borderless floating panel that can take keyboard focus and drive Quick Look.
final class SearchPanel: NSPanel {
    static let size = NSSize(width: 720, height: 480)
    weak var quickLook: SearchPanelController?

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) { quickLook?.hide() } // Esc

    // Quick Look panel control (found through the responder chain).
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = quickLook
        panel.delegate = quickLook
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

final class SearchPanelController: NSObject, NSWindowDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private let panel = SearchPanel()
    let model = SearchModel()
    private var keyMonitor: Any?
    /// True after ↑/↓: Space then previews instead of typing a space.
    private var listMode = false
    /// The key (⌘Y or Space) currently held to show the preview; nil when no peek is on.
    private var peekKey: UInt16?
    private var peekNeedsCommand = false
    /// macOS doesn't send key-up events for keys pressed with ⌘, so while a peek is on the key state is polled.
    private var peekTimer: Timer?

    override init() {
        super.init()
        panel.delegate = self
        panel.quickLook = self
        panel.contentView = NSHostingView(rootView: SearchView(model: model, onOpen: { [weak self] in self?.open($0) }))
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            switch event.type {
            case .keyUp: // releasing the peek key ends the preview
                if let key = self.peekKey, event.keyCode == key { self.endPeek() }
                return event
            case .flagsChanged: // releasing ⌘ ends a ⌘Y peek
                if self.peekNeedsCommand, !event.modifierFlags.contains(.command) { self.endPeek() }
                return event
            default:
                guard self.panel.isKeyWindow else { return event }
                return self.handleKey(event) ? nil : event
            }
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        position()
        listMode = false
        model.focusToken += 1
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        endPeek()
        if quickLookVisible { QLPreviewPanel.shared().orderOut(nil) }
        panel.orderOut(nil)
        clearPreviewFiles()
    }

    /// Refreshes visible results after the index changed.
    func indexDidChange() {
        if panel.isVisible && !model.query.isEmpty { model.refresh() }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Quick Look takes key focus; keep the panel open behind it.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.quickLookVisible, !self.panel.isKeyWindow else { return }
            self.hide()
        }
    }

    // MARK: - Keyboard

    enum Action { case down, up, open, reveal, copy, copyPath, trash, preview, close }

    /// Key codes used below (ANSI layout, same on every Mac keyboard).
    private enum Key {
        static let a: UInt16 = 0, z: UInt16 = 6, x: UInt16 = 7, c: UInt16 = 8, v: UInt16 = 9, y: UInt16 = 16
        static let comma: UInt16 = 43, delete: UInt16 = 51
        static let digits: [UInt16: ItemSource?] = [18: nil, 19: .file, 20: .screenshot, 21: .clipboard] // ⌘1…⌘4
    }

    private func handleKey(_ e: NSEvent) -> Bool {
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command), opt = flags.contains(.option), shift = flags.contains(.shift)
        let editor = panel.firstResponder as? NSTextView
        let hasTextSelection = (editor?.selectedRange().length ?? 0) > 0
        switch e.keyCode {
        case 125: listMode = true; perform(.down)
        case 126: listMode = true; perform(.up)
        case 36, 76:
            if cmd { perform(.reveal) } else if opt { perform(.copyPath) } else { perform(.open) }
        case 53: perform(.close)
        // Hold Space (after arrowing through results) or ⌘Y to peek at the selected result; letting go hides it.
        case 49 where listMode && !cmd: beginPeek(key: e.keyCode, needsCommand: false, repeating: e.isARepeat)
        case Key.y where cmd: beginPeek(key: e.keyCode, needsCommand: true, repeating: e.isARepeat)
        case Key.c where cmd: // ⌘C, unless the user is copying selected text in the search field
            if hasTextSelection { return false }
            guard model.selected != nil else { return false }
            perform(.copy)
        case Key.a where cmd, Key.x where cmd, Key.v where cmd, Key.z where cmd:
            // The panel has no Edit menu, so these standard editing keys are sent to the search field directly.
            guard editor != nil else { return false }
            switch e.keyCode {
            case Key.a: NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            case Key.x: NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            case Key.v: NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            default:
                guard let undo = editor?.undoManager else { return true }
                if shift { undo.redo() } else { undo.undo() }
            }
            listMode = false
        case Key.delete where cmd && listMode: perform(.trash) // ⌘⌫ on a result; in the search field it clears the line
        case Key.comma where cmd:
            hide()
            Task { @MainActor in (NSApp.delegate as? AppDelegate)?.openSettings() }
        case let code where cmd && Key.digits[code] != nil:
            model.filter = Key.digits[code] ?? nil
        default:
            if !cmd { listMode = false } // typing again
            return false
        }
        return true
    }

    func perform(_ action: Action) {
        switch action {
        case .down: model.move(1); reloadPreview()
        case .up: model.move(-1); reloadPreview()
        case .open: if let r = model.selected { open(r) }
        case .reveal: if let r = model.selected { reveal(r) }
        case .copy: if let r = model.selected { copy(r) }
        case .copyPath: if let r = model.selected { copyPath(r) }
        case .trash: if let r = model.selected { trash(r) }
        case .preview: togglePreview()
        case .close: hide()
        }
    }

    func open(_ r: SearchResult) {
        if r.source == .clipboard {
            let meta = AppDatabase.shared.metadata(itemId: r.id) ?? [:]
            hide()
            if let s = meta["url"] as? String, ClipboardWatcher.isSafeLink(s), let url = URL(string: s) {
                NSWorkspace.shared.open(url)
            } else if let path = meta["image"] as? String {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            } else {
                _ = ClipboardStore.copyToPasteboard(itemId: r.id) // text: Enter copies it
            }
            return
        }
        guard let path = r.path else { return }
        hide()
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// ⌘C: clipboard items go back on the clipboard; files are copied like in Finder.
    func copy(_ r: SearchResult) {
        if r.source == .clipboard {
            _ = ClipboardStore.copyToPasteboard(itemId: r.id)
        } else if let path = r.path {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([URL(fileURLWithPath: path) as NSURL])
        }
        hide()
    }

    func reveal(_ r: SearchResult) {
        let path = r.path ?? (AppDatabase.shared.metadata(itemId: r.id)?["image"] as? String)
        guard let path else { return }
        hide()
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// ⌥↩: the file's path goes on the clipboard as text.
    func copyPath(_ r: SearchResult) {
        guard let path = r.path else { NSSound.beep(); return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(path, forType: .string)
        hide()
    }

    /// ⌘⌫ on a file or screenshot: moves it to the Trash (never a permanent delete). Clipboard items are left alone.
    func trash(_ r: SearchResult) {
        guard r.source != .clipboard, let path = r.path else { NSSound.beep(); return }
        endPeek()
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        } catch {
            NSSound.beep()
            return
        }
        model.refresh() // the file watcher also drops it from the index
    }

    // MARK: - Quick Look

    /// Holding ⌘Y (or Space in the list) shows the preview; releasing the key hides it. The search panel keeps
    /// keyboard focus the whole time, so ↑/↓ change the previewed result while the key is held.
    private func beginPeek(key: UInt16, needsCommand: Bool, repeating: Bool) {
        if repeating { return } // key repeat while held
        guard peekKey == nil, previewURL(for: model.selected) != nil, let ql = QLPreviewPanel.shared() else { return }
        peekKey = key
        peekNeedsCommand = needsCommand
        ql.dataSource = self
        ql.delegate = self
        ql.reloadData()
        ql.orderFront(nil)
        peekTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self, let key = self.peekKey else { return }
            let held = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(key))
            let cmdHeld = NSEvent.modifierFlags.contains(.command)
            if !held || (self.peekNeedsCommand && !cmdHeld) { self.endPeek() }
        }
    }

    private func endPeek() {
        guard peekKey != nil else { return }
        peekKey = nil
        peekNeedsCommand = false
        peekTimer?.invalidate()
        peekTimer = nil
        if quickLookVisible { QLPreviewPanel.shared().orderOut(nil) }
    }

    private var quickLookVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    func togglePreview() {
        guard let ql = QLPreviewPanel.shared() else { return }
        if quickLookVisible {
            ql.orderOut(nil)
            panel.makeKey()
        } else if previewURL(for: model.selected) != nil {
            ql.makeKeyAndOrderFront(nil)
        }
    }

    private func reloadPreview() {
        if quickLookVisible { QLPreviewPanel.shared().reloadData() }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL(for: model.selected) == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL(for: model.selected) as NSURL?
    }

    /// Arrow keys, Space and Esc inside Quick Look still drive the result list.
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        switch event.keyCode {
        case 125: perform(.down); return true
        case 126: perform(.up); return true
        case 49, 53: togglePreview(); return true
        case 36, 76: togglePreview(); perform(.open); return true
        default: return false
        }
    }

    private static var previewDirectory: URL {
        let dir = AppDatabase.supportDirectory.appendingPathComponent("preview", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Files preview as themselves; clipboard text is written to a temporary .txt (removed on close).
    private func previewURL(for r: SearchResult?) -> URL? {
        guard let r else { return nil }
        if let path = r.path { return URL(fileURLWithPath: path) }
        let meta = AppDatabase.shared.metadata(itemId: r.id) ?? [:]
        if let image = meta["image"] as? String { return URL(fileURLWithPath: image) }
        guard let text = (meta["text"] as? String) ?? (meta["url"] as? String) else { return nil }
        let url = Self.previewDirectory.appendingPathComponent("clipboard-\(r.id).txt")
        if !FileManager.default.fileExists(atPath: url.path) { try? text.write(to: url, atomically: true, encoding: .utf8) }
        return url
    }

    private func clearPreviewFiles() {
        try? FileManager.default.removeItem(at: Self.previewDirectory)
    }

    // MARK: - Test hook support

    var panelView: NSView? { panel.contentView }

    func debugEscape() { perform(.close) }

    func debugKey(_ key: String) {
        switch key {
        case "down": perform(.down)
        case "up": perform(.up)
        case "enter": perform(.open)
        case "cmdenter": perform(.reveal)
        case "cmdc": perform(.copy)
        case "preview": perform(.preview)
        case "copypath": perform(.copyPath)
        default: break
        }
    }

    func debugStateDictionary() -> [String: Any] {
        [
            "visible": panel.isVisible,
            "quickLookVisible": quickLookVisible,
            "query": model.query,
            "filter": model.filter?.rawValue ?? "all",
            "selection": model.selection,
            "results": model.results.map { ["title": $0.title, "source": $0.source.rawValue, "path": $0.path ?? "", "snippet": $0.snippet] },
        ]
    }

    private func position() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.minY + frame.height * 0.72 - size.height / 2))
    }
}
