import NoteDesign
import SwiftUI

struct CLILinkPane: View {
    @ObservedObject var settings: CLILinkSettings
    let reminder: Bool
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
            HStack {
                Text("命令行工具").font(Tokens.TypeStyle.heading)
                Spacer()
                Button(reminder && settings.shouldRemind ? "稍后" : "完成", action: done)
            }
            Text(verbatim: CLILink.defaultCommand.path).textSelection(.enabled)
            switch settings.status {
            case .missing:
                Text("启用后，终端和 agent 可以用 glassnotes 管理便签。")
                Button(settings.installing ? "正在启用…" : "启用命令行", action: settings.install)
                    .disabled(settings.installing)
                    .keyboardShortcut(.defaultAction)
            case .installed:
                Text("已启用。可在终端运行 glassnotes list --json。")
            case .occupied:
                Text("此路径已被其他文件或链接占用。请移走它，再重新检测。")
                Button("重新检测", action: settings.refresh)
            case .unavailable(let reason):
                Text(verbatim: reason)
                Button("重新检测", action: settings.refresh)
            }
            if let message = settings.message {
                Text(verbatim: message).font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
            }
            Toggle("启动时不再提醒", isOn: $settings.suppressReminder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { settings.refresh() }
    }
}
