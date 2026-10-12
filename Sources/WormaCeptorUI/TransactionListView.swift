import SwiftUI
import WormaCeptor

/// Live transaction list with search and clear.
struct TransactionListScreen: View {
    @StateObject private var model = TransactionListModel()

    var body: some View {
        TransactionListContent(rows: model.rows, search: $model.search, onClear: model.clear)
    }
}

struct TransactionListContent: View {
    let rows: [WormaCeptorTransactionRow]
    @Binding var search: String
    let onClear: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        List(rows, id: \.id) { row in
            NavigationLink(destination: TransactionDetailScreen(id: row.id)) {
                TransactionRowView(row: row)
            }
        }
        .listStyle(.plain)
        .overlay {
            if rows.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.left.arrow.right",
                    title: search.isEmpty ? "No requests yet" : "No matches",
                    message: search.isEmpty
                        ? "Requests the app sends show up here as they happen."
                        : "Nothing matches \"\(search)\" in the URL or method."
                )
            }
        }
        .searchable(text: $search, prompt: "URL or method")
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel("Clear transactions")
                .disabled(rows.isEmpty)
            }
        }
        .confirmationDialog("Clear all transactions?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
    }
}

struct TransactionRowView: View {
    let row: WormaCeptorTransactionRow

    private var statusText: String {
        if let code = row.statusCode?.intValue { return String(code) }
        return row.isInFlight ? "..." : "ERR"
    }

    private var accessibilityText: String {
        let status = row.statusCode.map { "status \($0.intValue)" } ?? (row.isInFlight ? "in flight" : "failed")
        let parts = [row.method, row.path, row.host, status, InspectorFormat.duration(row.durationMs), row.isMocked ? "mocked" : nil]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text(row.method)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                    if row.isMocked {
                        InspectorBadge(text: "MOCK", color: InspectorTheme.mocked)
                    }
                    Text(row.path)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(row.host)
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: InspectorTheme.Spacing.sm)
            VStack(alignment: .trailing, spacing: InspectorTheme.Spacing.xs) {
                InspectorBadge(text: statusText, color: InspectorTheme.color(for: row.tone))
                if let duration = InspectorFormat.duration(row.durationMs) {
                    Text(duration)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

/// Centered icon, title and hint for an empty list.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(InspectorTheme.secondaryText)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(InspectorTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(InspectorTheme.Spacing.lg)
    }
}

#if DEBUG
#Preview("Transactions") {
    NavigationView {
        TransactionListContent(rows: PreviewSamples.rows, search: .constant(""), onClear: {})
    }
}

#Preview("Transactions, empty") {
    NavigationView {
        TransactionListContent(rows: [], search: .constant(""), onClear: {})
    }
}
#endif
