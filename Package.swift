// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GlassNotes",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GlassNotes", targets: ["GlassNotes"]),
        .executable(name: "GlassNotesCLI", targets: ["GlassNotesCLI"]),
    ],
    targets: [
        .target(name: "NoteCore"),
        .target(name: "NoteDesign"),
        .target(name: "NoteCommands", dependencies: ["NoteCore"]),
        .executableTarget(name: "GlassNotesCLI", dependencies: ["NoteCommands"]),
        .executableTarget(name: "GlassNotes", dependencies: ["NoteCore", "NoteDesign", "NoteCommands"]),
        .testTarget(name: "NoteCoreTests", dependencies: ["NoteCore"]),
        .testTarget(name: "DesktopTests", dependencies: ["GlassNotes", "NoteCore", "NoteDesign", "NoteCommands"]),
    ]
)
