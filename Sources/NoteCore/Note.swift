import Foundation

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
    // The v1 file format requires this field. Round-trip it for compatibility with older builds.
    private let ink: String
    public var placement: Placement
    public let createdAt: Date
    public internal(set) var updatedAt: Date?
    public var completedAt: Date?

    public init(text: String, placement: Placement, createdAt: Date = .now) {
        self.id = UUID()
        self.text = text
        self.ink = "chalk"
        self.placement = placement
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    public var title: String { String(text.split(whereSeparator: \.isNewline).first ?? "") }
}
