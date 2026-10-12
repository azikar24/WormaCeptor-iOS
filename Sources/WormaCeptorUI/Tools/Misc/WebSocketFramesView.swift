import SwiftUI
import WormaCeptor

/// One connection's frames, chat order. Android's message screen: search, direction chips, a count bar, and cards
/// that expand in place to the full payload.
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
    @State private var direction: WormaCeptorWebSocketDirection?
    @State private var expandedId: Int64?

    private var filtered: [WormaCeptorWebSocketFrame] {
        frames.filter { frame in
            (direction == nil || frame.direction == direction)
                && (search.isEmpty || frame.payload.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        let visible = filtered
        VStack(spacing: 0) {
            InspectorSearchField(placeholder: "Search messages…", text: $search)
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            directionChips
            WebSocketStatsBar(label: "Messages", total: frames.count, shown: visible.count)
            if let close = WebSocketFormat.closeSummary(connection) {
                Text("Closed: \(close)")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
                    .padding(.bottom, InspectorTheme.Spacing.xs)
            }
            if visible.isEmpty {
                emptyState
            } else {
                frameList(visible)
            }
        }
        .inspectorScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Messages")
                        .font(.headline)
                        .foregroundColor(InspectorTheme.textPrimary)
                    Text(connection.url)
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .primaryAction) {
                InspectorStatusDot(color: MiscToolColors.WebSocket.color(connection.state), size: InspectorTheme.Spacing.md)
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    .accessibilityHidden(false)
                    .accessibilityLabel("State \(WebSocketFormat.state(connection.state))")
            }
        }
    }

    private var directionChips: some View {
        InspectorChipRow {
            ForEach([WormaCeptorWebSocketDirection.sent, .received], id: \.self) { item in
                InspectorChip(
                    label: item.name,
                    isSelected: direction == item,
                    systemImage: WebSocketFormat.arrow(item),
                    count: frames.filter { $0.direction == item }.count,
                    shape: .filter
                ) {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) {
                        direction = direction == item ? nil : item
                    }
                }
            }
        }
        .padding(.bottom, InspectorTheme.Spacing.xs)
    }

    private var emptyState: some View {
        let isFiltering = !search.isEmpty || direction != nil
        return InspectorEmptyState(
            systemImage: "text.bubble",
            title: isFiltering ? "No matching messages" : "No messages yet",
            message: isFiltering ? "Try adjusting your filters" : "Messages will appear as they are sent or received"
        )
    }

    private func frameList(_ visible: [WormaCeptorWebSocketFrame]) -> some View {
        ScrollView {
            LazyVStack(spacing: InspectorTheme.Spacing.xs) {
                ForEach(visible, id: \.id) { frame in
                    WebSocketFrameCard(frame: frame, isExpanded: expandedId == frame.id) {
                        withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
                            expandedId = expandedId == frame.id ? nil : frame.id
                        }
                    }
                }
            }
            .padding(.horizontal, InspectorTheme.Spacing.sm)
            .padding(.vertical, InspectorTheme.Spacing.xs)
        }
    }
}

/// Android's `MessageItem`: direction, type, size and time over a three-line payload preview. Expanded, it shows
/// the whole payload (JSON pretty printed) with a copy button.
private struct WebSocketFrameCard: View {
    static let previewChars = 150

    let frame: WormaCeptorWebSocketFrame
    let isExpanded: Bool
    let onToggle: () -> Void

    private var fullPayload: String {
        WormaCeptorWebSockets.shared.prettyJson(payload: frame.payload) ?? frame.payload
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                    header
                    if frame.payload.isEmpty {
                        Text("No payload")
                            .font(InspectorFont.code)
                            .foregroundColor(InspectorTheme.secondaryText)
                    } else if !isExpanded {
                        Text(String(frame.payload.prefix(Self.previewChars)))
                            .font(InspectorFont.code)
                            .foregroundColor(InspectorTheme.textPrimary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            if isExpanded, !frame.payload.isEmpty {
                expandedPayload.transition(InspectorMotion.expand)
            }
        }
        .padding(.horizontal, InspectorTheme.Spacing.md)
        .padding(.vertical, InspectorTheme.Spacing.sm)
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: 0
        )
        .clipped()
    }

    private var header: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.xxs) {
                Image(systemName: WebSocketFormat.arrow(frame.direction))
                    .font(.system(size: InspectorTheme.IconSize.xs, weight: .bold))
                Text(WebSocketFormat.directionTag(frame.direction))
                    .font(InspectorFont.labelSmall.weight(.semibold))
            }
            .foregroundColor(InspectorTheme.secondaryText)
            InspectorBadge(text: frame.type.name, color: InspectorTheme.secondaryText)
            Text(WebSocketFormat.size(frame.size))
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.secondaryText)
            Spacer(minLength: InspectorTheme.Spacing.xs)
            Text(LogsFormat.time(frame.timestampMs))
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.secondaryText)
            Image(systemName: "chevron.down")
                .font(.system(size: InspectorTheme.IconSize.xs, weight: .semibold))
                .foregroundColor(InspectorTheme.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .frame(minHeight: InspectorTheme.Spacing.xl)
    }

    private var expandedPayload: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                Text(frame.type == .binary ? "Payload (hex)" : "Payload")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer()
                CopyButton(text: fullPayload, label: "Payload")
                    .tint(InspectorTheme.brand)
            }
            Text(fullPayload)
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityText: String {
        "\(WebSocketFormat.directionTitle(frame.direction)) \(WebSocketFormat.type(frame.type)), "
            + "\(WebSocketFormat.size(frame.size)), \(LogsFormat.time(frame.timestampMs)), \(frame.payload.prefix(200))"
    }
}

#if DEBUG
#Preview("Frames") {
    NavigationView {
        WebSocketFramesContent(connection: PreviewSamples.webSocketConnections[0], frames: PreviewSamples.webSocketFrames)
    }
}

#Preview("Frames dark") {
    NavigationView {
        WebSocketFramesContent(connection: PreviewSamples.webSocketConnections[0], frames: PreviewSamples.webSocketFrames)
    }
    .preferredColorScheme(.dark)
}
#endif
