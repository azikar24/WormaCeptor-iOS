import SwiftUI
import WormaCeptor

/// A value typed in the edit sheet, matching the entry's type.
enum PreferenceEdit {
    case string(String)
    case integer(Int64)
    case double(Double)
    case boolean(Bool)
}

/// UserDefaults domains, re-read after every edit.
@MainActor
final class PreferencesModel: ObservableObject {
    @Published private(set) var domains: [WormaCeptorDefaultsDomain] = []

    private let defaults = WormaCeptorUserDefaults.shared

    func refresh() {
        domains = defaults.domains()
    }

    func save(domain: String, key: String, edit: PreferenceEdit) {
        switch edit {
        case .string(let value): defaults.setString(domain: domain, key: key, value: value)
        case .integer(let value): defaults.setInteger(domain: domain, key: key, value: value)
        case .double(let value): defaults.setDouble(domain: domain, key: key, value: value)
        case .boolean(let value): defaults.setBoolean(domain: domain, key: key, value: value)
        }
        refresh()
    }

    func delete(domain: String, key: String) {
        defaults.remove(domain: domain, key: key)
        refresh()
    }
}

/// The app's UserDefaults and its registered suites, the same data `get_preferences` returns.
struct PreferencesScreen: View {
    @StateObject private var model = PreferencesModel()

    var body: some View {
        PreferenceDomainsContent(domains: model.domains) { domain in
            PreferenceEntriesScreen(model: model, domain: domain.name)
        }
        .onAppear { model.refresh() }
        .refreshable { model.refresh() }
    }
}

struct PreferenceDomainsContent<Destination: View>: View {
    let domains: [WormaCeptorDefaultsDomain]
    @ViewBuilder let destination: (WormaCeptorDefaultsDomain) -> Destination

    var body: some View {
        List(domains, id: \.name) { domain in
            NavigationLink(destination: destination(domain)) {
                HStack(spacing: InspectorTheme.Spacing.md) {
                    Text(domain.name)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer(minLength: InspectorTheme.Spacing.sm)
                    Text("\(domain.entries.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(domain.name), \(domain.entries.count) keys")
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if domains.isEmpty {
                EmptyStateView(systemImage: "slider.horizontal.3", title: "No defaults", message: "Nothing is stored yet.")
            }
        }
        .navigationTitle("UserDefaults")
    }
}

struct PreferenceEntriesScreen: View {
    @ObservedObject var model: PreferencesModel
    let domain: String

    var body: some View {
        PreferenceEntriesContent(
            entries: model.domains.first { $0.name == domain }?.entries ?? [],
            onSave: { entry, edit in model.save(domain: domain, key: entry.key, edit: edit) },
            onDelete: { entry in model.delete(domain: domain, key: entry.key) }
        )
        .navigationTitle(domain)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { model.refresh() }
    }
}

/// Wraps an entry for `sheet(item:)`, which needs an `Identifiable`.
private struct EditTarget: Identifiable {
    let entry: WormaCeptorDefaultsEntry
    var id: String { entry.key }
}

/// One domain's keys: search, tap to edit strings, numbers and booleans, swipe to delete.
struct PreferenceEntriesContent: View {
    let entries: [WormaCeptorDefaultsEntry]
    let onSave: (WormaCeptorDefaultsEntry, PreferenceEdit) -> Void
    let onDelete: (WormaCeptorDefaultsEntry) -> Void

    @State private var search = ""
    @State private var editing: EditTarget?
    @State private var pendingDelete: WormaCeptorDefaultsEntry?

    private var filtered: [WormaCeptorDefaultsEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter { $0.key.localizedCaseInsensitiveContains(search) || $0.value.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(filtered, id: \.key) { entry in
            PreferenceRowView(entry: entry) {
                editing = EditTarget(entry: entry)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDelete = entry
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "Search keys and values")
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: entries.isEmpty ? "No keys" : "No matches",
                    message: entries.isEmpty ? "This domain is empty." : "Nothing matches \"\(search)\"."
                )
            }
        }
        .sheet(item: $editing) { target in
            PreferenceEditSheet(entry: target.entry) { onSave(target.entry, $0) }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.key ?? "")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) { onDelete(entry) }
        } message: { _ in
            Text("The key is removed from UserDefaults.")
        }
    }
}

struct PreferenceRowView: View {
    let entry: WormaCeptorDefaultsEntry
    let onEdit: () -> Void

    var body: some View {
        let content = VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(entry.key)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: InspectorTheme.Spacing.sm)
                InspectorBadge(text: entry.type.label, color: InspectorTheme.color(for: .neutral))
            }
            Text(entry.value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(3)
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.value
            } label: {
                Label("Copy value", systemImage: "doc.on.doc")
            }
        }

        if entry.type.isEditable {
            Button(action: onEdit) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Edits the value")
        } else {
            content
        }
    }
}

struct PreferenceEditSheet: View {
    let entry: WormaCeptorDefaultsEntry
    let onSave: (PreferenceEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var flag: Bool

    init(entry: WormaCeptorDefaultsEntry, onSave: @escaping (PreferenceEdit) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.value)
        _flag = State(initialValue: entry.value == "true")
    }

    /// Nil while the text isn't a valid number for a number entry.
    private var edit: PreferenceEdit? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        switch entry.type {
        case .boolean: return .boolean(flag)
        case .integer: return Int64(trimmed).map(PreferenceEdit.integer)
        case .decimal: return Double(trimmed).map(PreferenceEdit.double)
        default: return .string(text)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Key") {
                    Text(entry.key)
                        .textSelection(.enabled)
                }
                Section {
                    valueField
                } header: {
                    Text(entry.type.label)
                } footer: {
                    if edit == nil {
                        Text(entry.type == .integer ? "Enter a whole number." : "Enter a number.")
                            .foregroundColor(InspectorTheme.color(for: .error))
                    }
                }
            }
            .navigationTitle("Edit value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let edit {
                            onSave(edit)
                            dismiss()
                        }
                    }
                    .disabled(edit == nil)
                }
            }
        }
    }

    @ViewBuilder private var valueField: some View {
        switch entry.type {
        case .boolean:
            Toggle(entry.key, isOn: $flag)
                .frame(minHeight: InspectorTheme.minTouchTarget)
        case .integer, .decimal:
            TextField("Value", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .font(.body.monospacedDigit())
                .frame(minHeight: InspectorTheme.minTouchTarget)
        default:
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: InspectorTheme.minTouchTarget * 3)
                .accessibilityLabel("Value")
        }
    }
}

#if DEBUG
#Preview("Defaults domains") {
    NavigationView {
        PreferenceDomainsContent(domains: PreviewSamples.defaultsDomains) { domain in
            Text(domain.name)
        }
    }
}

#Preview("Defaults entries") {
    NavigationView {
        PreferenceEntriesContent(entries: PreviewSamples.defaultsDomains[0].entries, onSave: { _, _ in }, onDelete: { _ in })
            .navigationTitle("com.wormadev.wormaceptor.sample")
    }
}

#Preview("Edit a string") {
    PreferenceEditSheet(entry: PreviewSamples.defaultsDomains[0].entries[0]) { _ in }
}
#endif
