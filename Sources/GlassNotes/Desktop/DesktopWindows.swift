import AppKit
import NoteCommands
import NoteCore

@MainActor
final class DesktopWindows {
    let state: AppState
    private(set) var windows: [UUID: NoteWindow] = [:]
    private let toast = UndoToast()
    init(state: AppState) { self.state = state }

    func reconcile() {
        let ids = Set(state.notes.map(\.id))
        for id in windows.keys where !ids.contains(id) {
            windows.removeValue(forKey: id)?.panel.close()
        }
        if let id = toast.noteID, !state.notes.contains(where: { $0.id == id && $0.completedAt != nil }) {
            toast.hide()
        }
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
        guard state.perform({ _ = try add(text: state.captureDraft) }) else { return false }
        state.captureDraft = ""
        return true
    }

    func add(text: String) throws -> Note {
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
        else { throw CommandError("未找到可以放置便签的显示器。") }
        let occupied = windows.values.filter { $0.card.note.completedAt == nil }.map { $0.panel.frame }
        let placement = DesktopLayout.freeSpot(
            size: NoteWindow.size(for: text),
            screen: screen.visibleFrame, display: screen.displayKey, occupied: occupied)
        return try state.library.add(text: text, at: placement)
    }

    func complete(_ id: UUID) {
        guard let entry = windows[id], entry.card.note.completedAt == nil else { return }
        if entry.card.editing && !entry.save() { return }
        state.perform { _ = try completeSavedNote(id) }
    }

    func completeSavedNote(_ id: UUID) throws -> Note {
        let entry = windows[id]
        guard entry?.card.editing != true else { throw CommandError("这张便签正在编辑，请保存或取消后再试。") }
        let frame = entry?.card.note.completedAt == nil ? entry?.panel.frame : nil
        let note = try state.library.complete(id)
        if let frame { toast.show(for: id, near: frame) { [weak self] in self?.restore(id) } }
        return note
    }

    func restore(_ id: UUID) {
        state.perform { try state.library.restore(id) }
    }

    private func finishDismissal(_ id: UUID) {
        guard let entry = windows[id], entry.card.note.completedAt != nil else { return }
        entry.panel.close()
        windows[id] = nil
    }
}
