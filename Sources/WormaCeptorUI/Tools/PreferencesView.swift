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
    @Published private(set) var isLoaded = false

    private let defaults = WormaCeptorUserDefaults.shared

    func refresh() {
        domains = defaults.domains()
        isLoaded = true
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
        PreferenceDomainsContent(domains: model.domains, isLoaded: model.isLoaded) { domain in
            PreferenceEntriesScreen(model: model, domain: domain.name)
        }
        .onAppear { model.refresh() }
        .refreshable { model.refresh() }
    }
}

/// Android's preference file list: surface cards with a folder tile, the name and the key count.
struct PreferenceDomainsContent<Destination: View>: View {
    let domains: [WormaCeptorDefaultsDomain]
    var isLoaded = true
    @ViewBuilder let destination: (WormaCeptorDefaultsDomain) -> Destination

    @State private var search = ""
    @State private var isSearching = false

    private var visible: [WormaCeptorDefaultsDomain] {
        search.isEmpty ? domains : domains.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Search domains", text: $search)
            InspectorLoadable(isLoading: !isLoaded, isEmpty: visible.isEmpty) {
                InspectorEmptyState(
                    systemImage: "gearshape",
                    title: search.isEmpty ? "No defaults" : "No matches",
                    message: search.isEmpty ? "Domains show up here once the app stores a value." : "Try a different search."
                )
            } content: {
                ScrollView {
                    LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                        ForEach(visible, id: \.name) { domain in
                            NavigationLink(destination: destination(domain)) {
                                PreferenceDomainRow(domain: domain)
                            }
                            .buttonStyle(InspectorPressStyle())
                        }
                    }
                    .padding(.horizontal, InspectorTheme.Spacing.md)
                    .padding(.vertical, InspectorTheme.Spacing.sm)
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("UserDefaults")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
            }
        }
    }
}

private struct PreferenceDomainRow: View {
    let domain: WormaCeptorDefaultsDomain

    var body: some View {
        let count = domain.entries.count
        HStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "folder.fill")
                .font(.system(size: InspectorTheme.IconSize.md - 2))
                .foregroundColor(InspectorTheme.brand)
                .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                .background(
                    RoundedRectangle(cornerRadius: InspectorTheme.Radius.sm)
                        .fill(InspectorTheme.brand.opacity(InspectorTheme.Alpha.light))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(domain.name)
                    .font(InspectorFont.listHeadline)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(count == 1 ? "1 item" : "\(count) items")
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
            }
            Spacer(minLength: InspectorTheme.Spacing.sm)
            Image(systemName: "arrow.right")
                .font(.system(size: InspectorTheme.IconSize.sm - 2, weight: .semibold))
                .foregroundColor(InspectorTheme.secondaryText.opacity(InspectorTheme.Alpha.bold))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, InspectorTheme.Spacing.lg)
        .padding(.vertical, InspectorTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.surface))
        .contentShape(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(domain.name), \(count) keys")
        .accessibilityAddTraits(.isButton)
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                let count = model.domains.first { $0.name == domain }?.entries.count ?? 0
                InspectorNavigationTitle(title: domain, subtitle: count == 1 ? "1 item" : "\(count) items")
            }
        }
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

/// One domain's keys as Android's preference cards: search, type chips, tap to edit, swipe to delete.
struct PreferenceEntriesContent: View {
    let entries: [WormaCeptorDefaultsEntry]
    let onSave: (WormaCeptorDefaultsEntry, PreferenceEdit) -> Void
    let onDelete: (WormaCeptorDefaultsEntry) -> Void

    @State private var search = ""
    @State private var isSearching = false
    @State private var typeFilter: WormaCeptorDefaultsType?
    @State private var expandedKeys: Set<String> = []
    @State private var editing: EditTarget?
    @State private var pendingDelete: WormaCeptorDefaultsEntry?

    private var filtered: [WormaCeptorDefaultsEntry] {
        entries.filter { entry in
            (typeFilter == nil || entry.type == typeFilter)
                && (search.isEmpty || entry.key.localizedCaseInsensitiveContains(search)
                    || entry.value.localizedCaseInsensitiveContains(search))
        }
    }

    private var availableTypes: [WormaCeptorDefaultsType] {
        entries.reduce(into: [WormaCeptorDefaultsType]()) { types, entry in
            if !types.contains(entry.type) { types.append(entry.type) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Search keys and values", text: $search)
            if !availableTypes.isEmpty {
                typeChips.padding(.vertical, InspectorTheme.Spacing.xs)
            }
            if filtered.isEmpty {
                InspectorEmptyState(
                    systemImage: "key",
                    title: entries.isEmpty ? "No keys" : "No matches",
                    message: entries.isEmpty ? "This domain is empty." : "Try adjusting the search or filters."
                )
            } else {
                list
            }
        }
        .inspectorScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
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

    private var typeChips: some View {
        InspectorChipRow {
            InspectorChip(label: "All", isSelected: typeFilter == nil) { typeFilter = nil }
            ForEach(availableTypes, id: \.self) { type in
                InspectorChip(label: type.label, isSelected: typeFilter == type) {
                    typeFilter = typeFilter == type ? nil : type
                }
            }
        }
    }

    private var list: some View {
        List(filtered, id: \.key) { entry in
            PreferenceRowView(entry: entry, isExpanded: expandedKeys.contains(entry.key)) {
                if entry.type.isEditable {
                    editing = EditTarget(entry: entry)
                } else {
                    withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) {
                        expandedKeys.formSymmetricDifference([entry.key])
                    }
                }
            }
            .inspectorCardRow()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDelete = entry
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .inspectorPlainList()
    }
}

/// Android's `PreferenceItemCard`: key with a key glyph, the value in mono under it, a colored type badge.
struct PreferenceRowView: View {
    let entry: WormaCeptorDefaultsEntry
    var isExpanded = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xs) {
                    HStack(spacing: InspectorTheme.Spacing.sm) {
                        Image(systemName: "key.fill")
                            .font(.system(size: InspectorTheme.IconSize.xs - 2))
                            .foregroundColor(InspectorTheme.secondaryText)
                            .accessibilityHidden(true)
                        Text(entry.key)
                            .font(InspectorFont.bodyMedium.monospaced())
                            .foregroundColor(InspectorTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(entry.value)
                        .font(InspectorFont.code)
                        .foregroundColor(InspectorTheme.secondaryText)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                InspectorBadge(text: entry.type.label, color: PreferenceTypeColor.color(for: entry.type), font: InspectorFont.overline)
            }
            .inspectorCard(fill: InspectorTheme.surface, padding: InspectorTheme.Spacing.lg)
        }
        .buttonStyle(InspectorPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.type.isEditable ? "Edits the value" : (isExpanded ? "Shows less" : "Shows the full value"))
        .contextMenu {
            Button {
                UIPasteboard.general.string = entry.value
            } label: {
                Label("Copy value", systemImage: "doc.on.doc")
            }
        }
    }
}

/// Android's `ToolColors.Preferences` type colors; light shades are darker so the badge text reaches 4.5:1.
enum PreferenceTypeColor {
    static func color(for type: WormaCeptorDefaultsType) -> Color {
        switch type {
        case .string: return InspectorTheme.dynamic(light: 0x2E7D32, dark: 0x81C784)
        case .integer: return InspectorTheme.dynamic(light: 0x1565C0, dark: 0x64B5F6)
        case .decimal: return InspectorTheme.dynamic(light: 0x7B1FA2, dark: 0xBA68C8)
        case .boolean: return InspectorTheme.dynamic(light: 0xC2410C, dark: 0xFFB74D)
        case .array: return InspectorTheme.dynamic(light: 0x00838F, dark: 0x4DD0E1)
        case .dictionary: return InspectorTheme.dynamic(light: 0x3949AB, dark: 0x7986CB)
        default: return InspectorTheme.color(for: .neutral)
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

#Preview("Defaults domains, dark") {
    NavigationView {
        PreferenceDomainsContent(domains: PreviewSamples.defaultsDomains) { domain in
            Text(domain.name)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Defaults entries") {
    NavigationView {
        PreferenceEntriesContent(entries: PreviewSamples.defaultsDomains[0].entries, onSave: { _, _ in }, onDelete: { _ in })
            .navigationTitle("com.wormadev.wormaceptor.sample")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Defaults entries, dark") {
    NavigationView {
        PreferenceEntriesContent(entries: PreviewSamples.defaultsDomains[0].entries, onSave: { _, _ in }, onDelete: { _ in })
            .navigationTitle("com.wormadev.wormaceptor.sample")
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
#endif
