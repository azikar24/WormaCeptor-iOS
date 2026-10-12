import SwiftUI

/// Android's `WormaCeptorSummaryCard`: a bold value over a small label, centered in an outlined card.
struct InspectorSummaryCard: View {
    let value: String
    let label: String
    var systemImage: String?
    var color: Color = InspectorTheme.textPrimary
    /// Dims the card, like Android does for a store it can't read.
    var isDimmed = false

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: InspectorTheme.IconSize.md - 2, weight: .medium))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(height: InspectorTheme.IconSize.md)
                    .padding(.bottom, InspectorTheme.Spacing.xxs)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(InspectorFont.headline.weight(.bold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .opacity(isDimmed ? InspectorTheme.Alpha.bold : 1)
        .frame(maxWidth: .infinity)
        .inspectorCard(fill: InspectorTheme.surface, radius: InspectorTheme.Radius.lg, padding: InspectorTheme.Spacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

extension InspectorSummaryCard {
    init(
        count: Int,
        label: String,
        systemImage: String? = nil,
        color: Color = InspectorTheme.textPrimary,
        isDimmed: Bool = false
    ) {
        self.init(value: "\(count)", label: label, systemImage: systemImage, color: color, isDimmed: isDimmed)
    }
}

#Preview("Summary cards") {
    HStack(spacing: InspectorTheme.Spacing.sm) {
        InspectorSummaryCard(count: 12, label: "Total")
        InspectorSummaryCard(value: "2", label: "Critical", color: InspectorTheme.error)
        InspectorSummaryCard(count: 2, label: "Keys", systemImage: "key", isDimmed: true)
    }
    .padding()
}
