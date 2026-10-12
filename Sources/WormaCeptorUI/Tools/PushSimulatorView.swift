import SwiftUI
import WormaCeptor

/// The notification being composed. `data` keeps rows in order so the editor doesn't reshuffle while typing.
struct PushDraft {
    struct DataRow: Identifiable {
        let id = UUID()
        var key = ""
        var value = ""
    }

    static let titleLimit = 50
    static let bodyLimit = 200

    var title = ""
    var body = ""
    var threadId = ""
    var priority: WormaCeptorPushPriority = .default_
    var data: [DataRow] = []

    var canSend: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !body.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var notification: WormaCeptorPushNotification {
        let pairs = data.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) }
        return WormaCeptorPushNotification(
            title: title,
            body: body,
            threadId: threadId,
            priority: priority,
            data: Dictionary(pairs, uniquingKeysWith: { _, last in last })
        )
    }

    init() {}

    init(_ notification: WormaCeptorPushNotification) {
        title = notification.title
        body = notification.body
        threadId = notification.threadId
        priority = notification.priority
        data = notification.data.sorted { $0.key < $1.key }.map { DataRow(key: $0.key, value: $0.value) }
    }
}

/// Sends, loads templates and keeps the last outcome.
@MainActor
final class PushSimulatorModel: ObservableObject {
    @Published var draft = PushDraft()
    @Published private(set) var templates: [WormaCeptorPushTemplate] = WormaCeptorPushSimulator.shared.templates
    @Published private(set) var status: WormaCeptorPushStatus?
    @Published private(set) var outcome: WormaCeptorPushResult?
    @Published private(set) var isSending = false

    func refreshStatus() async {
        status = try? await WormaCeptorPushSimulator.shared.status()
    }

    func send(delayed: Bool) async {
        isSending = true
        defer { isSending = false }
        let delay = delayed ? WormaCeptorPushSimulator.shared.LeaveAppDelaySeconds : 0
        do {
            outcome = try await WormaCeptorPushSimulator.shared.send(notification: draft.notification, delaySeconds: delay)
        } catch {
            outcome = WormaCeptorPushResult(isSent: false, message: error.localizedDescription)
        }
        await refreshStatus()
    }

    func load(_ template: WormaCeptorPushTemplate) {
        draft = PushDraft(template.notification)
        outcome = nil
    }

    func save(name: String) {
        _ = WormaCeptorPushSimulator.shared.saveTemplate(name: name, notification: draft.notification)
        templates = WormaCeptorPushSimulator.shared.templates
    }

    func delete(_ template: WormaCeptorPushTemplate) {
        WormaCeptorPushSimulator.shared.deleteTemplate(id: template.id)
        templates = WormaCeptorPushSimulator.shared.templates
    }
}

/// Posts a local notification in place of a push, the same thing `send_push_notification` does.
struct PushSimulatorScreen: View {
    @StateObject private var model = PushSimulatorModel()

    var body: some View {
        PushSimulatorContent(
            draft: $model.draft,
            templates: model.templates,
            status: model.status,
            outcome: model.outcome,
            isSending: model.isSending,
            onSend: { delayed in Task { await model.send(delayed: delayed) } },
            onLoad: model.load,
            onSave: model.save,
            onDelete: model.delete
        )
        .task { await model.refreshStatus() }
    }
}

struct PushSimulatorContent: View {
    @Binding var draft: PushDraft
    let templates: [WormaCeptorPushTemplate]
    let status: WormaCeptorPushStatus?
    let outcome: WormaCeptorPushResult?
    let isSending: Bool
    let onSend: (_ delayed: Bool) -> Void
    let onLoad: (WormaCeptorPushTemplate) -> Void
    let onSave: (String) -> Void
    let onDelete: (WormaCeptorPushTemplate) -> Void

    @State private var templateName = ""

    var body: some View {
        Form {
            notificationSection
            dataSection
            sendSection
            templatesSection
        }
        .navigationTitle("Push simulator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notificationSection: some View {
        Section {
            TextField("Title", text: limited($draft.title, to: PushDraft.titleLimit))
            TextField("Body", text: limited($draft.body, to: PushDraft.bodyLimit))
            Picker("Priority", selection: $draft.priority) {
                ForEach(WormaCeptorPushPriority.entries, id: \.self) { priority in
                    Text(priority.name.capitalized).tag(priority)
                }
            }
            TextField("Thread (Android channel)", text: $draft.threadId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Notification")
        } footer: {
            Text("Low is passive, default is active, high and max are time sensitive (critical alerts need an entitlement). The thread groups notifications, the closest thing iOS has to a channel.")
        }
    }

    private var dataSection: some View {
        Section {
            ForEach($draft.data) { $row in
                HStack {
                    TextField("Key", text: $row.key)
                    TextField("Value", text: $row.value)
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .onDelete { draft.data.remove(atOffsets: $0) }
            Button {
                draft.data.append(PushDraft.DataRow())
            } label: {
                Label("Add key", systemImage: "plus")
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Delivered as the notification's userInfo.")
        }
    }

    private var sendSection: some View {
        Section {
            Button {
                onSend(false)
            } label: {
                Label("Send", systemImage: "paperplane")
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
            .disabled(!draft.canSend || isSending)
            Button {
                onSend(true)
            } label: {
                Label("Send in \(Int(WormaCeptorPushSimulator.shared.LeaveAppDelaySeconds)) s", systemImage: "timer")
                    .frame(minHeight: InspectorTheme.minTouchTarget)
            }
            .disabled(!draft.canSend || isSending)
            .accessibilityHint("Gives you time to leave the app before it arrives")
            if let outcome {
                Text(outcome.message)
                    .font(.callout)
                    .foregroundColor(InspectorTheme.color(for: outcome.isSent ? .success : .error))
            }
        } footer: {
            Text(statusText)
        }
    }

    private var templatesSection: some View {
        Section("Templates") {
            ForEach(templates, id: \.id) { template in
                Button {
                    onLoad(template)
                } label: {
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        Text(template.name)
                            .foregroundColor(.primary)
                        Text(template.notification.title)
                            .font(.caption)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                    .frame(minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityHint("Loads it into the form")
                .swipeActions {
                    if !template.isBuiltIn {
                        Button(role: .destructive) {
                            onDelete(template)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            HStack {
                TextField("Template name", text: $templateName)
                Button("Save") {
                    onSave(templateName)
                    templateName = ""
                }
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty || !draft.canSend)
                .accessibilityLabel("Save as template")
            }
        }
    }

    private var statusText: String {
        guard let status else { return "" }
        if !status.isAuthorizationDetermined {
            return "The first send asks for notification permission."
        }
        if !status.isAllowed {
            return "Notifications are off for this app. Allow them in Settings > Notifications."
        }
        if status.isForegroundSilenced {
            return "While the app is open iOS silences notifications: the app has no notification center delegate that presents them. Use the delayed send and leave the app."
        }
        return "Notifications show while the app is open."
    }

    private func limited(_ text: Binding<String>, to limit: Int) -> Binding<String> {
        Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) })
    }
}

#if DEBUG
#Preview("Push simulator") {
    NavigationView {
        PushSimulatorContent(
            draft: .constant(PushDraft(PreviewSamples.pushTemplates[1].notification)),
            templates: PreviewSamples.pushTemplates,
            status: WormaCeptorPushStatus(isAuthorizationDetermined: true, isAllowed: true, isForegroundSilenced: true),
            outcome: WormaCeptorPushResult(isSent: true, message: "Sent."),
            isSending: false,
            onSend: { _ in },
            onLoad: { _ in },
            onSave: { _ in },
            onDelete: { _ in }
        )
    }
}
#endif
