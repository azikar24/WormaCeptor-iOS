import SwiftUI

/// Android's `WormaCeptorListItem` with the divider under it: optional leading icon, a medium headline, a grey
/// supporting line, optional trailing content. Flat, for lists Android draws without cards.
struct InspectorListRow<Leading: View, Trailing: View>: View {
    let headline: String
    var supporting: String?
    var monospacedHeadline = false
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    init(
        headline: String,
        supporting: String? = nil,
        monospacedHeadline: Bool = false,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.headline = headline
        self.supporting = supporting
        self.monospacedHeadline = monospacedHeadline
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            leading()
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(headline)
                    .font(monospacedHeadline ? InspectorFont.listHeadline.monospaced() : InspectorFont.listHeadline)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let supporting, !supporting.isEmpty {
                    Text(supporting)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.md)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { InspectorDivider() }
        .accessibilityElement(children: .combine)
    }
}

extension InspectorFont {
    /// Android's bodyLarge medium, the headline of a list row.
    static let listHeadline = Font.callout.weight(.medium)
}

/// Android's `WormaCeptorDivider`: a hairline in the outline color.
struct InspectorDivider: View {
    var body: some View {
        Rectangle()
            .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold))
            .frame(height: InspectorTheme.Border.thin)
            .accessibilityHidden(true)
    }
}

/// The leading icon of a flat list row, tinted (Android uses the accent for databases and tables).
struct InspectorRowIcon: View {
    let systemImage: String
    var color: Color = InspectorTheme.brand

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: InspectorTheme.IconSize.md, weight: .regular))
            .foregroundColor(color)
            .frame(width: InspectorTheme.IconSize.lg, height: InspectorTheme.IconSize.lg)
            .accessibilityHidden(true)
    }
}

extension View {
    /// A plain `List` on the inspector background, for screens that need swipe actions.
    func inspectorPlainList() -> some View {
        modifier(PlainListBackground())
    }

    /// A `List` row with no insets, separator or background, for rows that draw their own divider.
    func inspectorFlatRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }

    /// TextEditor draws an opaque background from iOS 16; hide it so the field's own fill shows.
    func inspectorHiddenEditorBackground() -> some View {
        modifier(HiddenEditorBackground())
    }

    /// Medium and large detents where the OS has them (iOS 16+), like Android's bottom sheets.
    func inspectorSheetDetents() -> some View {
        modifier(SheetDetents())
    }
}

private struct PlainListBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.listStyle(.plain).scrollContentBackground(.hidden).inspectorScreen()
        } else {
            content.listStyle(.plain).inspectorScreen()
        }
    }
}

private struct HiddenEditorBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

private struct SheetDetents: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}

/// Android's `WormaCeptorLoadableContent`: skeleton while loading, then the empty state or the content, crossfading.
struct InspectorLoadable<Content: View, Empty: View>: View {
    let isLoading: Bool
    let isEmpty: Bool
    var skeletonRowHeight: CGFloat = 72
    @ViewBuilder var empty: () -> Empty
    @ViewBuilder var content: () -> Content

    private enum Phase { case loading, empty, content }

    private var phase: Phase {
        if isLoading { return .loading }
        return isEmpty ? .empty : .content
    }

    var body: some View {
        ZStack {
            switch phase {
            case .loading:
                InspectorSkeletonList(rowHeight: skeletonRowHeight).transition(.opacity)
            case .empty:
                empty().transition(.opacity)
            case .content:
                content().transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: phase)
    }
}

#Preview("List rows") {
    VStack(spacing: 0) {
        InspectorListRow(headline: "app.sqlite", supporting: "5 tables · 512 KB") {
            InspectorRowIcon(systemImage: "cylinder.split.1x2")
        }
        InspectorListRow(headline: "cache.db", supporting: "2 tables · 128 KB") {
            InspectorRowIcon(systemImage: "cylinder.split.1x2")
        }
    }
    .inspectorScreen()
}
