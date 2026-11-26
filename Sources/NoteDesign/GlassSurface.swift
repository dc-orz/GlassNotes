import AppKit
import SwiftUI

public struct GlassSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var solid
    public enum Role { case interface, desktopNote }
    private let role: Role

    public init(_ role: Role = .interface) { self.role = role }

    public var body: some View {
        let tint: Color = role == .desktopNote ? Tokens.NoteGlass.tint : .clear
        let shape = RoundedRectangle(cornerRadius: Tokens.Size.radius, style: .continuous)
        if solid {
            shape.fill(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(tint), in: shape)
        } else {
            FrostedBackdrop().overlay(tint).clipShape(shape)
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
