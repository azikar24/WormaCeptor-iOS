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

struct WebSocketsContent: View {
    let connections: [WormaCeptorWebSocketConnection]
    let onClear: () -> Void

    @State private var search = ""
    @State private var isConfirmingClear = false

    private var filtered: [WormaCeptorWebSocketConnection] {
        search.isEmpty ? connections : connections.filter { $0.url.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered, id: \.id) { connection in
            NavigationLink(destination: WebSocketFramesScreen(connection: connection)) {
                WebSocketConnectionRow(connection: connection)
            }
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "URL")
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.left.arrow.right",
                    title: connections.isEmpty ? "No WebSocket connections" : "No matches",
                    message: connections.isEmpty
                        ? "Connections show up here once WormaCeptorWebSocketCapture.install() runs and the app opens one."
                        : "No connection URL contains \"\(search)\"."
                )
            }
        }
        .navigationTitle("WebSockets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
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

    static func color(_ state: WormaCeptorWebSocketState) -> Color {
        switch state {
        case .open: return InspectorTheme.color(for: .success)
        case .connecting: return InspectorTheme.color(for: .redirect)
        case .closing: return InspectorTheme.color(for: .warning)
        default: return InspectorTheme.color(for: .neutral)
        }
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

    static func type(_ type: WormaCeptorWebSocketFrameType) -> String {
        type.name.capitalized
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}

private struct WebSocketConnectionRow: View {
    let connection: WormaCeptorWebSocketConnection

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                InspectorBadge(text: WebSocketFormat.state(connection.state), color: WebSocketFormat.color(connection.state))
                Text("\(connection.frameCount) frames")
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                if let duration = InspectorFormat.duration(connection.durationMs) {
                    Text(duration)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            Text(connection.url)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// One connection's frames, chat order, with its state on top.
struct WebSocketFramesScreen: View {
    let connection: WormaCeptorWebSocketConnection
    @StateObject private var model: WebSocketFramesModel

    init(connection: WormaCeptorWebSocketConnection) {
        self.connection = connection
        _model = StateObject(wrappedValue: WebSocketFramesModel(connectionId: connection.id))
    }

    var body: some View {
        WebSocketFramesContent(connection: connection, frames: model.frames)
    }
}

struct WebSocketFramesContent: View {
    let connection: WormaCeptorWebSocketConnection
    let frames: [WormaCeptorWebSocketFrame]

    @State private var search = ""

    private var filtered: [WormaCeptorWebSocketFrame] {
        search.isEmpty ? frames : frames.filter { $0.payload.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                InfoRowView(row: WormaCeptorInfoRow(label: "URL", value: connection.url))
                InfoRowView(row: WormaCeptorInfoRow(label: "State", value: WebSocketFormat.state(connection.state)))
                if let close = WebSocketFormat.closeSummary(connection) {
                    InfoRowView(row: WormaCeptorInfoRow(label: "Close", value: close))
                }
            }
            Section("Frames") {
                ForEach(filtered, id: \.id) { frame in
                    NavigationLink(destination: WebSocketFrameScreen(frame: frame)) {
                        WebSocketFrameRow(frame: frame)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, prompt: "Payload")
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "text.bubble",
                    title: frames.isEmpty ? "No frames" : "No matches",
                    message: frames.isEmpty ? "Frames show up as the app sends and receives them." : "No payload contains \"\(search)\"."
                )
            }
        }
        .navigationTitle("Frames")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebSocketFrameRow: View {
    let frame: WormaCeptorWebSocketFrame

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorTheme.Spacing.sm) {
            Image(systemName: WebSocketFormat.arrow(frame.direction))
                .foregroundColor(InspectorTheme.color(for: frame.direction == .sent ? .redirect : .success))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    Text(WebSocketFormat.type(frame.type))
                        .font(.caption.weight(.semibold))
                    Text(WebSocketFormat.size(frame.size))
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                    Spacer(minLength: InspectorTheme.Spacing.sm)
                    Text(LogsFormat.time(frame.timestampMs))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                if !frame.payload.isEmpty {
                    Text(frame.payload)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(WebSocketFormat.directionTitle(frame.direction)) \(WebSocketFormat.type(frame.type)), "
                + "\(WebSocketFormat.size(frame.size)), \(frame.payload.prefix(200))"
        )
    }
}

/// One frame: its metadata and its payload, JSON pretty printed.
struct WebSocketFrameScreen: View {
    let frame: WormaCeptorWebSocketFrame

    private var payload: String {
        WormaCeptorWebSockets.shared.prettyJson(payload: frame.payload) ?? frame.payload
    }

    var body: some View {
        List {
            Section {
                InfoRowView(row: WormaCeptorInfoRow(label: "Direction", value: WebSocketFormat.directionTitle(frame.direction)))
                InfoRowView(row: WormaCeptorInfoRow(label: "Type", value: WebSocketFormat.type(frame.type)))
                InfoRowView(row: WormaCeptorInfoRow(label: "Size", value: WebSocketFormat.size(frame.size)))
                InfoRowView(row: WormaCeptorInfoRow(label: "Time", value: LogsFormat.time(frame.timestampMs)))
            }
            Section {
                if frame.payload.isEmpty {
                    Text("No payload").foregroundColor(InspectorTheme.secondaryText)
                } else {
                    Text(payload)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                HStack {
                    Text(frame.type == .binary ? "Payload (hex)" : "Payload")
                    Spacer()
                    if !frame.payload.isEmpty {
                        CopyButton(text: payload, label: "Payload")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Frame")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("WebSockets") {
    NavigationView {
        WebSocketsContent(connections: PreviewSamples.webSocketConnections, onClear: {})
    }
}

#Preview("Frames") {
    NavigationView {
        WebSocketFramesContent(connection: PreviewSamples.webSocketConnections[0], frames: PreviewSamples.webSocketFrames)
    }
}

#Preview("Frame") {
    NavigationView {
        WebSocketFrameScreen(frame: PreviewSamples.webSocketFrames[0])
    }
}
#endif
