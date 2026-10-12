import SwiftUI

/// Android's `WormaCeptorDistributionBar`: a dot, label and "count (percent)" over an 8 pt bar whose fill grows over
/// 600 ms.
struct InspectorDistributionBar: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    private static let fillDuration = 0.6

    @State private var shownFraction: CGFloat = 0

    private var fraction: CGFloat {
        total > 0 ? CGFloat(count) / CGFloat(total) : 0
    }

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Circle().fill(color).frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
                Text(label)
                    .font(InspectorFont.bodyMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                Text("\(count) (\(Int((fraction * 100).rounded()))%)")
                    .font(InspectorFont.body.weight(.semibold).monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                        .fill(InspectorTheme.surfaceHigh)
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                        .fill(color)
                        .frame(width: proxy.size.width * shownFraction)
                }
            }
            .frame(height: InspectorTheme.Spacing.sm)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(count) of \(total), \(Int((fraction * 100).rounded())) percent")
        .onAppear { grow() }
        .onChange(of: fraction) { _ in grow() }
    }

    private func grow() {
        withInspectorAnimation(InspectorMotion.standard(Self.fillDuration)) { shownFraction = fraction }
    }
}

#if DEBUG
#Preview("Distribution bars") {
    VStack(spacing: InspectorTheme.Spacing.md) {
        InspectorDistributionBar(label: "2xx Success", count: 842, total: 1000, color: Color(rgb: 0x10B981))
        InspectorDistributionBar(label: "4xx Client Error", count: 120, total: 1000, color: Color(rgb: 0xF59E0B))
        InspectorDistributionBar(label: "5xx Server Error", count: 38, total: 1000, color: Color(rgb: 0xEF4444))
    }
    .padding()
}
#endif
