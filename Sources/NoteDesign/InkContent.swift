import SwiftUI

public struct InkContent: View {
    let text: String
    let style: InkStyle

    public init(_ text: String, style: InkStyle) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        VStack(alignment: .leading, spacing: Tokens.Space.tight) {
            Text(verbatim: String(lines.first ?? ""))
                .font(Tokens.TypeStyle.title)
            if lines.count > 1 {
                Text(verbatim: String(lines[1]))
                    .font(Tokens.TypeStyle.ink)
                    .lineSpacing(Tokens.TypeStyle.markerLeading)
            }
        }
        .foregroundStyle(style.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
