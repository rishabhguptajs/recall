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

    override init() {
        super.init()
        panel.delegate = self
        panel.quickLook = self
        panel.contentView = NSHostingView(rootView: SearchView(model: model, onOpen: { [weak self] in self?.open($0) }))
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
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

    enum Action { case down, up, open, reveal, copy, preview, close }

    private func handleKey(_ e: NSEvent) -> Bool {
        let cmd = e.modifierFlags.contains(.command)
        switch e.keyCode {
        case 125: listMode = true; perform(.down)
        case 126: listMode = true; perform(.up)
        case 36, 76: perform(cmd ? .reveal : .open)
        case 53: perform(.close)
        case 49 where listMode && !cmd: perform(.preview) // Space after arrowing through results
        case 16 where cmd: perform(.preview)             // ⌘Y, like Finder
        case 8 where cmd: // ⌘C, unless the user is copying selected text in the search field
            if let editor = panel.firstResponder as? NSTextView, editor.selectedRange().length > 0 { return false }
            guard model.selected != nil else { return false }
            perform(.copy)
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

    // MARK: - Quick Look

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
