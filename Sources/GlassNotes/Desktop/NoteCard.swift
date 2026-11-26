import AppKit
import NoteCore
import NoteDesign
import SwiftUI

@MainActor
final class CardState: ObservableObject {
    @Published var note: Note
    @Published var editing = false
    @Published var keyWindow = false
    @Published var draft: String

    init(_ note: Note) {
        self.note = note
        draft = note.text
    }

    func beginEditing() {
        guard !editing, note.completedAt == nil else { return }
        draft = note.text
        editing = true
    }
}

struct NoteCard: View {
    @ObservedObject var state: CardState
    let edit: () -> Void
    let save: () -> Void
    let cancel: () -> Void
    let complete: () -> Void
    let dismissed: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @FocusState private var editingFocus: Bool
    @ViewState private var hovering = false
    @StateObject private var dismissal = InkDismissal()
    private var glass = DesktopGlassPreference()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if state.editing {
                    InkEditor(text: $state.draft, label: "便签内容")
                        .focused($editingFocus)
                } else {
                    ScrollView {
                        InkContent(state.note.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityAction(named: "编辑", edit)
                    .accessibilityAction(named: "完成", complete)
                    .mask(InkWipe(progress: dismissal.wipe))
                }
            }
            .padding([.horizontal, .top], Tokens.Space.inset)
            .padding(.bottom, Tokens.Size.action + Tokens.Space.small)

            if state.note.completedAt == nil {
                HStack(spacing: Tokens.Space.tight) {
                    if state.editing {
                        SymbolAction("取消编辑", symbol: "xmark", action: cancel)
                            .keyboardShortcut(.cancelAction)
                        SymbolAction("保存便签", symbol: "checkmark", action: save)
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        SymbolAction("编辑便签", symbol: "pencil", action: edit)
                        SymbolAction("完成便签", symbol: "checkmark.circle", action: complete)
                    }
                }
                .opacity(state.editing || hovering || state.keyWindow || voiceOver ? 1 : 0)
                .background(NoteActionBounds().accessibilityHidden(true))
                .padding(Tokens.Space.tight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .desktopNoteGlass(glass.selection)
        .opacity(dismissal.visibility)
        .onHover { hovering = $0 }
        .onChange(of: state.editing) { _, editing in editingFocus = editing }
        .task(id: state.note.completedAt) {
            await dismissal.present(
                completed: state.note.completedAt != nil, reduceMotion: reducedMotion, didFinish: dismissed)
        }
    }
}
