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
            .task { await refresh() }
            .refreshable { await refresh() }
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

struct PushTokenContent: View {
    let history: [WormaCeptorPushTokenEntry]
    let permission: NotificationPermission?

    var body: some View {
        List {
            tokenSection
            if let permission {
                Section("Notifications") {
                    InfoRowView(row: WormaCeptorInfoRow(label: "Permission", value: permission.status))
                    // iOS reports every setting "not supported" until the user has answered the prompt.
                    if permission.isAnswered {
                        InfoRowView(row: WormaCeptorInfoRow(label: "Alerts", value: permission.alerts))
                        InfoRowView(row: WormaCeptorInfoRow(label: "Badges", value: permission.badges))
                        InfoRowView(row: WormaCeptorInfoRow(label: "Sounds", value: permission.sounds))
                    }
                }
            }
            if history.count > 1 {
                Section("Earlier tokens") {
                    ForEach(history.dropFirst(), id: \.token) { entry in
                        TokenView(entry: entry)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var tokenSection: some View {
        if let current = history.first {
            Section {
                TokenView(entry: current)
            } header: {
                HStack {
                    Text("APNs token")
                    Spacer()
                    CopyButton(text: current.token, label: "Token")
                }
            }
        } else {
            Section("APNs token") {
                Text("No token reported. Call WormaCeptorPushToken.shared.set(deviceToken:) from application(_:didRegisterForRemoteNotificationsWithDeviceToken:).")
                    .font(.callout)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
        }
    }
}

private struct TokenView: View {
    let entry: WormaCeptorPushTokenEntry

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            Text(entry.token)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            Text("Received \(InspectorFormat.time(entry.receivedMs))")
                .font(.caption)
                .foregroundColor(InspectorTheme.secondaryText)
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Push token") {
    NavigationView {
        PushTokenContent(history: PreviewSamples.pushTokens, permission: PreviewSamples.permission)
            .navigationTitle("Push token")
    }
}

#Preview("No push token") {
    NavigationView {
        PushTokenContent(history: [], permission: nil)
            .navigationTitle("Push token")
    }
}
#endif
