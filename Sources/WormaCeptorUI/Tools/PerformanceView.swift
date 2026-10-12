import Combine
import SwiftUI
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
    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        default: return "FPS"
        }
    }

    var caption: String {
        switch self {
        case .cpu: return "The app's threads, as a share of all cores"
        case .memory: return "Physical footprint, what the system limits apps on"
        default: return "Frames per second on the main display"
        }
    }
}

/// One monitor: live value, the last minute as a line, details, start and stop. Like Android, it samples only while
/// started here, by an agent (`set_monitoring`), or by the overlay.
struct MetricScreen: View {
    let metric: WormaCeptorMetric
    @StateObject private var model = PerformanceModel()

    var body: some View {
        Group {
            if let state = model.state {
                MetricContent(
                    state: state.metric(metric),
                    isOverlayShowing: state.isOverlayShowing,
                    onClear: { WormaCeptorPerformance.shared.clearHistory(metric: metric) }
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                let running = model.state?.metric(metric).isRunning == true
                Button {
                    if running {
                        WormaCeptorPerformance.shared.stop(metric: metric)
                    } else {
                        WormaCeptorPerformance.shared.start(metric: metric)
                    }
                } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(running ? "Stop monitoring" : "Start monitoring")
            }
        }
    }
}

struct MetricContent: View {
    let state: WormaCeptorMetricState
    let isOverlayShowing: Bool
    var onClear: () -> Void = {}

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(state.isRunning || state.history.count > 0 ? state.valueText : "Off")
                            .font(.largeTitle.weight(.semibold).monospacedDigit())
                            .foregroundColor(InspectorTheme.color(for: state.tone))
                        Spacer()
                        InspectorBadge(
                            text: state.isRunning ? "LIVE" : "STOPPED",
                            color: InspectorTheme.color(for: state.isRunning ? .success : .neutral)
                        )
                    }
                    .accessibilityElement(children: .combine)
                    Sparkline(
                        values: state.history.map(\.doubleValue),
                        range: range,
                        color: InspectorTheme.color(for: state.isRunning ? .redirect : .neutral)
                    )
                    .frame(height: Self.chartHeight)
                    .accessibilityLabel("Last minute of \(state.metric.title)")
                    .accessibilityValue(chartSummary)
                    Text(state.metric.caption)
                        .font(.footnote)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .padding(.vertical, InspectorTheme.Spacing.xs)
            } footer: {
                if !state.isRunning && state.history.count == 0 {
                    Text("Start monitoring to sample once a second. It stops when you tap stop, not when you leave.")
                }
            }

            if state.isRunning || state.history.count > 0 {
                Section("Details") {
                    ForEach(state.details, id: \.label) { InfoRowView(row: $0) }
                }
            }

            Section {
                PerformanceOverlayToggle(isShowing: isOverlayShowing)
                Button("Clear history", action: onClear)
                    .frame(minHeight: InspectorTheme.minTouchTarget)
                    .disabled(state.history.count == 0)
            }
        }
        .listStyle(.insetGrouped)
    }

    private static let chartHeight: CGFloat = 96

    private var range: ClosedRange<Double> {
        let values = state.history.map(\.doubleValue)
        switch state.metric {
        case .cpu:
            return 0...100
        case .memory:
            guard let low = values.min(), let high = values.max(), high > 0 else { return 0...1 }
            // Footprint moves a few percent at a time; a zero-based axis would draw a flat line.
            return (low * 0.9)...(high * 1.05)
        default:
            return 0...max(60, values.max() ?? 0)
        }
    }

    private var chartSummary: String {
        guard state.history.count > 0 else { return "No readings" }
        return "\(state.history.count) readings, latest \(state.valueText)"
    }
}

/// The last minute of readings as a line, newest on the right. A plain path: Swift Charts needs iOS 16.
struct Sparkline: View {
    let values: [Double]
    let range: ClosedRange<Double>
    let color: Color

    /// Android keeps 60 readings; the line fills in from the right as they arrive.
    private static let slots = 60

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(InspectorTheme.secondaryText.opacity(InspectorTheme.badgeFillOpacity))
                    .frame(height: 1)
                line(in: size).stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func line(in size: CGSize) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            let step = size.width / CGFloat(max(values.count, Self.slots) - 1)
            let span = max(range.upperBound - range.lowerBound, .ulpOfOne)
            for (index, value) in values.enumerated() {
                let x = size.width - CGFloat(values.count - 1 - index) * step
                let fraction = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span
                let point = CGPoint(x: x, y: size.height * (1 - CGFloat(fraction)))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }
}

/// Shows or hides the floating overlay.
struct PerformanceOverlayToggle: View {
    let isShowing: Bool

    var body: some View {
        Toggle(isOn: Binding(
            get: { isShowing },
            set: { $0 ? WormaCeptorOverlay.show() : WormaCeptorOverlay.hide() }
        )) {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text("Floating overlay")
                Text("CPU, memory and FPS above the app. Tap it to open WormaCeptor.")
                    .font(.footnote)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
    }
}

/// The overlay switch on the Tools tab, with its own subscription so the rest of the list doesn't redraw every second.
struct PerformanceOverlayRow: View {
    @StateObject private var model = PerformanceModel()

    var body: some View {
        PerformanceOverlayToggle(isShowing: model.state?.isOverlayShowing == true)
    }
}

#if DEBUG
#Preview("CPU running") {
    NavigationView {
        MetricContent(state: PreviewSamples.cpu, isOverlayShowing: true)
            .navigationTitle("CPU")
    }
}

#Preview("Memory stopped") {
    NavigationView {
        MetricContent(state: PreviewSamples.memoryStopped, isOverlayShowing: false)
            .navigationTitle("Memory")
    }
}
#endif
