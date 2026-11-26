import AppKit

public enum MenuBarMark {
    /// Compose the brand's ink mask with a vector rim at the menu bar's backing scale.
    @MainActor public static func image(ink: NSImage) -> NSImage {
        let template = NSImage(size: Tokens.Size.menuBarMark, flipped: false) { bounds in
            let geometry = Tokens.MenuBar.self
            let halfStroke = geometry.lineWidth / 2
            let outline = NSBezierPath(
                roundedRect: bounds.insetBy(
                    dx: geometry.horizontalInset + halfStroke, dy: geometry.verticalInset + halfStroke),
                xRadius: geometry.cornerRadius, yRadius: geometry.cornerRadius)
            outline.lineWidth = geometry.lineWidth
            NSColor.black.setStroke()
            outline.stroke()
            ink.draw(in: bounds.insetBy(dx: geometry.inkInset, dy: geometry.inkInset))
            return true
        }
        template.isTemplate = true
        return template
    }
}
