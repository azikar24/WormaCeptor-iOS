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

struct LeaksContent: View {
    let leaks: [WormaCeptorLeak]
    let isWatching: Bool
    let onClear: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        List {
            if !isWatching {
                Section {
                    Text("Off. Call WormaCeptorLeaks.install() at launch to watch view controllers.")
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            Section {
                ForEach(Array(leaks.enumerated()), id: \.offset) { _, leak in
                    LeakRowView(leak: leak)
                }
            } footer: {
                if isWatching {
                    Text("A controller that leaves the screen is checked a few seconds later (5 by default). Still alive with no parent, no presenter and no window means something holds it. A controller the app caches to show again shows up here too.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if isWatching, leaks.isEmpty {
                Text("No leaks found")
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .navigationTitle("Leaks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(leaks.isEmpty)
                .accessibilityLabel("Clear leaks")
            }
        }
        .confirmationDialog("Clear all leaks?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
    }
}

private struct LeakRowView: View {
    let leak: WormaCeptorLeak

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                Text(leak.className.components(separatedBy: ".").last ?? leak.className)
                    .font(.body.weight(.semibold))
                Spacer()
                InspectorBadge(
                    text: leak.severity,
                    color: InspectorTheme.color(for: leak.severity == "CRITICAL" ? .error : .warning)
                )
            }
            Text(leak.details)
                .font(.footnote)
                .foregroundColor(InspectorTheme.secondaryText)
            Text("\(InspectorFormat.time(leak.timestampMs)) · \(leak.className)")
                .font(.caption)
                .foregroundColor(InspectorTheme.secondaryText)
                .textSelection(.enabled)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Leaks") {
    NavigationView {
        LeaksContent(leaks: PreviewSamples.leaks, isWatching: true, onClear: {})
    }
}

#Preview("Leaks off") {
    NavigationView {
        LeaksContent(leaks: [], isWatching: false, onClear: {})
    }
}
#endif
