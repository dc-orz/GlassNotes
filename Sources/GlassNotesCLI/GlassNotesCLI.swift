import Foundation
import NoteCommands

@main
enum GlassNotesCLI {
    static let usage = """
        glassnotes add "TEXT"
        glassnotes list [--json]
        glassnotes complete UUID

        All commands write JSON to stdout. Timestamps are in UTC.
        """

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args == ["--help"] || args == ["-h"] {
            print(usage)
            return
        }
        do {
            let command = try parse(args)
            let connection = try AppConnection.connect()
            let request = try JSONEncoder().encode(command)
            let reply: CommandReply
            do {
                try connection.send(request)
                reply = try JSONDecoder().decode(CommandReply.self, from: connection.receive())
            } catch {
                throw CommandError("GlassNotes did not confirm the request. Check the list before retrying.")
            }
            let output = try reply.output()
            FileHandle.standardOutput.write(output + Data([0x0A]))
        } catch {
            FileHandle.standardError.write(Data("glassnotes: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func parse(_ args: [String]) throws -> NoteCommand {
        if args == ["list"] || args == ["list", "--json"] { return .list }
        guard args.count == 2 else { throw CommandError(usage) }
        switch args[0] {
        case "add": return .add(args[1])
        case "complete":
            guard let id = UUID(uuidString: args[1]) else { throw CommandError("Expected a note UUID.") }
            return .complete(id)
        default: throw CommandError(usage)
        }
    }

}
