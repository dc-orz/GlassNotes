import Foundation
import NoteCommands
import NoteCore
import Testing

struct CommandReplyTests {
    @Test func timestampsSurviveTheWireAndUseExplicitNulls() throws {
        let note = Note(
            text: "line 1\nline 2", placement: Placement(display: "main", x: 0.5, y: 0.5),
            createdAt: Date(timeIntervalSince1970: 0.125))
        let reply = CommandReply.note(CommandNote(note))
        let wire = try JSONEncoder().encode(reply)
        let json = try JSONDecoder().decode(CommandReply.self, from: wire).output()
        let fields = try #require(JSONSerialization.jsonObject(with: json) as? [String: Any])
        #expect(fields["id"] as? String == note.id.uuidString)
        #expect(fields["text"] as? String == note.text)
        #expect(fields["createdAt"] as? String == "1970-01-01T00:00:00.125Z")
        #expect(fields["updatedAt"] as? String == fields["createdAt"] as? String)
        #expect(fields["completedAt"] is NSNull)

        var oldRecord = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        oldRecord.removeValue(forKey: "updatedAt")
        let legacy = try JSONDecoder().decode(Note.self, from: JSONSerialization.data(withJSONObject: oldRecord))
        let list = try CommandReply.list([CommandNote(legacy)]).output()
        let records = try #require(JSONSerialization.jsonObject(with: list) as? [[String: Any]])
        #expect(records.first?["updatedAt"] is NSNull)
    }
}
