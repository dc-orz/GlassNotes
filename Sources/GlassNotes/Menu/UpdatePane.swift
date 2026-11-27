import NoteDesign
import SwiftUI

struct UpdatePane: View {
    @ObservedObject var updates: UpdateSession
    let done: () -> Void
    @ViewState private var attempt = 0
    @ViewState private var now = Date.now

    private var doneShortcut: KeyboardShortcut? {
        switch updates.phase {
        case .checked(let result) where result.package == nil: .defaultAction
        case .installed: .defaultAction
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.section) {
            HStack {
                Text("检查更新").font(Tokens.TypeStyle.heading)
                Spacer()
                Button("完成", action: done)
                    .keyboardShortcut(doneShortcut)
            }
            LabeledContent("当前版本", value: ReleaseCheck.installedVersion ?? "本地开发版")
            switch updates.phase {
            case .checking:
                ProgressView("正在检查更新…")
            case .checked(let result):
                LabeledContent("最新版本", value: result.latest)
                switch result.status {
                case .available:
                    if result.package != nil {
                        Button("下载并安装", action: updates.install)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Text("此版本没有适用于这台 Mac 且可校验的安装包。")
                    }
                case .upToDate: Text("已是最新版本")
                case .unknownInstalledVersion: Text("无法与当前开发版本比较。")
                }
                if result.status != .upToDate {
                    Link("查看 GitHub 发布说明", destination: result.url)
                }
            case .installing(let package):
                ProgressView("正在下载并安装 \(package.version)…")
            case .installed(let version):
                Text("已安装 \(version)").font(Tokens.TypeStyle.heading)
                Text("请退出并重新打开 GlassNotes 以使用新版。")
            case .installFailed(let result, let reason):
                Text("安装更新失败").font(Tokens.TypeStyle.heading)
                Text(verbatim: reason)
                HStack {
                    Button("重试安装", action: updates.install).keyboardShortcut(.defaultAction)
                    Button("重新检查") { attempt += 1 }
                }
                Link("查看 GitHub 发布说明", destination: result.url)
            case .checkFailed(let reason, let retryAt):
                Text("检查更新失败").font(Tokens.TypeStyle.heading)
                Text(verbatim: reason)
                Button("重试") { attempt += 1 }
                    .keyboardShortcut(.defaultAction)
                    .disabled(retryAt.map { $0 > now } ?? false)
                    .task(id: retryAt) {
                        guard let retryAt else { return }
                        try? await Task.sleep(for: .seconds(max(0, retryAt.timeIntervalSinceNow)))
                        if !Task.isCancelled { now = .now }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: attempt) { await updates.check(refreshAfterFailure: attempt > 0) }
    }
}
