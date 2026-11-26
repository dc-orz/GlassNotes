import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class CaptureShortcut: ObservableObject {
    @Published private(set) var chord: CaptureChord?
    @Published private(set) var issue: String?
    @Published private(set) var isRecording = false
    var isUnavailable: Bool { chord != nil && key == nil }
    private var monitor: Any?
    private var key: EventHotKeyRef?
    private var keyID: UInt32 = 0
    private var handler: EventHandlerRef?
    private let defaults: UserDefaults
    private let fire: () -> Void
    private static let preference = "captureShortcut"
    private static let signature: OSType = 0x4D4A_4E54

    init(defaults: UserDefaults = .standard, fire: @escaping () -> Void) {
        self.fire = fire
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.preference),
            let saved = try? JSONDecoder().decode(CaptureChord.self, from: data), saved.isValid
        {
            chord = saved
        } else {
            switch defaults.string(forKey: Self.preference) {
            case "off": chord = nil
            case "commandShift": chord = .commandShift
            default: chord = .standard
            }
        }
    }

    func start() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let result = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                guard
                    GetEventParameter(
                        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr
                else { return OSStatus(eventNotHandledErr) }
                return MainActor.assumeIsolated {
                    let owner = Unmanaged<CaptureShortcut>.fromOpaque(context).takeUnretainedValue()
                    guard id.signature == CaptureShortcut.signature, id.id == owner.keyID, owner.key != nil
                    else { return OSStatus(eventNotHandledErr) }
                    if owner.isRecording { owner.cancelRecording() } else { owner.fire() }
                    return noErr
                }
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else {
            issue = "快捷键暂不可用，可从菜单栏记录。"
            return
        }
        select(chord)
    }

    /// Keep the current binding until the system accepts its replacement.
    @discardableResult func select(_ new: CaptureChord?) -> Bool {
        if let new {
            guard new.isValid else {
                issue = "请同时按住 ⌘、⌥ 或 ⌃，也可单独使用功能键。"
                return false
            }
            guard handler != nil else {
                issue = "无法注册快捷键，请重新打开 GlassNotes。"
                return false
            }
            if new != chord || key == nil {
                var candidate: EventHotKeyRef?
                let nextID = keyID &+ 1
                let result = RegisterEventHotKey(
                    new.keyCode, new.modifiers,
                    EventHotKeyID(signature: Self.signature, id: nextID), GetApplicationEventTarget(),
                    UInt32(kEventHotKeyExclusive), &candidate)
                guard result == noErr, let candidate else {
                    issue = "组合键不可用或已被占用，请换一个。"
                    return false
                }
                if let key { UnregisterEventHotKey(key) }
                key = candidate
                keyID = nextID
            }
        } else if let key {
            UnregisterEventHotKey(key)
            self.key = nil
        }

        switch new {
        case nil: defaults.set("off", forKey: Self.preference)
        case .standard: defaults.set("controlOption", forKey: Self.preference)
        case .commandShift: defaults.set("commandShift", forKey: Self.preference)
        case let custom?: defaults.set(try? JSONEncoder().encode(custom), forKey: Self.preference)
        }
        chord = new
        issue = nil
        cancelRecording()
        return true
    }

    func beginRecording(in window: NSWindow) {
        guard !isRecording else { return }
        issue = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let self, let window, window.isKeyWindow, event.window == nil || event.window === window else {
                return event
            }
            if event.isARepeat { return nil }
            if event.keyCode == UInt16(kVK_Escape),
                event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
            {
                self.cancelRecording()
            } else if let captured = CaptureChord(event: event) {
                self.select(captured)
            } else {
                self.issue = "请同时按住 ⌘、⌥ 或 ⌃，也可单独使用功能键。"
            }
            return nil
        }
    }

    func cancelRecording() {
        guard isRecording else { return }
        if !isUnavailable { issue = nil }
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    func stop() {
        cancelRecording()
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
