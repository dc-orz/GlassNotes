import AppKit
import NoteDesign
import SwiftUI

@MainActor
final class UndoToast {
    private(set) var noteID: UUID?
    private var panel: NSPanel?
    private var timeout: Task<Void, Never>?

    func show(for id: UUID, near source: CGRect, undo: @escaping () -> Void) {
        hide()
        let size = Tokens.Size.toast
        let screen =
            NSScreen.screens.first { $0.frame.contains(CGPoint(x: source.midX, y: source.midY)) } ?? NSScreen.main
        guard let bounds = screen?.visibleFrame else { return }
        let x = max(bounds.minX, min(source.midX - size.width / 2, bounds.maxX - size.width))
        let y = max(bounds.minY, min(source.minY - size.height - Tokens.Space.small, bounds.maxY - size.height))
        let panel = NSPanel(
            contentRect: CGRect(origin: CGPoint(x: x, y: y), size: size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.contentView = NSHostingView(
            rootView: HStack(spacing: Tokens.Space.standard) {
                Label("已完成", systemImage: "checkmark")
                Button("撤销", action: undo)
            }.frame(width: size.width, height: size.height).background(GlassSurface()))
        noteID = id
        self.panel = panel
        panel.orderFrontRegardless()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Tokens.Motion.undoSeconds))
            if !Task.isCancelled { self?.hide() }
        }
    }

    func hide() {
        noteID = nil
        timeout?.cancel()
        timeout = nil
        panel?.close()
        panel = nil
    }
}
