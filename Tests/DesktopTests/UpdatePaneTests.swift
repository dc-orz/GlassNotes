import AppKit
import NoteCore
import SwiftUI
import Testing

@testable import GlassNotes

extension NativeDesktopTests {
    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"),
        arguments: [false, true])
    func keyboardRetriesUpdateAndReturnsToCapture(rateLimited: Bool) async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let state = AppState(library: try NoteLibrary(directory: folder))
        let panel = KeyablePanel(
            contentRect: NSRect(x: 80, y: 80, width: 360, height: 420),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }

        var requests = 0
        var retryAt = Date.distantPast
        let capture = QuickCapture(
            state: state, desktop: DesktopWindows(state: state), close: {}, showEditor: { _ in },
            recordShortcut: {}, shortcut: CaptureShortcut {},
            checkForUpdate: {
                requests += 1
                if requests == 1 {
                    if rateLimited {
                        retryAt = Date.now.addingTimeInterval(1)
                        throw ReleaseCheck.Failure.rateLimited(until: retryAt)
                    }
                    throw ReleaseCheck.Failure.http(503)
                }
                return ReleaseCheck.Result(
                    latest: "0.2.0", url: URL(string: "https://github.com/dc-orz/GlassNotes/releases/tag/v0.2.0")!,
                    status: .available)
            }, detail: .update)
        panel.contentView = NSHostingView(rootView: capture)
        panel.makeKeyAndOrderFront(nil)
        let enter = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        func waitForUI(_ condition: () -> Bool) async throws -> Bool {
            let deadline = ContinuousClock.now + .seconds(3)
            while !condition() {
                guard ContinuousClock.now < deadline else { return false }
                try await Task.sleep(for: .milliseconds(20))
            }
            return true
        }
        if rateLimited {
            try #require(try await waitForUI { requests == 1 })
            _ = panel.performKeyEquivalent(with: enter)
            try await Task.sleep(for: .milliseconds(50))
            try #require(requests == 1)
        }
        // Return activates Retry after the failure, then Done after the successful response.
        try #require(
            try await waitForUI { requests == 1 && Date.now >= retryAt && panel.performKeyEquivalent(with: enter) }
        )
        try #require(try await waitForUI { requests == 2 && panel.performKeyEquivalent(with: enter) })
        try #require(try await waitForUI { panel.firstResponder is NSTextView })
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.insertText("重试后继续记录", replacementRange: NSRange(location: 0, length: 0))
        #expect(state.captureDraft == "重试后继续记录")
        #expect(requests == 2)
    }
}
