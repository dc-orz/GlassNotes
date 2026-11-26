import SwiftUI

public struct InkEditor: View {
    @Binding var text: String
    let label: String

    public init(text: Binding<String>, label: String) {
        _text = text
        self.label = label
    }

    public var body: some View {
        TextEditor(text: $text)
            .font(Tokens.TypeStyle.ink)
            .scrollContentBackground(.hidden)
            .accessibilityLabel(label)
    }
}
