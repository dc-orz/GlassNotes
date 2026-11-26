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
        try lib?.add(text: "  记得带伞\n", ink: .chalk, at: p)
        let id = try #require(lib?.notes.first?.id)
        try lib?.edit(id, text: "看展\n带速写本", ink: .petrol)
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
        #expect(reopened.notes.first?.ink == .petrol)
        #expect(reopened.notes.first?.completedAt == nil)
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
        #expect(throws: LibraryError.emptyNote) { try lib.add(text: "  \n", ink: .automatic, at: p) }
        // Turn the destination into a directory to force atomic replacement to fail.
        let file = folder.appendingPathComponent("notes.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        #expect(throws: (any Error).self) { try lib.add(text: "test", ink: .carbon, at: p) }
        #expect(lib.notes.isEmpty)
        #expect(events == 0)
    }

    @Test func existingEmptyLibraryStaysEmpty() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        do { _ = try NoteLibrary(directory: folder) }
        let lib = try NoteLibrary(directory: folder) { [Note(text: "示例", ink: .chalk, placement: p)] }
        #expect(lib.notes.isEmpty)
    }
}
