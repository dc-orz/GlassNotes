import NoteDesign
import SwiftUI

/// The original preset strings remain valid. Custom settings persist both channels in a single write.
struct DesktopGlassPreference: DynamicProperty {
    @AppStorage("desktopGlassTransparency") private var stored = GlassTransparency.standard.rawValue
    @AppStorage("desktopUsesNativeGlass") var prefersNativeGlass = false

    var usesNativeGlass: Bool {
        if #available(macOS 26.0, *) { prefersNativeGlass } else { false }
    }

    var selection: NoteGlassAppearance {
        get {
            if let preset = GlassTransparency(rawValue: stored) { return NoteGlassAppearance(preset) }
            let fields = stored.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count == 3, let base = GlassTransparency(rawValue: String(fields[0])),
                let material = Double(fields[1]), material.isFinite,
                let dimming = Double(fields[2]), dimming.isFinite
            else { return NoteGlassAppearance(.standard) }
            return NoteGlassAppearance(base, materialOpacity: material, dimming: dimming)
        }
        nonmutating set {
            if newValue == NoteGlassAppearance(newValue.base) {
                stored = newValue.base.rawValue
            } else {
                stored = "\(newValue.base.rawValue):\(newValue.materialOpacity):\(newValue.dimming)"
            }
        }
    }

    var binding: Binding<NoteGlassAppearance> {
        Binding(get: { selection }, set: { selection = $0 })
    }
}
