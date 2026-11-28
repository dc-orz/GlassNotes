import AppKit
import Darwin
import NoteCommands
import Security

enum AppConnection {
    static func connect() throws -> CommandSocket {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            throw CommandError("Could not locate the glassnotes executable.")
        }
        let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard app.pathExtension == "app", let id = Bundle(url: app)?.bundleIdentifier else {
            throw CommandError("Run the glassnotes helper from GlassNotes.app/Contents/Helpers.")
        }
        func runningApp() throws -> NSRunningApplication? {
            let copies = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter {
                !$0.isTerminated
            }
            if let running = copies.first(where: { $0.bundleURL?.resolvingSymlinksInPath().path == app.path }) {
                return running
            }
            guard copies.isEmpty else { throw CommandError("Quit the other copy of GlassNotes and retry.") }
            return nil
        }
        var diagnostics: URL?
        defer {
            if let diagnostics { try? FileManager.default.removeItem(at: diagnostics.deletingLastPathComponent()) }
        }
        if try runningApp() == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            let log = directory.appendingPathComponent("startup.log")
            diagnostics = log
            guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let launch = Process()
            launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            launch.arguments = [
                "-g", "--stderr", log.path, app.path, "--args", NoteCommand.backgroundLaunchArgument,
            ]
            try launch.run()
            launch.waitUntilExit()
            guard launch.terminationStatus == 0 else { throw CommandError("Could not launch GlassNotes.") }
        }
        let deadline = ContinuousClock.now + .seconds(10)
        repeat {
            if let diagnostics, let log = try? String(contentsOf: diagnostics, encoding: .utf8),
                let failure = log.split(whereSeparator: \.isNewline).first(where: {
                    $0.hasPrefix(NoteCommand.startupErrorPrefix)
                })
            {
                throw CommandError(String(failure.dropFirst(NoteCommand.startupErrorPrefix.count)))
            }
            if let appProcess = try runningApp() {
                do { return try connect(to: appProcess.processIdentifier, app: app) } catch let error as POSIXError
                    where [.ENOENT, .ECONNREFUSED].contains(error.code)
                {
                    // The app is still starting its listener.
                }
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while ContinuousClock.now < deadline
        throw CommandError("GlassNotes is unavailable. Open the app bundled with this CLI and try again.")
    }

    private static func connect(to pid: pid_t, app: URL) throws -> CommandSocket {
        let client = try CommandSocket(descriptor: socket(AF_UNIX, SOCK_STREAM, 0))
        let fd = client.handle.fileDescriptor
        try CommandSocket.withAddress(CommandSocket.path(for: pid)) { address, length in
            guard Darwin.connect(fd, address, length) == 0 else { throw CommandSocket.systemError() }
        }
        var token = audit_token_t()
        var size = socklen_t(MemoryLayout.size(ofValue: token))
        var peerPID: pid_t = 0
        var pidSize = socklen_t(MemoryLayout.size(ofValue: peerPID))
        guard getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &peerPID, &pidSize) == 0, peerPID == pid,
            getsockopt(fd, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &size) == 0,
            size == MemoryLayout.size(ofValue: token)
        else { throw CommandError("Could not verify the GlassNotes process.") }
        let attributes = [kSecGuestAttributeAudit as String: Data(bytes: &token, count: Int(size))] as CFDictionary
        var installed: SecStaticCode?
        var requirement: SecRequirement?
        var peer: SecCode?
        func check(_ status: OSStatus, _ operation: String) throws {
            guard status == errSecSuccess else {
                throw CommandError(
                    "Could not verify GlassNotes (\(operation), \(status)). Quit the app and retry.")
            }
        }
        try check(SecStaticCodeCreateWithPath(app as CFURL, [], &installed), "app signature")
        guard let installed else { throw CommandError("Missing application signature.") }
        try check(SecCodeCopyDesignatedRequirement(installed, [], &requirement), "signing requirement")
        guard let requirement else { throw CommandError("Missing application signing requirement.") }
        try check(SecCodeCopyGuestWithAttributes(nil, attributes, [], &peer), "peer code")
        guard let peer else { throw CommandError("Missing peer code.") }
        try check(SecCodeCheckValidity(peer, [], requirement), "peer signature")
        return client
    }
}
