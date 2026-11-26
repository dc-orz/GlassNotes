import NoteDesign
import SwiftUI

struct GlassAdjustmentPane: View {
    let done: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var glass = DesktopGlassPreference()

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.section) {
            HStack {
                Text("玻璃透明度").font(Tokens.TypeStyle.heading)
                Spacer()
                Button("完成", action: done)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.section) {
                Picker(
                    "基础预设",
                    selection: Binding(
                        get: { glass.selection.base },
                        set: { glass.selection = NoteGlassAppearance($0) }
                    )
                ) {
                    ForEach(GlassTransparency.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                slider("材质强度", value: glass.binding.materialOpacity, range: Tokens.NoteGlass.materialRange)
                slider("背景压暗", value: glass.binding.dimming, range: Tokens.NoteGlass.dimmingRange)
                Button("恢复「\(glass.selection.base.title)」预设") {
                    glass.selection = NoteGlassAppearance(glass.selection.base)
                }
                .disabled(glass.selection == NoteGlassAppearance(glass.selection.base))
            }
            .disabled(reduceTransparency)
            Text(reduceTransparency ? "系统已开启「减少透明度」，便签使用实色背景。" : "调整会实时应用到所有桌面便签。")
                .font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: Tokens.Space.tight) {
            HStack {
                Text(label)
                Spacer()
                Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit().foregroundStyle(.secondary)
            }.accessibilityHidden(true)
            Slider(value: value, in: range) { Text(label) }
                .labelsHidden()
                .accessibilityValue(Text(value.wrappedValue, format: .percent.precision(.fractionLength(0))))
        }
    }
}

extension GlassTransparency {
    fileprivate var title: String {
        switch self {
        case .clear: "通透"
        case .standard: "标准"
        case .low: "低透"
        }
    }
}
