import CryptoKit
import Foundation
import Testing

@testable import GlassNotes

struct UpdateInstallerTests {
    @Test func installsVerifiedImageAndPreservesOriginalOnFailure() throws {
        let files = FileManager.default
        let folder = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: folder) }
        let contents = folder.appendingPathComponent("image contents")
        let app = contents.appendingPathComponent("GlassNotes.app")
        let macOS = app.appendingPathComponent("Contents/MacOS")
        try files.createDirectory(at: macOS, withIntermediateDirectories: true)
        try files.copyItem(
            at: URL(fileURLWithPath: "/usr/bin/true"), to: macOS.appendingPathComponent("GlassNotes"))
        let installed = folder.appendingPathComponent("Installed GlassNotes.app")
        let plist = "Contents/Info.plist"
        func metadata(version: String) throws -> Data {
            try PropertyListSerialization.data(
                fromPropertyList: [
                    "CFBundleIdentifier": "app.glassnotes.mac", "CFBundleExecutable": "GlassNotes",
                    "CFBundleShortVersionString": version, "CFBundleVersion": version,
                    "CFBundlePackageType": "APPL",
                ], format: .xml, options: 0)
        }
        let original = try metadata(version: "1")
        let update = try metadata(version: "2")
        try original.write(to: app.appendingPathComponent(plist))
        try files.copyItem(at: app, to: installed)
        try update.write(to: app.appendingPathComponent(plist))
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        func makeImage(_ name: String) throws -> ReleasePackage {
            let image = folder.appendingPathComponent(name).appendingPathExtension("dmg")
            try run(
                "/usr/bin/hdiutil",
                ["create", "-quiet", "-srcfolder", contents.path, "-format", "UDZO", image.path])
            let digest = SHA256.hash(data: try Data(contentsOf: image)).map { String(format: "%02x", $0) }.joined()
            return ReleasePackage(version: "2", url: image, sha256: digest)
        }
        let image = try makeImage("Valid update")
        let download = folder.appendingPathComponent("CFNetworkDownload.tmp")
        try files.moveItem(at: image.url, to: download)
        let valid = ReleasePackage(version: "2", url: download, sha256: image.sha256)
        func install(_ package: ReleasePackage) throws {
            try UpdateInstaller.install(image: package.url, package: package, at: installed, runningVersion: "1")
        }

        let corrupt = ReleasePackage(version: "2", url: valid.url, sha256: String(repeating: "0", count: 64))
        #expect(throws: UpdateInstaller.Failure.wrongDigest) { try install(corrupt) }
        let mislabeled = ReleasePackage(version: "3", url: valid.url, sha256: valid.sha256)
        #expect(throws: UpdateInstaller.Failure.invalidApplication) { try install(mislabeled) }
        try Data("modified".utf8).write(to: app.appendingPathComponent("Contents/unsealed.txt"))
        let unsignedChange = try makeImage("Modified update")
        #expect(throws: UpdateInstaller.Failure.signature) { try install(unsignedChange) }
        #expect(try Data(contentsOf: installed.appendingPathComponent(plist)) == original)

        try install(valid)
        #expect(try Data(contentsOf: installed.appendingPathComponent(plist)) == update)
        try run("/usr/bin/codesign", ["--verify", "--strict", installed.path])
        #expect(throws: UpdateInstaller.Failure.changedApplication) { try install(valid) }
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "Fixture command failed: \(tool)")
    }
}
