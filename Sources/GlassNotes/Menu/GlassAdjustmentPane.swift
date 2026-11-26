import NoteDesign
import SwiftUI

struct GlassAdjustmentPane: View {
    let done: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var glass = DesktopGlassPreference()

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
            HStack {
                Text("玻璃透明度").font(Tokens.TypeStyle.heading)
                Spacer()
                Button("完成", action: done)
            }
            if #available(macOS 26.0, *) {
                Toggle("使用原生 Liquid Glass", isOn: glass.$prefersNativeGlass)
                    .toggleStyle(.switch)
                    .disabled(reduceTransparency)
            }
            if !glass.usesNativeGlass {
                frostedControls.disabled(reduceTransparency)
            }
            Text(hint).font(Tokens.TypeStyle.help).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hint: String {
        if reduceTransparency { return "系统已开启「减少透明度」，便签使用实色背景。" }
        if glass.usesNativeGlass { return "点铅笔编辑便签，再点其他窗口，比较玻璃的折射变化。" }
        return "调整会实时应用到所有桌面便签。"
    }

    private var frostedControls: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.standard) {
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
