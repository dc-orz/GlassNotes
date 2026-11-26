import AppKit
import NoteDesign
import SwiftUI

@MainActor
final class StatusMenu: NSObject, NSWindowDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let panel = KeyablePanel(
        contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered, defer: false)
    private let state: AppState
    private let desktop: DesktopWindows
    private let shortcut: CaptureShortcut

    init(state: AppState, desktop: DesktopWindows, shortcut: CaptureShortcut) {
        self.state = state
        self.desktop = desktop
        self.shortcut = shortcut
        super.init()
        if let button = item.button {
            if let mark = Bundle.main.image(forResource: "MenuBarTemplate") {
                button.image = MenuBarMark.image(ink: mark)
            } else {
                button.image = NSImage(
                    systemSymbolName: "square.and.pencil", accessibilityDescription: "GlassNotes")
            }
            button.setAccessibilityLabel("GlassNotes")
            button.toolTip = "GlassNotes · 快速记录"
            button.target = self
            button.action = #selector(toggle)
        }
        panel.title = "快速记录"
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
    }

    @objc func toggle() {
        if panel.isVisible { close() } else { show() }
    }

    @objc func show() {
        guard !panel.isVisible else {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let view = QuickCapture(
            state: state, desktop: desktop, close: { [weak self] in self?.close() },
            showEditor: { [weak self] id in
                self?.close()
                self?.desktop.windows[id]?.edit()
            }, shortcut: shortcut
        )
        .background(GlassSurface())
        .onExitCommand { [weak self] in self?.close() }
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        let anchor = item.button.flatMap { button in
            button.window?.convertToScreen(button.convert(button.bounds, to: nil))
        }
        let screen =
            NSScreen.screens.first { screen in
                anchor.map { screen.frame.intersects($0) } ?? false
            } ?? NSScreen.main
        guard let bounds = screen?.visibleFrame else { return }
        let size = host.fittingSize
        let x = min(bounds.maxX - size.width, max(bounds.minX, (anchor?.midX ?? bounds.maxX) - size.width / 2))
        let y = bounds.maxY - size.height - Tokens.Space.tight
        panel.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() { panel.orderOut(nil) }

    func windowDidResignKey(_ notification: Notification) { close() }
}
