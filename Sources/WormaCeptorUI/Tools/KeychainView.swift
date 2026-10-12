import SwiftUI
import WormaCeptor

/// The app's Keychain items. Values stay on the device: `browse_secure_storage` gets keys and metadata only.
struct KeychainScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorKeychainItem]()) {
        try await WormaCeptorKeychain.shared.items()
    }
    @State private var isRefreshing = false

    var body: some View {
        KeychainContent(items: model.value, isLoaded: model.isLoaded, error: model.error)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InspectorRefreshButton(isRefreshing: isRefreshing) { Task { await refresh() } }
                }
            }
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }

    private func refresh() async {
        isRefreshing = true
        await model.refresh()
        isRefreshing = false
    }
}

/// Android's secure storage screen: per-class counts, class chips, then one card per item.
struct KeychainContent: View {
    let items: [WormaCeptorKeychainItem]
    var isLoaded = true
    var error: String?

    @State private var search = ""
    @State private var isSearching = false
    @State private var selectedType: KeychainClass?

    private var filtered: [WormaCeptorKeychainItem] {
        items.filter { item in
            (selectedType == nil || item.storageType == selectedType?.rawValue)
                && (search.isEmpty || item.key.localizedCaseInsensitiveContains(search)
                    || (item.value?.localizedCaseInsensitiveContains(search) ?? false))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Key or value", text: $search)
            summary
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.top, InspectorTheme.Spacing.sm)
            chips.padding(.vertical, InspectorTheme.Spacing.xs)
            if let error {
                Text(error)
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(InspectorTheme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(InspectorTheme.error.opacity(InspectorTheme.Alpha.subtle)))
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
            }
            InspectorLoadable(isLoading: !isLoaded, isEmpty: filtered.isEmpty) {
                emptyState
            } content: {
                ScrollView {
                    LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                            NavigationLink(destination: KeychainItemScreen(item: item)) {
                                KeychainRowView(item: item)
                            }
                            .buttonStyle(InspectorPressStyle())
                        }
                    }
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
                    .padding(.bottom, InspectorTheme.Spacing.lg)
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("Keychain")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            ForEach(KeychainClass.allCases, id: \.self) { type in
                InspectorSummaryCard(
                    count: items.filter { $0.storageType == type.rawValue }.count,
                    label: type.shortTitle,
                    systemImage: type.systemImage
                )
            }
        }
    }

    private var chips: some View {
        InspectorChipRow {
            InspectorChip(label: "All", isSelected: selectedType == nil) { selectedType = nil }
            ForEach(KeychainClass.allCases, id: \.self) { type in
                InspectorChip(label: type.shortTitle, isSelected: selectedType == type, systemImage: type.systemImage) {
                    selectedType = selectedType == type ? nil : type
                }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if items.isEmpty {
            InspectorEmptyState(
                systemImage: "key",
                title: "No Keychain items",
                message: "Passwords, keys and certificates the app stores in its Keychain show up here."
            )
        } else {
            InspectorEmptyState(systemImage: "magnifyingglass", title: "No matches", message: "Try adjusting the search or filters.")
        }
    }
}

/// The four Keychain item classes `WormaCeptorKeychainItem.storageType` reports.
enum KeychainClass: String, CaseIterable {
    case genericPassword = "GENERIC_PASSWORD"
    case internetPassword = "INTERNET_PASSWORD"
    case key = "KEY"
    case certificate = "CERTIFICATE"

    init?(_ item: WormaCeptorKeychainItem) {
        self.init(rawValue: item.storageType)
    }

    var shortTitle: String {
        switch self {
        case .genericPassword: return "Generic"
        case .internetPassword: return "Internet"
        case .key: return "Keys"
        case .certificate: return "Certs"
        }
    }

    var systemImage: String {
        switch self {
        case .genericPassword: return "lock.shield"
        case .internetPassword: return "globe"
        case .key: return "key"
        case .certificate: return "checkmark.seal"
        }
    }
}

/// Android's `EntryCard`: a green lock tile (Keychain items are always encrypted), key, summary, date, class badge.
private struct KeychainRowView: View {
    let item: WormaCeptorKeychainItem

    var body: some View {
        let encrypted = InspectorTheme.color(for: .success)
        HStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: InspectorTheme.IconSize.md - 2))
                .foregroundColor(encrypted)
                .frame(width: InspectorTheme.minTouchTarget, height: InspectorTheme.minTouchTarget)
                .background(RoundedRectangle(cornerRadius: InspectorTheme.Radius.md).fill(encrypted.opacity(InspectorTheme.Alpha.light)))
                .accessibilityLabel("Encrypted")
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(item.key)
                    .font(InspectorFont.titleSmall.monospaced())
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(KeychainFormat.summary(item))
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
                if let modified = item.modifiedMs?.int64Value {
                    Text(KeychainFormat.date(modified))
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            InspectorBadge(
                text: KeychainClass(item)?.shortTitle ?? item.kind,
                color: InspectorTheme.secondaryText,
                font: InspectorFont.labelSmall.weight(.semibold)
            )
        }
        .inspectorCard(fill: InspectorTheme.surface, padding: InspectorTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// One item as Android's entry detail: class header, key, value (text values only), every attribute.
struct KeychainItemScreen: View {
    let item: WormaCeptorKeychainItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                InspectorDetailHeader(
                    systemImage: KeychainClass(item)?.systemImage ?? "key",
                    color: InspectorTheme.secondaryText,
                    title: item.kind
                ) {
                    Label("Encrypted", systemImage: "lock.fill")
                        .font(InspectorFont.labelSmall)
                        .foregroundColor(InspectorTheme.color(for: .success))
                }
                InspectorDetailSection("Key") { InspectorDetailValue(text: item.key) }
                if item.valueSize != nil {
                    InspectorDetailSection("Value") {
                        if let value = item.value {
                            CopyButton(text: value, label: "Value")
                        }
                    } content: {
                        if let value = item.value {
                            InspectorDetailValue(text: value)
                        } else {
                            InspectorDetailValue(text: KeychainFormat.summary(item), color: InspectorTheme.secondaryText)
                        }
                    }
                }
                InspectorDetailSection("Attributes") {
                    ForEach(item.details, id: \.label) { row in
                        InspectorDetailItem(label: row.label, value: row.value)
                    }
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .navigationTitle(item.key)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum KeychainFormat {
    static func summary(_ item: WormaCeptorKeychainItem) -> String {
        // The value itself only shows on the detail screen, so a list screenshot doesn't leak secrets.
        if let value = item.value {
            return value.isEmpty ? "Empty" : "Text, \(ByteCountFormatter.string(fromByteCount: Int64(value.utf8.count), countStyle: .memory))"
        }
        if let size = item.valueSize?.int64Value {
            return "Binary, \(ByteCountFormatter.string(fromByteCount: size, countStyle: .memory))"
        }
        return "Attributes only"
    }

    static func date(_ epochMillis: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000).formatted(date: .abbreviated, time: .shortened)
    }
}

#if DEBUG
#Preview("Keychain") {
    NavigationView {
        KeychainContent(items: PreviewSamples.keychain)
    }
}

#Preview("Keychain, dark") {
    NavigationView {
        KeychainContent(items: PreviewSamples.keychain)
    }
    .preferredColorScheme(.dark)
}

#Preview("Keychain item") {
    NavigationView {
        KeychainItemScreen(item: PreviewSamples.keychain[0])
    }
}
#endif
