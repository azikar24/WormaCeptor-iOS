import SwiftUI
import WormaCeptor

/// Android's CPU screen: status, the usage gauge, usage over time, then the details.
struct CpuContent: View {
    let state: WormaCeptorMetricState

    var body: some View {
        MetricPage(state: state) {
            CpuGaugeCard(state: state)
            MetricChartCard(
                title: "CPU Usage Over Time",
                values: state.doubles,
                range: 0...100,
                thresholds: [
                    ChartThreshold(value: CpuThreshold.warning, color: InspectorTheme.color(for: .warning)),
                    ChartThreshold(value: CpuThreshold.critical, color: InspectorTheme.color(for: .error)),
                ],
                summary: state.chartSummary
            ) {
                ChartLegendItem(label: "CPU Usage", color: InspectorTheme.brand)
            }
            MetricDetailsCard(state: state)
        }
    }
}

/// Android's CPU thresholds (`CpuUsageGauge.kt`).
enum CpuThreshold {
    static let warning = 50.0
    static let critical = 80.0

    static func tone(_ percent: Double) -> WormaCeptorStatusTone {
        percent >= critical ? .error : percent >= warning ? .warning : .success
    }
}

/// Android's `CpuUsageGaugeCard`: a 270 degree gauge that sweeps to the reading over 500 ms, the percent in its middle.
struct CpuGaugeCard: View {
    let state: WormaCeptorMetricState

    private static let gaugeSize: CGFloat = 160
    private static let containerHeight: CGFloat = 200
    private static let stroke: CGFloat = 16
    private static let sweep = 0.75

    var body: some View {
        let color = InspectorTheme.color(for: CpuThreshold.tone(state.value))
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: InspectorTheme.IconSize.md, weight: .semibold))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Overall CPU Usage")
                        .font(InspectorFont.titleMedium)
                        .foregroundColor(InspectorTheme.textPrimary)
                    Text("App Process CPU")
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Spacer(minLength: 0)
                if state.isRunning && state.value >= CpuThreshold.critical {
                    HighUsageBadge().transition(.opacity)
                }
            }
            gauge(color: color)
        }
        .inspectorCard(radius: InspectorTheme.Radius.xl, padding: InspectorTheme.Spacing.lg)
    }

    private func gauge(color: Color) -> some View {
        let progress = min(max(state.value / 100, 0), 1)
        return ZStack {
            Circle()
                .trim(from: 0, to: Self.sweep)
                .stroke(InspectorTheme.outline.opacity(InspectorTheme.Alpha.medium), style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: Self.sweep * progress)
                .stroke(color, style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round))
                .rotationEffect(.degrees(135))
                .inspectorAnimation(InspectorMotion.standard(InspectorMotion.verySlow), value: progress)
            VStack(spacing: 0) {
                Text(String(format: "%.1f%%", state.value))
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .foregroundColor(color)
                if let cores = state.detail("Cores") {
                    Text("\(cores) cores")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
        }
        .padding(Self.stroke / 2)
        .frame(width: Self.gaugeSize, height: Self.gaugeSize)
        .frame(maxWidth: .infinity, minHeight: Self.containerHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CPU usage")
        .accessibilityValue(String(format: "%.0f percent", state.value))
    }
}

#if DEBUG
#Preview("CPU") {
    NavigationView {
        CpuContent(state: PreviewSamples.cpu).navigationTitle("CPU Monitor")
    }
}

#Preview("CPU high dark") {
    NavigationView {
        CpuContent(state: PreviewSamples.cpuHigh).navigationTitle("CPU Monitor")
    }
    .preferredColorScheme(.dark)
}
#endif
