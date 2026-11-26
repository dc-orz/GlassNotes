import SwiftUI

public enum GlassTransparency: String, Sendable {
    case clear, standard, low
}

/// Runtime design tokens. Native glass owns optical effects such as lensing and blur.
public enum Tokens {
    public enum Space {
        public static let tight: CGFloat = 4, small: CGFloat = 8, standard: CGFloat = 12
        public static let inset: CGFloat = 18, section: CGFloat = 20
    }

    public enum Size {
        public static let radius: CGFloat = 16
        public static let action: CGFloat = 32
        public static let shortNote = CGSize(width: 256, height: 148)
        public static let longNote = CGSize(width: 336, height: 190)
        public static let menuWidth: CGFloat = 360
        public static let menuBarMark = CGSize(width: 18, height: 18)
        public static let listHeight: CGFloat = 158
        public static let inputHeight: CGFloat = 76
        public static let toast = CGSize(width: 184, height: 48)
    }

    public enum TypeStyle {
        public static let title = Font.system(size: 24, weight: .medium)
        public static let ink = Font.system(size: 19, weight: .regular)
        public static let heading = Font.headline
        public static let help = Font.caption
        public static let bodyLineSpacing: CGFloat = 3
    }

    public enum Motion {
        public static let erase = 0.18, dismiss = 0.12, reduced = 0.08
        public static let undoSeconds = 5
    }

    /// The desktop material and ink are shared by every note, including archived notes on restore.
    public enum NoteGlass {
        public static let appearance = NSAppearance.Name.darkAqua
        static let clearFrostOpacity = 0.45
        static func shade(for transparency: GlassTransparency) -> Color {
            switch transparency {
            case .clear: Color.black.opacity(0.10)
            case .standard: Color.black.opacity(0.26)
            case .low: Color.black.opacity(0.62)
            }
        }
        public static let ink = Color(red: 0.953, green: 0.969, blue: 0.988)
    }
}
