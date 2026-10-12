import SwiftUI
import WormaCeptor

/// Android's memory screen. iOS has no Java heap: the headline card shows the physical footprint against the app's
/// limit (where the system reports one), and the malloc card stands in for Android's native heap.
struct MemoryContent: View {
    let state: WormaCeptorMetricState

    var body: some View {
        MetricPage(state: state) {
            FootprintCard(state: state)
            MetricChartCard(
                title: "Memory Over Time",
                values: state.doubles,
                range: 0...max(state.doubles.max() ?? 1, 1),
                summary: state.chartSummary
            ) {
                ChartLegendItem(label: "Footprint", color: InspectorTheme.brand)
            }
            MallocCard(state: state)
        }
    }
}

/// Android's `HeapUsageCard`.
struct FootprintCard: View {
    let state: WormaCeptorMetricState

    var body: some View {
        let percent = state.detailNumber("Of limit")
        let color = state.tone == .neutral ? InspectorTheme.textPrimary : InspectorTheme.color(for: state.tone)
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: "memorychip")
                    .font(.system(size: InspectorTheme.IconSize.md, weight: .semibold))
                    .foregroundColor(state.tone == .neutral ? InspectorTheme.brand : color)
                    .accessibilityHidden(true)
                Text("Footprint")
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                Spacer(minLength: 0)
                if state.isRunning && state.tone == .error {
                    HighUsageBadge().transition(.opacity)
                }
            }
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(percent.map { String(format: "%.1f%%", $0) } ?? state.valueText)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundColor(color)
                    Spacer(minLength: InspectorTheme.Spacing.sm)
                    if let limit = state.detail("Limit") {
                        Text("\(state.valueText) / \(limit)")
                            .font(InspectorFont.code)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
                if let percent {
                    UsageBar(fraction: percent / 100, color: color)
                }
            }
            HStack {
                stat("Used", state.valueText)
                stat("Available", state.detail("Available"))
                stat("Limit", state.detail("Limit"), secondary: true)
            }
        }
        .inspectorCard(radius: InspectorTheme.Radius.md, padding: InspectorTheme.Spacing.lg)
    }

    private func stat(_ label: String, _ value: String?, secondary: Bool = false) -> some View {
        VStack(spacing: InspectorTheme.Spacing.xxs) {
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
            Text(value ?? "–")
                .font(InspectorFont.code.weight(.semibold))
                .foregroundColor(secondary ? InspectorTheme.secondaryText : InspectorTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Android's `NativeHeapCard`, on malloc zone numbers.
struct MallocCard: View {
    let state: WormaCeptorMetricState

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            Text("Malloc")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
            HStack {
                Text("\(state.detail("Malloc in use") ?? "–") / \(state.detail("Malloc reserved") ?? "–")")
                    .font(.callout.monospaced())
                    .foregroundColor(InspectorTheme.textPrimary)
                Spacer(minLength: 0)
            }
            Text("In use / reserved by the allocator")
                .font(InspectorFont.bodySmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .inspectorCard(radius: InspectorTheme.Radius.lg, padding: InspectorTheme.Spacing.lg)
    }
}

/// Android's rounded `LinearProgressIndicator`, animated to new values.
struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(InspectorTheme.surfaceHigh)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: InspectorTheme.Spacing.sm)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.slow), value: fraction)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Memory") {
    NavigationView {
        MemoryContent(state: PreviewSamples.memoryRunning).navigationTitle("Memory Monitor")
    }
}

#Preview("Memory dark") {
    NavigationView {
        MemoryContent(state: PreviewSamples.memoryStopped).navigationTitle("Memory Monitor")
    }
    .preferredColorScheme(.dark)
}
#endif
