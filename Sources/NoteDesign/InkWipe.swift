import SwiftUI

/// Animate this mask on the writing only. The glass remains flat and stationary.
public struct InkWipe: Shape {
    public var progress: CGFloat
    public init(progress: CGFloat) { self.progress = progress }
    public var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let amount = min(1, max(0, progress))
        return Path(
            CGRect(
                x: rect.minX + rect.width * amount, y: rect.minY,
                width: rect.width * (1 - amount), height: rect.height))
    }
}
