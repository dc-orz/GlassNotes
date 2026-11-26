import SwiftUI

/// Drives both layers of one completion. The caller owns the task so undo can cancel it.
@MainActor
public final class InkDismissal: ObservableObject {
    @Published public private(set) var wipe: CGFloat = 0
    @Published public private(set) var visibility = 1.0

    public init() {}

    public func present(completed: Bool, reduceMotion: Bool, didFinish: () -> Void) async {
        guard completed else {
            wipe = 0
            visibility = 1
            return
        }
        do {
            if !reduceMotion {
                withAnimation(.linear(duration: Tokens.Motion.erase)) { wipe = 1 }
                try await Task.sleep(for: .seconds(Tokens.Motion.erase))
            }
            let duration = reduceMotion ? Tokens.Motion.reduced : Tokens.Motion.dismiss
            withAnimation(.easeOut(duration: duration)) { visibility = 0 }
            try await Task.sleep(for: .seconds(duration))
            didFinish()
        } catch {
            // The owner cancelled this task when the note was restored or the view closed.
        }
    }
}
