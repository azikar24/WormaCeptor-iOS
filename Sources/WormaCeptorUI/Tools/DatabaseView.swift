import SwiftUI
import UIKit
import WormaCeptor

/// The app's SQLite databases, the same ones `list_databases` returns. Every connection is read-only.
struct DatabaseListScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorDatabase]()) {
        try await WormaCeptorDatabases.shared.databases()
    }
    @State private var search = ""

    var body: some View {
        DatabaseListContent(databases: model.value, search: search)
            .overlay {
                if let error = model.error {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't list databases", message: error)
                } else if !model.isLoaded {
                    ProgressView()
                } else if model.value.isEmpty {
                    EmptyStateView(
                        systemImage: "cylinder.split.1x2",
                        title: "No databases found",
                        message: "SQLite files in Documents, Library, tmp and added app groups show up here."
                    )
                }
            }
            .searchable(text: $search, prompt: "Filter by name")
            .navigationTitle("SQLite browser")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }
}

struct DatabaseListContent: View {
    let databases: [WormaCeptorDatabase]
    var search = ""

    private var visible: [WormaCeptorDatabase] {
        search.isEmpty ? databases : databases.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(visible, id: \.path) { database in
            NavigationLink(destination: DatabaseTablesScreen(database: database)) {
                DatabaseRow(database: database)
            }
            .contextMenu {
                Button {
                    UIPasteboard.general.string = database.path
                } label: {
                    Label("Copy path", systemImage: "doc.on.doc")
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct DatabaseRow: View {
    let database: WormaCeptorDatabase

    private var details: String {
        let tables = database.tableCount == 1 ? "1 table" : "\(database.tableCount) tables"
        return "\(tables) · \(InspectorFormat.bytes(database.sizeBytes))"
    }

    var body: some View {
        HStack(spacing: InspectorTheme.Spacing.md) {
            Image(systemName: "cylinder.split.1x2")
                .foregroundColor(.accentColor)
                .frame(width: InspectorTheme.Spacing.lg + InspectorTheme.Spacing.sm)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                Text(database.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(details)
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                Text(database.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(InspectorTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

/// A database's tables with their row and column counts.
struct DatabaseTablesScreen: View {
    let database: WormaCeptorDatabase
    @StateObject private var model: SnapshotModel<[WormaCeptorTable]>
    @State private var search = ""

    init(database: WormaCeptorDatabase) {
        self.database = database
        _model = StateObject(wrappedValue: SnapshotModel(initial: []) {
            try await WormaCeptorDatabases.shared.tables(path: database.path)
        })
    }

    var body: some View {
        DatabaseTablesContent(database: database, tables: model.value, search: search)
            .overlay {
                if let error = model.error {
                    EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't read tables", message: error)
                } else if !model.isLoaded {
                    ProgressView()
                } else if model.value.isEmpty {
                    EmptyStateView(
                        systemImage: "tablecells",
                        title: "No tables found",
                        message: "The file is empty, encrypted or can't be opened."
                    )
                }
            }
            .searchable(text: $search, prompt: "Filter tables")
            .navigationTitle(database.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: QueryScreen(database: database, tables: model.value.map(\.name))) {
                        Label("SQL query", systemImage: "terminal")
                    }
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
            }
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }
}

struct DatabaseTablesContent: View {
    let database: WormaCeptorDatabase
    let tables: [WormaCeptorTable]
    var search = ""

    private var visible: [WormaCeptorTable] {
        search.isEmpty ? tables : tables.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List(visible, id: \.name) { table in
            NavigationLink(destination: TableRowsScreen(database: database, table: table.name)) {
                VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                    Text(table.name)
                        .lineLimit(1)
                    Text("\(table.rowCount) rows · \(table.columnCount) columns")
                        .font(.caption)
                        .foregroundColor(InspectorTheme.secondaryText)
                }
                .frame(minHeight: InspectorTheme.minTouchTarget)
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.plain)
    }
}

@MainActor
final class TableRowsModel: ObservableObject {
    static let pageSize: Int32 = 100

    @Published private(set) var result: WormaCeptorQueryResult?
    @Published private(set) var columns: [WormaCeptorColumn] = []
    @Published private(set) var page: Int32 = 0
    @Published private(set) var error: String?

    let path: String
    let table: String

    init(path: String, table: String) {
        self.path = path
        self.table = table
    }

    /// Like Android: a full page means there may be another.
    var hasNextPage: Bool { result?.rowCount == Self.pageSize }

    func load(page: Int32) async {
        do {
            if columns.isEmpty {
                columns = try await WormaCeptorDatabases.shared.columns(path: path, table: table)
            }
            result = try await WormaCeptorDatabases.shared.rows(
                path: path, table: table, limit: Self.pageSize, offset: page * Self.pageSize
            )
            self.page = page
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A table's rows, 100 per page, with its schema a tap away.
struct TableRowsScreen: View {
    let table: String
    @StateObject private var model: TableRowsModel
    @State private var showsSchema = false

    init(database: WormaCeptorDatabase, table: String) {
        self.table = table
        _model = StateObject(wrappedValue: TableRowsModel(path: database.path, table: table))
    }

    var body: some View {
        Group {
            if let result = model.result {
                QueryResultView(result: result)
            } else if let error = model.error {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Couldn't read rows", message: error)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(table)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsSchema = true
                } label: {
                    Label("Schema", systemImage: "list.bullet.rectangle")
                }
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Task { await model.load(page: model.page - 1) }
                } label: {
                    Label("Previous page", systemImage: "chevron.left")
                }
                .disabled(model.page == 0)
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                Spacer()
                Text("Page \(model.page + 1)")
                    .font(.footnote)
                Spacer()
                Button {
                    Task { await model.load(page: model.page + 1) }
                } label: {
                    Label("Next page", systemImage: "chevron.right")
                }
                .disabled(!model.hasNextPage)
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
        }
        .sheet(isPresented: $showsSchema) {
            NavigationView {
                TableSchemaView(columns: model.columns)
                    .navigationTitle(table)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsSchema = false }
                        }
                    }
            }
        }
        .task { await model.load(page: model.page) }
    }
}

struct TableSchemaView: View {
    let columns: [WormaCeptorColumn]

    var body: some View {
        List(columns, id: \.name) { column in
            HStack(spacing: InspectorTheme.Spacing.sm) {
                Text(column.name)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Text(column.type)
                    .font(.caption)
                    .foregroundColor(InspectorTheme.secondaryText)
                if column.isPrimaryKey {
                    InspectorBadge(text: "PK", color: InspectorTheme.color(for: .redirect))
                }
                if column.isNullable {
                    InspectorBadge(text: "NULL", color: InspectorTheme.secondaryText)
                }
            }
            .frame(minHeight: InspectorTheme.minTouchTarget)
            .accessibilityElement(children: .combine)
        }
        .listStyle(.plain)
    }
}

/// Free SQL against one database, on a read-only connection: writes come back as errors.
struct QueryScreen: View {
    let database: WormaCeptorDatabase
    let tables: [String]

    @State private var sql = ""
    @State private var result: WormaCeptorQueryResult?
    @State private var failure: String?
    @State private var isRunning = false
    @State private var history: [String] = []
    @FocusState private var editorFocused: Bool

    private static let historyLimit = 20

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $sql)
                .font(.system(.callout, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($editorFocused)
                .frame(minHeight: InspectorTheme.minTouchTarget * 2, maxHeight: InspectorTheme.minTouchTarget * 3)
                .padding(.horizontal, InspectorTheme.Spacing.sm)
                .overlay(alignment: .topLeading) {
                    if sql.isEmpty {
                        Text("Enter SQL query…")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundColor(InspectorTheme.secondaryText)
                            .padding(.horizontal, InspectorTheme.Spacing.md)
                            .padding(.vertical, InspectorTheme.Spacing.sm)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel("SQL query")
            Divider()
            QueryOutcomeView(result: result, failure: failure, history: history, onPickHistory: { sql = $0 })
        }
        .navigationTitle("SQL query")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                templates
                Button {
                    Task { await run() }
                } label: {
                    Label("Execute", systemImage: "play.fill")
                }
                .disabled(isRunning || sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
            }
        }
    }

    private var templates: some View {
        Menu {
            ForEach(tables, id: \.self) { table in
                let name = "\"" + table.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                Menu(table) {
                    Button("Select 10 rows") { sql = "SELECT * FROM \(name) LIMIT 10" }
                    Button("Count rows") { sql = "SELECT COUNT(*) FROM \(name)" }
                    Button("Schema") { sql = "PRAGMA table_info(\(name))" }
                }
            }
        } label: {
            Label("Templates", systemImage: "text.badge.plus")
        }
        .disabled(tables.isEmpty)
        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
    }

    private func run() async {
        let query = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        editorFocused = false
        isRunning = true
        defer { isRunning = false }
        do {
            let outcome = try await WormaCeptorDatabases.shared.execute(path: database.path, sql: query)
            result = outcome
            failure = nil
            if outcome.error == nil && !history.contains(query) {
                history = Array((history + [query]).suffix(Self.historyLimit))
            }
        } catch {
            result = nil
            failure = error.localizedDescription
        }
    }
}

private struct QueryOutcomeView: View {
    let result: WormaCeptorQueryResult?
    let failure: String?
    let history: [String]
    let onPickHistory: (String) -> Void

    var body: some View {
        if let failure {
            EmptyStateView(systemImage: "exclamationmark.triangle", title: "Query failed", message: failure)
                .frame(maxHeight: .infinity)
        } else if let result {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let error = result.error {
                        Text("Error: \(error)")
                            .foregroundColor(InspectorTheme.color(for: .error))
                    } else {
                        Text(result.rowCount == 1 ? "1 row returned" : "\(result.rowCount) rows returned")
                            .foregroundColor(InspectorTheme.secondaryText)
                    }
                }
                .font(.footnote)
                .textSelection(.enabled)
                .padding(InspectorTheme.Spacing.md)
                if result.error == nil {
                    QueryResultView(result: result)
                } else {
                    Spacer()
                }
            }
        } else if history.isEmpty {
            EmptyStateView(
                systemImage: "terminal",
                title: "Enter a SQL query and press Execute",
                message: "The database is opened read-only, so writes return an error."
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                Section("Query history") {
                    ForEach(history.reversed(), id: \.self) { query in
                        Button { onPickHistory(query) } label: {
                            Text(query)
                                .font(.system(.footnote, design: .monospaced))
                                .lineLimit(2)
                                .frame(minHeight: InspectorTheme.minTouchTarget, alignment: .leading)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

/// Rows in a grid that scrolls both ways, the header pinned. Tap a row to see every value in full.
struct QueryResultView: View {
    let result: WormaCeptorQueryResult

    @State private var selectedRow: SelectedRow?

    private static let columnWidth: CGFloat = 160

    var body: some View {
        if result.rowCount == 0 {
            EmptyStateView(systemImage: "tablecells", title: "No data", message: "The query returned no rows.")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(0..<Int(result.rowCount), id: \.self) { row in
                            Button {
                                selectedRow = SelectedRow(index: row)
                            } label: {
                                rowView(row)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Row \(row + 1)")
                            .accessibilityHint("Shows every value")
                            Divider()
                        }
                    } header: {
                        header
                    }
                }
            }
            .sheet(item: $selectedRow) { selected in
                NavigationView {
                    RowDetailView(result: result, row: selected.index)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(Array(result.columns.enumerated()), id: \.offset) { _, column in
                Text(column)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func rowView(_ row: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<result.columns.count, id: \.self) { column in
                CellText(value: result.value(row: Int32(row), column: Int32(column)))
                    .lineLimit(1)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .contentShape(Rectangle())
    }
}

private struct SelectedRow: Identifiable {
    let index: Int
    var id: Int { index }
}

/// A value, or NULL set apart so it can't be mistaken for the text "NULL".
private struct CellText: View {
    let value: String?

    var body: some View {
        if let value {
            Text(value)
                .font(.system(.caption, design: .monospaced))
        } else {
            Text("NULL")
                .font(.system(.caption, design: .monospaced).italic())
                .foregroundColor(InspectorTheme.secondaryText)
        }
    }
}

private struct RowDetailView: View {
    let result: WormaCeptorQueryResult
    let row: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Array(result.columns.enumerated()), id: \.offset) { index, column in
                let value = result.value(row: Int32(row), column: Int32(index))
                Section {
                    CellText(value: value)
                        .textSelection(.enabled)
                } header: {
                    HStack {
                        Text(column)
                        Spacer()
                        if let value {
                            CopyButton(text: value, label: column)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Row \(row + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#if DEBUG
#Preview("Databases") {
    NavigationView {
        DatabaseListContent(databases: PreviewSamples.databases)
            .navigationTitle("SQLite browser")
    }
}

#Preview("Tables") {
    NavigationView {
        DatabaseTablesContent(database: PreviewSamples.databases[0], tables: PreviewSamples.tables)
            .navigationTitle("app.sqlite")
    }
}

#Preview("Rows") {
    NavigationView {
        QueryResultView(result: PreviewSamples.queryResult)
            .navigationTitle("ZORDER")
    }
}

#Preview("Schema") {
    NavigationView {
        TableSchemaView(columns: PreviewSamples.columns)
    }
}
#endif
