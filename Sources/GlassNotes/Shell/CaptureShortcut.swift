import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Carbon hot keys reserve only a specific chord and do not monitor other keystrokes.
@MainActor
final class CaptureShortcut: ObservableObject {
    enum Choice: String, CaseIterable {
        case controlOption, commandShift, off
        var title: String {
            switch self {
            case .controlOption: "⌃⌥N"
            case .commandShift: "⇧⌘N"
            case .off: "关闭快捷键"
            }
        }
    }
    @Published private(set) var choice: Choice
    @Published private(set) var issue: String?
    private var key: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let defaults: UserDefaults
    private let fire: () -> Void
    private static let preference = "captureShortcut"

    init(defaults: UserDefaults = .standard, fire: @escaping () -> Void) {
        self.fire = fire
        self.defaults = defaults
        choice = Choice(rawValue: defaults.string(forKey: Self.preference) ?? "") ?? .controlOption
    }

    func start() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                guard
                    GetEventParameter(
                        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                    id.signature == 0x4D4A_4E54, id.id == 1
                else { return OSStatus(eventNotHandledErr) }
                MainActor.assumeIsolated {
                    Unmanaged<CaptureShortcut>.fromOpaque(context).takeUnretainedValue().fire()
                }
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else {
            issue = "快捷键不可用，可从菜单栏记录。"
            return
        }
        select(choice)
    }

    func select(_ new: Choice) {
        if let key {
            UnregisterEventHotKey(key)
            self.key = nil
        }
        choice = new
        defaults.set(new.rawValue, forKey: Self.preference)
        issue = nil
        guard new != .off else { return }
        let modifiers = new == .controlOption ? controlKey | optionKey : cmdKey | shiftKey
        let result = RegisterEventHotKey(
            UInt32(kVK_ANSI_N), UInt32(modifiers),
            EventHotKeyID(signature: 0x4D4A_4E54, id: 1),
            GetApplicationEventTarget(), 0, &key)
        if result != noErr { issue = "快捷键暂不可用，可从设置里换一个组合。" }
    }

    func stop() {
        if let key {
            UnregisterEventHotKey(key)
            self.key = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}
