import AppKit
import NoteCore
import NoteDesign
import SwiftUI

struct QuickCapture: View {
    @ObservedObject var state: AppState
    let desktop: DesktopWindows
    let close: () -> Void
    let showEditor: (UUID) -> Void
    let recordShortcut: () -> Void
    @ObservedObject var shortcut: CaptureShortcut
    @ViewState private var archived = false
    @FocusState private var focused: Bool
    private enum Detail: Equatable {
        case glass, shortcut
        case delete(Note)
    }
    @ViewState private var detail: Detail?

    private var displayed: [Note] {
        state.notes.filter { ($0.completedAt != nil) == archived }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        capturePane
            .disabled(detail != nil)
            .allowsHitTesting(detail == nil)
            .accessibilityHidden(detail != nil)
            .opacity(detail == nil ? 1 : 0)
            .overlay(alignment: .topLeading) {
                switch detail {
                case .glass: GlassAdjustmentPane { detail = nil }
                case .shortcut: ShortcutSettingsPane(shortcut: shortcut, record: recordShortcut) { detail = nil }
                case .delete(let note): confirmDeletion(note)
                case nil: EmptyView()
                }
            }
            .padding(Tokens.Space.inset)
            .frame(width: Tokens.Size.menuWidth)
            .onAppear { focused = true }
            .onChange(of: detail) { _, value in focused = value == nil }
    }

    private func confirmDeletion(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
            Text("永久删除这张便签？").font(Tokens.TypeStyle.heading)
            Text(verbatim: note.text).lineLimit(3)
            Text("删除后无法恢复。").font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            HStack {
                Button("取消") { detail = nil }
                Button("永久删除", role: .destructive) {
                    if state.perform({ try state.library.deleteCompleted(note.id) }) { detail = nil }
                }
            }
        }
    }

    private var capturePane: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
            HStack {
                Text(verbatim: "GlassNotes").font(Tokens.TypeStyle.heading)
                Spacer()
                Menu {
                    Button("玻璃透明度…") { detail = .glass }
                    Divider()
                    Button("快速记录快捷键…") { detail = .shortcut }
                    Divider()
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                        as? String
                    {
                        Text("版本 \(version)")
                    } else {
                        Text("本地开发版")
                    }
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
                                    SymbolAction("永久删除便签", symbol: "trash") { detail = .delete(note) }
                                } else {
                                    SymbolAction("完成便签", symbol: "checkmark.circle") { desktop.complete(note.id) }
                                }
                            }
                        }
                    }
                }.frame(height: Tokens.Size.listHeight)
            }
            if shortcut.isUnavailable, let issue = shortcut.issue {
                Text(issue).font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            }
        }
    }
}
