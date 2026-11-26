import AppKit
import Carbon.HIToolbox

/// A global shortcut is registered by physical key and modifiers; its legend follows the keyboard layout.
struct CaptureChord: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    static let standard = Self(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey))
    static let commandShift = Self(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | shiftKey))

    private static let functionKeys = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]
    private static let symbols = [
        kVK_Space: "空格", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_ANSI_KeypadEnter: "⌤", kVK_ANSI_KeypadClear: "清除",
    ]
    private static let flags: [(NSEvent.ModifierFlags, UInt32, String)] = [
        (.control, UInt32(controlKey), "⌃"), (.option, UInt32(optionKey), "⌥"),
        (.shift, UInt32(shiftKey), "⇧"), (.command, UInt32(cmdKey), "⌘"),
    ]

    var isValid: Bool {
        let allowed = UInt32(controlKey | optionKey | cmdKey | shiftKey)
        return keyCode < 128 && modifiers & ~allowed == 0
            && (modifiers & UInt32(controlKey | optionKey | cmdKey) != 0
                || Self.functionKeys.contains(Int(keyCode)))
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init?(event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: Self.flags.reduce(0) {
                event.modifierFlags.contains($1.0) ? $0 | $1.1 : $0
            })
        guard isValid else { return nil }
    }

    @MainActor var title: String {
        let prefix = Self.flags.filter { modifiers & $0.1 != 0 }.map { $0.2 }.joined()
        if let number = Self.functionKeys.firstIndex(of: Int(keyCode)) { return prefix + "F\(number + 1)" }
        return prefix + (Self.symbols[Int(keyCode)] ?? translatedKey() ?? "键 \(keyCode)")
    }

    @MainActor private func translatedKey() -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let property = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        return withExtendedLifetime(layout) {
            let keyboard = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKey: UInt32 = 0
            var length = 0
            var buffer = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(
                keyboard, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKey,
                buffer.count, &length, &buffer)
            guard result == noErr, length > 0 else { return nil }
            return String(decoding: buffer.prefix(length), as: UTF16.self).uppercased()
        }
    }
}
