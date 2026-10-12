import SwiftUI
import WormaCeptor

/// Live connections, newest first.
@MainActor
final class WebSocketConnectionsModel: ObservableObject {
    @Published private(set) var connections: [WormaCeptorWebSocketConnection] = []

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorWebSockets.shared.observeConnections { [weak self] in self?.connections = $0 }
    }

    deinit {
        subscription?.cancel()
    }
}

/// Live frames of one connection, oldest first.
@MainActor
final class WebSocketFramesModel: ObservableObject {
    @Published private(set) var frames: [WormaCeptorWebSocketFrame] = []

    private var subscription: WormaCeptorSubscription?

    init(connectionId: Int64) {
        subscription = WormaCeptorWebSockets.shared.observeFrames(connectionId: connectionId) { [weak self] in
            self?.frames = $0
        }
    }

    deinit {
        subscription?.cancel()
    }
}

/// WebSocket connections the app opened through `URLSessionWebSocketTask`, the same data
/// `list_websocket_connections` reads.
struct WebSocketsScreen: View {
    @StateObject private var model = WebSocketConnectionsModel()

    var body: some View {
        WebSocketsContent(connections: model.connections, onClear: { WormaCeptorWebSockets.shared.clear() })
    }
}

/// Android's WebSocket monitor: search, a count bar, then one outlined card per connection.
struct WebSocketsContent: View {
    let connections: [WormaCeptorWebSocketConnection]
    let onClear: () -> Void

    @State private var search = ""
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorWebSocketConnection] {
        search.isEmpty ? connections : connections.filter { $0.url.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        let visible = filtered
        VStack(spacing: 0) {
            InspectorSearchField(placeholder: "Search by URL…", text: $search)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            WebSocketStatsBar(label: "Connections", total: connections.count, shown: visible.count)
            if visible.isEmpty {
                InspectorEmptyState(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: connections.isEmpty ? "No WebSocket connections" : "No matching connections",
                    message: connections.isEmpty
                        ? "Connections show up here once WormaCeptorWebSocketCapture.install() runs and the app opens one."
                        : "Try a different search query"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: InspectorTheme.Spacing.xs) {
                        ForEach(visible, id: \.id) { connection in
                            NavigationLink(destination: WebSocketFramesScreen(connection: connection)) {
                                WebSocketConnectionCard(connection: connection)
                            }
                            .buttonStyle(InspectorPressStyle())
                        }
                    }
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
                    .padding(.vertical, InspectorTheme.Spacing.xs)
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("WebSockets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            .tint(InspectorTheme.brand)
            .disabled(connections.isEmpty)
            .accessibilityLabel("Clear connections")
        }
        .confirmationDialog("Clear all connections?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: onClear)
        } message: {
            Text("Connections and their frames are deleted. Open sockets keep recording new frames.")
        }
    }
}

enum WebSocketFormat {
    static func state(_ state: WormaCeptorWebSocketState) -> String {
        state.name.capitalized
    }

    static func closeSummary(_ connection: WormaCeptorWebSocketConnection) -> String? {
        let parts = [connection.closeCode.map { "Code \($0.int32Value)" }, connection.closeReason].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    static func arrow(_ direction: WormaCeptorWebSocketDirection) -> String {
        direction == .sent ? "arrow.up.right" : "arrow.down.left"
    }

    static func directionTitle(_ direction: WormaCeptorWebSocketDirection) -> String {
        direction == .sent ? "Sent" : "Received"
    }

    /// Android's short direction label in the message header.
    static func directionTag(_ direction: WormaCeptorWebSocketDirection) -> String {
        direction == .sent ? "SENT" : "RECV"
    }

    static func type(_ type: WormaCeptorWebSocketFrameType) -> String {
        type.name.capitalized
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    /// `HH:mm:ss`, as Android prints the connection's open time.
    static func clock(_ epochMillis: KotlinLong?) -> String {
        guard let millis = epochMillis?.int64Value else { return "--:--:--" }
        return clockFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(millis) / 1000))
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

/// Android's `StatsBar`: a label on the left, "N total" or "shown / total" on the right.
struct WebSocketStatsBar: View {
    let label: String
    let total: Int
    let shown: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shown == total ? "\(total) total" : "\(shown) / \(total)")
                .monospacedDigit()
        }
        .font(InspectorFont.labelSmall)
        .foregroundColor(InspectorTheme.secondaryText)
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private struct WebSocketConnectionCard: View {
    let connection: WormaCeptorWebSocketConnection

    var body: some View {
        let color = MiscToolColors.WebSocket.color(connection.state)
        let duration = InspectorFormat.duration(connection.durationMs) ?? "--"
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                InspectorStatusDot(color: color)
                Text(connection.url)
                    .font(InspectorFont.bodyMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(WebSocketFormat.clock(connection.openedAtMs))
                    .font(InspectorFont.code)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            HStack(spacing: InspectorTheme.Spacing.md) {
                InspectorBadge(text: connection.state.name, color: color)
                Text("\(connection.frameCount) msgs")
                    .font(InspectorFont.labelSmall.monospacedDigit())
                    .foregroundColor(InspectorTheme.secondaryText)
                Text(duration)
                    .font(InspectorFont.code)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .padding(.vertical, InspectorTheme.Spacing.sm)
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(WebSocketFormat.state(connection.state)), \(connection.url), \(connection.frameCount) messages, \(duration)"
        )
    }
}

#if DEBUG
#Preview("WebSockets") {
    NavigationView {
        WebSocketsContent(connections: PreviewSamples.webSocketConnections, onClear: {})
    }
}

#Preview("WebSockets dark") {
    NavigationView {
        WebSocketsContent(connections: PreviewSamples.webSocketConnections, onClear: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("WebSockets empty") {
    NavigationView {
        WebSocketsContent(connections: [], onClear: {})
    }
}
#endif
