import SwiftUI
import UIKit
import WormaCeptor

/// The app's SQLite databases, the same ones `list_databases` returns. Every connection is read-only.
struct DatabaseListScreen: View {
    @StateObject private var model = SnapshotModel(initial: [WormaCeptorDatabase]()) {
        try await WormaCeptorDatabases.shared.databases()
    }
    @State private var isRefreshing = false

    var body: some View {
        DatabaseListContent(databases: model.value, isLoaded: model.isLoaded, error: model.error)
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

/// Android's database list: flat rows with an accent database icon, the table count and the file size.
struct DatabaseListContent: View {
    let databases: [WormaCeptorDatabase]
    var isLoaded = true
    var error: String?

    @State private var search = ""
    @State private var isSearching = false

    private var visible: [WormaCeptorDatabase] {
        search.isEmpty ? databases : databases.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Filter by name", text: $search)
            InspectorLoadable(isLoading: !isLoaded, isEmpty: error != nil || visible.isEmpty) {
                emptyState
            } content: {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible, id: \.path) { database in
                            NavigationLink(destination: DatabaseTablesScreen(database: database)) {
                                DatabaseRow(database: database)
                            }
                            .buttonStyle(InspectorPressStyle())
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = database.path
                                } label: {
                                    Label("Copy path", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                }
            }
        }
        .inspectorScreen()
        .navigationTitle("SQLite browser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if let error {
            InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't list databases", message: error)
        } else if !search.isEmpty {
            InspectorEmptyState(systemImage: "magnifyingglass", title: "No matches", message: "Nothing matches \"\(search)\".")
        } else {
            InspectorEmptyState(
                systemImage: "cylinder.split.1x2",
                title: "No databases found",
                message: "SQLite files in Documents, Library, tmp and added app groups show up here."
            )
        }
    }
}

private struct DatabaseRow: View {
    let database: WormaCeptorDatabase

    var body: some View {
        let tables = database.tableCount == 1 ? "1 table" : "\(database.tableCount) tables"
        InspectorListRow(headline: database.name, supporting: "\(tables) · \(InspectorFormat.bytes(database.sizeBytes))") {
            InspectorRowIcon(systemImage: "cylinder.split.1x2")
        }
    }
}

/// A database's tables with their row and column counts.
struct DatabaseTablesScreen: View {
    let database: WormaCeptorDatabase
    @StateObject private var model: SnapshotModel<[WormaCeptorTable]>

    init(database: WormaCeptorDatabase) {
        self.database = database
        _model = StateObject(wrappedValue: SnapshotModel(initial: []) {
            try await WormaCeptorDatabases.shared.tables(path: database.path)
        })
    }

    var body: some View {
        DatabaseTablesContent(database: database, tables: model.value, isLoaded: model.isLoaded, error: model.error)
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
    }
}

/// Android's table list: the database name with a table count in the top bar, search and SQL query actions.
struct DatabaseTablesContent: View {
    let database: WormaCeptorDatabase
    let tables: [WormaCeptorTable]
    var isLoaded = true
    var error: String?

    @State private var search = ""
    @State private var isSearching = false

    private var visible: [WormaCeptorTable] {
        search.isEmpty ? tables : tables.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorCollapsibleSearch(isActive: isSearching, placeholder: "Filter tables", text: $search)
            InspectorLoadable(isLoading: !isLoaded, isEmpty: error != nil || visible.isEmpty) {
                if let error {
                    InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't read tables", message: error)
                } else {
                    InspectorEmptyState(
                        systemImage: "tablecells",
                        title: tables.isEmpty ? "No tables found" : "No matches",
                        message: tables.isEmpty ? "The file is empty, encrypted or can't be opened." : "Try a different search."
                    )
                }
            } content: {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visible, id: \.name) { table in
                            NavigationLink(destination: TableRowsScreen(database: database, table: table.name)) {
                                InspectorListRow(
                                    headline: table.name,
                                    supporting: "\(table.rowCount) rows · \(table.columnCount) columns"
                                ) {
                                    InspectorRowIcon(systemImage: "tablecells")
                                }
                            }
                            .buttonStyle(InspectorPressStyle())
                        }
                    }
                }
            }
        }
        .inspectorScreen()
        .navigationTitle(database.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                InspectorNavigationTitle(title: database.name, subtitle: tables.count == 1 ? "1 table" : "\(tables.count) tables")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                InspectorSearchButton(isActive: $isSearching, text: $search)
                NavigationLink(destination: QueryScreen(database: database, tables: tables.map(\.name))) {
                    Image(systemName: "terminal")
                        .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .accessibilityLabel("SQL query")
            }
        }
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

/// A table's rows, 100 per page. As on Android, the top bar pages and switches to the schema in place.
struct TableRowsScreen: View {
    let table: String
    @StateObject private var model: TableRowsModel
    @State private var showsSchema = false

    init(database: WormaCeptorDatabase, table: String) {
        self.table = table
        _model = StateObject(wrappedValue: TableRowsModel(path: database.path, table: table))
    }

    var body: some View {
        ZStack {
            if let error = model.error {
                InspectorEmptyState(systemImage: "exclamationmark.triangle", title: "Couldn't read rows", message: error)
            } else if showsSchema {
                TableSchemaView(columns: model.columns).transition(.opacity)
            } else if let result = model.result {
                QueryResultView(result: result).transition(.opacity)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inspectorAnimation(InspectorMotion.standard(InspectorMotion.normal), value: showsSchema)
        .inspectorScreen()
        .navigationTitle(table)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                InspectorNavigationTitle(title: table, subtitle: "Page \(model.page + 1)")
            }
            ToolbarItemGroup(placement: .primaryAction) { toolbarActions }
        }
        .task { await model.load(page: model.page) }
    }

    @ViewBuilder private var toolbarActions: some View {
        Button {
            withInspectorAnimation(InspectorMotion.standard(InspectorMotion.normal)) { showsSchema.toggle() }
        } label: {
            Image(systemName: showsSchema ? "info.circle.fill" : "info.circle")
                .foregroundColor(showsSchema ? InspectorTheme.brand : InspectorTheme.textPrimary)
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .accessibilityLabel("Schema")
        .accessibilityAddTraits(showsSchema ? .isSelected : [])
        Button {
            Task { await model.load(page: model.page - 1) }
        } label: {
            Image(systemName: "chevron.left")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .disabled(model.page == 0)
        .accessibilityLabel("Previous page")
        Button {
            Task { await model.load(page: model.page + 1) }
        } label: {
            Image(systemName: "chevron.right")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .disabled(!model.hasNextPage)
        .accessibilityLabel("Next page")
    }
}

/// Android's schema list: column name with an amber PK mark, its type in the type color, NULLABLE.
struct TableSchemaView: View {
    let columns: [WormaCeptorColumn]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(columns, id: \.name) { column in
                    VStack(alignment: .leading, spacing: InspectorTheme.Spacing.xxs) {
                        HStack(spacing: InspectorTheme.Spacing.xs) {
                            Text(column.name)
                                .font(InspectorFont.listHeadline)
                                .foregroundColor(InspectorTheme.textPrimary)
                            if column.isPrimaryKey {
                                Text("PK").font(InspectorFont.badge).foregroundColor(SQLiteColors.primaryKey)
                            }
                        }
                        HStack(spacing: InspectorTheme.Spacing.sm) {
                            Text(column.type.isEmpty ? "ANY" : column.type)
                                .font(InspectorFont.bodySmall)
                                .foregroundColor(SQLiteColors.color(forType: column.type))
                            if column.isNullable {
                                Text("NULLABLE").font(InspectorFont.labelSmall).foregroundColor(InspectorTheme.secondaryText)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: InspectorTheme.minTouchTarget, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.lg)
                    .padding(.vertical, InspectorTheme.Spacing.md)
                    .overlay(alignment: .bottom) { InspectorDivider() }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Android's `ToolColors.Database`, with darker light shades so text reaches 4.5:1.
enum SQLiteColors {
    static let integer = InspectorTheme.dynamic(light: 0x0277BD, dark: 0x4FC3F7)
    static let real = InspectorTheme.dynamic(light: 0x2E7D32, dark: 0x81C784)
    static let text = InspectorTheme.dynamic(light: 0xC2410C, dark: 0xFFB74D)
    static let blob = InspectorTheme.dynamic(light: 0x7B1FA2, dark: 0xBA68C8)
    static let null = InspectorTheme.dynamic(light: 0x546E7A, dark: 0x90A4AE)
    static let primaryKey = InspectorTheme.dynamic(light: 0xB45309, dark: 0xFFD54F)

    static func color(forType type: String) -> Color {
        switch type.uppercased() {
        case "INTEGER", "INT", "BIGINT", "SMALLINT", "TINYINT": return integer
        case "REAL", "FLOAT", "DOUBLE", "DECIMAL", "NUMERIC": return real
        case "BLOB", "BINARY", "VARBINARY": return blob
        default: return text
        }
    }
}

#if DEBUG
#Preview("Databases") {
    NavigationView {
        DatabaseListContent(databases: PreviewSamples.databases)
    }
}

#Preview("Databases, dark") {
    NavigationView {
        DatabaseListContent(databases: PreviewSamples.databases)
    }
    .preferredColorScheme(.dark)
}

#Preview("Tables") {
    NavigationView {
        DatabaseTablesContent(database: PreviewSamples.databases[0], tables: PreviewSamples.tables)
    }
}

#Preview("Schema") {
    NavigationView {
        TableSchemaView(columns: PreviewSamples.columns)
    }
}
#endif
