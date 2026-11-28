import AppKit
import CoreFoundation
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
            let port = try connect()
            let request = try JSONEncoder().encode(command)
            var data: Unmanaged<CFData>?
            let mode = RunLoop.Mode.default.rawValue as CFString
            let status = CFMessagePortSendRequest(port, 1, request as CFData, 5, 10, mode, &data)
            guard status == kCFMessagePortSuccess, let reply = data?.takeRetainedValue() else {
                throw CommandError("GlassNotes did not confirm the request. Check the list before retrying.")
            }
            let output = try JSONDecoder().decode(CommandReply.self, from: reply as Data).output()
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

    private static func connect() throws -> CFMessagePort {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw CommandError("Could not locate the glassnotes executable.")
        }
        let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app", let bundleID = Bundle(url: app)?.bundleIdentifier else {
            throw CommandError("Run the glassnotes helper from GlassNotes.app/Contents/Helpers.")
        }
        let name = NoteCommand.portName(for: bundleID) as CFString
        if let port = CFMessagePortCreateRemote(nil, name) { return port }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            let launch = Process()
            launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            launch.arguments = ["-g", app.path, "--args", NoteCommand.backgroundLaunchArgument]
            try launch.run()
            launch.waitUntilExit()
            guard launch.terminationStatus == 0 else { throw CommandError("Could not launch GlassNotes.") }
        }
        // Only wait for startup. Never resend a mutation after an uncertain reply.
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let port = CFMessagePortCreateRemote(nil, name) { return port }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw CommandError("GlassNotes is unavailable. Open the app bundled with this CLI and try again.")
    }
}
