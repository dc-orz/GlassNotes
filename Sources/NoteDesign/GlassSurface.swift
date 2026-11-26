import AppKit
import SwiftUI

public struct GlassSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var solid
    public enum Role {
        case interface
        case desktopNote(GlassTransparency)
    }
    private let role: Role

    public init(_ role: Role = .interface) { self.role = role }

    public var body: some View {
        let level: GlassTransparency? = if case .desktopNote(let level) = role { level } else { nil }
        let shade = level.map(Tokens.NoteGlass.shade(for:)) ?? Color.clear
        let shape = RoundedRectangle(cornerRadius: Tokens.Size.radius, style: .continuous)
        if solid {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *) {
            if level == .clear {
                Color.clear.glassEffect(.clear, in: shape)
                    .opacity(Tokens.NoteGlass.clearGlassOpacity)
            } else if level == .low {
                Color.clear.glassEffect(.regular.tint(Tokens.NoteGlass.shade(for: .standard)), in: shape)
                    .background(shape.fill(shade))
            } else {
                Color.clear.glassEffect(.regular.tint(shade), in: shape)
            }
        } else {
            FrostedBackdrop()
                .opacity(level == .clear ? Tokens.NoteGlass.clearFrostOpacity : 1)
                .overlay(shade).clipShape(shape)
        }
    }
}

extension View {
    /// Keep ink legible on bright wallpaper while allowing the glass behind it to stay clear.
    public func desktopNoteGlass(_ level: GlassTransparency) -> some View {
        foregroundStyle(Tokens.NoteGlass.ink)
            .shadow(
                color: level == .clear ? Tokens.NoteGlass.inkShadow : .clear,
                radius: Tokens.NoteGlass.inkShadowRadius, y: Tokens.NoteGlass.inkShadowOffset
            )
            .background(GlassSurface(.desktopNote(level)))
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
