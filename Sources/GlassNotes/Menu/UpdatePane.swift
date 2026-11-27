import NoteDesign
import SwiftUI

struct UpdatePane: View {
    let checkForUpdate: @MainActor () async throws -> ReleaseCheck.Result
    let done: () -> Void
    private enum Phase {
        case checking
        case finished(ReleaseCheck.Result)
        case failed(String)
    }
    @ViewState private var phase = Phase.checking
    @ViewState private var attempt = 0

    private var doneShortcut: KeyboardShortcut? {
        if case .finished = phase { .defaultAction } else { nil }
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
            switch phase {
            case .checking:
                ProgressView("正在检查更新…")
            case .finished(let result):
                LabeledContent("最新版本", value: result.latest)
                switch result.status {
                case .available: Text("有新版本可用")
                case .upToDate: Text("已是最新版本")
                case .unknownInstalledVersion: Text("无法与当前开发版本比较。")
                }
                if result.status != .upToDate {
                    Link("查看更新说明和下载", destination: result.url)
                }
            case .failed(let reason):
                Text("检查更新失败").font(Tokens.TypeStyle.heading)
                Text(verbatim: reason)
                Button("重试") {
                    phase = .checking
                    attempt += 1
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: attempt) {
            do {
                let result = try await checkForUpdate()
                if !Task.isCancelled { phase = .finished(result) }
            } catch {
                if !Task.isCancelled { phase = .failed(error.localizedDescription) }
            }
        }
    }
}
