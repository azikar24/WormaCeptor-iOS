import SwiftUI
import WormaCeptor

/// The app's Keychain items. Values stay on the device: `browse_secure_storage` gets keys and metadata only.
struct KeychainScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorKeychainItem]()) {
        try await WormaCeptorKeychain.shared.items()
    }
    @State private var search = ""

    var body: some View {
        KeychainContent(items: filtered, search: search)
            .overlay {
                if let error = model.error {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't read the Keychain", message: error)
                } else if !model.isLoaded {
                    ProgressView()
                }
            }
            .searchable(text: $search, prompt: "Key or value")
            .navigationTitle("Keychain")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }

    private var filtered: [WormaCeptorKeychainItem] {
        guard !search.isEmpty else { return model.value }
        return model.value.filter {
            $0.key.localizedCaseInsensitiveContains(search) || ($0.value?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }
}

struct KeychainContent: View {
    let items: [WormaCeptorKeychainItem]
    var search = ""

    var body: some View {
        List {
            ForEach(kinds, id: \.self) { kind in
                Section(kind) {
                    ForEach(Array(items.filter { $0.kind == kind }.enumerated()), id: \.offset) { _, item in
                        NavigationLink(destination: KeychainItemScreen(item: item)) {
                            KeychainRowView(item: item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if items.isEmpty {
                EmptyStateView(
                    systemImage: "key",
                    title: search.isEmpty ? "No Keychain items" : "No matches",
                    message: search.isEmpty
                        ? "Passwords, keys and certificates the app stores in its Keychain show up here."
                        : "Nothing matches \"\(search)\" in a key or value."
                )
            }
        }
    }

    private var kinds: [String] {
        items.reduce(into: [String]()) { kinds, item in
            if !kinds.contains(item.kind) { kinds.append(item.kind) }
        }
    }
}

private struct KeychainRowView: View {
    let item: WormaCeptorKeychainItem

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            Text(item.key)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
            Text(KeychainFormat.summary(item))
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// One item: its value, if it is text, and every attribute.
struct KeychainItemScreen: View {
    let item: WormaCeptorKeychainItem

    var body: some View {
        List {
            if item.valueSize != nil {
                Section {
                    if let value = item.value {
                        Text(value)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    } else {
                        Text(KeychainFormat.summary(item))
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                } header: {
                    HStack {
                        Text("Value")
                        Spacer()
                        if let value = item.value {
                            CopyButton(text: value, label: "Value")
                        }
                    }
                }
            }
            Section("Attributes") {
                ForEach(item.details, id: \.label) { row in
                    InfoRowView(row: row)
                }
            }
        }
        .listStyle(.insetGrouped)
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
}

#if DEBUG
#Preview("Keychain") {
    NavigationView {
        KeychainContent(items: PreviewSamples.keychain)
            .navigationTitle("Keychain")
    }
}

#Preview("Keychain item") {
    NavigationView {
        KeychainItemScreen(item: PreviewSamples.keychain[0])
    }
}
#endif
