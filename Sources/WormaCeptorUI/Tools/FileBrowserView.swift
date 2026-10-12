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
            canDelete: model.path != nil,
            onDelete: { entry in Task { await model.delete(entry) } }
        )
        .overlay {
            if let error = model.error {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't open folder", message: error)
            } else if !model.isLoaded {
                ProgressView()
            } else if model.entries.isEmpty {
                EmptyStateView(systemImage: "folder", title: "Empty folder", message: "Nothing in here yet.")
            }
        }
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

struct FileFolderContent: View {
    let entries: [WormaCeptorFileEntry]
    let canDelete: Bool
    let onDelete: (WormaCeptorFileEntry) -> Void

    @State private var search = ""
    @State private var pendingDelete: WormaCeptorFileEntry?
    @State private var shared: SharedFile?

    private var visible: [WormaCeptorFileEntry] {
        search.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(visible, id: \.path) { entry in
            NavigationLink(destination: destination(for: entry)) {
                FileRowView(entry: entry)
            }
            .swipeActions(edge: .trailing) {
                if canDelete && entry.isWritable {
                    Button(role: .destructive) {
                        pendingDelete = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .contextMenu {
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
        }
        .listStyle(.plain)
        .searchable(text: $search, prompt: "Filter by name")
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
            ? Date(timeIntervalSince1970: TimeInterval(entry.lastModifiedMs) / 1000)
                .formatted(date: .abbreviated, time: .shortened)
            : nil
        let size = entry.isDirectory ? nil : ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file)
        return [size, modified].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                .foregroundColor(entry.isDirectory ? .accentColor : InspectorTheme.secondaryText)
                .frame(width: InspectorTheme.Spacing.lg + InspectorTheme.Spacing.sm)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.isDirectory ? "Folder \(entry.name)" : entry.name)
        .accessibilityValue(details)
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
        Group {
            if let content = model.content {
                FileContentView(content: content)
            } else if let error = model.error {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't read file", message: error)
            } else {
                ProgressView()
            }
        }
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

struct FileContentView: View {
    let content: WormaCeptorFileContent

    var body: some View {
        if content.isText {
            SelectableTextView(text: content.text)
        } else {
            EmptyStateView(
                systemImage: "doc",
                title: "No text preview",
                message: content.text + "\nShare the file to open it in another app."
            )
        }
    }
}

/// UITextView rather than Text: files go up to 1 MB, which a single SwiftUI Text lays out slowly.
private struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        // 13 pt is the footnote size at the default text size; the metrics scale it with Dynamic Type.
        view.font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: .monospacedSystemFont(ofSize: 13, weight: .regular))
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(
            top: InspectorTheme.Spacing.md,
            left: InspectorTheme.Spacing.sm,
            bottom: InspectorTheme.Spacing.md,
            right: InspectorTheme.Spacing.sm
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
    }
}

#Preview("File text") {
    NavigationView {
        FileContentView(content: PreviewSamples.fileContent)
            .navigationTitle("config.json")
    }
}
#endif
