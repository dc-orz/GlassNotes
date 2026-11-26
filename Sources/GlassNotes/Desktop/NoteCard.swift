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

    var body: some View {
        ZStack(alignment: .top) {
            GlassSurface(.desktopNote)
            VStack(alignment: .leading, spacing: Tokens.Space.tight) {
                WindowGrip().frame(height: Tokens.Size.grip).accessibilityHidden(true)
                if state.editing {
                    InkEditor(text: $state.draft, label: "便签内容")
                        .focused($editingFocus)
                    HStack {
                        Spacer()
                        SymbolAction("取消编辑", symbol: "xmark", action: cancel)
                            .keyboardShortcut(.cancelAction)
                        SymbolAction("保存便签", symbol: "checkmark", action: save)
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    ScrollView {
                        InkContent(state.note.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: edit)
                    .accessibilityAction(named: "编辑", edit)
                    .accessibilityAction(named: "完成", complete)
                    .mask(InkWipe(progress: dismissal.wipe))
                }
            }
            .padding(.horizontal, Tokens.Space.inset)
            .padding(.bottom, Tokens.Space.small)
            if !state.editing && state.note.completedAt == nil {
                SymbolAction("完成便签", symbol: "checkmark.circle", action: complete)
                    .opacity(hovering || state.keyWindow || voiceOver ? 1 : 0)
                    .padding(Tokens.Space.tight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .foregroundStyle(Tokens.NoteGlass.ink)
        .opacity(dismissal.visibility)
        .onHover { hovering = $0 }
        .onChange(of: state.editing) { _, editing in editingFocus = editing }
        .task(id: state.note.completedAt) {
            await dismissal.present(
                completed: state.note.completedAt != nil, reduceMotion: reducedMotion, didFinish: dismissed)
        }
        .contextMenu {
            Button("编辑便签", action: edit)
            Button("完成便签", action: complete).disabled(state.editing)
        }
    }

}

private struct WindowGrip: NSViewRepresentable {
    final class Grip: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
    func makeNSView(context: Context) -> Grip { Grip() }
    func updateNSView(_ view: Grip, context: Context) {}
}
