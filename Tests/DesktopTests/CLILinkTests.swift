import AppKit
import NoteCore
import Testing

@testable import GlassNotes

@MainActor
struct CLILinkTests {
    let files = FileManager.default

    private func fixture(in directory: URL) throws -> CLILink {
        let helper = directory.appendingPathComponent("Test 'app'/Contents/Helpers/glassnotes")
        try files.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: helper)
        return CLILink(
            helper: helper, command: directory.appendingPathComponent("bin/glassnotes"),
            applicationsDirectory: directory)
    }

    @Test func suppressionPersistsAndAllowsManualInstallation() async throws {
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? files.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        let link = try fixture(in: root)
        let alternate = CLILink(
            helper: link.helper, command: link.command,
            applicationsDirectory: root.appendingPathComponent("Applications"))
        #expect(throws: (any Error).self) { try alternate.install() }
        #expect(!files.fileExists(atPath: link.command.path))
        let firstLaunch = CLILinkSettings(link: link, defaults: defaults)
        #expect(firstLaunch.shouldRemind)
        let nextLaunch = CLILinkSettings(link: link, defaults: defaults)
        #expect(nextLaunch.shouldRemind)
        nextLaunch.suppressReminder = true
        let settings = CLILinkSettings(link: link, defaults: try #require(UserDefaults(suiteName: suite)))
        #expect(!settings.shouldRemind)
        settings.install()
        while settings.installing { await Task.yield() }
        #expect(settings.message == nil)
        #expect(settings.status == .installed)
        #expect(try files.destinationOfSymbolicLink(atPath: link.command.path) == link.helper.path)
        try link.install()
        settings.suppressReminder = false
        #expect(!settings.shouldRemind)
        try files.removeItem(at: link.command)
        settings.refresh()
        #expect(settings.shouldRemind)
    }

    @Test func preservesOccupiedAndDanglingEntriesAndRecognizesRelativeLinks() throws {
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        let link = try fixture(in: root)
        try files.createDirectory(at: link.command.deletingLastPathComponent(), withIntermediateDirectories: true)
        for isDirectory in [false, true] {
            if isDirectory {
                try files.createDirectory(at: link.command, withIntermediateDirectories: false)
            } else {
                try Data("existing".utf8).write(to: link.command)
            }
            #expect(link.status == .occupied)
            #expect(throws: (any Error).self) { try link.install() }
            if isDirectory {
                #expect(try files.contentsOfDirectory(atPath: link.command.path).isEmpty)
            } else {
                #expect(try String(contentsOf: link.command, encoding: .utf8) == "existing")
            }
            try files.removeItem(at: link.command)
        }
        try files.createSymbolicLink(atPath: link.command.path, withDestinationPath: "missing")
        #expect(link.status == .occupied)
        #expect(throws: (any Error).self) { try link.install() }
        #expect(try files.destinationOfSymbolicLink(atPath: link.command.path) == "missing")
        try files.removeItem(at: link.command)
        try files.createSymbolicLink(
            atPath: link.command.path, withDestinationPath: "missing/../../Test 'app'/Contents/Helpers/glassnotes")
        #expect(link.status == .occupied)
        try files.removeItem(at: link.command)
        try files.createSymbolicLink(
            atPath: link.command.path, withDestinationPath: "../Test 'app'/Contents/Helpers/glassnotes")
        #expect(link.status == .installed)
    }
}

extension NativeDesktopTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLASSNOTES_WINDOW_TESTS"] == "1"))
    func backgroundCLIReminderWaitsForMenuAndSupportsKeyboardInstallation() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        let state = AppState(library: try NoteLibrary(directory: root))
        let tool = root.appendingPathComponent("helper")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: tool)
        let link = CLILink(
            helper: tool, command: root.appendingPathComponent("glassnotes"), applicationsDirectory: root)
        let settings = CLILinkSettings(link: link, defaults: defaults)
        let menu = StatusMenu(
            state: state, desktop: DesktopWindows(state: state), shortcut: CaptureShortcut {},
            cliSettings: settings)
        menu.checkCLIOnLaunch(inBackground: true)
        func visiblePanel() -> NSWindow? { NSApp.windows.first { $0.isVisible && $0.title == "快速记录" } }
        #expect(visiblePanel() == nil)
        menu.toggleCapture()
        try await Task.sleep(for: .milliseconds(200))
        #expect(visiblePanel()?.firstResponder is NSTextView)
        menu.toggleCapture()
        menu.show()
        let panel = try #require(visiblePanel())
        defer { if panel.isVisible { menu.toggle() } }
        try await Task.sleep(for: .milliseconds(200))
        let enter = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        try #require(panel.performKeyEquivalent(with: enter))
        let deadline = ContinuousClock.now + .seconds(2)
        while settings.status != .installed && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(settings.status == .installed)
        menu.toggle()
        menu.checkCLIOnLaunch(inBackground: false)
        #expect(visiblePanel() == nil)
        try FileManager.default.removeItem(at: link.command)
        menu.checkCLIOnLaunch(inBackground: false)
        #expect(visiblePanel() != nil)
        menu.toggleCapture()
        try await Task.sleep(for: .milliseconds(200))
        #expect(visiblePanel()?.firstResponder is NSTextView)
    }
}
