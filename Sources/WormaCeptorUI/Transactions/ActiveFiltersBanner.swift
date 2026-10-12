import SwiftUI

/// Android's `ActiveFiltersBanner`: "Active filters:", a clear-all button, and one removable chip per filter.
struct ActiveFiltersBanner: View {
    let search: String
    let filters: TransactionFilters
    let onClearSearch: () -> Void
    let onChange: (TransactionFilters) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Active filters:")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer()
                Button(action: onClearAll) {
                    Image(systemName: "xmark")
                        .font(.system(size: InspectorTheme.IconSize.sm, weight: .semibold))
                        .foregroundColor(InspectorTheme.textPrimary)
                        .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear all filters")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InspectorTheme.Spacing.xs) {
                    if !search.isEmpty {
                        FilterChip(text: "\"\(search)\"", systemImage: "magnifyingglass", kind: "Search", action: onClearSearch)
                    }
                    ForEach(TransactionFilters.methods.filter(filters.methods.contains), id: \.self) { method in
                        FilterChip(text: method, kind: "HTTP method") {
                            onChange(TransactionFilters(methods: filters.methods.subtracting([method]), statusRanges: filters.statusRanges))
                        }
                    }
                    ForEach(StatusRangeFilter.allCases.filter(filters.statusRanges.contains)) { range in
                        FilterChip(text: range.label, kind: "Status code") {
                            onChange(TransactionFilters(methods: filters.methods, statusRanges: filters.statusRanges.subtracting([range])))
                        }
                    }
                }
            }
        }
        .padding(.leading, InspectorTheme.Spacing.lg)
        .padding(.trailing, InspectorTheme.Spacing.xs)
        .padding(.bottom, InspectorTheme.Spacing.xs)
        .background(InspectorTheme.background)
    }
}

/// Android's AssistChip in the banner: tap removes the filter.
private struct FilterChip: View {
    let text: String
    var systemImage: String?
    let kind: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: InspectorTheme.IconSize.xs, weight: .semibold))
                }
                Text(text).font(InspectorFont.labelSmall).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: InspectorTheme.IconSize.xs - 2, weight: .semibold))
            }
            .foregroundColor(InspectorTheme.textPrimary)
            .padding(.horizontal, InspectorTheme.Spacing.sm)
            .frame(height: InspectorTheme.Spacing.xxl)
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.xs)
                    .strokeBorder(InspectorTheme.outlineVariant, lineWidth: InspectorTheme.Border.regular)
            )
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind) filter: \(text)")
        .accessibilityHint("Removes this filter")
        .accessibilityAddTraits([.isButton, .isSelected])
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

#if DEBUG
#Preview("Active filters") {
    ActiveFiltersBanner(
        search: "orders",
        filters: TransactionFilters(methods: ["GET", "POST"], statusRanges: [.clientError]),
        onClearSearch: {},
        onChange: { _ in },
        onClearAll: {}
    )
}

#Preview("Active filters, dark") {
    ActiveFiltersBanner(
        search: "",
        filters: TransactionFilters(methods: ["DELETE"], statusRanges: [.success, .serverError]),
        onClearSearch: {},
        onChange: { _ in },
        onClearAll: {}
    )
    .preferredColorScheme(.dark)
}
#endif
