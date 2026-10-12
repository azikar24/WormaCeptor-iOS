import SwiftUI
import WormaCeptor

/// Android's `Colors.Chart`: bar fills only, never text.
enum InspectorChartColor {
    static let fast = Color(rgb: 0x10B981)
    static let medium = Color(rgb: 0xF59E0B)
    static let slow = Color(rgb: 0xEF4444)

    static func status(_ range: StatusRangeFilter) -> Color {
        switch range {
        case .success: return fast
        case .redirect: return Color(rgb: 0x1D4ED8)
        case .clientError: return medium
        case .serverError: return slow
        }
    }
}

/// Android's `MetricsCard`: success rate, total and average time; tap to expand the distributions.
struct MetricsCard: View {
    let metrics: TransactionMetrics

    @State private var isExpanded = false

    var body: some View {
        // Like Android the whole card toggles; VoiceOver gets the summary as the button and the details as text.
        VStack(alignment: .leading, spacing: 0) {
            summary
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint(isExpanded ? "Hides the breakdown" : "Shows the breakdown")
                .accessibilityAction { toggle() }
            if isExpanded {
                MetricsDetails(metrics: metrics).transition(InspectorMotion.expand)
            }
        }
        .inspectorCard(padding: InspectorTheme.Spacing.lg)
        .clipped()
        .onTapGesture(perform: toggle)
    }

    private func toggle() {
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.page)) { isExpanded.toggle() }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack {
                Text("Performance Metrics")
                    .font(InspectorFont.titleMedium.weight(.bold))
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: InspectorTheme.IconSize.md - 2, weight: .semibold))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                MetricsStat(value: metrics.successText, label: "Success", color: successColor)
                MetricsStat(value: "\(metrics.total)", label: "Total", color: InspectorTheme.textPrimary)
                MetricsStat(value: metrics.averageText, label: "Avg Time", color: InspectorTheme.textPrimary)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
    }

    /// Android's thresholds: 90% and up green, 70% and up amber, else red.
    private var successColor: Color {
        if metrics.successRate >= 90 { return InspectorTheme.color(for: .success) }
        if metrics.successRate >= 70 { return InspectorTheme.warning }
        return InspectorTheme.error
    }
}

/// Android's `WormaCeptorStatItem`: a big colored value over a small label.
private struct MetricsStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.xs) {
            Text(value)
                .font(InspectorFont.titleLarge.weight(.bold).monospacedDigit())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(InspectorFont.bodySmall.weight(.medium))
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

private struct MetricsDetails: View {
    let metrics: TransactionMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            Divider()
                .overlay(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium))
                .padding(.vertical, InspectorTheme.Spacing.xl)
            MetricsSectionHeader(title: "Response Time Distribution", systemImage: "speedometer")
            bar("Fast (<100ms)", metrics.fast, InspectorChartColor.fast)
            bar("Medium (100–500ms)", metrics.medium, InspectorChartColor.medium)
            bar("Slow (>500ms)", metrics.slow, InspectorChartColor.slow)
            MetricsSectionHeader(title: "Status Code Breakdown", systemImage: "chart.pie")
                .padding(.top, InspectorTheme.Spacing.lg)
            ForEach(metrics.statusRanges, id: \.range) { item in
                InspectorDistributionBar(
                    label: "\(item.range.label) \(item.range.sublabel)",
                    count: item.count,
                    total: metrics.total,
                    color: InspectorChartColor.status(item.range)
                )
            }
            if !metrics.methods.isEmpty {
                Text("Requests by Method")
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .padding(.top, InspectorTheme.Spacing.lg)
                ForEach(metrics.methods, id: \.method) { item in
                    methodRow(item.method, item.count)
                }
            }
        }
    }

    private func bar(_ label: String, _ bucket: TransactionMetrics.Bucket, _ color: Color) -> some View {
        InspectorDistributionBar(label: label, count: bucket.count, total: bucket.total, color: color)
    }

    private func methodRow(_ method: String, _ count: Int) -> some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Circle()
                .fill(InspectorTheme.brand.opacity(InspectorTheme.Alpha.heavy))
                .frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
            Text(method)
                .font(InspectorFont.bodyMedium)
                .foregroundColor(InspectorTheme.textPrimary)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(InspectorFont.body.weight(.semibold).monospacedDigit())
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .padding(.vertical, InspectorTheme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(method), \(count) requests")
    }
}

/// Android's `WormaCeptorSectionHeader`: a small brand icon and a semibold title.
private struct MetricsSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                .foregroundColor(InspectorTheme.brand.opacity(InspectorTheme.Alpha.heavy))
                .accessibilityHidden(true)
            Text(title)
                .font(InspectorFont.titleSmall)
                .foregroundColor(InspectorTheme.textPrimary)
        }
        .padding(.bottom, InspectorTheme.Spacing.xs)
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Metrics") {
    ScrollView {
        MetricsCard(metrics: TransactionMetrics(rows: PreviewSamples.rows)).padding()
    }
    .inspectorScreen()
}

#Preview("Metrics, dark") {
    ScrollView {
        MetricsCard(metrics: TransactionMetrics(rows: PreviewSamples.rows)).padding()
    }
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
#endif
