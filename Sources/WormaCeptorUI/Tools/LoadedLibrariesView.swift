import SwiftUI
import WormaCeptor

/// The images dyld loaded into the process, the same list `list_loaded_libraries` returns.
struct LoadedLibrariesScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorLoadedLibrary]()) {
        try await WormaCeptorLoadedLibraries.shared.libraries()
    }
    @State private var search = ""
    @State private var origin = LibraryOrigin.app

    var body: some View {
        LoadedLibrariesContent(libraries: model.value, search: search, origin: $origin)
            .overlay {
                if let error = model.error {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't list libraries", message: error)
                } else if !model.isLoaded {
                    ProgressView()
                }
            }
            .searchable(text: $search, prompt: "Name or path")
            .navigationTitle("Loaded libraries")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }
}

enum LibraryOrigin: String, CaseIterable {
    case app = "App"
    case system = "System"
    case all = "All"

    func includes(_ library: WormaCeptorLoadedLibrary) -> Bool {
        switch self {
        case .app: return !library.isSystemLibrary
        case .system: return library.isSystemLibrary
        case .all: return true
        }
    }
}

struct LoadedLibrariesContent: View {
    let libraries: [WormaCeptorLoadedLibrary]
    var search = ""
    @Binding var origin: LibraryOrigin

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $origin) {
                    ForEach(LibraryOrigin.allCases, id: \.self) { origin in
                        Text("\(origin.rawValue) (\(count(origin)))").tag(origin)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(visible, id: \.path) { library in
                    NavigationLink(destination: LoadedLibraryScreen(library: library)) {
                        LoadedLibraryRow(library: library)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if visible.isEmpty && !libraries.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: "No matches",
                    message: search.isEmpty
                        ? "No \(origin.rawValue.lowercased()) libraries are loaded."
                        : "Nothing matches \"\(search)\" in a name or path."
                )
            }
        }
    }

    private var visible: [WormaCeptorLoadedLibrary] {
        libraries.filter { library in
            origin.includes(library)
                && (search.isEmpty || library.path.localizedCaseInsensitiveContains(search))
        }
    }

    private func count(_ origin: LibraryOrigin) -> Int {
        libraries.filter(origin.includes).count
    }
}

private struct LoadedLibraryRow: View {
    let library: WormaCeptorLoadedLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(library.name)
                    .font(.callout)
                    .lineLimit(1)
                if let version = library.version {
                    Text(version)
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
            Text(library.path)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(InspectorTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// One library's details.
struct LoadedLibraryScreen: View {
    let library: WormaCeptorLoadedLibrary

    var body: some View {
        List {
            Section {
                ForEach(rows, id: \.label) { InfoRowView(row: $0) }
            }
            Section {
                Text(library.path)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                HStack {
                    Text("Path")
                    Spacer()
                    CopyButton(text: library.path, label: "Path")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rows: [WormaCeptorInfoRow] {
        [
            ("Type", library.type.capitalized),
            ("Origin", library.isSystemLibrary ? "System" : "App"),
            ("Version", library.version),
            ("Size", library.sizeBytes.map { InspectorFormat.bytes($0.int64Value) }),
            ("Load address", library.loadAddress),
        ].compactMap { label, value in value.map { WormaCeptorInfoRow(label: label, value: $0) } }
    }
}

#if DEBUG
#Preview("Loaded libraries") {
    NavigationView {
        LoadedLibrariesContent(libraries: PreviewSamples.libraries, origin: .constant(.all))
            .navigationTitle("Loaded libraries")
    }
}

#Preview("Loaded library") {
    NavigationView {
        LoadedLibraryScreen(library: PreviewSamples.libraries[1])
    }
}
#endif
