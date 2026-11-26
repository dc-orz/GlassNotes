import AppKit
import SwiftUI

/// Route the initial press before a text or scroll view can claim the mouse drag.
/// Scroll-wheel events, keyboard input and the action buttons retain normal AppKit dispatch.
final class NotePanel: KeyablePanel {
    private let card: CardState
    fileprivate weak var actionBounds: NSView?

    init(card: CardState) {
        self.card = card
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    }

    func isMoveArea(at windowPoint: NSPoint) -> Bool {
        guard !card.editing, card.note.completedAt == nil, let contentView,
            contentView.bounds.contains(contentView.convert(windowPoint, from: nil)),
            let actionBounds, actionBounds.window === self
        else { return false }
        return !actionBounds.bounds.contains(actionBounds.convert(windowPoint, from: nil))
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, isMoveArea(at: event.locationInWindow) {
            performDrag(with: event)
        } else {
            super.sendEvent(event)
        }
    }
}

/// Read the bounds of the rendered button row rather than duplicating its geometry.
struct NoteActionBounds: NSViewRepresentable {
    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            (window as? NotePanel)?.actionBounds = self
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Anchor { Anchor() }
    func updateNSView(_ view: Anchor, context: Context) {}
}
