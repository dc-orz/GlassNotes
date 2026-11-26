// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GlassNotes",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GlassNotes", targets: ["GlassNotes"])],
    targets: [
        .target(name: "NoteCore"),
        .target(name: "NoteDesign"),
        .executableTarget(name: "GlassNotes", dependencies: ["NoteCore", "NoteDesign"]),
        .testTarget(name: "NoteCoreTests", dependencies: ["NoteCore"]),
        .testTarget(name: "DesktopTests", dependencies: ["GlassNotes", "NoteCore", "NoteDesign"]),
    ]
)
