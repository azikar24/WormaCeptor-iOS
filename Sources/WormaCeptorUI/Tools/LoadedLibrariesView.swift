import SwiftUI
import WormaCeptor

/// The images dyld loaded into the process, the same list `list_loaded_libraries` returns.
struct LoadedLibrariesScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorLoadedLibrary]()) {
        try await WormaCeptorLoadedLibraries.shared.libraries()
    }
    @State private var origin = LibraryOrigin.app
    @State private var isRefreshing = false

    var body: some View {
        LoadedLibrariesContent(libraries: model.value, isLoaded: model.isLoaded, error: model.error, origin: $origin)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InspectorRefreshButton(isRefreshing: isRefreshing) {
                        Task {
                            isRefreshing = true
                            await model.refresh()
                            isRefreshing = false
                        }
                    }
                }
            }
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

/// The dyld image kinds `WormaCeptorLoadedLibrary.type` reports, with Android's per-type icon and badge.
enum LibraryKind: String, CaseIterable {
    case executable = "EXECUTABLE"
    case framework = "FRAMEWORK"
    case dylib = "DYLIB"

    init?(_ library: WormaCeptorLoadedLibrary) {
        self.init(rawValue: library.type.uppercased())
    }

    var title: String {
        switch self {
        case .executable: return "Executable"
        case .framework: return "Frameworks"
        case .dylib: return "Dylibs"
        }
    }

    var badge: String {
        switch self {
        case .executable: return "EXEC"
        case .framework: return "FRAMEWORK"
        case .dylib: return "DYLIB"
        }
    }

    var systemImage: String {
        switch self {
        case .executable: return "app"
        case .framework: return "shippingbox"
        case .dylib: return "memorychip"
        }
    }
}

/// Android's loaded libraries screen: per-type counts, filter chips, one card per image.
struct LoadedLibrariesContent: View {
    let libraries: [WormaCeptorLoadedLibrary]
    var isLoaded = true
    var error: String?
    @Binding var origin: LibraryOrigin

    @State private var search = ""
    @State private var isSearching = false

    private var visible: [WormaCeptorLoadedLibrary] {
        libraries.filter { library in
            origin.includes(library) && (search.isEmpty || library.path.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Name or path", text: $search)
            summary
                .padding(.horizontal, InspectorTheme.Spacing.lg)
                .padding(.top, InspectorTheme.Spacing.sm)
            InspectorChipRow {
                ForEach(LibraryOrigin.allCases, id: \.self) { option in
                    InspectorChip(label: "\(option.rawValue) (\(count(option)))", isSelected: origin == option) {
                        origin = option
                    }
                }
            }
            .padding(.vertical, InspectorTheme.Spacing.xs)
            InspectorLoadable(isLoading: !isLoaded, isEmpty: error != nil || visible.isEmpty) {
                emptyState
            } content: {
                ScrollView {
                    LazyVStack(spacing: InspectorTheme.Spacing.sm) {
                        ForEach(visible, id: \.path) { library in
                            NavigationLink(destination: LoadedLibraryScreen(library: library)) {
                                LibraryCard(library: library)
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
        .navigationTitle("Loaded libraries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: InspectorTheme.Spacing.sm) {
            ForEach(LibraryKind.allCases, id: \.self) { kind in
                InspectorSummaryCard(count: libraries.filter { LibraryKind($0) == kind }.count, label: kind.title)
            }
            InspectorSummaryCard(count: libraries.count, label: "Total")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if let error {
            InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't list libraries", message: error)
        } else {
            InspectorEmptyState(
                systemImage: "puzzlepiece.extension",
                title: "No libraries found",
                message: search.isEmpty
                    ? "No \(origin.rawValue.lowercased()) libraries are loaded."
                    : "Nothing matches \"\(search)\" in a name or path."
            )
        }
    }

    private func count(_ origin: LibraryOrigin) -> Int {
        libraries.filter(origin.includes).count
    }
}

/// Android's `LibraryCard`: a tinted type tile, name, path, size and origin, the type badge on the right.
private struct LibraryCard: View {
    let library: WormaCeptorLoadedLibrary

    var body: some View {
        let kind = LibraryKind(library)
        HStack(spacing: InspectorTheme.Spacing.md) {
            InspectorIconWell(systemImage: kind?.systemImage ?? "puzzlepiece.extension", color: InspectorTheme.secondaryText)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(library.name)
                    .font(InspectorFont.titleSmall)
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                Text(library.path)
                    .font(InspectorFont.bodySmall)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.head)
                HStack(spacing: InspectorTheme.Spacing.sm) {
                    if let size = library.sizeBytes?.int64Value {
                        Text(InspectorFormat.bytes(size))
                            .font(InspectorFont.labelSmall.monospaced())
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                    if let version = library.version {
                        Text("v\(version)")
                            .font(InspectorFont.labelSmall.monospaced())
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                    if library.isSystemLibrary {
                        Text("System").font(InspectorFont.labelSmall).foregroundColor(InspectorTheme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            InspectorBadge(text: kind?.badge ?? library.type.uppercased(), color: InspectorTheme.secondaryText)
        }
        .inspectorCard(fill: InspectorTheme.surface)
        .accessibilityElement(children: .combine)
    }
}

/// One library, as Android's detail sheet: type header and a details block.
struct LoadedLibraryScreen: View {
    let library: WormaCeptorLoadedLibrary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                InspectorDetailHeader(
                    systemImage: LibraryKind(library)?.systemImage ?? "puzzlepiece.extension",
                    color: InspectorTheme.secondaryText,
                    title: library.name
                ) {
                    Text(library.type.capitalized)
                        .font(InspectorFont.bodySmall)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                InspectorDetailSection("Details") {
                    CopyButton(text: library.path, label: "Path")
                } content: {
                    ForEach(rows, id: \.label) { InspectorDetailItem(label: $0.label, value: $0.value) }
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rows: [WormaCeptorInfoRow] {
        [
            ("Path", library.path),
            ("Size", library.sizeBytes.map { InspectorFormat.bytes($0.int64Value) }),
            ("Load address", library.loadAddress),
            ("Version", library.version),
            ("Type", library.isSystemLibrary ? "System" : "App"),
        ].compactMap { label, value in value.map { WormaCeptorInfoRow(label: label, value: $0) } }
    }
}

#if DEBUG
#Preview("Loaded libraries") {
    NavigationView {
        LoadedLibrariesContent(libraries: PreviewSamples.libraries, origin: .constant(.all))
    }
}

#Preview("Loaded libraries, dark") {
    NavigationView {
        LoadedLibrariesContent(libraries: PreviewSamples.libraries, origin: .constant(.all))
    }
    .preferredColorScheme(.dark)
}

#Preview("Loaded library") {
    NavigationView {
        LoadedLibraryScreen(library: PreviewSamples.libraries[1])
    }
}
#endif
