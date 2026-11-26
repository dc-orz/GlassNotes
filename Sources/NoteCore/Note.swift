import Foundation

public enum Ink: String, Codable, CaseIterable, Sendable {
    case automatic, chalk, carbon, petrol
}

public struct Placement: Codable, Equatable, Sendable {
    public var display: String
    public var x: Double
    public var y: Double

    public init(display: String, x: Double, y: Double) {
        self.display = display
        self.x = x
        self.y = y
    }
}

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var ink: Ink
    public var placement: Placement
    public let createdAt: Date
    public var completedAt: Date?

    public init(text: String, ink: Ink, placement: Placement, createdAt: Date = .now) {
        self.id = UUID()
        self.text = text
        self.ink = ink
        self.placement = placement
        self.createdAt = createdAt
    }

    public var title: String { String(text.split(whereSeparator: \.isNewline).first ?? "") }
}
