import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassNotes

extension NativeDesktopTests {
    @Test func shortcutReadsLegacyPreferencesAndRejectsTypingKeys() throws {
        let suite = "ShortcutTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for (stored, expected): (String, CaptureChord?) in [
            ("controlOption", .standard), ("commandShift", .commandShift), ("off", nil),
        ] {
            defaults.set(stored, forKey: "captureShortcut")
            #expect(CaptureShortcut(defaults: defaults) {}.chord == expected)
        }
        #expect(!CaptureChord(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).isValid)
        #expect(CaptureChord(keyCode: UInt32(kVK_F8), modifiers: 0).isValid)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func recordsShortcutInPanelAndPreservesOldBindingOnConflict() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let suite = "ShortcutTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("off", forKey: "captureShortcut")
        let shortcut = CaptureShortcut(defaults: defaults) {}
        shortcut.start()
        defer { shortcut.stop() }

        let panel = KeyablePanel(
            contentRect: CGRect(x: 80, y: 80, width: 180, height: 80),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.makeKeyAndOrderFront(nil)
        defer { panel.close() }
        try await Task.sleep(for: .milliseconds(150))

        func press(_ code: Int, _ flags: NSEvent.ModifierFlags) throws {
            let event = try #require(
                NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: flags,
                    timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "x",
                    charactersIgnoringModifiers: "x", isARepeat: false, keyCode: UInt16(code)))
            app.sendEvent(event)
        }
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let mask = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let selected = CaptureChord(keyCode: UInt32(kVK_F16), modifiers: mask)
        shortcut.beginRecording(in: panel)
        try press(kVK_ANSI_A, [])
        #expect(shortcut.isRecording && shortcut.issue != nil)
        try press(kVK_Escape, [])
        #expect(!shortcut.isRecording && shortcut.chord == nil)
        shortcut.beginRecording(in: panel)
        try press(kVK_F16, flags)
        #expect(shortcut.chord == selected && !shortcut.isRecording)
        #expect(CaptureShortcut(defaults: defaults) {}.chord == selected)

        let occupied = CaptureChord(keyCode: UInt32(kVK_F17), modifiers: mask)
        var blocker: EventHotKeyRef?
        let blockerID = EventHotKeyID(signature: 0x5445_5354, id: 1)
        try #require(
            RegisterEventHotKey(
                occupied.keyCode, mask, blockerID, GetApplicationEventTarget(),
                UInt32(kEventHotKeyExclusive), &blocker) == noErr)
        defer { if let blocker { UnregisterEventHotKey(blocker) } }
        #expect(!shortcut.select(occupied))
        #expect(shortcut.issue != nil && shortcut.chord == selected)
        #expect(CaptureShortcut(defaults: defaults) {}.chord == selected)
        var probe: EventHotKeyRef?
        let probeID = EventHotKeyID(signature: 0x5445_5354, id: 2)
        defer { if let probe { UnregisterEventHotKey(probe) } }
        func claimPreviousChord() -> OSStatus {
            RegisterEventHotKey(
                selected.keyCode, mask, probeID, GetApplicationEventTarget(),
                UInt32(kEventHotKeyExclusive), &probe)
        }
        try #require(claimPreviousChord() != noErr)
        #expect(shortcut.select(nil))
        #expect(claimPreviousChord() == noErr)
        #expect(CaptureShortcut(defaults: defaults) {}.chord == nil)
    }
}
