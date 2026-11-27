import AppKit
import NoteCore
import SwiftUI
import Testing

@testable import GlassNotes

extension NativeDesktopTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func menuPanelHasTransparentCorners() async throws {
        guard #available(macOS 14.4, *) else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let state = AppState(library: try NoteLibrary(directory: folder))
        let menu = StatusMenu(state: state, desktop: DesktopWindows(state: state), shortcut: CaptureShortcut {})
        menu.show()
        let panel = try #require(app.windows.first { $0.title == "快速记录" && $0.isVisible })
        defer { if panel.isVisible { menu.toggle() } }

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            panel.appearance = NSAppearance(named: appearance)
            try await Task.sleep(for: .milliseconds(350))
            let bitmap = try await windowBitmap(of: panel)
            let center = try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            #expect(center.alphaComponent > 0)
            for x in [1, bitmap.pixelsWide - 2] {
                for y in [1, bitmap.pixelsHigh - 2] {
                    #expect(
                        bitmap.colorAt(x: x, y: y)?.alphaComponent == 0, "Corner (\(x), \(y)) in \(appearance)")
                }
            }
        }
    }

    @Test(
        .enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"),
        arguments: [NSAppearance.Name.aqua, .darkAqua])
    func capturePlaceholderFollowsMarkedText(appearance: NSAppearance.Name) async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let state = AppState(library: try NoteLibrary(directory: folder))
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: appearance)
        defer { panel.close() }
        let capture = QuickCapture(
            state: state, panel: panel, desktop: DesktopWindows(state: state), close: {}, showEditor: { _ in },
            recordShortcut: {}, shortcut: CaptureShortcut {}, updates: UpdateSession())
        let host = NSHostingView(rootView: capture.background(Color(nsColor: .windowBackgroundColor)))
        panel.setContentSize(host.fittingSize)
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(150))
        let editor = try #require(panel.firstResponder as? NSTextView)
        let start = NSRange(location: 0, length: 0)
        let insertion = editor.firstRect(forCharacterRange: start, actualRange: nil)
        // Sample the trailing characters of the prompt, clear of the caret and the marked "s".
        let line = host.convert(panel.convertFromScreen(insertion), from: nil)
        let sample = NSRect(x: line.minX + 30, y: line.minY, width: 50, height: line.height).integral
        func promptPixels() async throws -> Data {
            try await Task.sleep(for: .milliseconds(80))
            host.displayIfNeeded()
            let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: sample))
            host.cacheDisplay(in: sample, to: bitmap)
            return try #require(bitmap.representation(using: .png, properties: [:]))
        }

        let empty = try await promptPixels()
        let current = NSRange(location: NSNotFound, length: 0)
        editor.setMarkedText("s", selectedRange: NSRange(location: 1, length: 0), replacementRange: current)
        try #require(editor.hasMarkedText())
        #expect(editor.string == "s")
        let composing = try await promptPixels()
        editor.insertText("", replacementRange: editor.markedRange())
        #expect(editor.string.isEmpty)
        #expect(try await promptPixels() == empty)

        // Some input methods cancel by replacing the marked text with an empty marked string.
        editor.setMarkedText("s", selectedRange: start, replacementRange: current)
        editor.setMarkedText("", selectedRange: start, replacementRange: current)
        #expect(editor.string.isEmpty)
        #expect(try await promptPixels() == empty)

        editor.setMarkedText("s", selectedRange: start, replacementRange: current)
        editor.insertText("是", replacementRange: editor.markedRange())
        #expect(state.captureDraft == "是")
        let committed = try await promptPixels()
        #expect(empty != committed)
        #expect(composing == committed)

        let enter = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        editor.keyDown(with: enter)
        #expect(state.captureDraft == "是\n")
        #expect(panel.firstResponder === editor)
    }
}
