import Darwin
import Foundation

public enum LibraryError: LocalizedError {
    case alreadyOpen, unknownVersion, invalidData, missingNote, emptyNote
    public var errorDescription: String? {
        switch self {
        case .alreadyOpen: "这份便签库已在另一个进程中打开。"
        case .unknownVersion: "这份便签库来自更新的版本，请用新版墨笺打开。"
        case .invalidData: "无法读取便签库。原文件已保留，可从备份恢复。"
        case .missingNote: "这张便签已不存在，请重新打开。"
        case .emptyNote: "请先写一点内容。"
        }
    }
}

@MainActor public final class NoteLibrary {
    private struct Document: Codable {
        var version = 1
        var notes: [Note]
    }

    public private(set) var notes: [Note]
    public var onChange: (() -> Void)?
    private let file: URL
    private let lock: FileHandle

    public init(directory: URL, initial: () -> [Note] = { [] }) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        file = directory.appendingPathComponent("notes.json")
        let descriptor = open(directory.appendingPathComponent("library.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.EACCES) }
        lock = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw LibraryError.alreadyOpen }
        if FileManager.default.fileExists(atPath: file.path) {
            let data = try Data(contentsOf: file)
            struct Header: Decodable { let version: Int }
            guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
                throw LibraryError.invalidData
            }
            guard header.version == 1 else { throw LibraryError.unknownVersion }
            guard let doc = try? JSONDecoder().decode(Document.self, from: data),
                Set(doc.notes.map(\.id)).count == doc.notes.count
            else { throw LibraryError.invalidData }
            notes = doc.notes
        } else {
            notes = initial()
            try Self.write(notes, to: file)
        }
    }

    public func add(text: String, ink: Ink, at position: Placement) throws {
        let note = Note(text: try Self.content(text), ink: ink, placement: position)
        try commit(notes + [note])
    }

    public func edit(_ id: UUID, text: String, ink: Ink) throws {
        let text = try Self.content(text)
        try update(id) {
            $0.text = text
            $0.ink = ink
        }
    }

    public func move(_ id: UUID, to position: Placement) throws {
        try update(id) { $0.placement = position }
    }

    public func complete(_ id: UUID, at date: Date = .now) throws {
        try update(id) { if $0.completedAt == nil { $0.completedAt = date } }
    }

    public func restore(_ id: UUID) throws { try update(id) { $0.completedAt = nil } }

    private func update(_ id: UUID, change: (inout Note) -> Void) throws {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { throw LibraryError.missingNote }
        var next = notes
        change(&next[index])
        if next[index] != notes[index] { try commit(next) }
    }

    private static func content(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LibraryError.emptyNote }
        return trimmed
    }

    private func commit(_ next: [Note]) throws {
        try Self.write(next, to: file)
        notes = next
        onChange?()
    }

    private static func write(_ notes: [Note], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Document(notes: notes)).write(to: url, options: .atomic)
    }
}
