import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus.
final class SearchPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
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

    override init() {
        super.init()
        panel.delegate = self
        let host = NSHostingView(rootView: SearchView(model: model, onClose: { [weak self] in self?.hide() }))
        panel.contentView = host
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        position()
        model.focusToken += 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() { panel.orderOut(nil) }

    func windowDidResignKey(_ notification: Notification) { hide() }

    var panelView: NSView? { panel.contentView }

    func debugEscape() { panel.cancelOperation(nil) }

    func debugKey(_ key: String) {}

    func debugStateDictionary() -> [String: Any] {
        ["visible": panel.isVisible, "query": model.query]
    }

    private func position() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.minY + frame.height * 0.72 - size.height / 2))
    }
}
