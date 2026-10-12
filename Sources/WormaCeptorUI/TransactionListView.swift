import SwiftUI
import WormaCeptor

/// Live transaction list with metrics, search, filters and clear.
struct TransactionListScreen: View {
    @StateObject private var model = TransactionListModel()

    var body: some View {
        TransactionListContent(
            rows: model.rows,
            isLoaded: model.isLoaded,
            search: $model.search,
            filters: $model.filters,
            onClear: model.clear
        )
    }
}

struct TransactionListContent: View {
    let rows: [WormaCeptorTransactionRow]
    var isLoaded = true
    @Binding var search: String
    @Binding var filters: TransactionFilters
    let onClear: () -> Void

    @State private var isConfirmingClear = false
    @State private var isFiltering = false

    private enum Phase { case loading, empty, content }

    private var visibleRows: [WormaCeptorTransactionRow] { filters.apply(to: rows) }

    private var hasActiveFilters: Bool { !filters.isEmpty || !search.isEmpty }

    private var activeFilterCount: Int { filters.count + (search.isEmpty ? 0 : 1) }

    var body: some View {
        let visible = visibleRows
        let phase: Phase = !isLoaded ? .loading : visible.isEmpty ? .empty : .content
        VStack(spacing: 0) {
            if hasActiveFilters {
                ActiveFiltersBanner(
                    search: search,
                    filters: filters,
                    onClearSearch: { search = "" },
                    onChange: { filters = $0 },
                    onClearAll: clearFilters
                )
                .transition(InspectorMotion.expand)
            }
            ZStack {
                switch phase {
                case .loading: InspectorSkeletonList().transition(.opacity)
                case .empty: emptyState.transition(.opacity)
                case .content: list(visible).transition(.opacity)
                }
            }
            .inspectorAnimation(InspectorMotion.standard(Self.crossfade), value: phase)
            .frame(maxHeight: .infinity)
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: hasActiveFilters)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: filters)
        .inspectorScreen()
        .searchable(text: $search, prompt: "URL or method")
        .navigationTitle("Transactions")
        .toolbar { toolbarItems }
        .sheet(isPresented: $isFiltering) {
            TransactionFilterSheet(rows: rows, filters: filters) { applied in
                filters = applied
                isFiltering = false
            }
            .filterSheetDetents()
        }
        .confirmationDialog("Clear all transactions?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        }
    }

    /// Android's `WormaCeptorLoadableContent` crossfade.
    private static let crossfade = 0.18

    private func list(_ visible: [WormaCeptorTransactionRow]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                MetricsCard(metrics: TransactionMetrics(rows: visible))
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
                    .padding(.vertical, InspectorTheme.Spacing.md)
                ForEach(visible, id: \.id) { row in
                    TransactionRow(row: row)
                        .padding(.horizontal, InspectorTheme.Spacing.sm)
                        .padding(.vertical, InspectorTheme.Spacing.xs)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, InspectorTheme.Spacing.xs)
        }
        // Android's animateItem: new and removed rows fade, the rest slide into place.
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: visible.map(\.id))
    }

    private var emptyState: some View {
        Group {
            if hasActiveFilters {
                InspectorEmptyState(
                    systemImage: "wifi",
                    title: "No matches found",
                    message: "Try adjusting your filters to see more results",
                    actionTitle: "Clear Filters",
                    action: clearFilters
                )
            } else {
                InspectorEmptyState(systemImage: "wifi", title: "No transactions yet", message: "Network requests will appear here")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isFiltering = true
            } label: {
                FilterButtonLabel(count: activeFilterCount)
            }
            .accessibilityLabel("Filter")
            .accessibilityValue(activeFilterCount == 0 ? "None active" : "\(activeFilterCount) active")
        }
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

    private func clearFilters() {
        search = ""
        filters = TransactionFilters()
    }
}

/// The filter icon with Android's filled brand count badge.
private struct FilterButtonLabel: View {
    let count: Int

    var body: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(count)")
                        .font(InspectorFont.badge.monospacedDigit())
                        .foregroundColor(InspectorTheme.background)
                        .frame(minWidth: InspectorTheme.IconSize.sm, minHeight: InspectorTheme.IconSize.sm)
                        .background(Circle().fill(InspectorTheme.brand))
                        .offset(x: -InspectorTheme.Spacing.xs, y: InspectorTheme.Spacing.xs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .inspectorAnimation(InspectorMotion.bouncy, value: count)
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
        TransactionListContent(rows: PreviewSamples.rows, search: .constant(""), filters: .constant(.init()), onClear: {})
    }
}

#Preview("Transactions, dark") {
    NavigationView {
        TransactionListContent(
            rows: PreviewSamples.rows,
            search: .constant(""),
            filters: .constant(TransactionFilters(methods: ["GET"])),
            onClear: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Transactions, loading") {
    NavigationView {
        TransactionListContent(rows: [], isLoaded: false, search: .constant(""), filters: .constant(.init()), onClear: {})
    }
}

#Preview("Transactions, empty") {
    NavigationView {
        TransactionListContent(rows: [], search: .constant(""), filters: .constant(.init()), onClear: {})
    }
}
#endif
