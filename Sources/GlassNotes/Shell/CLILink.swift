import Darwin
import Foundation

struct CLILink: Sendable {
    enum Status: Equatable {
        case missing, installed, occupied
        case unavailable(String)
    }

    static let defaultCommand = URL(fileURLWithPath: "/usr/local/bin/glassnotes")
    let helper: URL
    let command: URL
    private let applicationsDirectory: URL

    init(
        helper: URL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/glassnotes"),
        command: URL = CLILink.defaultCommand,
        applicationsDirectory: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    ) {
        self.helper = helper
        self.command = command
        self.applicationsDirectory = applicationsDirectory
    }

    var status: Status {
        let files = FileManager.default
        guard files.isExecutableFile(atPath: helper.path) else {
            return .unavailable("当前应用中找不到命令行工具，请打开完整的 GlassNotes.app。")
        }
        if helper.pathComponents.contains("AppTranslocation")
            || (try? helper.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true
        {
            return .unavailable("请先把 GlassNotes 拖入「应用程序」，然后重新打开。")
        }
        var entry = stat()
        guard lstat(command.path, &entry) == 0 else {
            let code = errno
            guard code == ENOENT else { return .unavailable(String(cString: strerror(code))) }
            // The system-wide command must keep working after downloads and build directories are removed.
            let applications = applicationsDirectory.resolvingSymlinksInPath().path
            guard helper.resolvingSymlinksInPath().path.hasPrefix(applications + "/") else {
                return .unavailable("请先把 GlassNotes 移到系统「应用程序」文件夹，重新打开后再启用命令行。")
            }
            return .missing
        }
        var linked = stat()
        var bundled = stat()
        guard entry.st_mode & S_IFMT == S_IFLNK, stat(command.path, &linked) == 0, stat(helper.path, &bundled) == 0
        else {
            return .occupied
        }
        return linked.st_dev == bundled.st_dev && linked.st_ino == bundled.st_ino ? .installed : .occupied
    }

    func install() throws {
        switch status {
        case .installed: return
        case .missing: break
        case .occupied: throw Failure("命令路径已被占用。请先移走同名文件或其他链接，再重试。")
        case .unavailable(let reason): throw Failure(reason)
        }
        do {
            try FileManager.default.createDirectory(
                at: command.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: command, withDestinationURL: helper)
        } catch {
            if status == .installed { return }
            guard command == Self.defaultCommand, Self.permissionDenied(error as NSError)
            else { throw error }
            try installWithAuthorization()
        }
        guard status == .installed else { throw Failure("未能验证命令链接，请重试。") }
    }

    private static func permissionDenied(_ error: NSError) -> Bool {
        if error.domain == NSPOSIXErrorDomain { return error.code == EACCES || error.code == EPERM }
        if error.domain == NSCocoaErrorDomain && error.code == CocoaError.fileWriteNoPermission.rawValue {
            return true
        }
        return (error.userInfo[NSUnderlyingErrorKey] as? NSError).map(permissionDenied) ?? false
    }

    private func installWithAuthorization() throws {
        // Passing the parent to ln creates exactly one entry named glassnotes, without replacing existing entries.
        let script = """
            on run argv
                set helperPath to quoted form of (item 1 of argv)
                try
                    do shell script ("/bin/mkdir -p /usr/local/bin && /bin/ln -s " & helperPath & " /usr/local/bin/") with administrator privileges
                on error number -128
                    return "cancelled"
                end try
            end run
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, helper.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let message = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if message == "cancelled" { throw Failure("已取消授权。需要时可重试。") }
        guard process.terminationStatus == 0 || status == .installed else {
            throw Failure(message.isEmpty ? "未能创建命令链接，请重试。" : message)
        }
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
