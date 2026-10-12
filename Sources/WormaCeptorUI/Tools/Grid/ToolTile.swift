import SwiftUI

/// Android's `WormaCeptorToolTile`: 116 pt outlined tile, 12 pt corners, the icon in a 40 pt well of the accent color,
/// a centered two-line label, and a star when the tool is in Quick access.
struct ToolTile: View {
    let tool: InspectorTool
    let accent: Color
    var isFavorite = false
    /// Off in the Quick access strip, where every tile is a favorite.
    var showsStar = true
    let onToggleFavorite: () -> Void

    static let height: CGFloat = 116

    // A real link per tile: hidden `NavigationLink(tag:selection:)` links stop pushing once their selection drifts.
    // Quick access lives in the long-press context menu, iOS's long-press convention.
    var body: some View {
        NavigationLink(destination: tool.destination()) {
            label
        }
        .buttonStyle(InspectorPressStyle())
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(
                    isFavorite ? "Remove from Quick access" : "Add to Quick access",
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
        }
        .accessibilityLabel(tool.title)
        .accessibilityValue(isFavorite ? "In Quick access" : "")
        .accessibilityAction(named: isFavorite ? "Remove from Quick access" : "Add to Quick access", onToggleFavorite)
    }

    private var label: some View {
        VStack(spacing: InspectorTheme.Spacing.md) {
            InspectorIconWell(systemImage: tool.systemImage, color: accent)
            ZStack {
                // Two lines reserved, like Android's minLines = 2, so icons line up across a row.
                Text("A\nA").hidden()
                Text(tool.title)
                    .lineLimit(2)
            }
            .font(InspectorFont.label)
            .foregroundColor(InspectorTheme.textPrimary)
            .multilineTextAlignment(.center)
        }
        .padding(InspectorTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: Self.height)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg).fill(InspectorTheme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg)
                .strokeBorder(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.strong), lineWidth: InspectorTheme.Border.thin)
        )
        .overlay(alignment: .topTrailing) {
            if isFavorite && showsStar {
                Image(systemName: "star.fill")
                    .font(.system(size: InspectorTheme.IconSize.xs))
                    .foregroundColor(InspectorTheme.favorite)
                    .padding(InspectorTheme.Spacing.sm)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: isFavorite)
        .contentShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.lg))
    }
}

#Preview("Tiles") {
    HStack(spacing: InspectorTheme.Spacing.sm) {
        ToolTile(tool: InspectorTools.all[0], accent: InspectorCategoryColor.inspection, isFavorite: true, onToggleFavorite: {})
        ToolTile(tool: InspectorTools.all[1], accent: InspectorCategoryColor.inspection, onToggleFavorite: {})
        ToolTile(tool: InspectorTools.all[2], accent: InspectorCategoryColor.inspection, onToggleFavorite: {})
    }
    .padding()
}

#Preview("Tiles dark") {
    HStack(spacing: InspectorTheme.Spacing.sm) {
        ToolTile(tool: InspectorTools.all[6], accent: InspectorCategoryColor.performance, isFavorite: true, onToggleFavorite: {})
        ToolTile(tool: InspectorTools.all[7], accent: InspectorCategoryColor.performance, onToggleFavorite: {})
    }
    .padding()
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
