import AppKit
import NoteCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    let library: NoteLibrary
    @Published private(set) var notes: [Note]
    @Published var captureDraft = ""
    @Published var captureInk = Ink.automatic
    var changed: (() -> Void)?

    init(library: NoteLibrary) {
        self.library = library
        notes = library.notes
        library.onChange = { [weak self] in
            guard let self else { return }
            self.notes = self.library.notes
            self.changed?()
        }
    }

    @discardableResult
    func perform(_ change: () throws -> Void) -> Bool {
        do {
            try change()
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "未能保存这次更改"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }
}

enum InitialNotes {
    static func make(display: String) -> [Note] {
        [
            Note(text: "记得带伞 ☂", ink: .chalk, placement: .init(display: display, x: 0.13, y: 0.16)),
            Note(
                text: "周五前发报价\n核对印刷和装订费用，\n把新版发给小陈。", ink: .carbon,
                placement: .init(display: display, x: 0.77, y: 0.32)),
            Note(
                text: "周末看展\n周六下午去美术馆", ink: .petrol,
                placement: .init(display: display, x: 0.18, y: 0.68)),
            Note(
                text: "看展清单\n带速写本和铅笔", ink: .petrol,
                placement: .init(display: display, x: 0.50, y: 0.80)),
        ]
    }
}
