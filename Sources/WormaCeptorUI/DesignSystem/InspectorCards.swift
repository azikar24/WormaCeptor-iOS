import SwiftUI

/// Android's tool category colors (`FeatureColors.kt`). Icons only, so Android's exact values.
enum InspectorCategoryColor {
    static let inspection = Color(rgb: 0x6366F1)
    static let performance = Color(rgb: 0xF59E0B)
    static let network = Color(rgb: 0x10B981)
    static let simulation = Color(rgb: 0x8B5CF6)
    static let core = Color(rgb: 0x3B82F6)
}

extension View {
    /// Android's outlined card: a fill, a hairline border, 8 pt corners.
    func inspectorCard(
        fill: Color = InspectorTheme.background,
        border: Color = InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.strong),
        radius: CGFloat = InspectorTheme.Radius.md,
        padding: CGFloat = InspectorTheme.Spacing.md
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(border, lineWidth: InspectorTheme.Border.thin))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }

    /// The page behind cards: Android's background color instead of the grouped grey.
    func inspectorScreen() -> some View {
        background(InspectorTheme.background.ignoresSafeArea())
    }

    /// For `List`s that hold cards: no separators, no row insets or backgrounds, Android's background.
    func inspectorCardRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(
                top: InspectorTheme.Spacing.xs,
                leading: InspectorTheme.Spacing.sm,
                bottom: InspectorTheme.Spacing.xs,
                trailing: InspectorTheme.Spacing.sm
            ))
    }
}

/// Android's press feedback on tappable cards: scale to 0.98 over 100 ms. Use on `Button` and `NavigationLink`.
struct InspectorPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(InspectorMotion.standard(InspectorMotion.ultraFast), value: configuration.isPressed)
    }
}

/// Android's overview card: an icon + title header over its content, outlined, 16 pt padding.
struct InspectorSectionCard<Content: View, Trailing: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: InspectorTheme.IconSize.md - 2, weight: .semibold))
                    .foregroundColor(InspectorTheme.brand)
                    .accessibilityHidden(true)
                Text(title)
                    .font(InspectorFont.titleMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                trailing()
            }
            content()
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: InspectorTheme.Spacing.lg
        )
    }
}

/// A label/value line inside a section card.
struct InspectorKeyValueRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.md) {
            Text(label)
                .font(InspectorFont.bodySmall)
                .foregroundColor(InspectorTheme.secondaryText)
                .frame(minWidth: 88, alignment: .leading)
            Text(value)
                .font(monospaced ? InspectorFont.code : InspectorFont.body)
                .foregroundColor(InspectorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Android's collapsible section: tappable header with a rotating chevron, content expands and fades.
struct InspectorExpandableSection<Header: View, Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    header()
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: InspectorTheme.IconSize.xs + 2, weight: .semibold))
                        .foregroundColor(InspectorTheme.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            if isExpanded {
                content().transition(InspectorMotion.expand)
            }
        }
        .clipped()
    }
}

#Preview("Cards") {
    struct Demo: View {
        @State var expanded = true

        var body: some View {
            ScrollView {
                VStack(spacing: InspectorTheme.Spacing.lg) {
                    InspectorSectionCard("Timing", systemImage: "clock") {
                        InspectorKeyValueRow(label: "URL", value: "https://api.example.com/v1/forecast", monospaced: true)
                        InspectorKeyValueRow(label: "Duration", value: "733 ms")
                    }
                    InspectorExpandableSection(isExpanded: $expanded) {
                        Text("Headers").font(InspectorFont.titleSmall)
                        InspectorCountChip(count: 4)
                    } content: {
                        Text("content-type: application/json").font(InspectorFont.code)
                    }
                    .inspectorCard()
                }
                .padding()
            }
            .inspectorScreen()
        }
    }
    return Demo()
}
