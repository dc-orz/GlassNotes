import AppKit
import NoteCore
import NoteDesign
import SwiftUI

struct QuickCapture: View {
    @ObservedObject var state: AppState
    let desktop: DesktopWindows
    let close: () -> Void
    let showEditor: (UUID) -> Void
    @ObservedObject var shortcut: CaptureShortcut
    @ViewState private var archived = false
    @FocusState private var focused: Bool
    @ViewState private var adjustingGlass = false

    private var displayed: [Note] {
        state.notes.filter { ($0.completedAt != nil) == archived }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        capturePane
            .disabled(adjustingGlass)
            .allowsHitTesting(!adjustingGlass)
            .accessibilityHidden(adjustingGlass)
            .opacity(adjustingGlass ? 0 : 1)
            .overlay(alignment: .topLeading) {
                if adjustingGlass { GlassAdjustmentPane { adjustingGlass = false } }
            }
            .padding(Tokens.Space.inset)
            .frame(width: Tokens.Size.menuWidth)
            .onAppear { focused = true }
            .onChange(of: adjustingGlass) { _, adjusting in focused = !adjusting }
    }

    private var capturePane: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
            HStack {
                Text(verbatim: "GlassNotes").font(Tokens.TypeStyle.heading)
                Spacer()
                Menu {
                    Button("玻璃透明度…") { adjustingGlass = true }
                    Divider()
                    Picker("快速记录快捷键", selection: Binding(get: { shortcut.choice }, set: { shortcut.select($0) })) {
                        ForEach(CaptureShortcut.Choice.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Button("退出 GlassNotes") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("设置")
            }
            ZStack(alignment: .topLeading) {
                if state.captureDraft.isEmpty {
                    Text("记下一件事…").font(Tokens.TypeStyle.ink)
                        .foregroundStyle(.secondary).padding(.leading, Tokens.Space.small)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                InkEditor(text: $state.captureDraft, label: "新便签").focused($focused)
            }
            .frame(height: Tokens.Size.inputHeight)
            HStack {
                Spacer()
                Button("贴到桌面") { if desktop.addDraft() { close() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(state.captureDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("贴到桌面（⌘↩）")
            }
            Divider()
            Picker("查看便签", selection: $archived) {
                Text("桌面").tag(false)
                Text("已完成").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            if displayed.isEmpty {
                Text(archived ? "完成的便签会保存在这里" : "桌面上还没有便签")
                    .font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: Tokens.Size.listHeight)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.tight) {
                        ForEach(displayed) { note in
                            HStack {
                                Button {
                                    if archived { desktop.restore(note.id) } else { showEditor(note.id) }
                                } label: {
                                    Text(note.title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if archived {
                                    SymbolAction("恢复到桌面", symbol: "arrow.uturn.backward") {
                                        desktop.restore(note.id)
                                    }
                                } else {
                                    SymbolAction("完成便签", symbol: "checkmark.circle") { desktop.complete(note.id) }
                                }
                            }
                        }
                    }
                }.frame(height: Tokens.Size.listHeight)
            }
            if let issue = shortcut.issue {
                Text(issue).font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            }
        }
    }
}
