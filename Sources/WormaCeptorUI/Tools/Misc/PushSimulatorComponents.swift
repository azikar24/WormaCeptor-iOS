import SwiftUI
import WormaCeptor

/// Android's `TemplatesRow`: a header with the count, then template cards in a horizontal scroll.
struct PushTemplatesRow: View {
    let templates: [WormaCeptorPushTemplate]
    let onLoad: (WormaCeptorPushTemplate) -> Void
    let onSend: (WormaCeptorPushTemplate) -> Void
    let onDelete: (WormaCeptorPushTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundColor(InspectorTheme.brand)
                    .accessibilityHidden(true)
                Text("Templates")
                    .font(InspectorFont.titleMedium.weight(.bold))
                    .foregroundColor(InspectorTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !templates.isEmpty {
                    InspectorBadge(text: "\(templates.count)", color: InspectorTheme.brand)
                }
            }
            if templates.isEmpty {
                InspectorEmptyState(
                    systemImage: "square.and.arrow.down",
                    title: "No templates saved",
                    message: "Save your notification configuration as a template for quick reuse"
                )
                .frame(height: 280)
            } else {
                InspectorChipRow(inset: 0) {
                    ForEach(templates, id: \.id) { template in
                        PushTemplateCard(
                            template: template,
                            onLoad: { onLoad(template) },
                            onSend: { onSend(template) },
                            onDelete: { onDelete(template) }
                        )
                    }
                }
            }
        }
    }
}

/// Android's `TemplateCard`: priority, data and preset chips, name, title and body; delete and a round send button.
private struct PushTemplateCard: View {
    let template: WormaCeptorPushTemplate
    let onLoad: () -> Void
    let onSend: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let notification = template.notification
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Button(action: onLoad) {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                    HStack(spacing: InspectorTheme.Spacing.xs) {
                        PushPriorityChip(priority: notification.priority)
                        if !notification.data.isEmpty {
                            InspectorBadge(text: "\(notification.data.count) keys", color: InspectorTheme.secondaryText)
                        }
                        if template.isBuiltIn {
                            InspectorBadge(text: "Preset", color: InspectorTheme.secondaryText)
                        }
                    }
                    .padding(.bottom, InspectorTheme.Spacing.xs)
                    Text(template.name)
                        .font(InspectorFont.titleSmall)
                        .foregroundColor(InspectorTheme.textPrimary)
                        .lineLimit(1)
                    Text(notification.title)
                        .font(InspectorFont.bodySmall.weight(.medium))
                        .foregroundColor(InspectorTheme.textPrimary)
                        .lineLimit(1)
                    Text(notification.body)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(2)
                        .frame(minHeight: 32, alignment: .top)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Loads it into the form")
            HStack {
                if !template.isBuiltIn {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(InspectorTheme.error.opacity(InspectorTheme.Alpha.heavy))
                            .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Delete \(template.name)")
                }
                Spacer()
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                        .foregroundColor(InspectorTheme.background)
                        .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                        .background(Circle().fill(InspectorTheme.brand))
                }
                .buttonStyle(InspectorPressStyle())
                .accessibilityLabel("Send \(template.name)")
            }
        }
        .frame(width: 200)
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
        )
    }
}

/// Android's `PriorityIndicator`: a dot and the priority name on its tint.
struct PushPriorityChip: View {
    let priority: WormaCeptorPushPriority

    var body: some View {
        let color = MiscToolColors.PushPriority.color(priority)
        HStack(spacing: InspectorTheme.Spacing.xs) {
            InspectorStatusDot(color: color, size: 6)
            Text(priority.name)
                .font(InspectorFont.labelSmall)
                .foregroundColor(color)
        }
        .padding(.horizontal, InspectorTheme.Spacing.sm)
        .padding(.vertical, InspectorTheme.Spacing.xxs)
        .background(Capsule().fill(color.opacity(InspectorTheme.Alpha.subtle)))
        .accessibilityLabel("Priority \(priority.name.lowercased())")
    }
}

/// The form card: Android's live preview, title and message with counters, thread, priority chips, and iOS's
/// userInfo data rows in place of Android's action buttons.
struct PushFormCard: View {
    @Binding var draft: PushDraft

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.md) {
            PushNotificationPreview(draft: draft)
            Rectangle()
                .fill(InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.moderate))
                .frame(height: InspectorTheme.Border.thin)
                .padding(.vertical, InspectorTheme.Spacing.sm)
            counted(InspectorTextField(
                label: "Title",
                text: limited($draft.title, to: PushDraft.titleLimit),
                placeholder: "Enter notification title"
            ), count: draft.title.count, limit: PushDraft.titleLimit)
            counted(InspectorTextField(
                label: "Message",
                text: limited($draft.body, to: PushDraft.bodyLimit),
                placeholder: "Enter notification message",
                multiline: true
            ), count: draft.body.count, limit: PushDraft.bodyLimit)
            InspectorTextField(
                label: "Thread",
                text: $draft.threadId,
                placeholder: "e.g., chat-42 (groups notifications)"
            )
            priorityChips
            PushDataEditor(rows: $draft.data)
        }
        .inspectorCard(
            fill: InspectorTheme.surface,
            border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium),
            padding: InspectorTheme.Spacing.lg
        )
    }

    private var priorityChips: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            Text("Priority")
                .font(InspectorFont.label)
                .foregroundColor(InspectorTheme.secondaryText)
            InspectorChipRow(inset: 0) {
                ForEach(WormaCeptorPushPriority.entries, id: \.self) { priority in
                    InspectorChip(
                        label: priority.name,
                        isSelected: draft.priority == priority,
                        leading: AnyView(InspectorStatusDot(color: MiscToolColors.PushPriority.color(priority))),
                        action: { draft.priority = priority }
                    )
                }
            }
            Text("Low is passive, default is active, high and max are time sensitive (critical alerts need an entitlement).")
                .font(InspectorFont.labelSmall)
                .foregroundColor(InspectorTheme.secondaryText)
        }
    }

    /// Android's `OutlinedTextFieldWithCounter`: "n / max", brand past 80%.
    private func counted<Field: View>(_ field: Field, count: Int, limit: Int) -> some View {
        VStack(alignment: .trailing, spacing: InspectorTheme.Spacing.xxs) {
            field
            Text("\(count) / \(limit)")
                .font(InspectorFont.labelSmall.monospacedDigit())
                .foregroundColor(Double(count) > Double(limit) * 0.8 ? InspectorTheme.brand : InspectorTheme.secondaryText)
                .inspectorAnimation(InspectorMotion.standard(InspectorMotion.fast), value: Double(count) > Double(limit) * 0.8)
        }
    }

    private func limited(_ text: Binding<String>, to limit: Int) -> Binding<String> {
        Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) })
    }
}

/// Android's `NotificationPreview`: how the notification will read, updated as you type.
private struct PushNotificationPreview: View {
    let draft: PushDraft

    var body: some View {
        let color = MiscToolColors.PushPriority.color(draft.priority)
        let isHigh = draft.priority == .high || draft.priority == .max
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.sm) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text("Preview")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
                if !draft.threadId.isEmpty {
                    InspectorBadge(text: draft.threadId, color: InspectorTheme.brand, font: InspectorFont.labelSmall)
                }
                Spacer()
                PushPriorityChip(priority: draft.priority)
            }
            HStack(alignment: .top, spacing: InspectorTheme.Spacing.md) {
                Image(systemName: isHigh ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: InspectorTheme.IconSize.md))
                    .foregroundColor(InspectorTheme.brand)
                    .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surfaceHigh))
                    .overlay(alignment: .topTrailing) { InspectorStatusDot(color: color, size: InspectorTheme.Spacing.md) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    HStack {
                        Text(draft.title.isEmpty ? "Notification Title" : draft.title)
                            .font(InspectorFont.titleSmall)
                            .foregroundColor(InspectorTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("now")
                            .font(InspectorFont.labelSmall)
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                    Text(draft.body.isEmpty ? "Notification message will appear here" : draft.body)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(3)
                }
            }
            .inspectorCard(
                fill: InspectorTheme.background,
                border: InspectorTheme.outlineVariant.opacity(InspectorTheme.Alpha.medium)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview")
        }
    }
}

/// The notification's userInfo as key/value rows.
private struct PushDataEditor: View {
    @Binding var rows: [PushDraft.DataRow]

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack {
                Text("Data")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
                Spacer()
                Text("Delivered as userInfo")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            ForEach($rows) { $row in
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    InspectorTextField(label: "Key", text: $row.key)
                    InspectorTextField(label: "Value", text: $row.value)
                    Button {
                        rows.removeAll { $0.id == row.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(InspectorTheme.secondaryText)
                            .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                    }
                    .padding(.top, InspectorTheme.Spacing.lg)
                    .accessibilityLabel("Remove \(row.key.isEmpty ? "row" : row.key)")
                }
                .transition(.opacity)
            }
            Button {
                withInspectorAnimation(InspectorMotion.standard(InspectorMotion.fast)) { rows.append(PushDraft.DataRow()) }
            } label: {
                Label("Add key", systemImage: "plus")
            }
            .buttonStyle(InspectorOutlinedButtonStyle())
        }
    }
}
