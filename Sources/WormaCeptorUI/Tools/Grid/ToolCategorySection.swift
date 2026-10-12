import SwiftUI

/// Android's `ToolCategorySection`: a header (category icon in its color, name, count, rotating chevron) that collapses
/// the section, optional header content, then the tools as a 3-column grid.
struct ToolCategorySection<Header: View>: View {
    let category: InspectorTool.Category
    let tools: [InspectorTool]
    let favorites: Set<String>
    @Binding var isExpanded: Bool
    let onToggleFavorite: (InspectorTool) -> Void
    @ViewBuilder var header: () -> Header

    private static var columns: Int { 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                VStack(spacing: 0) {
                    header()
                    grid.padding(.top, InspectorTheme.Spacing.sm)
                }
                .transition(InspectorMotion.expand)
            }
        }
        .clipped()
    }

    private var headerButton: some View {
        Button {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: category.systemImage)
                    .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                    .foregroundColor(category.color)
                    .frame(width: InspectorTheme.IconSize.sm)
                Text(category.rawValue)
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                InspectorCountChip(count: tools.count)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: InspectorTheme.IconSize.xs + 2, weight: .semibold))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, InspectorTheme.Spacing.sm)
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.rawValue), \(tools.count) tools")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityAddTraits([.isHeader, .isButton])
    }

    private var grid: some View {
        VStack(spacing: InspectorTheme.Spacing.sm) {
            ForEach(Array(stride(from: 0, to: tools.count, by: Self.columns)), id: \.self) { start in
                let row = Array(tools[start..<min(start + Self.columns, tools.count)])
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    ForEach(row) { tool in
                        ToolTile(
                            tool: tool,
                            accent: category.color,
                            isFavorite: favorites.contains(tool.id),
                            onToggleFavorite: { onToggleFavorite(tool) }
                        )
                    }
                    ForEach(0..<(Self.columns - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}

extension ToolCategorySection where Header == EmptyView {
    init(
        category: InspectorTool.Category,
        tools: [InspectorTool],
        favorites: Set<String>,
        isExpanded: Binding<Bool>,
        onToggleFavorite: @escaping (InspectorTool) -> Void
    ) {
        self.init(
            category: category,
            tools: tools,
            favorites: favorites,
            isExpanded: isExpanded,
            onToggleFavorite: onToggleFavorite,
            header: { EmptyView() }
        )
    }
}

#Preview("Category") {
    struct Demo: View {
        @State var expanded = true

        var body: some View {
            ScrollView {
                ToolCategorySection(
                    category: .inspection,
                    tools: InspectorTools.all.filter { $0.category == .inspection },
                    favorites: ["preferences"],
                    isExpanded: $expanded,
                    onToggleFavorite: { _ in }
                )
                .padding()
            }
            .inspectorScreen()
        }
    }
    return Demo()
}

#Preview("Category dark") {
    ScrollView {
        ToolCategorySection(
            category: .simulation,
            tools: InspectorTools.all.filter { $0.category == .simulation },
            favorites: [],
            isExpanded: .constant(true),
            onToggleFavorite: { _ in }
        )
        .padding()
    }
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
