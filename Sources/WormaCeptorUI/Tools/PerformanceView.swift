import Combine
import SwiftUI
import UIKit
import WormaCeptor

/// The shared CPU, memory and FPS monitors. Deliveries arrive on the main queue.
final class PerformanceModel: ObservableObject {
    @Published private(set) var state: WormaCeptorPerformanceState?

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorPerformance.shared.observe { [weak self] state in
            self?.state = state
        }
    }

    deinit {
        subscription?.cancel()
    }
}

extension WormaCeptorPerformanceState {
    func metric(_ metric: WormaCeptorMetric) -> WormaCeptorMetricState {
        switch metric {
        case .cpu: return cpu
        case .memory: return memory
        default: return fps
        }
    }
}

extension WormaCeptorMetric {
    /// Android's screen titles.
    var title: String {
        switch self {
        case .cpu: return "CPU Monitor"
        case .memory: return "Memory Monitor"
        default: return "FPS Monitor"
        }
    }
}

extension WormaCeptorMetricState {
    var doubles: [Double] {
        history.map(\.doubleValue)
    }

    var chartSummary: String {
        history.isEmpty ? "No readings" : "\(history.count) readings, latest \(valueText)"
    }

    /// Android's warning badge next to the title: CPU from 80%, memory at the error tone.
    var isHigh: Bool {
        guard isRunning else { return false }
        switch metric {
        case .cpu: return value >= CpuThreshold.critical
        case .memory: return tone == .error
        default: return false
        }
    }

    func detail(_ label: String) -> String? {
        details.first { $0.label == label }?.value
    }

    /// The leading number of a detail ("58 fps", "62%"), for the cards that show it on its own.
    func detailNumber(_ label: String) -> Double? {
        guard let value = detail(label) else { return nil }
        return Double(value.prefix { $0.isNumber || $0 == "." || $0 == "-" })
    }
}

/// One monitor, laid out like Android's CPU, memory and FPS screens. Like Android, it samples only while started
/// here, by an agent (`set_monitoring`), or by the overlay.
struct MetricScreen: View {
    let metric: WormaCeptorMetric
    @StateObject private var model = PerformanceModel()

    var body: some View {
        Group {
            if let state = model.state?.metric(metric) {
                switch metric {
                case .cpu: CpuContent(state: state)
                case .memory: MemoryContent(state: state)
                default: FpsContent(state: state)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).inspectorScreen()
            }
        }
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        let state = model.state?.metric(metric)
        let running = state?.isRunning == true
        ToolbarItem(placement: .principal) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(metric.title).font(.headline)
                if state?.isHigh == true {
                    WarningBadge().transition(.opacity)
                }
            }
            .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: state?.isHigh == true)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if running {
                    WormaCeptorPerformance.shared.stop(metric: metric)
                } else {
                    WormaCeptorPerformance.shared.start(metric: metric)
                }
            } label: {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .foregroundColor(running ? InspectorTheme.brand : InspectorTheme.secondaryText)
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            .accessibilityLabel(running ? "Pause monitoring" : "Start monitoring")
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                WormaCeptorPerformance.shared.clearHistory(metric: metric)
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            .accessibilityLabel("Clear history")
        }
    }
}

/// The scrolling column every monitor screen shares: 16 pt padding and gaps, the status row first.
struct MetricPage<Content: View>: View {
    let state: WormaCeptorMetricState
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                MonitoringStatusBar(isMonitoring: state.isRunning, sampleCount: state.history.count)
                content()
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
    }
}

/// The monitor's label/value rows, standing in for Android's system info card.
struct MetricDetailsCard: View {
    let state: WormaCeptorMetricState

    var body: some View {
        if !state.details.isEmpty {
            InspectorSectionCard("Details", systemImage: "info.circle") {
                ForEach(state.details, id: \.label) { row in
                    InspectorKeyValueRow(label: row.label, value: row.value)
                }
            }
        }
    }
}

#if DEBUG
#Preview("CPU running") {
    NavigationView {
        CpuContent(state: PreviewSamples.cpu).navigationTitle("CPU Monitor")
    }
}

#Preview("Memory stopped dark") {
    NavigationView {
        MemoryContent(state: PreviewSamples.memoryStopped).navigationTitle("Memory Monitor")
    }
    .preferredColorScheme(.dark)
}
#endif
