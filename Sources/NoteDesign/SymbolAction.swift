import SwiftUI

public struct SymbolAction: View {
    let label: String
    let symbol: String
    let action: () -> Void

    public init(_ label: String, symbol: String, action: @escaping () -> Void) {
        self.label = label
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: Tokens.Size.action, height: Tokens.Size.action)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
