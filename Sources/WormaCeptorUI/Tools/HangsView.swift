import SwiftUI
import WormaCeptor

/// Found hangs and whether the watchdog runs, live.
@MainActor
final class HangsModel: ObservableObject {
    @Published private(set) var hangs: [WormaCeptorHang] = []
    @Published private(set) var isRunning = false

    private var subscriptions: [WormaCeptorSubscription] = []

    init() {
        subscriptions = [
            WormaCeptorHangs.shared.observe { [weak self] hangs in self?.hangs = hangs },
            WormaCeptorHangs.shared.observeRunning { [weak self] running in self?.isRunning = running.boolValue },
        ]
    }

    deinit {
        subscriptions.forEach { $0.cancel() }
    }

    func setRunning(_ running: Bool) {
        if running {
            WormaCeptorHangs.shared.start()
        } else {
            WormaCeptorHangs.shared.stop()
        }
    }

    func clear() {
        WormaCeptorHangs.shared.clear()
    }
}

/// Times the main thread stopped answering, the list `list_violations` returns.
struct HangsScreen: View {
    @StateObject private var model = HangsModel()

    var body: some View {
        HangsContent(
            hangs: model.hangs,
            isRunning: model.isRunning,
            onSetRunning: model.setRunning,
            onClear: model.clear
        )
    }
}

/// Android's thread violations screen, for hangs: monitoring dot and play/pause in the bar, summary cards, then one
/// card per hang. A card opens its stack in a sheet.
struct HangsContent: View {
    let hangs: [WormaCeptorHang]
    let isRunning: Bool
    let onSetRunning: (Bool) -> Void
    let onClear: () -> Void

    @State private var selected: WormaCeptorHang?
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
            summaryRow
            Text("Reports the main thread blocked for \(WormaCeptorHangs.shared.DefaultThresholdMs) ms or more, with its stack, the iOS stand-in for Android's StrictMode. The first \(WormaCeptorHangs.shared.StartupGraceMs / 1000) s after turning it on are skipped.")
                .font(InspectorFont.bodySmall)
                .foregroundColor(InspectorTheme.secondaryText)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
            hangList
        }
        .padding(.top, InspectorTheme.Spacing.lg)
        .inspectorScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                InspectorMonitoringTitle(title: "Hangs", isActive: isRunning)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onSetRunning(!isRunning)
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(isRunning ? "Stop detecting hangs" : "Detect hangs")
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(hangs.isEmpty)
                .accessibilityLabel("Clear hangs")
            }
        }
        .tint(InspectorTheme.brand)
        .confirmationDialog("Clear all hangs?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let selected {
                NavigationView { HangDetailView(hang: selected) }
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            InspectorSummaryCard(value: "\(hangs.count)", label: "Hangs", color: countColor(hangs.count))
            let severe = hangs.filter { $0.durationMs >= 1000 }.count
            InspectorSummaryCard(value: "\(severe)", label: "Over 1 s", color: countColor(severe))
            InspectorSummaryCard(
                value: hangs.map(\.durationMs).max().flatMap { InspectorFormat.duration(KotlinLong(value: $0)) } ?? "-",
                label: "Longest",
                color: countColor(hangs.count)
            )
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
    }

    @ViewBuilder private var hangList: some View {
        if hangs.isEmpty {
            InspectorEmptyState(
                systemImage: "exclamationmark.triangle",
                title: isRunning ? "Monitoring…" : "No hangs",
                message: isRunning ? "Hangs will appear here" : "Start monitoring to detect main thread hangs",
                actionTitle: isRunning ? nil : "Start",
                action: isRunning ? nil : { onSetRunning(true) }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                    ForEach(hangs, id: \.id) { hang in
                        HangCard(hang: hang) { selected = hang }
                    }
                }
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.bottom, InspectorTheme.Spacing.lg)
            }
        }
    }

    private func countColor(_ count: Int) -> Color {
        count > 0 ? InspectorTheme.textPrimary : InspectorTheme.secondaryText
    }
}

enum HangFormat {
    static func tone(_ hang: WormaCeptorHang) -> WormaCeptorStatusTone {
        hang.durationMs >= 1000 ? .error : .warning
    }

    static func duration(_ hang: WormaCeptorHang) -> String {
        InspectorFormat.duration(KotlinLong(value: hang.durationMs)) ?? ""
    }

    /// The first frame outside Apple's libraries: usually the app code that blocked.
    static func culprit(_ hang: WormaCeptorHang) -> String? {
        let system = ["libsystem_", "libdispatch", "libobjc", "Foundation", "CoreFoundation", "UIKitCore", "?  "]
        return hang.stack.first { frame in !system.contains { frame.hasPrefix($0) } }
    }
}

/// Android's `ViolationCard`: icon well, the culprit frame, time and duration, and a duration badge.
private struct HangCard: View {
    let hang: WormaCeptorHang
    let onOpen: () -> Void

    var body: some View {
        let color = InspectorTheme.color(for: HangFormat.tone(hang))
        Button(action: onOpen) {
            HStack(spacing: InspectorTheme.Spacing.md) {
                Image(systemName: "hourglass")
                    .font(.system(size: InspectorTheme.IconSize.md - 2))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(HangFormat.culprit(hang) ?? "No stack")
                        .font(InspectorFont.code.weight(.semibold))
                        .foregroundColor(InspectorTheme.textPrimary)
                        .lineLimit(1)
                    Text(InspectorFormat.time(hang.timestampMs))
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                InspectorBadge(text: HangFormat.duration(hang), color: color)
            }
            .inspectorCard(
                fill: InspectorTheme.surface,
                border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
            )
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hang, \(HangFormat.duration(hang)), \(InspectorFormat.time(hang.timestampMs)), \(HangFormat.culprit(hang) ?? "no stack")")
        .accessibilityAddTraits(.isButton)
    }
}

/// One hang's full main-thread stack, Android's `ViolationDetailContent`.
struct HangDetailView: View {
    let hang: WormaCeptorHang
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                HStack(spacing: InspectorTheme.Spacing.md) {
                    InspectorIconWell(
                        systemImage: "exclamationmark.triangle.fill",
                        color: InspectorTheme.color(for: HangFormat.tone(hang)),
                        size: InspectorTheme.Spacing.xxxl,
                        iconSize: InspectorTheme.IconSize.lg
                    )
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        Text("Main thread hang")
                            .font(InspectorFont.titleLarge)
                            .foregroundColor(InspectorTheme.textPrimary)
                        Text("Main thread")
                            .font(InspectorFont.bodySmall)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
                .accessibilityElement(children: .combine)
                InspectorSectionCard("Details", systemImage: "info.circle") {
                    InspectorKeyValueRow(label: "Blocked for", value: HangFormat.duration(hang))
                    InspectorKeyValueRow(label: "Started", value: InspectorFormat.time(hang.timestampMs))
                }
                stackSection
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .navigationTitle("Hang")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.tint(InspectorTheme.brand)
            }
        }
    }

    private var stackSection: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            HStack {
                Text("Stack trace")
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                CopyButton(text: hang.stack.joined(separator: "\n"), label: "Stack")
                    .tint(InspectorTheme.secondaryText)
            }
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                if hang.stack.isEmpty {
                    Text("The main thread couldn't be sampled.")
                        .font(InspectorFont.body)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                ForEach(Array(hang.stack.enumerated()), id: \.offset) { index, frame in
                    Text("\(index)  \(frame)")
                        .font(InspectorFont.code)
                        .foregroundColor(InspectorTheme.textPrimary.opacity(InspectorTheme.Alpha.prominent))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(InspectorTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
        }
    }
}

#if DEBUG
#Preview("Hangs") {
    NavigationView {
        HangsContent(hangs: PreviewSamples.hangs, isRunning: true, onSetRunning: { _ in }, onClear: {})
    }
}

#Preview("Hangs dark") {
    NavigationView {
        HangsContent(hangs: PreviewSamples.hangs, isRunning: true, onSetRunning: { _ in }, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Hang detail") {
    NavigationView {
        HangDetailView(hang: PreviewSamples.hangs[0])
    }
}
#endif
