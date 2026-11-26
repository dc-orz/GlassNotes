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
        let shape = RoundedRectangle(cornerRadius: Tokens.Size.radius, style: .continuous)
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
                if #available(macOS 26.0, *) {
                    let glass: Glass =
                        look.base == .clear ? .clear : .regular.tint(.black.opacity(look.regularTint))
                    Color.clear.glassEffect(glass, in: shape)
                        .opacity(look.materialOpacity)
                        .background(shape.fill(.black.opacity(look.backing)))
                } else {
                    FrostedBackdrop().opacity(look.materialOpacity)
                        .overlay(Color.black.opacity(look.dimming)).clipShape(shape)
                }
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
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .popover
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
