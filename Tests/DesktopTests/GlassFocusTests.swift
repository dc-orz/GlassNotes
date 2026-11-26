import AppKit
import NoteDesign
import ScreenCaptureKit
import SwiftUI
import Testing

@testable import GlassNotes

extension NativeDesktopTests {
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
        let host = NSHostingView(rootView: GlassSurface(.desktopNote(NoteGlassAppearance(.clear))))
        note.contentView = host
        for preset in GlassTransparency.allCases {
            host.rootView = GlassSurface(.desktopNote(NoteGlassAppearance(preset)))
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
