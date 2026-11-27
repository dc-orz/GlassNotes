import CryptoKit
import Darwin
import Foundation

enum UpdateInstaller {
    enum Failure: LocalizedError {
        case unavailableLocation, changedApplication, wrongDigest, invalidApplication, incompatibleSystem
        case mount, detach, signature

        var errorDescription: String? {
            switch self {
            case .unavailableLocation: "当前位置无法安装更新。请将 GlassNotes 移到可写的「应用程序」文件夹，重新打开后重试。"
            case .changedApplication: "磁盘上的 GlassNotes 已更改，请重新打开后检查更新。"
            case .wrongDigest: "下载文件的 SHA-256 校验失败，请重新下载。"
            case .invalidApplication: "安装包中的应用与此版本或 Mac 架构不符。"
            case .incompatibleSystem: "此版本需要更新的 macOS。"
            case .mount: "无法打开下载的磁盘镜像。"
            case .detach: "无法推出更新磁盘镜像，请重试。"
            case .signature: "安装包中的 GlassNotes 未通过代码签名校验。"
            }
        }
    }

    @concurrent static func install(_ package: ReleasePackage) async throws {
        let destination = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard let runningVersion = ReleaseCheck.installedVersion, destination.pathExtension == "app",
            try destination.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly != true,
            FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path)
        else { throw Failure.unavailableLocation }
        let (image, response) = try await URLSession.shared.download(from: package.url)
        defer { try? FileManager.default.removeItem(at: image) }
        guard let http = response as? HTTPURLResponse else { throw ReleaseCheck.Failure.invalidResponse }
        guard http.statusCode == 200 else { throw ReleaseCheck.Failure.http(http.statusCode) }
        try install(image: image, package: package, at: destination, runningVersion: runningVersion)
    }

    static func install(image: URL, package: ReleasePackage, at destination: URL, runningVersion: String) throws {
        let file = try FileHandle(forReadingFrom: image)
        defer { try? file.close() }
        var hash = SHA256()
        while let bytes = try file.read(upToCount: 1024 * 1024), !bytes.isEmpty { hash.update(data: bytes) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == package.sha256 else {
            throw Failure.wrongDigest
        }

        let files = FileManager.default
        let staging = try files.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destination, create: true)
        defer { try? files.removeItem(at: staging) }
        let candidate = staging.appendingPathComponent("GlassNotes.app")
        try copyApplication(from: image, to: candidate)
        try validate(candidate, version: package.version)

        // Read the file directly. Bundle caches the metadata of the running copy.
        let info = try metadata(at: destination)
        guard info.identifier == "app.glassnotes.mac", info.version == runningVersion
        else { throw Failure.changedApplication }
        guard renamex_np(candidate.path, destination.path, UInt32(RENAME_SWAP)) == 0 else {
            let code = errno
            if [EACCES, EPERM, EROFS].contains(code) { throw Failure.unavailableLocation }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
    }

    private struct Metadata: Decodable {
        let identifier: String
        let version: String
        let minimumOS: String?

        enum CodingKeys: String, CodingKey {
            case identifier = "CFBundleIdentifier"
            case version = "CFBundleShortVersionString"
            case minimumOS = "LSMinimumSystemVersion"
        }
    }

    private static func metadata(at app: URL) throws -> Metadata {
        let data = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        return try PropertyListDecoder().decode(Metadata.self, from: data)
    }

    private static func validate(_ app: URL, version: String) throws {
        guard let info = try? metadata(at: app), info.identifier == "app.glassnotes.mac",
            info.version == version, let bundle = Bundle(url: app),
            bundle.executableArchitectures?.contains(
                NSNumber(value: MacArchitecture.current.executableArchitecture)) == true
        else { throw Failure.invalidApplication }
        if let minimum = info.minimumOS {
            let os = ProcessInfo.processInfo.operatingSystemVersion
            let current = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
            guard current.compare(minimum, options: .numeric) != .orderedAscending else {
                throw Failure.incompatibleSystem
            }
        }
        try run("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path], failure: .signature)
    }

    private static func copyApplication(from image: URL, to candidate: URL) throws {
        let files = FileManager.default
        let mount = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(
            at: mount, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { _ = rmdir(mount.path) }
        try run(
            "/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-mountpoint", mount.path, image.path],
            failure: .mount)
        do {
            let source = mount.appendingPathComponent("GlassNotes.app")
            let type = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard type.isDirectory == true, type.isSymbolicLink != true else { throw Failure.invalidApplication }
            try files.copyItem(at: source, to: candidate)
        } catch {
            try run("/usr/bin/hdiutil", ["detach", "-force", mount.path], failure: .detach)
            throw error
        }
        do {
            try run("/usr/bin/hdiutil", ["detach", mount.path], failure: .detach)
        } catch {
            try run("/usr/bin/hdiutil", ["detach", "-force", mount.path], failure: .detach)
        }
    }

    private static func run(_ executable: String, _ arguments: [String], failure: Failure) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw failure }
    }
}
