import AppKit
import NoteCore
import NoteDesign
import SwiftUI
import Testing

@testable import GlassNotes

@Suite(.serialized)
@MainActor
struct NativeDesktopTests {
    @Test func continuousGlassValuesRespectDesignLimits() {
        let outOfRange = NoteGlassAppearance(.clear, materialOpacity: -1, dimming: 1)
        #expect(outOfRange.materialOpacity == Tokens.NoteGlass.materialRange.lowerBound)
        #expect(outOfRange.dimming == Tokens.NoteGlass.dimmingRange.upperBound)
        #expect(
            NoteGlassAppearance(.clear, materialOpacity: .nan, dimming: .infinity) == NoteGlassAppearance(.clear))
        let fractional = NoteGlassAppearance(.clear, materialOpacity: 0.42367, dimming: 0.08291)
        #expect(fractional.materialOpacity == 0.42367)
        #expect(fractional.dimming == 0.08291)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func glassPreferenceUpdatesOpenWindowsAndSurvivesReopen() async throws {
        _ = NSApplication.shared
        let suite = "GlassNotesTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        func host(_ store: UserDefaults, observe: @escaping (Binding<NoteGlassAppearance>) -> Void) -> NSPanel {
            let panel = NSPanel(
                contentRect: CGRect(origin: .zero, size: Tokens.Size.shortNote),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(
                rootView: GlassPreferenceProbe(observe: observe).defaultAppStorage(store))
            panel.orderBack(nil)
            return panel
        }

        defaults.set("low", forKey: "desktopGlassTransparency")  // Existing installations store a bare preset.
        var selection: Binding<NoteGlassAppearance>?
        var displayed: NoteGlassAppearance?
        let menu = host(defaults) { selection = $0 }
        let note = host(defaults) { displayed = $0.wrappedValue }
        defer {
            menu.close()
            note.close()
        }
        try await Task.sleep(for: .milliseconds(200))
        let setting = try #require(selection)
        #expect(displayed == NoteGlassAppearance(.low))
        let custom = NoteGlassAppearance(.clear, materialOpacity: 0.5371, dimming: 0.0729)
        for level in GlassTransparency.allCases.map({ NoteGlassAppearance($0) }) {
            setting.wrappedValue = level
            try await Task.sleep(for: .milliseconds(150))
            #expect(displayed == level)
        }

        setting.wrappedValue = NoteGlassAppearance(.clear)
        setting.materialOpacity.wrappedValue = custom.materialOpacity
        setting.dimming.wrappedValue = custom.dimming
        try await Task.sleep(for: .milliseconds(150))
        #expect(displayed == custom)

        let reopened = try #require(UserDefaults(suiteName: suite))
        var restored: NoteGlassAppearance?
        let nextNote = host(reopened) { restored = $0.wrappedValue }
        defer { nextNote.close() }
        try await Task.sleep(for: .milliseconds(150))
        #expect(restored == custom)
        setting.wrappedValue = NoteGlassAppearance(.clear)
        try await Task.sleep(for: .milliseconds(150))
        #expect(displayed == NoteGlassAppearance(.clear))
        #expect(reopened.string(forKey: "desktopGlassTransparency") == "clear")
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
    func readingSurfaceMovesExceptForTheTwoCornerButtons() async throws {
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let screen = try #require(NSScreen.main)
        let library = try NoteLibrary(directory: folder) { InitialNotes.make(display: screen.displayKey) }
        let state = AppState(library: library)
        let desktop = DesktopWindows(state: state)
        state.changed = { [weak desktop] in desktop?.reconcile() }
        desktop.reconcile()
        defer { for window in desktop.windows.values { window.panel.close() } }
        let note = try #require(library.notes.first)
        let window = try #require(desktop.windows[note.id])
        let panel = window.panel
        panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(200))
        let size = panel.frame.size
        let midpoint = CGPoint(x: size.width / 2, y: size.height / 2)
        let body = CGPoint(x: Tokens.Space.inset * 2, y: size.height - Tokens.Space.inset * 2)
        let lowerLeft = CGPoint(x: Tokens.Space.small, y: Tokens.Space.small)
        let endButton = CGPoint(
            x: size.width - Tokens.Space.tight - Tokens.Size.action / 2,
            y: Tokens.Space.tight + Tokens.Size.action / 2)
        let editButton = CGPoint(x: endButton.x - Tokens.Size.action - Tokens.Space.tight, y: endButton.y)
        for point in [body, midpoint, lowerLeft, CGPoint(x: size.width - 2, y: size.height / 2)] {
            #expect(panel.isMoveArea(at: point))
        }
        #expect(!panel.isMoveArea(at: editButton))
        #expect(!panel.isMoveArea(at: endButton))
        // Just outside the toolbar, even the narrow margin remains draggable.
        #expect(panel.isMoveArea(at: CGPoint(x: editButton.x - Tokens.Size.action / 2 - 1, y: endButton.y)))

        let destination = DesktopLayout.frame(
            for: Placement(display: screen.displayKey, x: 0.35, y: 0.42), size: size, in: screen.visibleFrame)
        panel.setFrameOrigin(destination.origin)
        try await Task.sleep(for: .milliseconds(150))
        let savedNote = try #require(library.notes.first { $0.id == note.id })
        #expect(DesktopLayout.frame(for: savedNote.placement, size: size, in: screen.visibleFrame) == destination)

        window.edit()
        try await Task.sleep(for: .milliseconds(200))
        #expect(!panel.isMoveArea(at: body))
        let editor = try #require(panel.firstResponder as? NSTextView)
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        #expect(editor.selectedRange().length == 2)
        window.endEdit()
        try await Task.sleep(for: .milliseconds(100))
        #expect(panel.isMoveArea(at: body))
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
        let bodyFont = try #require(editor.font)
        #expect(bodyFont.familyName == NSFont.systemFont(ofSize: bodyFont.pointSize).familyName)
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
        desktop.complete(note.id)
        try lib.deleteCompleted(note.id)
        #expect(desktop.windows[note.id] == nil)
        #expect(!state.notes.contains(where: { $0.id == note.id }))
    }
}

private struct GlassPreferenceProbe: View {
    private var glass = DesktopGlassPreference()
    let observe: (Binding<NoteGlassAppearance>) -> Void

    var body: some View {
        GlassSurface(.desktopNote(glass.selection))
            .onChange(of: glass.selection, initial: true) { _, _ in observe(glass.binding) }
    }
}
