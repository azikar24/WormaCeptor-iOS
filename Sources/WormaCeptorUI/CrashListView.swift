import SwiftUI
import WormaCeptor

final class CrashListModel: ObservableObject {
    @Published private(set) var rows: [WormaCeptorCrashRow] = []

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorCrashes.shared.observeCrashes { [weak self] rows in
            self?.rows = rows
        }
    }

    deinit {
        subscription?.cancel()
    }

    func clear() {
        WormaCeptorCrashes.shared.clear()
    }
}

/// Crashes of earlier launches, newest first, with clear.
struct CrashListScreen: View {
    @StateObject private var model = CrashListModel()

    var body: some View {
        CrashListContent(rows: model.rows, onClear: model.clear)
    }
}

struct CrashListContent: View {
    let rows: [WormaCeptorCrashRow]
    let onClear: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        List(rows, id: \.id) { row in
            NavigationLink(destination: CrashDetailScreen(id: row.id)) {
                CrashRowView(row: row)
            }
        }
        .listStyle(.plain)
        .overlay {
            if rows.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.shield",
                    title: "No crashes",
                    message: "When the app crashes, the crash shows up here on the next launch."
                )
            }
        }
        .navigationTitle("Crashes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel("Clear crashes")
                .disabled(rows.isEmpty)
            }
        }
        .confirmationDialog("Clear all crashes?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
    }
}

struct CrashRowView: View {
    let row: WormaCeptorCrashRow

    private var when: String {
        CrashFormat.relative(row.timestampMs)
    }

    var body: some View {
        HStack(alignment: .top, spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(InspectorTheme.color(for: .error))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                Text(row.exceptionType)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let message = row.message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    if let location = row.location {
                        Text(location)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: InspectorTheme.Spacing.sm)
                    Text(when)
                        .font(.caption)
                }
                .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([row.exceptionType, row.message, row.location, when].compactMap { $0 }.joined(separator: ", "))
    }
}

enum CrashFormat {
    static func date(_ epochMillis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }

    static func relative(_ epochMillis: Int64) -> String {
        date(epochMillis).formatted(.relative(presentation: .named))
    }

    static func full(_ epochMillis: Int64) -> String {
        date(epochMillis).formatted(date: .abbreviated, time: .standard)
    }
}

#if DEBUG
#Preview("Crashes") {
    NavigationView {
        CrashListContent(rows: PreviewSamples.crashRows, onClear: {})
    }
}

#Preview("Crashes, empty") {
    NavigationView {
        CrashListContent(rows: [], onClear: {})
    }
}
#endif
