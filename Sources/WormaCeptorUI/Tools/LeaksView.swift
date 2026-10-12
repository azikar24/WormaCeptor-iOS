import SwiftUI
import WormaCeptor

/// Found leaks, live.
@MainActor
final class LeaksModel: ObservableObject {
    @Published private(set) var leaks: [WormaCeptorLeak] = []

    let isWatching = WormaCeptorLeakReports.shared.isWatching
    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorLeakReports.shared.observe { [weak self] leaks in self?.leaks = leaks }
    }

    deinit {
        subscription?.cancel()
    }

    func clear() {
        WormaCeptorLeakReports.shared.clear()
    }
}

/// View controllers still alive after they left the screen, the same list `list_leaks` returns.
struct LeaksScreen: View {
    @StateObject private var model = LeaksModel()

    var body: some View {
        LeaksContent(leaks: model.leaks, isWatching: model.isWatching, onClear: model.clear)
    }
}

/// Android's leak detection: severity summary cards, severity chips, then one card per leak. A card opens its
/// details in a sheet.
struct LeaksContent: View {
    static let severities = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]

    let leaks: [WormaCeptorLeak]
    let isWatching: Bool
    let onClear: () -> Void

    @State private var severity: String?
    @State private var selected: WormaCeptorLeak?
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorLeak] {
        severity.map { wanted in leaks.filter { $0.severity.uppercased() == wanted } } ?? leaks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
            summaryRow
            severityChips
            leakList
        }
        .padding(.top, InspectorTheme.Spacing.lg)
        .inspectorScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                InspectorMonitoringTitle(title: "Leaks", isActive: isWatching)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .tint(InspectorTheme.brand)
                .disabled(leaks.isEmpty)
                .accessibilityLabel("Clear leaks")
            }
        }
        .confirmationDialog("Clear all leaks?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let selected {
                LeakDetailSheet(leak: selected)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            ForEach(Self.severities, id: \.self) { name in
                let count = leaks.filter { $0.severity.uppercased() == name }.count
                InspectorSummaryCard(
                    value: "\(count)",
                    label: name.capitalized,
                    color: count > 0 ? MiscToolColors.Leak.color(name) : InspectorTheme.textPrimary
                )
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
    }

    private var severityChips: some View {
        InspectorChipRow {
            InspectorChip(label: "All", isSelected: severity == nil) { select(nil) }
            ForEach(Self.severities, id: \.self) { name in
                InspectorChip(label: name.capitalized, isSelected: severity == name) {
                    select(severity == name ? nil : name)
                }
            }
        }
    }

    @ViewBuilder private var leakList: some View {
        let visible = filtered
        if visible.isEmpty {
            InspectorEmptyState(
                systemImage: "ladybug",
                title: isWatching ? "Monitoring for leaks…" : "Leak detection is off",
                message: isWatching
                    ? "Open and close screens. A controller still alive a few seconds after it left (5 by default) with no parent, presenter or window shows up here."
                    : "Call WormaCeptorLeaks.install() at launch to watch view controllers."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, leak in
                        LeakCard(leak: leak) { selected = leak }
                    }
                }
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.bottom, InspectorTheme.Spacing.lg)
            }
        }
    }

    private func select(_ name: String?) {
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { severity = name }
    }
}

enum LeakFormat {
    static func shortName(_ leak: WormaCeptorLeak) -> String {
        leak.className.components(separatedBy: ".").last ?? leak.className
    }
}

/// Android's `LeakCard`: a severity well, the class, its description and time, and the severity letter.
private struct LeakCard: View {
    let leak: WormaCeptorLeak
    let onOpen: () -> Void

    var body: some View {
        let color = MiscToolColors.Leak.color(leak.severity)
        Button(action: onOpen) {
            HStack(spacing: InspectorTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: InspectorTheme.IconSize.md - 2))
                    .foregroundColor(color)
                    .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(color.opacity(InspectorTheme.Alpha.subtle)))
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(LeakFormat.shortName(leak))
                        .font(InspectorFont.bodyMedium.weight(.semibold))
                        .foregroundColor(InspectorTheme.textPrimary)
                        .lineLimit(1)
                    Text(leak.details)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(1)
                    Text(InspectorFormat.time(leak.timestampMs))
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                InspectorBadge(text: String(leak.severity.prefix(1)), color: color)
            }
            .inspectorCard(
                fill: InspectorTheme.surface,
                border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
                radius: InspectorTheme.Radius.lg
            )
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(leak.severity.capitalized) leak, \(LeakFormat.shortName(leak)), \(leak.details)")
        .accessibilityAddTraits(.isButton)
    }
}

/// Android's `LeakDetailContent` in a sheet: header with the severity, then the details.
private struct LeakDetailSheet: View {
    let leak: WormaCeptorLeak
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let color = MiscToolColors.Leak.color(leak.severity)
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                    HStack(spacing: InspectorTheme.Spacing.md) {
                        InspectorIconWell(systemImage: "memorychip", color: color, size: InspectorTheme.Spacing.xxxl, iconSize: InspectorTheme.IconSize.lg)
                        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                            Text(LeakFormat.shortName(leak))
                                .font(InspectorFont.titleLarge)
                                .foregroundColor(InspectorTheme.textPrimary)
                            InspectorBadge(text: leak.severity, color: color)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    InspectorSectionCard("Details", systemImage: "info.circle") {
                        InspectorKeyValueRow(label: "Class", value: leak.className, monospaced: true)
                        InspectorKeyValueRow(label: "Description", value: leak.details)
                        InspectorKeyValueRow(label: "Detected", value: InspectorFormat.time(leak.timestampMs))
                        InspectorKeyValueRow(
                            label: "Retained for",
                            value: InspectorFormat.duration(KotlinLong(value: leak.retainedForMs)) ?? ""
                        )
                    }
                }
                .padding(InspectorTheme.Spacing.lg)
            }
            .inspectorScreen()
            .navigationTitle("Leak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(InspectorTheme.brand)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Leaks") {
    NavigationView {
        LeaksContent(leaks: PreviewSamples.leaks, isWatching: true, onClear: {})
    }
}

#Preview("Leaks dark") {
    NavigationView {
        LeaksContent(leaks: PreviewSamples.leaks, isWatching: true, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Leaks off") {
    NavigationView {
        LeaksContent(leaks: [], isWatching: false, onClear: {})
    }
}
#endif
