import AppKit
import NoteCore
import NoteDesign
import ScreenCaptureKit
import SwiftUI
import Testing

@testable import GlassNotes

extension NativeDesktopTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func draggingNativeGlassFocusesTheNoteAtDesktopLevel() async throws {
        guard #available(macOS 26.0, *) else { return }
        _ = NSApplication.shared
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let screen = try #require(NSScreen.main)
        let library = try NoteLibrary(directory: folder) { InitialNotes.make(display: screen.displayKey) }
        let state = AppState(library: library)
        let desktop = DesktopWindows(state: state)
        desktop.reconcile()
        defer { for window in desktop.windows.values { window.panel.close() } }
        let window = try #require(desktop.windows.values.first)
        let other = try #require(desktop.windows.values.first { $0 !== window })
        let panel = window.panel
        let body = CGPoint(x: panel.frame.width / 2, y: panel.frame.height / 2)
        let preferences = DesktopGlassPreference()
        let original = preferences.prefersNativeGlass
        defer { preferences.prefersNativeGlass = original }

        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let cases: [(native: Bool, modifiers: NSEvent.ModifierFlags, shouldFocus: Bool)] = [
            (false, [], false), (true, .command, false), (true, [], !reduceTransparency),
        ]
        for drag in cases {
            preferences.prefersNativeGlass = drag.native
            other.panel.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            try #require(other.panel.isKeyWindow)
            try #require(panel.isMoveArea(at: body))
            let press = try #require(
                NSEvent.mouseEvent(
                    with: .leftMouseDown, location: body, modifierFlags: drag.modifiers,
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            panel.sendEvent(press)
            try await Task.sleep(for: .milliseconds(150))
            #expect(panel.isKeyWindow == drag.shouldFocus)
            #expect(!window.card.editing)
            #expect(panel.level == NoteWindow.restingLevel)
        }
        other.panel.makeKeyAndOrderFront(nil)
        try await Task.sleep(for: .milliseconds(150))
        #expect(!panel.isKeyWindow)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func desktopGlassKeepsItsToneAfterFocusMoves() async throws {
        guard #available(macOS 14.4, *) else { return }
        _ = NSApplication.shared
        let size = Tokens.Size.shortNote
        func panel() -> KeyablePanel {
            let window = KeyablePanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.appearance = NSAppearance(named: Tokens.NoteGlass.appearance)
            return window
        }
        let note = panel()
        let other = panel()
        defer {
            note.close()
            other.close()
        }
        note.center()
        other.setFrameOrigin(NSPoint(x: note.frame.maxX, y: note.frame.minY))
        let host = NSHostingView(rootView: Color.clear.desktopNoteGlass(NoteGlassAppearance(.clear)))
        note.contentView = host
        for preset in GlassTransparency.allCases {
            host.rootView = Color.clear.desktopNoteGlass(NoteGlassAppearance(preset))
            note.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(350))
            try #require(note.isKeyWindow)
            let active = try await glassSample(in: note)
            other.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(350))
            try #require(!note.isKeyWindow)
            let inactive = try await glassSample(in: note)
            #expect(
                zip(active, inactive).allSatisfy { abs($0 - $1) < 2.0 / 255 },
                "The center of the \(preset.rawValue) material changed when focus moved.")
        }
    }

    /// Window-only capture measures the material without reading the user's desktop.
    @available(macOS 14.4, *)
    private func glassSample(in panel: NSWindow) async throws -> [CGFloat] {
        let content = try await SCShareableContent.currentProcess
        let window = try #require(content.windows.first { $0.windowID == UInt32(panel.windowNumber) })
        let config = SCStreamConfiguration()
        config.width = Int(panel.frame.width)
        config.height = Int(panel.frame.height)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let center = try #require(
            bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        return [
            center.redComponent * center.alphaComponent, center.greenComponent * center.alphaComponent,
            center.blueComponent * center.alphaComponent, center.alphaComponent,
        ]
    }
}
