import AppKit
import SwiftUI

public struct GlassSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var solid
    public enum Role {
        case interface
        case desktopNote(NoteGlassAppearance)
    }
    private let role: Role

    public init(_ role: Role = .interface) { self.role = role }

    public var body: some View {
        let radius =
            switch role {
            case .interface: Tokens.Size.radius
            case .desktopNote: Tokens.NoteGlass.cornerRadius
            }
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if solid {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else {
            switch role {
            case .interface:
                if #available(macOS 26.0, *) {
                    Color.clear.glassEffect(.regular.tint(.clear), in: shape)
                } else {
                    FrostedBackdrop().clipShape(shape)
                }
            case .desktopNote(let look):
                FrostedBackdrop(material: .hudWindow)
                    .opacity(look.frostOpacity)
                    .overlay(Color.black.opacity(look.dimming))
                    .overlay {
                        shape.strokeBorder(Tokens.NoteGlass.edgeLight, lineWidth: Tokens.NoteGlass.edgeWidth)
                            .blur(radius: Tokens.NoteGlass.edgeSoftness)
                            .opacity(look.materialOpacity)
                    }
                    .clipShape(shape)
            }
        }
    }
}

extension View {
    /// Keep the ink at full opacity while letting light wallpaper show through the material.
    public func desktopNoteGlass(_ look: NoteGlassAppearance) -> some View {
        let shadowStrength = look.base == .clear ? 1 : 1 - look.materialOpacity
        return foregroundStyle(Tokens.NoteGlass.ink)
            .shadow(
                color: Tokens.NoteGlass.inkShadow.opacity(shadowStrength),
                radius: Tokens.NoteGlass.inkShadowRadius, y: Tokens.NoteGlass.inkShadowOffset
            )
            .background(GlassSurface(.desktopNote(look)))
    }
}

private struct FrostedBackdrop: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = material
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        if view.material != material { view.material = material }
    }
}
