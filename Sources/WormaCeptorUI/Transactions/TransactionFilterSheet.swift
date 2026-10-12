import SwiftUI
import WormaCeptor

/// Android's `FilterBottomSheetContent`: method and status grids on a draft, applied with Done.
struct TransactionFilterSheet: View {
    let rows: [WormaCeptorTransactionRow]
    let onApply: (TransactionFilters) -> Void

    @State private var draft: TransactionFilters

    init(rows: [WormaCeptorTransactionRow], filters: TransactionFilters, onApply: @escaping (TransactionFilters) -> Void) {
        self.rows = rows
        self.onApply = onApply
        _draft = State(initialValue: filters)
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterSheetHeader(filteredCount: draft.apply(to: rows).count, totalCount: rows.count, isActive: !draft.isEmpty)
            divider
            ScrollView {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
                    sectionHeader("HTTP Method", systemImage: "chevron.left.forwardslash.chevron.right")
                    FilterGrid(items: TransactionFilters.methods) { method in
                        GridFilterCard(
                            label: method,
                            count: rows.filter { $0.method.uppercased() == method }.count,
                            color: TransactionFilters.methodColor(method),
                            isSelected: draft.methods.contains(method)
                        ) { toggle(&draft.methods, method) }
                    }
                    sectionHeader("Status Code", systemImage: "chart.pie")
                        .padding(.top, InspectorTheme.Spacing.md)
                    FilterGrid(items: StatusRangeFilter.allCases) { range in
                        GridFilterCard(
                            label: range.label,
                            sublabel: range.sublabel,
                            count: rows.filter { range.contains($0) }.count,
                            color: range.color,
                            isSelected: draft.statusRanges.contains(range)
                        ) { toggle(&draft.statusRanges, range) }
                    }
                }
                .padding(InspectorTheme.Spacing.lg)
            }
            divider
            HStack(spacing: InspectorTheme.Spacing.md) {
                Button {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.medium)) { draft = .init() }
                } label: {
                    Text("Clear All").frame(maxWidth: .infinity)
                }
                .buttonStyle(InspectorOutlinedButtonStyle())
                .disabled(draft.isEmpty)
                .opacity(draft.isEmpty ? InspectorTheme.Alpha.strong : 1)
                Button {
                    onApply(draft)
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(InspectorFilledButtonStyle())
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .background(InspectorTheme.background.ignoresSafeArea())
        .tint(InspectorTheme.brand)
    }

    private var divider: some View {
        Rectangle()
            .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium))
            .frame(height: InspectorTheme.Border.thin)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                .foregroundColor(InspectorTheme.brand.opacity(InspectorTheme.Alpha.heavy))
                .accessibilityHidden(true)
            Text(title)
                .font(InspectorFont.titleSmall)
                .foregroundColor(InspectorTheme.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func toggle<T>(_ set: inout Set<T>, _ value: T) {
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.medium)) {
            if set.contains(value) { set.remove(value) } else { set.insert(value) }
        }
    }
}

private struct FilterSheetHeader: View {
    let filteredCount: Int
    let totalCount: Int
    let isActive: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text("Filters")
                    .font(InspectorFont.titleLarge.weight(.bold))
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if isActive {
                    Text("\(filteredCount) of \(totalCount) requests")
                        .font(InspectorFont.label)
                        .foregroundColor(InspectorTheme.brand)
                        .transition(.opacity)
                }
            }
            Spacer()
            Text("\(filteredCount)")
                .font(InspectorFont.titleMedium.weight(.bold).monospacedDigit())
                .foregroundColor(isActive ? InspectorTheme.brand : InspectorTheme.secondaryText)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
                .background(Capsule().fill(isActive ? InspectorTheme.brand.opacity(InspectorTheme.Alpha.subtle) : InspectorTheme.surfaceHigh))
                .accessibilityLabel("\(filteredCount) of \(totalCount) requests shown")
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.md)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.medium), value: isActive)
    }
}

/// Two equal columns, like Android's `chunked(2)` rows.
private struct FilterGrid<Item: Hashable, Cell: View>: View {
    let items: [Item]
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: InspectorTheme.Spacing.sm), GridItem(.flexible())],
            spacing: InspectorTheme.Spacing.sm
        ) {
            ForEach(items, id: \.self) { cell($0) }
        }
    }
}

/// Android's `GridFilterCard`: dot, label, count and a check when selected; tinted and outlined in its color.
private struct GridFilterCard: View {
    let label: String
    var sublabel: String?
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    private var isEnabled: Bool { count > 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Circle()
                    .fill(color.opacity(isEnabled ? 1 : InspectorTheme.Alpha.moderate))
                    .frame(width: InspectorTheme.Spacing.sm, height: InspectorTheme.Spacing.sm)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(isSelected ? InspectorFont.body.weight(.bold) : InspectorFont.bodyMedium)
                        .foregroundColor(InspectorTheme.textPrimary.opacity(isEnabled ? 1 : InspectorTheme.Alpha.strong))
                    if let sublabel {
                        Text(sublabel)
                            .font(InspectorFont.labelSmall)
                            .foregroundColor(InspectorTheme.secondaryText.opacity(isEnabled ? 1 : InspectorTheme.Alpha.bold))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(InspectorFont.body.weight(.bold).monospacedDigit())
                    .foregroundColor(color.opacity(isEnabled ? 1 : InspectorTheme.Alpha.moderate))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: InspectorTheme.IconSize.xs - 4, weight: .bold))
                        .foregroundColor(InspectorTheme.background)
                        .frame(width: InspectorTheme.IconSize.sm, height: InspectorTheme.IconSize.sm)
                        .background(Circle().fill(color))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(InspectorTheme.Spacing.md)
            .frame(minHeight: InspectorTheme.minTouchTarget + InspectorTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md)
                    .fill(isSelected ? color.opacity(InspectorTheme.Alpha.light) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).strokeBorder(
                    isSelected ? color : InspectorTheme.surfaceHigh,
                    lineWidth: isSelected ? InspectorTheme.Border.regular : InspectorTheme.Border.thin
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md))
        }
        .buttonStyle(GridPressStyle())
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) filter")
        .accessibilityValue(isEnabled ? "\(count) items" : "No items available")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Android's grid card press: scale to 0.96 over 100 ms.
private struct GridPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(InspectorMotion.standard(InspectorMotion.ultraFast), value: configuration.isPressed)
    }
}

extension View {
    /// Three-quarter sheet that drags to full height, like Android's bottom sheet; full height before iOS 16.
    @ViewBuilder
    func filterSheetDetents() -> some View {
        if #available(iOS 16.0, *) {
            presentationDetents([.fraction(0.75), .large]).presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("Filter sheet") {
    TransactionFilterSheet(
        rows: PreviewSamples.rows,
        filters: TransactionFilters(methods: ["GET"], statusRanges: [.success]),
        onApply: { _ in }
    )
}

#Preview("Filter sheet, dark") {
    TransactionFilterSheet(rows: PreviewSamples.rows, filters: TransactionFilters(), onApply: { _ in })
        .preferredColorScheme(.dark)
}
#endif
