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
            onSendTemplate: { template in
                model.load(template)
                Task { await model.send(delayed: false) }
            },
            onSave: model.save,
            onDelete: model.delete
        )
        .task { await model.refreshStatus() }
    }
}

/// Android's push simulator: template cards on top, the form with its live preview, then save and send.
struct PushSimulatorContent: View {
    @Binding var draft: PushDraft
    let templates: [WormaCeptorPushTemplate]
    let status: WormaCeptorPushStatus?
    let outcome: WormaCeptorPushResult?
    let isSending: Bool
    let onSend: (_ delayed: Bool) -> Void
    let onLoad: (WormaCeptorPushTemplate) -> Void
    let onSendTemplate: (WormaCeptorPushTemplate) -> Void
    let onSave: (String) -> Void
    let onDelete: (WormaCeptorPushTemplate) -> Void

    @State private var templateName = ""
    @State private var isNamingTemplate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                PushTemplatesRow(templates: templates, onLoad: onLoad, onSend: onSendTemplate, onDelete: onDelete)
                PushFormCard(draft: $draft)
                actions
                if let outcome {
                    Text(outcome.message)
                        .font(InspectorFont.body)
                        .foregroundColor(InspectorTheme.color(for: outcome.isSent ? .success : .error))
                }
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorDismissesKeyboardOnScroll()
        .inspectorScreen()
        .navigationTitle("Push simulator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    draft = PushDraft()
                } label: {
                    Image(systemName: "xmark")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .tint(InspectorTheme.brand)
                .accessibilityLabel("Clear form")
            }
        }
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: isNamingTemplate)
    }

    private var actions: some View {
        let canSend = draft.canSend && !isSending
        return VStack(spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.md) {
                Button {
                    isNamingTemplate.toggle()
                } label: {
                    Label("Save template", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(InspectorOutlinedButtonStyle())
                .disabled(!draft.canSend)
                .opacity(draft.canSend ? 1 : InspectorTheme.Alpha.strong)
                Button {
                    onSend(false)
                } label: {
                    Label("Send", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(InspectorFilledButtonStyle())
                .disabled(!canSend)
                .opacity(canSend ? 1 : InspectorTheme.Alpha.strong)
            }
            if isNamingTemplate {
                saveTemplateField.transition(InspectorMotion.expand)
            }
            Button {
                onSend(true)
            } label: {
                Label("Send in \(Int(WormaCeptorPushSimulator.shared.LeaveAppDelaySeconds)) s", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InspectorOutlinedButtonStyle())
            .disabled(!canSend)
            .opacity(canSend ? 1 : InspectorTheme.Alpha.strong)
            .accessibilityHint("Gives you time to leave the app before it arrives")
        }
    }

    private var saveTemplateField: some View {
        let isValid = !templateName.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            InspectorTextField(
                label: "Template name",
                text: $templateName,
                placeholder: "e.g., Welcome Message",
                supporting: "Give your notification a name for quick access later."
            )
            HStack(spacing: InspectorTheme.Spacing.md) {
                Spacer()
                Button("Cancel") {
                    isNamingTemplate = false
                    templateName = ""
                }
                .buttonStyle(InspectorOutlinedButtonStyle())
                Button("Save") {
                    onSave(templateName)
                    templateName = ""
                    isNamingTemplate = false
                }
                .buttonStyle(InspectorFilledButtonStyle())
                .disabled(!isValid)
                .opacity(isValid ? 1 : InspectorTheme.Alpha.strong)
                .accessibilityLabel("Save as template")
            }
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: InspectorTheme.Spacing.lg
        )
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
}

#if DEBUG
private func pushSimulatorPreview() -> some View {
    NavigationView {
        PushSimulatorContent(
            draft: .constant(PushDraft(PreviewSamples.pushTemplates[1].notification)),
            templates: PreviewSamples.pushTemplates,
            status: WormaCeptorPushStatus(isAuthorizationDetermined: true, isAllowed: true, isForegroundSilenced: true),
            outcome: WormaCeptorPushResult(isSent: true, message: "Sent."),
            isSending: false,
            onSend: { _ in },
            onLoad: { _ in },
            onSendTemplate: { _ in },
            onSave: { _ in },
            onDelete: { _ in }
        )
    }
}

#Preview("Push simulator") {
    pushSimulatorPreview()
}

#Preview("Push simulator dark") {
    pushSimulatorPreview().preferredColorScheme(.dark)
}
#endif
