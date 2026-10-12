import SwiftUI
import UserNotifications
import WormaCeptor

/// The APNs token the host reported through `WormaCeptorPushToken`, and the app's notification permission.
struct PushTokenScreen: View {
    @State private var history: [WormaCeptorPushTokenEntry] = []
    @State private var permission: NotificationPermission?

    var body: some View {
        PushTokenContent(history: history, permission: permission)
            .navigationTitle("Push token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .tint(InspectorTheme.brand)
                    .accessibilityLabel("Refresh")
                }
            }
            .task { await refresh() }
    }

    private func refresh() async {
        history = WormaCeptorPushToken.shared.history
        permission = NotificationPermission(await UNUserNotificationCenter.current().notificationSettings())
    }
}

/// The parts of `UNNotificationSettings` the screen shows.
struct NotificationPermission {
    let status: String
    let alerts: String
    let badges: String
    let sounds: String
    let isAnswered: Bool

    init(status: String, alerts: String, badges: String, sounds: String, isAnswered: Bool = true) {
        self.status = status
        self.isAnswered = isAnswered
        self.alerts = alerts
        self.badges = badges
        self.sounds = sounds
    }

    init(_ settings: UNNotificationSettings) {
        self.init(
            status: Self.label(settings.authorizationStatus),
            alerts: Self.label(settings.alertSetting),
            badges: Self.label(settings.badgeSetting),
            sounds: Self.label(settings.soundSetting),
            isAnswered: settings.authorizationStatus != .notDetermined
        )
    }

    private static func label(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not asked yet"
        case .denied: return "Denied"
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral (App Clip)"
        @unknown default: return "Unknown"
        }
    }

    private static func label(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled: return "On"
        case .disabled: return "Off"
        case .notSupported: return "Not supported"
        @unknown default: return "Unknown"
        }
    }
}

/// Android's push token screen: the current token card, then the token history. iOS adds the notification
/// permission card.
struct PushTokenContent: View {
    let history: [WormaCeptorPushTokenEntry]
    let permission: NotificationPermission?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                PushTokenCurrentCard(entry: history.first)
                if let permission {
                    permissionCard(permission)
                }
                historySection
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
    }

    private func permissionCard(_ permission: NotificationPermission) -> some View {
        InspectorSectionCard("Notifications", systemImage: "bell") {
            InspectorKeyValueRow(label: "Permission", value: permission.status)
            // iOS reports every setting "not supported" until the user has answered the prompt.
            if permission.isAnswered {
                InspectorKeyValueRow(label: "Alerts", value: permission.alerts)
                InspectorKeyValueRow(label: "Badges", value: permission.badges)
                InspectorKeyValueRow(label: "Sounds", value: permission.sounds)
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            Text("Token history")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .accessibilityAddTraits(.isHeader)
            if history.isEmpty {
                Text("No history")
                    .font(InspectorFont.body)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 96)
            }
            ForEach(Array(history.enumerated()), id: \.element.token) { index, entry in
                PushTokenHistoryRow(entry: entry, isFirst: index == history.count - 1)
            }
        }
    }
}

/// Android's `PushTokenCurrentTokenCard`: the token in a mono box, its provider and time, and a copy button.
private struct PushTokenCurrentCard: View {
    let entry: WormaCeptorPushTokenEntry?

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            Text("Current token")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            if let entry {
                tokenSection(entry)
            } else {
                VStack(spacing: InspectorTheme.Spacing.sm) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: InspectorTheme.IconSize.xl))
                        .foregroundColor(InspectorTheme.secondaryText)
                        .accessibilityHidden(true)
                    Text("No token reported")
                        .font(InspectorFont.bodyMedium)
                        .foregroundColor(InspectorTheme.secondaryText)
                    Text("Call WormaCeptorPushToken.shared.set(deviceToken:) from application(_:didRegisterForRemoteNotificationsWithDeviceToken:).")
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            }
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: InspectorTheme.Spacing.lg
        )
    }
    @ViewBuilder private func tokenSection(_ entry: WormaCeptorPushTokenEntry) -> some View {
        Text(entry.token)
            .font(InspectorFont.code)
            .foregroundColor(InspectorTheme.textPrimary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(InspectorTheme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.background))
        HStack(spacing: InspectorTheme.Spacing.sm) {
            InspectorBadge(text: "APNS", color: InspectorTheme.color(for: .success))
            Text("Received \(InspectorFormat.time(entry.receivedMs))")
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        Button {
            UIPasteboard.general.string = entry.token
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(InspectorFilledButtonStyle())
        .accessibilityLabel(copied ? "Token copied" : "Copy token")
    }
}

/// Android's `PushTokenHistoryItem`: event icon well, event name, token prefix and time. iOS knows no events, so the
/// oldest token reads as created and later ones as refreshed.
private struct PushTokenHistoryRow: View {
    static let previewLength = 20

    let entry: WormaCeptorPushTokenEntry
    let isFirst: Bool

    var body: some View {
        let color = InspectorTheme.color(for: isFirst ? .success : .redirect)
        HStack(spacing: InspectorTheme.Spacing.md) {
            InspectorIconWell(
                systemImage: isFirst ? "plus" : "arrow.triangle.2.circlepath",
                color: color,
                size: InspectorTheme.IconSize.xl,
                iconSize: InspectorTheme.IconSize.sm - 2
            )
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(isFirst ? "Created" : "Refreshed")
                    .font(InspectorFont.bodyMedium)
                    .foregroundColor(InspectorTheme.textPrimary)
                Text(entry.token.prefix(Self.previewLength) + "...")
                    .font(InspectorFont.code)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Spacer(minLength: InspectorTheme.Spacing.sm)
            Text(InspectorFormat.time(entry.receivedMs))
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
        )
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.token
            } label: {
                Label("Copy token", systemImage: "doc.on.doc")
            }
        }
    }
}

#if DEBUG
#Preview("Push token") {
    NavigationView {
        PushTokenContent(history: PreviewSamples.pushTokens, permission: PreviewSamples.permission)
            .navigationTitle("Push token")
    }
}

#Preview("Push token dark") {
    NavigationView {
        PushTokenContent(history: PreviewSamples.pushTokens, permission: PreviewSamples.permission)
            .navigationTitle("Push token")
    }
    .preferredColorScheme(.dark)
}

#Preview("No push token") {
    NavigationView {
        PushTokenContent(history: [], permission: nil)
            .navigationTitle("Push token")
    }
}
#endif
