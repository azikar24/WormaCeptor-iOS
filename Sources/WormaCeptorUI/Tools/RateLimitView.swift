import SwiftUI
import WormaCeptor

/// The shared network throttle. Deliveries arrive on the main queue.
final class RateLimitModel: ObservableObject {
    @Published private(set) var state: WormaCeptorRateLimitState?

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorRateLimit.shared.observe { [weak self] state in
            self?.state = state
        }
    }

    deinit {
        subscription?.cancel()
    }
}

/// Network throttling: on/off, Android's presets, custom speeds, latency and packet loss, and what it did.
struct RateLimitScreen: View {
    @StateObject private var model = RateLimitModel()

    var body: some View {
        Group {
            if let state = model.state {
                RateLimitContent(state: state, presets: WormaCeptorRateLimit.shared.presets)
            } else {
                InspectorSkeletonList(rows: 4, rowHeight: 96)
            }
        }
        .inspectorScreen()
        .navigationTitle("Network throttling")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButton("arrow.counterclockwise", label: "Reset to defaults") {
                    WormaCeptorRateLimit.shared.resetToDefaults()
                }
                toolbarButton("trash", label: "Clear statistics") {
                    WormaCeptorRateLimit.shared.clearStats()
                }
            }
        }
    }

    private func toolbarButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .tint(InspectorTheme.brand)
        .accessibilityLabel(label)
    }
}

/// Android's layout: the enable card, then statistics, presets and custom configuration while throttling is on.
struct RateLimitContent: View {
    let state: WormaCeptorRateLimitState
    let presets: [WormaCeptorRateLimitPreset]
    var limiter: WormaCeptorRateLimit = .shared

    var body: some View {
        ScrollView {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                InspectorToggleCard(
                    title: "Rate limiting",
                    status: state.enabled ? "Active, throttling the network" : "Disabled",
                    systemImage: "speedometer",
                    isOn: state.enabled,
                    onToggle: { limiter.setEnabled(enabled: $0) }
                )
                if state.enabled {
                    VStack(spacing: InspectorTheme.Spacing.lg) {
                        RateLimitStatisticsCard(state: state)
                        RateLimitPresetsCard(state: state, presets: presets, limiter: limiter)
                        RateLimitConfigurationCard(state: state, limiter: limiter)
                    }
                    .transition(InspectorMotion.expand)
                }
                Text("Applies to URLSession with WormaCeptorURLSession installed and to Ktor clients with the "
                    + "WormaCeptor plugin. Mocked responses are not throttled. Changing a value replaces the preset; "
                    + "speeds are per request.")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.page), value: state.enabled)
    }
}

/// Android's `RateLimitCard`: an outlined card with a title row.
private struct RateLimitCard<Content: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack {
                Text(title)
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                trailing()
            }
            content()
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: InspectorTheme.Spacing.lg
        )
    }
}

private struct RateLimitStatisticsCard: View {
    let state: WormaCeptorRateLimitState

    var body: some View {
        RateLimitCard("Statistics") {
            Image(systemName: "network")
                .foregroundColor(InspectorTheme.secondaryText)
                .accessibilityHidden(true)
        } content: {
            HStack {
                stat("Requests throttled", "\(state.requestsThrottled)")
                stat(
                    "Packets dropped",
                    "\(state.packetsDropped)",
                    color: state.packetsDropped > 0 ? InspectorTheme.error : InspectorTheme.textPrimary
                )
            }
            HStack {
                stat("Total delay", InspectorFormat.duration(KotlinLong(longLong: state.totalDelayMs)) ?? "0 ms")
                stat("Bytes throttled", state.bytesThrottledText)
            }
        }
    }

    private func stat(_ label: String, _ value: String, color: Color = InspectorTheme.textPrimary) -> some View {
        VStack(spacing: InspectorTheme.Spacing.xxs) {
            Text(value)
                .font(InspectorFont.headline.weight(.bold).monospaced())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(InspectorTheme.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

private struct RateLimitPresetsCard: View {
    let state: WormaCeptorRateLimitState
    let presets: [WormaCeptorRateLimitPreset]
    let limiter: WormaCeptorRateLimit

    var body: some View {
        RateLimitCard("Network presets") {
            InspectorChipRow(inset: 0) {
                ForEach(presets, id: \.id) { preset in
                    InspectorChip(
                        label: preset.title,
                        isSelected: state.presetId == preset.id,
                        systemImage: Self.icon(preset.id)
                    ) {
                        limiter.applyPreset(id: preset.id)
                    }
                }
            }
            if let selected = presets.first(where: { $0.id == state.presetId }) {
                HStack {
                    info("icloud.and.arrow.down", "Down", selected.downloadText)
                    info("icloud.and.arrow.up", "Up", selected.uploadText)
                    info("timer", "Latency", "\(selected.latencyMs)ms")
                    info("exclamationmark.triangle", "Loss", "\(Int(selected.packetLossPercent))%")
                }
                .padding(InspectorTheme.Spacing.md)
                .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
                .transition(.opacity)
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: state.presetId)
    }

    private func info(_ systemImage: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: InspectorTheme.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: InspectorTheme.IconSize.sm - 2))
                .foregroundColor(InspectorTheme.secondaryText)
            Text(label)
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
            Text(value)
                .font(InspectorFont.code.weight(.semibold))
                .foregroundColor(InspectorTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }

    /// Android's preset icons: Wi-Fi, cellular bars, or no signal.
    static func icon(_ id: String) -> String {
        switch id {
        case "WIFI": return "wifi"
        case "OFFLINE": return "antenna.radiowaves.left.and.right.slash"
        default: return "cellularbars"
        }
    }
}

private struct RateLimitConfigurationCard: View {
    let state: WormaCeptorRateLimitState
    let limiter: WormaCeptorRateLimit

    var body: some View {
        RateLimitCard("Custom configuration") {
            VStack(spacing: InspectorTheme.Spacing.lg) {
                SpeedSlider(icon: "icloud.and.arrow.down", title: "Download speed", kbps: state.downloadSpeedKbps, text: state.downloadText) {
                    limiter.setDownloadSpeed(kbps: $0)
                }
                SpeedSlider(icon: "icloud.and.arrow.up", title: "Upload speed", kbps: state.uploadSpeedKbps, text: state.uploadText) {
                    limiter.setUploadSpeed(kbps: $0)
                }
                ValueSlider(
                    icon: "timer",
                    title: "Latency",
                    value: Double(state.latencyMs),
                    range: 0...Double(WormaCeptorRateLimit.shared.MAX_LATENCY_MS),
                    step: 50,
                    format: { "\(Int($0)) ms" },
                    onCommit: { limiter.setLatency(ms: Int64($0)) }
                )
                ValueSlider(
                    icon: "exclamationmark.triangle",
                    title: "Packet loss",
                    value: Double(state.packetLossPercent),
                    range: 0...100,
                    step: 1,
                    format: { "\(Int($0))%" },
                    onCommit: { limiter.setPacketLoss(percent: Float($0)) }
                )
            }
        }
    }
}

/// A speed from 1 Kbps to 100 Mbps on a log scale, so slow networks get as much of the track as fast ones.
private struct SpeedSlider: View {
    let icon: String
    let title: String
    let kbps: Int64
    let text: String
    let onCommit: (Int64) -> Void

    var body: some View {
        ValueSlider(
            icon: icon,
            title: title,
            value: log10(Double(max(kbps, 1))),
            range: 0...log10(Double(WormaCeptorRateLimit.shared.MAX_SPEED_KBPS)),
            step: 0.01,
            format: { Self.label(Self.kbps($0)) },
            initialText: text,
            onCommit: { onCommit(Self.kbps($0)) }
        )
    }

    private static func kbps(_ position: Double) -> Int64 {
        Int64(pow(10, position).rounded())
    }

    /// Android's format, for the value under the finger before the throttle reports it back.
    private static func label(_ kbps: Int64) -> String {
        kbps < 1000 ? "\(kbps) Kbps" : String(format: "%.1f Mbps", Double(kbps) / 1000)
    }
}

/// Android's `ConfigSlider`: icon, label and mono value over a brand slider. Commits when the finger lifts, so a
/// drag isn't a stream of config changes.
private struct ValueSlider: View {
    let icon: String
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var initialText: String?
    let onCommit: (Double) -> Void

    @State private var draft: Double?

    var body: some View {
        let shown = draft.map(format) ?? initialText ?? format(value)
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: InspectorTheme.IconSize.sm))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(width: InspectorTheme.IconSize.md)
                    .accessibilityHidden(true)
                Text(title)
                    .font(InspectorFont.body)
                    .foregroundColor(InspectorTheme.textPrimary)
                Spacer()
                Text(shown)
                    .font(InspectorFont.body.weight(.semibold).monospaced())
                    .foregroundColor(InspectorTheme.textPrimary)
            }
            Slider(
                value: Binding(get: { draft ?? value }, set: { draft = $0 }),
                in: range,
                step: step
            ) { editing in
                if !editing, let draft {
                    onCommit(draft)
                    self.draft = nil
                }
            }
            .tint(InspectorTheme.brand)
            .accessibilityLabel(title)
            .accessibilityValue(shown)
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
    }
}

#if DEBUG
#Preview("Throttling on") {
    NavigationView {
        RateLimitContent(state: PreviewSamples.rateLimit, presets: PreviewSamples.rateLimitPresets)
            .inspectorScreen()
            .navigationTitle("Network throttling")
    }
}

#Preview("Throttling on, dark") {
    NavigationView {
        RateLimitContent(state: PreviewSamples.rateLimit, presets: PreviewSamples.rateLimitPresets)
            .inspectorScreen()
            .navigationTitle("Network throttling")
    }
    .preferredColorScheme(.dark)
}
#endif
