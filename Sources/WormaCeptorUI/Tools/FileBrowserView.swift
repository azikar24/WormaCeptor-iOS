import SwiftUI
import UIKit
import WormaCeptor

/// The app's files: the sandbox (Documents, Library, tmp), the app bundle and named app groups, the same view
/// `browse_files` and `read_file` get.
struct FileBrowserScreen: View {
    var body: some View {
        FileFolderScreen(path: nil, title: "File browser")
    }
}

@MainActor
final class FileFolderModel: ObservableObject {
    @Published private(set) var entries: [WormaCeptorFileEntry] = []
    @Published private(set) var error: String?
    @Published private(set) var isLoaded = false
    @Published var deleteFailure: String?

    let path: String?

    init(path: String?) {
        self.path = path
    }

    func refresh() async {
        do {
            entries = try await WormaCeptorFiles.shared.list(path: path)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoaded = true
    }

    func delete(_ entry: WormaCeptorFileEntry) async {
        do {
            if try await WormaCeptorFiles.shared.delete(path: entry.path).boolValue {
                entries.removeAll { $0.path == entry.path }
            } else {
                deleteFailure = entry.isDirectory ? "Only empty folders can be deleted." : "The file can't be deleted."
            }
        } catch {
            deleteFailure = error.localizedDescription
        }
    }
}

/// One folder, or the roots when `path` is nil.
struct FileFolderScreen: View {
    let title: String
    @StateObject private var model: FileFolderModel

    init(path: String?, title: String) {
        self.title = title
        _model = StateObject(wrappedValue: FileFolderModel(path: path))
    }

    var body: some View {
        FileFolderContent(
            entries: model.entries,
            isLoaded: model.isLoaded,
            error: model.error,
            canDelete: model.path != nil,
            onDelete: { entry in Task { await model.delete(entry) } }
        )
        .alert(
            "Couldn't delete",
            isPresented: Binding(get: { model.deleteFailure != nil }, set: { if !$0 { model.deleteFailure = nil } }),
            presenting: model.deleteFailure
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
        .refreshable { await model.refresh() }
    }
}

/// Android's file list: flat rows with a type icon, name, size and date, under a collapsible search field.
struct FileFolderContent: View {
    let entries: [WormaCeptorFileEntry]
    var isLoaded = true
    var error: String?
    let canDelete: Bool
    let onDelete: (WormaCeptorFileEntry) -> Void

    @State private var search = ""
    @State private var isSearching = false
    @State private var pendingDelete: WormaCeptorFileEntry?
    @State private var shared: SharedFile?

    private var visible: [WormaCeptorFileEntry] {
        search.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Filter by name", text: $search)
            InspectorLoadable(isLoading: !isLoaded, isEmpty: error != nil || visible.isEmpty) {
                emptyState
            } content: {
                list
            }
        }
        .inspectorScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { entry in
            Button("Delete", role: .destructive) { onDelete(entry) }
        } message: { _ in
            Text("This can't be undone.")
        }
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
    }

    private var list: some View {
        List(visible, id: \.path) { entry in
            FileRowView(entry: entry)
                // A hidden link keeps the whole row tappable without List's disclosure chevron, as on Android.
                .background(NavigationLink(destination: destination(for: entry)) { EmptyView() }.opacity(0))
                .inspectorFlatRow()
                .swipeActions(edge: .trailing) {
                    if canDelete && entry.isWritable {
                        Button(role: .destructive) {
                            pendingDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .contextMenu { contextMenu(for: entry) }
        }
        .inspectorPlainList()
    }

    @ViewBuilder
    private func contextMenu(for entry: WormaCeptorFileEntry) -> some View {
        if !entry.isDirectory {
            Button {
                shared = SharedFile(path: entry.path)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        Button {
            UIPasteboard.general.string = entry.path
        } label: {
            Label("Copy path", systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let error {
            InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't open folder", message: error)
        } else if !search.isEmpty {
            InspectorEmptyState(systemImage: "magnifyingglass", title: "No matches", message: "Nothing matches \"\(search)\".")
        } else {
            InspectorEmptyState(systemImage: "folder", title: "No files found", message: "Nothing in here yet.")
        }
    }

    @ViewBuilder
    private func destination(for entry: WormaCeptorFileEntry) -> some View {
        if entry.isDirectory {
            FileFolderScreen(path: entry.path, title: entry.name)
        } else {
            FileViewerScreen(entry: entry)
        }
    }
}

struct FileRowView: View {
    let entry: WormaCeptorFileEntry

    private var details: String {
        let modified = entry.lastModifiedMs > 0
            ? Date(timeIntervalSince1970: TimeInterval(entry.lastModifiedMs) / 1000).formatted(date: .abbreviated, time: .omitted)
            : nil
        let size = entry.isDirectory ? nil : ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file)
        return [size, modified].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        InspectorListRow(headline: entry.name, supporting: details) {
            InspectorRowIcon(systemImage: FileAppearance.icon(for: entry), color: InspectorTheme.secondaryText)
        }
        .accessibilityLabel(entry.isDirectory ? "Folder \(entry.name)" : entry.name)
        .accessibilityValue(details)
        .accessibilityAddTraits(.isButton)
    }
}

/// Android's `resolveFileIcon`: folders, images, text, databases, everything else.
enum FileAppearance {
    private static let images: Set = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "heic"]
    private static let texts: Set = ["txt", "log", "json", "xml", "html", "css", "js", "md", "plist", "swift", "csv"]
    private static let databases: Set = ["db", "sqlite", "sqlite3", "db3"]

    static func icon(for entry: WormaCeptorFileEntry) -> String {
        if entry.isDirectory { return "folder.fill" }
        let ext = (entry.name as NSString).pathExtension.lowercased()
        if images.contains(ext) { return "photo" }
        if texts.contains(ext) { return "doc.text" }
        if databases.contains(ext) { return "cylinder.split.1x2" }
        return "doc"
    }
}

@MainActor
final class FileViewerModel: ObservableObject {
    @Published private(set) var content: WormaCeptorFileContent?
    @Published private(set) var error: String?

    func load(_ path: String) async {
        do {
            content = try await WormaCeptorFiles.shared.read(path: path)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A file's text, or a summary for binaries, images, PDFs and files over 1 MB. Share it from the toolbar.
struct FileViewerScreen: View {
    let entry: WormaCeptorFileEntry
    @StateObject private var model = FileViewerModel()
    @State private var isSharing = false

    var body: some View {
        ZStack {
            if let content = model.content {
                FileContentView(name: entry.name, content: content).transition(.opacity)
            } else if let error = model.error {
                InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't read file", message: error)
                    .transition(.opacity)
            } else {
                ProgressView().transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: model.content != nil)
        .inspectorScreen()
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSharing = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(url: URL(fileURLWithPath: entry.path))
        }
        .task { await model.load(entry.path) }
    }
}

/// Android's text viewer: a "N lines" header (with JSON validity for JSON files) over the monospaced text.
struct FileContentView: View {
    let name: String
    let content: WormaCeptorFileContent

    private var isJSON: Bool {
        content.mimeType?.contains("json") == true || (name as NSString).pathExtension.lowercased() == "json"
    }

    var body: some View {
        if content.isText {
            VStack(spacing: 0) {
                header
                InspectorDivider()
                SelectableTextView(text: content.text)
            }
        } else {
            InspectorEmptyState(
                systemImage: "doc",
                title: "No text preview",
                message: content.text + "\nShare the file to open it in another app."
            )
        }
    }

    private var header: some View {
        let lines = content.text.utf8.lazy.filter { $0 == 10 }.count + 1
        return HStack(spacing: InspectorTheme.Spacing.xs) {
            Text(lines == 1 ? "1 line" : "\(lines) lines")
                .font(InspectorFont.titleMedium)
                .foregroundColor(InspectorTheme.textPrimary)
            Spacer(minLength: InspectorTheme.Spacing.sm)
            if isJSON {
                let valid = (try? JSONSerialization.jsonObject(with: Data(content.text.utf8), options: .fragmentsAllowed)) != nil
                let color = InspectorTheme.color(for: valid ? .success : .warning)
                Image(systemName: valid ? "checkmark" : "exclamationmark.triangle")
                    .font(.system(size: InspectorTheme.IconSize.sm, weight: .semibold))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Text(valid ? "Valid JSON" : "Invalid JSON")
                    .font(InspectorFont.labelSmall)
                    .foregroundColor(color)
            }
        }
        .padding(InspectorTheme.Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// UITextView rather than Text: files go up to 1 MB, which a single SwiftUI Text lays out slowly.
private struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        // InspectorTheme.background (#FFFFFF / #0A0A0A), built here so it follows appearance changes.
        view.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.04, alpha: 1) : .white }
        view.textColor = .label
        // 12 pt is the caption size at the default text size; the metrics scale it with Dynamic Type.
        view.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .monospacedSystemFont(ofSize: 12, weight: .regular))
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(
            top: InspectorTheme.Spacing.lg,
            left: InspectorTheme.Spacing.md,
            bottom: InspectorTheme.Spacing.lg,
            right: InspectorTheme.Spacing.md
        )
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text { view.text = text }
    }
}

private struct SharedFile: Identifiable {
    let path: String
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview("Files") {
    NavigationView {
        FileFolderContent(entries: PreviewSamples.fileEntries, canDelete: true, onDelete: { _ in })
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Files, dark") {
    NavigationView {
        FileFolderContent(entries: PreviewSamples.fileEntries, canDelete: true, onDelete: { _ in })
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}

#Preview("File text") {
    NavigationView {
        FileContentView(name: "config.json", content: PreviewSamples.fileContent)
            .navigationTitle("config.json")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
