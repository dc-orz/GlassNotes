import AppKit
import CoreGraphics
import NoteCore

extension NSScreen {
    var displayKey: String {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
            let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return "main" }
        return CFUUIDCreateString(nil, uuid) as String
    }

    static func forNote(_ note: Note) -> NSScreen? {
        screens.first { $0.displayKey == note.placement.display } ?? main ?? screens.first
    }
}
