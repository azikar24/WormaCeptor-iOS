import SwiftUI

/// Android's chips. `.pill` is `WormaCeptorChip` (presets, filters); `.filter` is Material's `FilterChip` with a
/// tinted border (log levels, message directions). Selected chips fill with `color`, unselected ones stay neutral.
struct InspectorChip: View {
    enum Shape {
        case pill
        case filter
    }

    let label: String
    let isSelected: Bool
    var systemImage: String?
    var color: Color = InspectorTheme.brand
    var count: Int?
    var shape: Shape = .pill
    var leading: AnyView?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: InspectorTheme.Spacing.xs) {
                if let leading {
                    leading
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(shape == .filter ? InspectorFont.label.weight(.bold) : InspectorFont.label)
                    .lineLimit(1)
                if let count, count > 0 {
                    Text(count > 999 ? "999+" : "\(count)")
                        .font(InspectorFont.labelSmall.monospacedDigit())
                        .foregroundColor(isSelected ? color : InspectorTheme.secondaryText)
                }
            }
            .foregroundColor(isSelected ? color : InspectorTheme.textPrimary)
            .padding(.horizontal, shape == .pill ? InspectorTheme.Spacing.lg : InspectorTheme.Spacing.md)
            .padding(.vertical, InspectorTheme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: InspectorTheme.Border.regular))
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(InspectorPressStyle())
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var radius: CGFloat {
        shape == .pill ? InspectorTheme.minTouchTarget : InspectorTheme.Radius.md
    }

    private var fill: Color {
        if isSelected {
            return color.opacity(shape == .pill ? InspectorTheme.Alpha.light : InspectorTheme.Alpha.soft)
        }
        return shape == .pill ? InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.bold) : .clear
    }

    private var border: Color {
        switch (shape, isSelected) {
        case (.pill, true): return color.opacity(InspectorTheme.Alpha.strong)
        case (.pill, false): return InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
        case (.filter, true): return color.opacity(InspectorTheme.Alpha.bold)
        case (.filter, false): return color.opacity(InspectorTheme.Alpha.moderate)
        }
    }
}

/// Android's `WormaCeptorScrollableRow`: chips in a horizontal scroll, page-inset on both ends.
struct InspectorChipRow<Content: View>: View {
    var inset: CGFloat = InspectorTheme.Spacing.lg
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                content()
            }
            .padding(.horizontal, inset)
        }
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
        InspectorChipRow {
            InspectorChip(label: "Wi-Fi", isSelected: true, systemImage: "wifi") {}
            InspectorChip(label: "Good 3G", isSelected: false, systemImage: "cellularbars") {}
        }
        InspectorChipRow {
            InspectorChip(label: "E", isSelected: true, color: InspectorTheme.error, count: 4, shape: .filter) {}
            InspectorChip(label: "W", isSelected: false, color: InspectorTheme.warning, count: 12, shape: .filter) {}
        }
    }
    .padding(.vertical)
}
