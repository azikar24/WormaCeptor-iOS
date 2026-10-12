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
                ProgressView()
            }
        }
        .navigationTitle("Network throttling")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    WormaCeptorRateLimit.shared.resetToDefaults()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel("Reset to defaults")
            }
        }
    }
}

struct RateLimitContent: View {
    let state: WormaCeptorRateLimitState
    let presets: [WormaCeptorRateLimitPreset]
    var limiter: WormaCeptorRateLimit = .shared

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(get: { state.enabled }, set: { limiter.setEnabled(enabled: $0) })) {
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        Text("Throttle requests")
                        Text(state.enabled ? "Active, throttling the network" : "Off")
                            .font(.footnote)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
            } footer: {
                Text("Applies to URLSession with WormaCeptorURLSession installed and to Ktor clients with the "
                    + "WormaCeptor plugin. Mocked responses are not throttled.")
            }

            Section("Presets") {
                ForEach(presets, id: \.id) { preset in
                    PresetRow(preset: preset, isSelected: state.presetId == preset.id) {
                        limiter.applyPreset(id: preset.id)
                    }
                }
            }

            Section {
                SpeedSlider(title: "Download speed", kbps: state.downloadSpeedKbps, text: state.downloadText) {
                    limiter.setDownloadSpeed(kbps: $0)
                }
                SpeedSlider(title: "Upload speed", kbps: state.uploadSpeedKbps, text: state.uploadText) {
                    limiter.setUploadSpeed(kbps: $0)
                }
                ValueSlider(
                    title: "Latency",
                    value: Double(state.latencyMs),
                    range: 0...Double(WormaCeptorRateLimit.shared.MAX_LATENCY_MS),
                    step: 50,
                    format: { "\(Int($0)) ms" },
                    onCommit: { limiter.setLatency(ms: Int64($0)) }
                )
                ValueSlider(
                    title: "Packet loss",
                    value: Double(state.packetLossPercent),
                    range: 0...100,
                    step: 1,
                    format: { "\(Int($0))%" },
                    onCommit: { limiter.setPacketLoss(percent: Float($0)) }
                )
            } header: {
                Text("Custom")
            } footer: {
                Text("Changing a value replaces the preset. Speeds are per request.")
            }
            .disabled(!state.enabled)

            Section {
                StatRow(label: "Requests throttled", value: "\(state.requestsThrottled)")
                StatRow(
                    label: "Packets dropped",
                    value: "\(state.packetsDropped)",
                    color: state.packetsDropped > 0 ? InspectorTheme.color(for: .error) : nil
                )
                StatRow(label: "Total delay", value: Self.delay(state.totalDelayMs))
                StatRow(label: "Bytes throttled", value: state.bytesThrottledText)
                Button("Clear statistics") { limiter.clearStats() }
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            } header: {
                Text("Statistics")
            }
        }
        .listStyle(.insetGrouped)
    }

    private static func delay(_ milliseconds: Int64) -> String {
        InspectorFormat.duration(KotlinLong(longLong: milliseconds)) ?? "0 ms"
    }
}

private struct PresetRow: View {
    let preset: WormaCeptorRateLimitPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(preset.title)
                        .foregroundColor(.primary)
                    Text(summary)
                        .font(.footnote.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var summary: String {
        if preset.downloadKbps == 0 && preset.uploadKbps == 0 {
            return "Every request fails"
        }
        return "Down \(preset.downloadText), up \(preset.uploadText), \(preset.latencyMs) ms, "
            + "\(Int(preset.packetLossPercent))% loss"
    }
}

/// A speed from 1 Kbps to 100 Mbps on a log scale, so slow networks get as much of the track as fast ones.
private struct SpeedSlider: View {
    let title: String
    let kbps: Int64
    let text: String
    let onCommit: (Int64) -> Void

    var body: some View {
        ValueSlider(
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

/// A labelled slider that commits when the finger lifts, so a drag isn't a stream of config changes.
private struct ValueSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var initialText: String?
    let onCommit: (Double) -> Void

    @State private var draft: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                Text(title)
                Spacer()
                Text(draft.map(format) ?? initialText ?? format(value))
                    .font(.callout.monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
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
            .accessibilityLabel(title)
            .accessibilityValue(draft.map(format) ?? initialText ?? format(value))
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var color: Color?

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(color ?? .primary)
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Throttling on") {
    NavigationView {
        RateLimitContent(state: PreviewSamples.rateLimit, presets: PreviewSamples.rateLimitPresets)
            .navigationTitle("Network throttling")
    }
}
#endif
