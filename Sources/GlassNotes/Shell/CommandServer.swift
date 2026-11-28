import CoreFoundation
import Foundation
import NoteCommands

@MainActor
final class CommandServer {
    private let port: CFMessagePort

    init(bundleID: String, desktop: DesktopWindows) throws {
        var context = CFMessagePortContext(
            version: 0, info: Unmanaged.passUnretained(desktop).toOpaque(),
            retain: { pointer in
                if let pointer { _ = Unmanaged<DesktopWindows>.fromOpaque(pointer).retain() }
                return pointer
            },
            release: { pointer in
                if let pointer { Unmanaged<DesktopWindows>.fromOpaque(pointer).release() }
            }, copyDescription: nil)
        let name = NoteCommand.portName(for: bundleID) as CFString
        guard
            let port = CFMessagePortCreateLocal(
                nil, name,
                { _, _, data, info in
                    guard let data, let info else { return nil }
                    let desktop = Unmanaged<DesktopWindows>.fromOpaque(info).takeUnretainedValue()
                    let request = data as Data
                    let response = MainActor.assumeIsolated {
                        CommandServer.respond(to: request, desktop: desktop)
                    }
                    guard let response else { return nil }
                    return .passRetained(response as CFData)
                }, &context, nil)
        else { throw CommandError("未能开启 GlassNotes 本地命令接口。") }
        self.port = port
        CFMessagePortSetDispatchQueue(port, .main)
    }

    func stop() { CFMessagePortInvalidate(port) }

    private static func respond(to data: Data, desktop: DesktopWindows) -> Data? {
        let reply: CommandReply
        do {
            switch try JSONDecoder().decode(NoteCommand.self, from: data) {
            case .add(let text): reply = .note(CommandNote(try desktop.add(text: text)))
            case .list: reply = .list(desktop.state.notes.map(CommandNote.init))
            case .complete(let id): reply = .note(CommandNote(try desktop.completeSavedNote(id)))
            }
        } catch {
            reply = .failure(error.localizedDescription)
        }
        return try? JSONEncoder().encode(reply)
    }
}
