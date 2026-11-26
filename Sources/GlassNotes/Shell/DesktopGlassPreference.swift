import NoteDesign
import SwiftUI

/// One app preference shared across the independently hosted menu and desktop windows.
struct DesktopGlassPreference: DynamicProperty {
    @AppStorage("desktopGlassTransparency") var selection: GlassTransparency = .standard
}
