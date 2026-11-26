import AppKit
import NoteCore

@MainActor
final class DesktopWindows {
    let state: AppState
    private(set) var windows: [UUID: NoteWindow] = [:]
    private let toast = UndoToast()
    init(state: AppState) { self.state = state }

    func reconcile() {
        for note in state.notes {
            if let existing = windows[note.id] {
                existing.update(note)
            } else if note.completedAt == nil {
                windows[note.id] = NoteWindow(
                    note, state: state,
                    complete: { [weak self] in
                        self?.complete(note.id)
                    }, dismissed: { [weak self] in self?.finishDismissal(note.id) })
            }
        }
    }

    func addDraft() -> Bool {
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
        else { return false }
        let occupied = windows.values.filter { $0.card.note.completedAt == nil }.map { $0.panel.frame }
        let placement = DesktopLayout.freeSpot(
            size: NoteWindow.size(for: state.captureDraft),
            screen: screen.visibleFrame, display: screen.displayKey, occupied: occupied)
        guard
            state.perform({ try state.library.add(text: state.captureDraft, at: placement) }
            )
        else { return false }
        state.captureDraft = ""
        return true
    }

    func complete(_ id: UUID) {
        guard let entry = windows[id], entry.card.note.completedAt == nil else { return }
        if entry.card.editing && !entry.save() { return }
        let frame = entry.panel.frame
        guard state.perform({ try state.library.complete(id) }) else { return }
        toast.show(near: frame) { [weak self] in self?.restore(id) }
    }

    func restore(_ id: UUID) {
        if state.perform({ try state.library.restore(id) }) { toast.hide() }
    }

    private func finishDismissal(_ id: UUID) {
        guard let entry = windows[id], entry.card.note.completedAt != nil else { return }
        entry.panel.close()
        windows[id] = nil
    }
}
