import SwiftUI

/// One entry in the Tools tab. A tool adds itself to `InspectorTools.all`.
struct InspectorTool: Identifiable {
    enum Category: String, CaseIterable {
        case network = "Network"
        case storage = "Storage"
        case performance = "Performance"
        case debugging = "Debugging"
    }

    /// Android's tool route ("deviceinfo"), so both platforms name a tool the same way.
    let id: String
    let title: String
    let systemImage: String
    let category: Category
    let destination: () -> AnyView
}

enum InspectorTools {
    static let all: [InspectorTool] = [
        InspectorTool(id: "websocket", title: "WebSockets", systemImage: "arrow.left.arrow.right", category: .network) {
            AnyView(WebSocketsScreen())
        },
        InspectorTool(id: "webviewmonitor", title: "WebView monitor", systemImage: "globe", category: .network) {
            AnyView(WebViewMonitorScreen())
        },
        InspectorTool(id: "logs", title: "Console logs", systemImage: "terminal", category: .debugging) {
            AnyView(LogsScreen())
        },
        InspectorTool(id: "deviceinfo", title: "Device info", systemImage: "iphone", category: .debugging) {
            AnyView(DeviceInfoScreen())
        },
        InspectorTool(id: "filebrowser", title: "File browser", systemImage: "folder", category: .storage) {
            AnyView(FileBrowserScreen())
        },
        InspectorTool(id: "ratelimit", title: "Network throttling", systemImage: "tortoise", category: .network) {
            AnyView(RateLimitScreen())
        },
        InspectorTool(id: "preferences", title: "UserDefaults", systemImage: "slider.horizontal.3", category: .storage) {
            AnyView(PreferencesScreen())
        },
        InspectorTool(id: "securestorage", title: "Keychain", systemImage: "key", category: .storage) {
            AnyView(KeychainScreen())
        },
        InspectorTool(id: "database", title: "SQLite browser", systemImage: "cylinder.split.1x2", category: .storage) {
            AnyView(DatabaseListScreen())
        },
        InspectorTool(id: "loadedlibraries", title: "Loaded libraries", systemImage: "books.vertical", category: .storage) {
            AnyView(LoadedLibrariesScreen())
        },
        InspectorTool(id: "pushtoken", title: "Push token", systemImage: "bell.badge", category: .debugging) {
            AnyView(PushTokenScreen())
        },
        InspectorTool(id: "crypto", title: "Crypto", systemImage: "lock", category: .debugging) {
            AnyView(CryptoScreen())
        },
        InspectorTool(id: "pushsimulator", title: "Push simulator", systemImage: "bell.and.waves.left.and.right", category: .debugging) {
            AnyView(PushSimulatorScreen())
        },
        InspectorTool(id: "location", title: "Location", systemImage: "location", category: .debugging) {
            AnyView(LocationScreen())
        },
        InspectorTool(id: "cpu", title: "CPU", systemImage: "cpu", category: .performance) {
            AnyView(MetricScreen(metric: .cpu))
        },
        InspectorTool(id: "memory", title: "Memory", systemImage: "memorychip", category: .performance) {
            AnyView(MetricScreen(metric: .memory))
        },
        InspectorTool(id: "fps", title: "FPS", systemImage: "speedometer", category: .performance) {
            AnyView(MetricScreen(metric: .fps))
        },
        InspectorTool(id: "leakdetection", title: "Leaks", systemImage: "drop.triangle", category: .performance) {
            AnyView(LeaksScreen())
        },
        InspectorTool(id: "threadviolation", title: "Main thread hangs", systemImage: "hourglass", category: .performance) {
            AnyView(HangsScreen())
        },
    ]
}

/// The Tools tab: every tool, grouped like Android's Tools screen.
struct ToolsScreen: View {
    var tools: [InspectorTool] = InspectorTools.all

    var body: some View {
        List {
            ForEach(InspectorTool.Category.allCases, id: \.self) { category in
                let entries = tools.filter { $0.category == category }
                if !entries.isEmpty {
                    Section(category.rawValue) {
                        ForEach(entries) { tool in
                            NavigationLink(destination: tool.destination()) {
                                Label(tool.title, systemImage: tool.systemImage)
                                    .frame(minHeight: InspectorTheme.minTouchTarget)
                            }
                        }
                        if category == .performance {
                            PerformanceOverlayRow()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tools")
    }
}

#Preview("Tools") {
    NavigationView { ToolsScreen() }
}
