import AppKit
import NoteCore
import NoteDesign
import Testing

@testable import GlassNotes

@Suite(.serialized)
@MainActor
struct NativeDesktopTests {
    @Test func markerFontIsRegistered() {
        #expect(MarkerFont.name.lowercased().contains("markergothic"))
        #expect(NSFont(name: MarkerFont.name, size: 19) != nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func menuOpensWithAKeyboardReadyEditor() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.finishLaunching()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let state = AppState(library: try NoteLibrary(directory: folder))
        let desktop = DesktopWindows(state: state)
        let menu = StatusMenu(state: state, desktop: desktop, shortcut: CaptureShortcut {})
        menu.toggle()
        try await Task.sleep(for: .milliseconds(400))
        let panel = try #require(NSApp.windows.first { $0.isVisible && $0.title == "快速记录" })
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.insertText("从菜单栏记录", replacementRange: NSRange(location: 0, length: 0))
        #expect(state.captureDraft == "从菜单栏记录")
        menu.toggle()
        #expect(state.captureDraft == "从菜单栏记录")
        menu.show()
        try await Task.sleep(for: .milliseconds(150))
        let submit = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: "\r",
                charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        #expect(panel.performKeyEquivalent(with: submit))
        #expect(state.notes.first?.text == "从菜单栏记录")
        #expect(!panel.isVisible)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func nativeWindowLifecycle() async throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let screen = try #require(NSScreen.main)
        let lib = try NoteLibrary(directory: folder) { InitialNotes.make(display: screen.displayKey) }
        let state = AppState(library: lib)
        let desktop = DesktopWindows(state: state)
        state.changed = { [weak desktop] in desktop?.reconcile() }
        desktop.reconcile()
        defer { for w in desktop.windows.values { w.panel.close() } }
        #expect(desktop.windows.count == 4)
        let previousAppearance = NSApp.appearance
        defer { NSApp.appearance = previousAppearance }
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSApp.appearance = NSAppearance(named: appearance)
            #expect(
                desktop.windows.values.allSatisfy {
                    $0.panel.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                })
        }
        let frames = desktop.windows.mapValues { $0.panel.frame }
        state.captureDraft = "新记录"
        #expect(desktop.addDraft())
        #expect(state.captureDraft.isEmpty)
        let note = try #require(state.notes.last)
        let window = try #require(desktop.windows[note.id])
        #expect(window.panel.level == NoteWindow.restingLevel)
        window.edit()
        try await Task.sleep(for: .milliseconds(250))
        let editor = try #require(window.panel.firstResponder as? NSTextView)
        let ink = try #require(editor.textColor?.usingColorSpace(.sRGB))
        #expect(min(ink.redComponent, ink.greenComponent, ink.blueComponent) > 0.9)
        window.card.draft = "修改后的中文 ✍"
        #expect(window.save())
        #expect(window.card.note.text == "修改后的中文 ✍")
        desktop.complete(note.id)
        // Undo during the wipe must cancel the pending window close.
        desktop.restore(note.id)
        try await Task.sleep(for: .milliseconds(600))
        #expect(desktop.windows[note.id]?.panel.isVisible == true)
        desktop.complete(note.id)
        try await Task.sleep(for: .seconds(1))
        #expect(desktop.windows[note.id] == nil)
        desktop.restore(note.id)
        #expect(desktop.windows[note.id]?.panel.frame == window.panel.frame)
        #expect(desktop.windows[note.id]?.panel.appearance?.name == .darkAqua)
        for (id, frame) in frames { #expect(desktop.windows[id]?.panel.frame == frame) }
    }
}
