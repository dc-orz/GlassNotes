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
                FrostedBackdrop()
                    .opacity(look.frostCoverage)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(Tokens.NoteGlass.edgeLight, lineWidth: Tokens.NoteGlass.edgeWidth)
                            .blur(radius: Tokens.NoteGlass.edgeSoftness)
                            .clipShape(shape)
                    }
                    .opacity(look.materialOpacity)
                    .overlay(shape.fill(.black.opacity(look.dimming)))
            }
        }
    }
}

extension View {
    public func desktopNoteGlass(_ look: NoteGlassAppearance, useNativeGlass: Bool = false) -> some View {
        modifier(DesktopNoteGlass(look: look, useNativeGlass: useNativeGlass))
    }
}

private struct DesktopNoteGlass: ViewModifier {
    let look: NoteGlassAppearance
    let useNativeGlass: Bool
    @Environment(\.accessibilityReduceTransparency) private var solid

    func body(content: Content) -> some View {
        let shadowStrength = useNativeGlass || look.base == .clear ? 1 : 1 - look.materialOpacity
        let ink = content.foregroundStyle(Tokens.NoteGlass.ink)
            .shadow(
                color: Tokens.NoteGlass.inkShadow.opacity(shadowStrength),
                radius: Tokens.NoteGlass.inkShadowRadius, y: Tokens.NoteGlass.inkShadowOffset
            )
        let frosted = GlassSurface(.desktopNote(look))
        if #available(macOS 26.0, *) {
            let native = useNativeGlass && !solid
            let shape = RoundedRectangle(cornerRadius: Tokens.NoteGlass.cornerRadius, style: .continuous)
            ink.glassEffect(native ? .clear : .identity, in: shape)
                .background { if !native { frosted } }
        } else {
            ink.background(frosted)
        }
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
