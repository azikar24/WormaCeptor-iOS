import SwiftUI

/// One entry in the Tools tab. A tool adds itself to `InspectorTools.all`.
struct InspectorTool: Identifiable {
    /// Android's tool categories, in Android's order.
    enum Category: String, CaseIterable {
        case inspection = "Inspection"
        case performance = "Performance"
        case network = "Network"
        case simulation = "Simulation"
        case core = "Core"

        var color: Color {
            switch self {
            case .inspection: return InspectorCategoryColor.inspection
            case .performance: return InspectorCategoryColor.performance
            case .network: return InspectorCategoryColor.network
            case .simulation: return InspectorCategoryColor.simulation
            case .core: return InspectorCategoryColor.core
            }
        }

        /// SF equivalents of Android's category icons (Explore, Speed, Cable, LocationOn, Code).
        var systemImage: String {
            switch self {
            case .inspection: return "safari.fill"
            case .performance: return "speedometer"
            case .network: return "cable.connector"
            case .simulation: return "mappin.circle.fill"
            case .core: return "chevron.left.forwardslash.chevron.right"
            }
        }
    }

    /// Android's tool route ("deviceinfo"), so both platforms name a tool the same way.
    let id: String
    let title: String
    let systemImage: String
    let category: Category
    let destination: () -> AnyView
}

/// Titles follow Android's; tools backed by an iOS-only store keep the iOS name (UserDefaults, Keychain, hangs).
/// Within a category, Android's order.
enum InspectorTools {
    static let all: [InspectorTool] = [
        InspectorTool(id: "preferences", title: "UserDefaults", systemImage: "gearshape.fill", category: .inspection) {
            AnyView(PreferencesScreen())
        },
        InspectorTool(id: "database", title: "Database Browser", systemImage: "list.bullet.rectangle.fill", category: .inspection) {
            AnyView(DatabaseListScreen())
        },
        InspectorTool(id: "filebrowser", title: "File Browser", systemImage: "folder.fill", category: .inspection) {
            AnyView(FileBrowserScreen())
        },
        InspectorTool(id: "loadedlibraries", title: "Loaded Libraries", systemImage: "books.vertical.fill", category: .inspection) {
            AnyView(LoadedLibrariesScreen())
        },
        InspectorTool(id: "securestorage", title: "Keychain", systemImage: "lock.shield.fill", category: .inspection) {
            AnyView(KeychainScreen())
        },
        InspectorTool(id: "webviewmonitor", title: "WebView Monitor", systemImage: "globe", category: .inspection) {
            AnyView(WebViewMonitorScreen())
        },
        InspectorTool(id: "memory", title: "Memory Monitor", systemImage: "memorychip", category: .performance) {
            AnyView(MetricScreen(metric: .memory))
        },
        InspectorTool(id: "fps", title: "FPS Monitor", systemImage: "speedometer", category: .performance) {
            AnyView(MetricScreen(metric: .fps))
        },
        InspectorTool(id: "cpu", title: "CPU Monitor", systemImage: "cpu", category: .performance) {
            AnyView(MetricScreen(metric: .cpu))
        },
        InspectorTool(id: "leakdetection", title: "Leak Detection", systemImage: "ladybug.fill", category: .performance) {
            AnyView(LeaksScreen())
        },
        InspectorTool(id: "threadviolation", title: "Main Thread Hangs", systemImage: "exclamationmark.triangle.fill", category: .performance) {
            AnyView(HangsScreen())
        },
        InspectorTool(id: "websocket", title: "WebSocket Monitor", systemImage: "cable.connector", category: .network) {
            AnyView(WebSocketsScreen())
        },
        InspectorTool(id: "ratelimit", title: "Rate Limiter", systemImage: "network", category: .network) {
            AnyView(RateLimitScreen())
        },
        InspectorTool(id: "mockrules", title: "Mock Rules", systemImage: "flask.fill", category: .network) {
            AnyView(MockRulesScreen())
        },
        InspectorTool(id: "location", title: "Location Simulator", systemImage: "mappin.circle.fill", category: .simulation) {
            AnyView(LocationScreen())
        },
        InspectorTool(id: "pushsimulator", title: "Push Simulator", systemImage: "bell.fill", category: .simulation) {
            AnyView(PushSimulatorScreen())
        },
        InspectorTool(id: "pushtoken", title: "Push Token", systemImage: "key.fill", category: .simulation) {
            AnyView(PushTokenScreen())
        },
        InspectorTool(id: "crypto", title: "Crypto Tool", systemImage: "lock.fill", category: .simulation) {
            AnyView(CryptoScreen())
        },
        InspectorTool(id: "logs", title: "Console Logs", systemImage: "terminal.fill", category: .core) {
            AnyView(LogsScreen())
        },
        InspectorTool(id: "deviceinfo", title: "Device Info", systemImage: "info.circle.fill", category: .core) {
            AnyView(DeviceInfoScreen())
        },
    ]
}

/// The Tools tab like Android's: a search field behind the toolbar button, the Quick access strip, then each category
/// as a collapsible 3-column grid. Long-press a tile for the menu that adds it to or removes it from Quick access.
struct ToolsScreen: View {
    var tools: [InspectorTool] = InspectorTools.all
    @StateObject var favorites = ToolFavorites()

    @State private var searchActive = false
    @State private var query = ""
    @State private var collapsed: Set<InspectorTool.Category> = []

    private static let top = "top"

    var body: some View {
        // The ScrollView stays the root so the large title collapses with it.
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if searchActive {
                        InspectorSearchField(placeholder: "Search tools…", text: $query)
                            .padding(.horizontal, InspectorTheme.Spacing.lg)
                            .padding(.top, InspectorTheme.Spacing.sm)
                            .transition(InspectorMotion.expand)
                    }
                    content
                        .padding(.top, InspectorTheme.Spacing.lg)
                        .padding(.bottom, InspectorTheme.Spacing.xxl)
                }
                .id(Self.top)
            }
            .onChange(of: searchActive) { active in
                guard active else { return }
                withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
                    proxy.scrollTo(Self.top, anchor: .top)
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("Tools")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
                        searchActive.toggle()
                        if !searchActive { query = "" }
                    }
                } label: {
                    Image(systemName: searchActive ? "xmark" : "magnifyingglass")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel(searchActive ? "Close search" : "Search tools")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let favoriteTools = favorites.ids.compactMap { id in matching.first { $0.id == id } }
        let categories = InspectorTool.Category.allCases.filter { category in matching.contains { $0.category == category } }
        VStack(alignment: .leading, spacing: 0) {
            if !favoriteTools.isEmpty {
                FavoritesStrip(tools: favoriteTools, onToggleFavorite: { favorites.toggle($0.id) })
                    .padding(.bottom, InspectorTheme.Spacing.lg)
            }
            ForEach(categories, id: \.self) { category in
                ToolCategorySection(
                    category: category,
                    tools: matching.filter { $0.category == category },
                    favorites: Set(favorites.ids),
                    isExpanded: expandedBinding(category),
                    onToggleFavorite: { favorites.toggle($0.id) }
                ) {
                    if category == .performance {
                        PerformanceOverlayCard().padding(.top, InspectorTheme.Spacing.sm)
                    }
                }
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            }
            if categories.isEmpty && favoriteTools.isEmpty {
                EmptyToolsState(query: query).padding(InspectorTheme.Spacing.xxl)
            }
        }
    }

    private var matching: [InspectorTool] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return tools }
        return tools.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private func expandedBinding(_ category: InspectorTool.Category) -> Binding<Bool> {
        Binding(
            get: { !collapsed.contains(category) },
            set: { expanded in
                if expanded { collapsed.remove(category) } else { collapsed.insert(category) }
            }
        )
    }
}

/// Android's `EmptyToolsState`: shown when the search matches no tool.
private struct EmptyToolsState: View {
    let query: String

    var body: some View {
        VStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: InspectorTheme.IconSize.xxl + InspectorTheme.Spacing.lg))
                .foregroundColor(InspectorTheme.secondaryText.opacity(InspectorTheme.Alpha.strong))
                .accessibilityHidden(true)
            VStack(spacing: InspectorTheme.Spacing.xs) {
                Text(query.isEmpty ? "No tools available" : "No tools found for \"\(query)\"")
                    .font(InspectorFont.body)
                    .foregroundColor(InspectorTheme.secondaryText)
                if !query.isEmpty {
                    Text("Try a different search term")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Tools") {
    NavigationView { ToolsScreen() }
}

#Preview("Tools dark") {
    NavigationView { ToolsScreen() }
        .preferredColorScheme(.dark)
}
