import SwiftUI

/// Android's `WormaCeptorTabRow`: equal-width text tabs with a brand underline that slides to the selection.
/// Pair it with `InspectorPager` so the pages also swipe, as on Android.
struct InspectorTabRow<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { selection = tab }
                } label: {
                    VStack(spacing: InspectorTheme.Spacing.sm) {
                        Text(title(tab))
                            .font(isSelected ? InspectorFont.titleSmall : InspectorFont.bodyMedium)
                            .foregroundColor(isSelected ? InspectorTheme.brand : InspectorTheme.secondaryText)
                            .lineLimit(1)
                        ZStack {
                            Color.clear.frame(height: InspectorTheme.Border.bold)
                            if isSelected {
                                Capsule()
                                    .fill(InspectorTheme.brand)
                                    .frame(height: InspectorTheme.Border.bold)
                                    .matchedGeometryEffect(id: "indicator", in: indicator)
                            }
                        }
                    }
                    .padding(.top, InspectorTheme.Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: InspectorTheme.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.sm)
        .background(InspectorTheme.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.bold))
                .frame(height: InspectorTheme.Border.thin)
        }
    }
}

/// Swipeable pages for `InspectorTabRow`, like Android's HorizontalPager.
struct InspectorPager<Tab: Hashable, Page: View>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    @ViewBuilder let page: (Tab) -> Page

    var body: some View {
        TabView(selection: $selection) {
            ForEach(tabs, id: \.self) { tab in
                page(tab).tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

#Preview("Tab row") {
    struct Demo: View {
        @State var tab = "Overview"
        let tabs = ["Overview", "Request", "Response"]

        var body: some View {
            VStack(spacing: 0) {
                InspectorTabRow(tabs: tabs, selection: $tab) { $0 }
                InspectorPager(tabs: tabs, selection: $tab) { Text($0).frame(maxHeight: .infinity) }
            }
            .inspectorScreen()
        }
    }
    return Demo()
}
