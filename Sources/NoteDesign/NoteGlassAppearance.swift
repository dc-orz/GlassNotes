import Foundation

public enum GlassTransparency: String, CaseIterable, Sendable {
    case clear, standard, low
}

/// The starting material and the two independent, bounded controls for a desktop note.
public struct NoteGlassAppearance: Equatable, Sendable {
    public let base: GlassTransparency
    public var materialOpacity: Double {
        didSet {
            materialOpacity = Self.bounded(materialOpacity, in: Tokens.NoteGlass.materialRange, fallback: oldValue)
        }
    }
    public var dimming: Double {
        didSet { dimming = Self.bounded(dimming, in: Tokens.NoteGlass.dimmingRange, fallback: oldValue) }
    }

    public init(_ base: GlassTransparency, materialOpacity: Double? = nil, dimming: Double? = nil) {
        self.base = base
        let clearOpacity: Double
        if #available(macOS 26.0, *) {
            clearOpacity = Tokens.NoteGlass.clearGlassOpacity
        } else {
            clearOpacity = Tokens.NoteGlass.clearFrostOpacity
        }
        let defaultDimming: Double
        switch base {
        case .clear: defaultDimming = 0
        case .standard: defaultDimming = Tokens.NoteGlass.standardDimming
        case .low: defaultDimming = Tokens.NoteGlass.dimmingRange.upperBound
        }

        self.materialOpacity = Self.bounded(
            materialOpacity, in: Tokens.NoteGlass.materialRange, fallback: base == .clear ? clearOpacity : 1)
        self.dimming = Self.bounded(dimming, in: Tokens.NoteGlass.dimmingRange, fallback: defaultDimming)
    }

    private static func bounded(_ value: Double?, in range: ClosedRange<Double>, fallback: Double) -> Double {
        guard let value, value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }

    /// Regular glass first takes a tint. Beyond the Standard preset the black backing fades in.
    var regularTint: Double { min(dimming, Tokens.NoteGlass.standardDimming) }

    var backing: Double {
        if base == .clear { return dimming }
        let start = Tokens.NoteGlass.standardDimming
        let end = Tokens.NoteGlass.dimmingRange.upperBound
        return end * (max(0, dimming - start) / (end - start))
    }
}
