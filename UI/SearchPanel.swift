import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus.
final class SearchPanel: NSPanel {
    static let size = NSSize(width: 720, height: 460)

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

    override func cancelOperation(_ sender: Any?) { close() } // Esc
}

final class SearchPanelController: NSObject, NSWindowDelegate {
    private let panel = SearchPanel()
    let model = SearchModel()
    private var keyMonitor: Any?

    override init() {
        super.init()
        panel.delegate = self
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
        model.focusToken += 1
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() { panel.orderOut(nil) }

    func windowDidResignKey(_ notification: Notification) { hide() }

    // MARK: - Keyboard

    enum Action { case down, up, open, reveal, close }

    private func handleKey(_ e: NSEvent) -> Bool {
        let cmd = e.modifierFlags.contains(.command)
        switch e.keyCode {
        case 125: perform(.down)
        case 126: perform(.up)
        case 36, 76: perform(cmd ? .reveal : .open)
        case 53: perform(.close)
        default: return false
        }
        return true
    }

    func perform(_ action: Action) {
        switch action {
        case .down: model.move(1)
        case .up: model.move(-1)
        case .open: if let r = model.selected { open(r) }
        case .reveal: if let r = model.selected { reveal(r) }
        case .close: hide()
        }
    }

    func open(_ r: SearchResult) {
        guard let path = r.path else { return }
        hide()
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func reveal(_ r: SearchResult) {
        guard let path = r.path else { return }
        hide()
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
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
        default: break
        }
    }

    func debugStateDictionary() -> [String: Any] {
        [
            "visible": panel.isVisible,
            "query": model.query,
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
