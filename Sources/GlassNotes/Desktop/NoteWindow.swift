import AppKit
import CoreGraphics
import NoteCore
import NoteDesign
import SwiftUI

@MainActor
final class NoteWindow: NSObject, NSWindowDelegate {
    static let restingLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    let panel: KeyablePanel
    let card: CardState
    let state: AppState
    private var positioning = false

    init(_ note: Note, state: AppState, complete: @escaping () -> Void, dismissed: @escaping () -> Void) {
        self.state = state
        card = CardState(note)
        panel = KeyablePanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        super.init()
        panel.title = note.title
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = Self.restingLevel
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.delegate = self
        let view = NoteCard(
            state: card, edit: { [weak self] in self?.edit() },
            save: { [weak self] in self?.save() }, cancel: { [weak self] in self?.endEdit() },
            complete: complete, dismissed: dismissed)
        panel.contentView = NSHostingView(rootView: view)
        update(note)
        panel.orderFrontRegardless()
    }

    static func size(for text: String) -> CGSize {
        text.count > 22 || text.components(separatedBy: .newlines).count > 2
            ? Tokens.Size.longNote : Tokens.Size.shortNote
    }

    func update(_ note: Note) {
        if card.note != note { card.note = note }
        panel.title = note.title
        panel.appearance = note.ink.style.appearance
        guard let screen = NSScreen.forNote(note) else { return }
        let frame = DesktopLayout.frame(
            for: note.placement, size: Self.size(for: note.text), in: screen.visibleFrame)
        guard frame != panel.frame else { return }
        positioning = true
        panel.setFrame(frame, display: true)
        positioning = false
    }

    func edit() {
        guard card.note.completedAt == nil else { return }
        card.beginEditing()
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
    }

    func endEdit() {
        card.editing = false
        panel.level = Self.restingLevel
    }

    @discardableResult func save() -> Bool {
        let ok = state.perform { try state.library.edit(card.note.id, text: card.draft, ink: card.ink) }
        if ok { endEdit() }
        return ok
    }

    func windowDidMove(_ notification: Notification) {
        guard !positioning, let screen = panel.screen else { return }
        let note = card.note
        // AppKit can post a move notification after a programmatic display remap.
        if let target = NSScreen.forNote(note),
            DesktopLayout.frame(for: note.placement, size: Self.size(for: note.text), in: target.visibleFrame)
                == panel.frame
        {
            return
        }
        let placement = DesktopLayout.placement(
            of: panel.frame, in: screen.visibleFrame, display: screen.displayKey)
        if !state.perform({ try state.library.move(note.id, to: placement) }) { update(note) }
    }

    func windowDidBecomeKey(_ notification: Notification) { card.keyWindow = true }
    func windowDidResignKey(_ notification: Notification) {
        card.keyWindow = false
        // Keep the editor and draft available; only its temporary floating level changes.
        panel.level = Self.restingLevel
    }
}
