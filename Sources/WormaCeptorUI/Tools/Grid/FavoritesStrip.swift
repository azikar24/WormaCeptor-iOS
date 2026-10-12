import SwiftUI

/// The tools in Quick access, kept in UserDefaults. New installs start with Android's defaults.
final class ToolFavorites: ObservableObject {
    @Published private(set) var ids: [String]

    private let defaults: UserDefaults

    static let key = "wormaceptor.favoriteTools"
    /// Android's `FavoritesRepository.DEFAULT_FAVORITES`: console logs, memory monitor, preferences.
    static let defaultIds = ["logs", "memory", "preferences"]
    /// Android's `MAX_FAVORITES`.
    static let maxCount = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: Self.key) {
            ids = saved
        } else {
            ids = Self.defaultIds
            defaults.set(Self.defaultIds, forKey: Self.key)
        }
    }

    /// Adds or removes `id`. Adding past the limit does nothing and returns false.
    @discardableResult
    func toggle(_ id: String) -> Bool {
        let next: [String]
        if ids.contains(id) {
            next = ids.filter { $0 != id }
        } else {
            guard ids.count < Self.maxCount else { return false }
            next = ids + [id]
        }
        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { ids = next }
        defaults.set(next, forKey: Self.key)
        return true
    }
}

/// Android's `FavoritesStrip`: an amber star over "QUICK ACCESS", then the favorites as a row of 116 pt tiles in the
/// brand color that scrolls sideways.
struct FavoritesStrip: View {
    let tools: [InspectorTool]
    let onToggleFavorite: (InspectorTool) -> Void

    private static let tileWidth: CGFloat = 116

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: "star.fill")
                    .font(.system(size: InspectorTheme.IconSize.sm - 2))
                    .foregroundColor(InspectorTheme.favorite)
                    .accessibilityHidden(true)
                Text("QUICK ACCESS")
                    .font(InspectorFont.overline)
                    .tracking(1.5)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .accessibilityLabel("Quick access")
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, InspectorTheme.Spacing.lg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    ForEach(tools) { tool in
                        ToolTile(
                            tool: tool,
                            accent: InspectorTheme.brand,
                            isFavorite: true,
                            showsStar: false,
                            onToggleFavorite: { onToggleFavorite(tool) }
                        )
                        .frame(width: Self.tileWidth)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.horizontal, InspectorTheme.Spacing.lg)
            }
        }
    }
}

#Preview("Quick access") {
    FavoritesStrip(
        tools: InspectorTools.all.filter { ToolFavorites.defaultIds.contains($0.id) },
        onToggleFavorite: { _ in }
    )
    .padding(.vertical)
    .inspectorScreen()
}

#Preview("Quick access dark") {
    FavoritesStrip(
        tools: InspectorTools.all.filter { ToolFavorites.defaultIds.contains($0.id) },
        onToggleFavorite: { _ in }
    )
    .padding(.vertical)
    .inspectorScreen()
    .preferredColorScheme(.dark)
}
