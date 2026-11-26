import AppKit
import NoteCore
import SwiftUI

@main
enum GlassNotesMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var desktop: DesktopWindows?
    private var menu: StatusMenu?
    private var shortcut: CaptureShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directory = base.appendingPathComponent("GlassNotes", isDirectory: true)
            let library = try NoteLibrary(directory: directory) {
                InitialNotes.make(display: NSScreen.main?.displayKey ?? "main")
            }
            let state = AppState(library: library)
            let desktop = DesktopWindows(state: state)
            let shortcut = CaptureShortcut { [weak self] in self?.menu?.toggle() }
            self.desktop = desktop
            self.shortcut = shortcut
            menu = StatusMenu(state: state, desktop: desktop, shortcut: shortcut)
            state.changed = { [weak desktop] in desktop?.reconcile() }
            setupEditMenu()
            desktop.reconcile()
            shortcut.start()
        } catch {
            NSApp.activate()
            let alert = NSAlert(error: error)
            alert.messageText = "无法打开墨笺"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) { desktop?.reconcile() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menu?.show()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for entry in desktop?.windows.values.filter({ $0.card.editing }) ?? [] {
            if !entry.save() { return .terminateCancel }
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) { shortcut?.stop() }

    private func setupEditMenu() {
        let bar = NSMenu()
        let appMenu = NSMenu()
        let capture = appMenu.addItem(withTitle: "快速记录…", action: #selector(StatusMenu.show), keyEquivalent: "n")
        capture.target = menu
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出墨笺", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        bar.addItem(appItem)
        let edit = NSMenu(title: "编辑")
        for (title, selector, key) in [
            ("撤销", "undo:", "z"), ("剪切", "cut:", "x"),
            ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a"),
        ] {
            edit.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        let item = NSMenuItem()
        item.submenu = edit
        bar.addItem(item)
        NSApp.mainMenu = bar
    }
}
