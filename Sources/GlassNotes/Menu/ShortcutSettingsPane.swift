import NoteDesign
import SwiftUI

struct ShortcutSettingsPane: View {
    @ObservedObject var shortcut: CaptureShortcut
    let record: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.section) {
            HStack {
                Text("快速记录快捷键").font(Tokens.TypeStyle.heading)
                Spacer()
                Button("完成", action: done)
            }
            LabeledContent("当前快捷键", value: shortcut.chord?.title ?? "已关闭")
            HStack {
                Button(shortcut.isRecording ? "取消录制" : "录制快捷键…") {
                    if shortcut.isRecording { shortcut.cancelRecording() } else { record() }
                }
                Menu("预设") {
                    Button(CaptureChord.standard.title) { shortcut.select(.standard) }
                    Button(CaptureChord.commandShift.title) { shortcut.select(.commandShift) }
                    Divider()
                    Button("关闭快捷键") { shortcut.select(nil) }
                }.fixedSize().disabled(shortcut.isRecording)
            }
            if let issue = shortcut.issue {
                Text(issue).font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            } else if shortcut.isRecording {
                Text("按下想用的组合键，或按 Esc 取消。")
                    .font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear { shortcut.cancelRecording() }
    }
}
