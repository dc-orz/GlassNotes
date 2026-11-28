import Darwin
import Foundation
import NoteCommands

final class CommandServer {
    private let source: DispatchSourceRead

    init(desktop: DesktopWindows) throws {
        let path = try CommandSocket.path(for: getpid())
        let listener = try CommandSocket(descriptor: socket(AF_UNIX, SOCK_STREAM, 0))
        let fd = listener.handle.fileDescriptor
        // A previously killed app may have left this user's socket behind before its PID was reused.
        var stale = stat()
        if lstat(path, &stale) == 0 {
            guard stale.st_mode & S_IFMT == S_IFSOCK, stale.st_uid == geteuid(), unlink(path) == 0
            else { throw POSIXError(.EADDRINUSE) }
        }
        try CommandSocket.withAddress(path) { address, length in
            guard bind(fd, address, length) == 0 else { throw CommandSocket.systemError() }
        }
        guard chmod(path, 0o600) == 0, listen(fd, 16) == 0, fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else {
            let error = CommandSocket.systemError()
            unlink(path)
            throw error
        }
        source = DispatchSource.makeReadSource(
            fileDescriptor: fd, queue: DispatchQueue(label: "GlassNotes.CLI.accept"))
        source.setEventHandler {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            DispatchQueue.global(qos: .userInitiated).async { Self.serve(client, desktop: desktop) }
        }
        source.setCancelHandler {
            unlink(path)
            try? listener.handle.close()
        }
        source.resume()
    }

    func stop() { source.cancel() }

    private static func serve(_ descriptor: Int32, desktop: DesktopWindows) {
        guard let client = try? CommandSocket(descriptor: descriptor) else { return }
        var uid = uid_t.max
        var gid = gid_t.max
        guard getpeereid(descriptor, &uid, &gid) == 0, uid == geteuid() else { return }
        let reply: CommandReply
        do {
            // Even JSON-escaped arguments cannot exceed six bytes per byte of the OS argument limit.
            let data = try client.receive(limit: 6 * Int(sysconf(_SC_ARG_MAX)) + 1024)
            let command = try JSONDecoder().decode(NoteCommand.self, from: data)
            reply = try DispatchQueue.main.sync {
                switch command {
                case .add(let text): .note(CommandNote(try desktop.add(text: text)))
                case .list: .list(desktop.state.notes.map(CommandNote.init))
                case .complete(let id): .note(CommandNote(try desktop.completeSavedNote(id)))
                }
            }
        } catch {
            reply = .failure(error.localizedDescription)
        }
        if let data = try? JSONEncoder().encode(reply) { try? client.send(data) }
    }
}
