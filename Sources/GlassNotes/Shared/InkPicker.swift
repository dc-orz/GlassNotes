import NoteCore
import SwiftUI

struct InkPicker: View {
    @Binding var selection: Ink
    var body: some View {
        Picker("墨色", selection: $selection) {
            ForEach(Ink.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        .fixedSize()
        .accessibilityLabel("墨色")
    }
}
