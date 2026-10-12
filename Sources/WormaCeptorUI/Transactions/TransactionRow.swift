import SwiftUI
import UIKit
import WormaCeptor

/// Android's `SelectableTransactionItem`: an outlined card per request that opens its detail and has a long-press
/// menu.
struct TransactionRow: View {
    let row: WormaCeptorTransactionRow

    var body: some View {
        NavigationLink(destination: TransactionDetailScreen(id: row.id)) {
            TransactionRowCard(row: row)
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityLabel(Self.accessibilityText(row))
        .contextMenu {
            // Only what WormaCeptorInspectorData exposes per row today: no cURL, share, or single delete.
            Button {
                UIPasteboard.general.string = row.url
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }
        }
    }

    static func accessibilityText(_ row: WormaCeptorTransactionRow) -> String {
        let status = row.statusCode.map { "status \($0.intValue)" } ?? (row.isInFlight ? "in flight" : "failed")
        let parts = [row.method, row.path, row.host, status, InspectorFormat.duration(row.durationMs), row.isMocked ? "mocked" : nil]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }
}

struct TransactionRowCard: View {
    let row: WormaCeptorTransactionRow

    private var statusText: String {
        if let code = row.statusCode?.intValue { return String(code) }
        return row.isInFlight ? "?" : "ERR"
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    InspectorMethodBadge(method: row.method)
                    if row.isMocked {
                        InspectorBadge(text: "MOCKED", color: InspectorTheme.mocked)
                    }
                    Text(row.path)
                        .font(InspectorFont.bodyMedium)
                        .foregroundColor(InspectorTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Text(row.host)
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: InspectorTheme.Spacing.xxs) {
                InspectorBadge(text: statusText, color: InspectorTheme.color(for: row.tone))
                Text(InspectorFormat.duration(row.durationMs) ?? "?")
                    .font(InspectorFont.labelSmall.monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .inspectorCard()
    }
}

#if DEBUG
#Preview("Rows") {
    NavigationView {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(PreviewSamples.rows, id: \.id) { row in
                    TransactionRow(row: row)
                        .padding(.horizontal, InspectorTheme.Spacing.sm)
                        .padding(.vertical, InspectorTheme.Spacing.xs)
                }
            }
        }
        .inspectorScreen()
    }
}

#Preview("Rows, dark") {
    VStack(spacing: InspectorTheme.Spacing.sm) {
        ForEach(PreviewSamples.rows, id: \.id) { TransactionRowCard(row: $0) }
    }
    .padding(InspectorTheme.Spacing.sm)
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
#endif
