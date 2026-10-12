import SwiftUI
import WormaCeptor

/// Android's FPS screen: "Ready to monitor" until the first start, then the current rate, min/avg/max, the rate over
/// time, and dropped frames.
struct FpsContent: View {
    let state: WormaCeptorMetricState

    var body: some View {
        if !state.isRunning && state.history.isEmpty {
            InspectorEmptyState(
                systemImage: "play.fill",
                title: "Ready to monitor",
                message: "Tap play to start measuring frame rate",
                actionTitle: "Start Monitoring",
                action: { WormaCeptorPerformance.shared.start(metric: .fps) }
            )
            .inspectorScreen()
        } else {
            MetricPage(state: state) {
                CurrentFpsCard(value: state.value, isMonitoring: state.isRunning)
                HStack(spacing: InspectorTheme.Spacing.md) {
                    FpsStatCard(label: "Min", fps: state.detailNumber("Min"))
                    FpsStatCard(label: "Avg", fps: state.detailNumber("Average"))
                    FpsStatCard(label: "Max", fps: state.detailNumber("Max"))
                }
                MetricChartCard(
                    title: "FPS Over Time",
                    values: state.doubles,
                    range: 0...FpsStatus.chartCeiling,
                    thresholds: [
                        ChartThreshold(value: FpsStatus.good, color: InspectorTheme.color(for: .success)),
                        ChartThreshold(value: FpsStatus.warning, color: InspectorTheme.color(for: .warning)),
                    ],
                    summary: state.chartSummary
                ) {
                    ChartLegendItem(label: "FPS", color: InspectorTheme.brand)
                    ChartLegendItem(label: "Good (55+ fps)", color: InspectorTheme.color(for: .success))
                    ChartLegendItem(label: "Warning (< 30 fps)", color: InspectorTheme.color(for: .warning))
                }
                DroppedFramesCard(
                    dropped: state.detailNumber("Dropped frames"),
                    jank: state.detailNumber("Jank frames (over 32 ms)")
                )
            }
        }
    }
}

/// Android's `FpsStatus` and chart constants.
enum FpsStatus: Equatable {
    case excellent, moderate, poor, idle

    static let good = 55.0
    static let warning = 30.0
    static let chartCeiling = 65.0

    init(_ fps: Double) {
        if fps >= Self.good {
            self = .excellent
        } else if fps >= Self.warning {
            self = .moderate
        } else if fps > 0 {
            self = .poor
        } else {
            self = .idle
        }
    }

    var title: String {
        switch self {
        case .excellent: return "Excellent"
        case .moderate: return "Moderate"
        case .poor: return "Poor"
        case .idle: return "Not monitoring"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return InspectorTheme.color(for: .success)
        case .moderate: return InspectorTheme.color(for: .warning)
        case .poor: return InspectorTheme.color(for: .error)
        case .idle: return InspectorTheme.secondaryText
        }
    }
}

/// Android's `CurrentFpsCard`: the rate in its status color on a tint of it; both change over 300 ms.
struct CurrentFpsCard: View {
    let value: Double
    let isMonitoring: Bool

    var body: some View {
        let status = FpsStatus(value)
        VStack(spacing: InspectorTheme.Spacing.sm) {
            Text("Current FPS")
                .font(InspectorFont.bodyMedium)
                .foregroundColor(InspectorTheme.secondaryText)
            Text(status != .idle || isMonitoring ? "\(Int(value.rounded()))" : "--")
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(status.color)
            Text(status.title)
                .font(InspectorFont.body)
                .foregroundColor(status == .idle ? InspectorTheme.secondaryText : status.color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .inspectorCard(
            fill: status == .idle ? InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.moderate) : status.color.opacity(InspectorTheme.Alpha.light),
            border: status == .idle ? InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.strong) : status.color.opacity(InspectorTheme.Alpha.moderate),
            radius: InspectorTheme.Radius.xl,
            padding: InspectorTheme.Spacing.xl
        )
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.page), value: status)
    }
}

/// Android's `FpsStatCard`: the number in text color, a status dot by the label.
struct FpsStatCard: View {
    let label: String
    let fps: Double?

    var body: some View {
        let hasValue = (fps ?? 0) > 0
        VStack(spacing: InspectorTheme.Spacing.xxs) {
            Text(hasValue ? "\(Int((fps ?? 0).rounded()))" : "--")
                .font(InspectorFont.headline.weight(.bold).monospacedDigit())
                .foregroundColor(hasValue ? InspectorTheme.textPrimary : InspectorTheme.secondaryText)
            HStack(spacing: InspectorTheme.Spacing.xs) {
                if let fps, hasValue {
                    Circle().fill(FpsStatus(fps).color).frame(width: 6, height: 6)
                }
                Text(label)
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .inspectorCard(
            fill: InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.bold),
            border: .clear,
            radius: InspectorTheme.Radius.lg,
            padding: InspectorTheme.Spacing.md
        )
    }
}

/// Android's `DroppedFramesCard`.
struct DroppedFramesCard: View {
    let dropped: Double?
    let jank: Double?

    var body: some View {
        HStack {
            column("Dropped Frames", dropped, color: InspectorTheme.color(for: .warning))
            Rectangle()
                .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold))
                .frame(width: InspectorTheme.Border.thin, height: InspectorTheme.Spacing.xxxl)
            column("Jank Frames", jank, color: InspectorTheme.color(for: .error))
        }
        .inspectorCard(radius: InspectorTheme.Radius.lg, padding: InspectorTheme.Spacing.lg)
    }

    private func column(_ label: String, _ value: Double?, color: Color) -> some View {
        let count = Int(value ?? 0)
        return VStack(spacing: InspectorTheme.Spacing.xs) {
            Text(label)
                .font(InspectorFont.label)
                .foregroundColor(InspectorTheme.secondaryText)
            Text("\(count)")
                .font(InspectorFont.headline.weight(.bold).monospaced())
                .foregroundColor(count > 0 ? color : InspectorTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("FPS") {
    NavigationView {
        FpsContent(state: PreviewSamples.fpsRunning).navigationTitle("FPS Monitor")
    }
}

#Preview("FPS ready dark") {
    NavigationView {
        FpsContent(state: PreviewSamples.fpsStopped).navigationTitle("FPS Monitor")
    }
    .preferredColorScheme(.dark)
}
#endif
