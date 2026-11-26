import Foundation
import NoteCore
import Testing

@MainActor
struct NoteLibraryTests {
    private let p = Placement(display: "external", x: 0.4, y: 0.7)

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @Test func editsCompletionAndRestorationPersist() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        var lib: NoteLibrary? = try NoteLibrary(directory: folder)
        try lib?.add(text: "  记得带伞\n", at: p)
        let id = try #require(lib?.notes.first?.id)
        try lib?.edit(id, text: "看展\n带速写本")
        let moved = Placement(display: "other", x: 0.21, y: 0.01)
        try lib?.move(id, to: moved)
        let completed = Date(timeIntervalSince1970: 150)
        try lib?.complete(id, at: completed)
        try lib?.complete(id)
        #expect(lib?.notes.first?.completedAt == completed)
        lib = nil
        let reopened = try NoteLibrary(directory: folder)
        #expect(reopened.notes.first?.completedAt == completed)
        try reopened.restore(id)
        #expect(reopened.notes.first?.placement == moved)
        #expect(reopened.notes.first?.text == "看展\n带速写本")
        #expect(reopened.notes.first?.completedAt == nil)
    }

    @Test func historicalInksRoundTripWithoutAStyleMigration() throws {
        let folder = temporaryFolder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.json")
        let oldInks = ["carbon", "petrol", "automatic", "chalk"]
        let ids = oldInks.map { _ in UUID() }
        let records: [[String: Any]] = zip(ids, oldInks).map { id, ink in
            [
                "id": id.uuidString, "text": "已有便签", "ink": ink,
                "placement": ["display": "external", "x": 0.4, "y": 0.7],
                "createdAt": 1, "completedAt": 2,
            ]
        }
        let oldData = try JSONSerialization.data(withJSONObject: ["version": 1, "notes": records])
        try oldData.write(to: file)
        let library = try NoteLibrary(directory: folder)
        #expect(try Data(contentsOf: file) == oldData)
        #expect(library.notes.allSatisfy { $0.completedAt != nil && $0.placement == p })
        try library.restore(ids[0])
        try library.edit(ids[0], text: "恢复后的便签")
        try library.add(text: "新便签", at: p)
        let stored = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let saved = try #require(stored["notes"] as? [[String: Any]])
        #expect(saved.compactMap { $0["ink"] as? String } == oldInks + ["chalk"])
        #expect(library.notes[0].completedAt == nil)
        #expect(library.notes[1].completedAt != nil)
    }

    @Test func cannotOverwriteCorruptOrFutureFiles() throws {
        let folder = temporaryFolder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for input in ["invalid", #"{"version":2,"notes":[]}"#, #"{"version":1,"notes":[{}]}"#] {
            let file = folder.appendingPathComponent("notes.json")
            try Data(input.utf8).write(to: file)
            #expect(throws: (any Error).self) { try NoteLibrary(directory: folder) }
            #expect(try Data(contentsOf: file) == Data(input.utf8))
        }
    }

    @Test func lockedLibraryAndFailedWriteDoNotPublishChanges() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let lib = try NoteLibrary(directory: folder)
        #expect(throws: LibraryError.alreadyOpen) { try NoteLibrary(directory: folder) }
        var events = 0
        lib.onChange = { events += 1 }
        #expect(throws: LibraryError.emptyNote) { try lib.add(text: "  \n", at: p) }
        // Turn the destination into a directory to force atomic replacement to fail.
        let file = folder.appendingPathComponent("notes.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try lib.add(text: "test", at: p) }
        #expect(lib.notes.isEmpty)
        #expect(events == 0)
    }

    @Test func existingEmptyLibraryStaysEmpty() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        do { _ = try NoteLibrary(directory: folder) }
        let lib = try NoteLibrary(directory: folder) { [Note(text: "示例", placement: p)] }
        #expect(lib.notes.isEmpty)
    }
}
