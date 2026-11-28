import Foundation
import NoteCore

package struct CommandError: LocalizedError {
    package let message: String
    package init(_ message: String) { self.message = message }
    package var errorDescription: String? { message }
}

package enum NoteCommand: Codable {
    package static let backgroundLaunchArgument = "--glassnotes-cli-launch"
    case add(String)
    case list
    case complete(UUID)

    package static func portName(for bundleID: String) -> String { bundleID + ".commands.v1" }
}

package enum CommandReply: Codable {
    case note(CommandNote)
    case list([CommandNote])
    case failure(String)

    package func output() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        switch self {
        case .note(let note): return try encoder.encode(note)
        case .list(let notes): return try encoder.encode(notes)
        case .failure(let message): throw CommandError(message)
        }
    }
}

package struct CommandNote: Codable {
    let id: UUID
    let text: String
    let createdAt: String
    let updatedAt: String?
    let completedAt: String?

    package init(_ note: Note) {
        let format = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        id = note.id
        text = note.text
        createdAt = format.format(note.createdAt)
        updatedAt = note.updatedAt.map(format.format)
        completedAt = note.completedAt.map(format.format)
    }

    // Keep unknown timestamps explicit in the JSON consumed by agents.
    package func encode(to encoder: Encoder) throws {
        var record = encoder.container(keyedBy: CodingKeys.self)
        try record.encode(id, forKey: .id)
        try record.encode(text, forKey: .text)
        try record.encode(createdAt, forKey: .createdAt)
        try record.encode(updatedAt, forKey: .updatedAt)
        try record.encode(completedAt, forKey: .completedAt)
    }
}
