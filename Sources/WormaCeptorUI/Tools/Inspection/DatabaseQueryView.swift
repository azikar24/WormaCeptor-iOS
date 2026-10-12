import SwiftUI
import WormaCeptor

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
            editor
            InspectorDivider()
            QueryOutcomeView(
                databaseName: database.name,
                result: result,
                failure: failure,
                history: history,
                onPickHistory: { sql = $0 }
            )
            .frame(maxHeight: .infinity)
        }
        .inspectorScreen()
        .navigationTitle("SQL query")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                templates
                if !sql.isEmpty {
                    Button {
                        sql = ""
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                    }
                    .accessibilityLabel("Clear query")
                }
                Button {
                    Task { await run() }
                } label: {
                    Group {
                        if isRunning {
                            ProgressView()
                        } else {
                            Image(systemName: "play.fill")
                        }
                    }
                    .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
                }
                .disabled(isRunning || sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Execute")
            }
        }
    }

    /// Android's query field: monospaced text on a tinted block, accent cursor.
    private var editor: some View {
        TextEditor(text: $sql)
            .font(InspectorFont.body.monospaced())
            .foregroundColor(InspectorTheme.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($editorFocused)
            .inspectorHiddenEditorBackground()
            .frame(minHeight: InspectorTheme.minTouchTarget * 2, maxHeight: InspectorTheme.minTouchTarget * 3)
            .padding(.horizontal, InspectorTheme.Spacing.sm)
            .padding(.vertical, InspectorTheme.Spacing.xs)
            .background(InspectorTheme.surfaceHigh.opacity(InspectorTheme.Alpha.bold))
            .overlay(alignment: .topLeading) {
                if sql.isEmpty {
                    Text("Enter SQL query…")
                        .font(InspectorFont.body.monospaced())
                        .foregroundColor(InspectorTheme.secondaryText)
                        .padding(.horizontal, InspectorTheme.Spacing.md)
                        .padding(.vertical, InspectorTheme.Spacing.md)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("SQL query")
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
            Image(systemName: "text.badge.plus")
                .frame(minWidth: InspectorTheme.minTouchTarget, minHeight: InspectorTheme.minTouchTarget)
        }
        .disabled(tables.isEmpty)
        .accessibilityLabel("Templates")
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

/// Android's result area: the error in red, a row count over the grid, the history, or the instructions.
private struct QueryOutcomeView: View {
    let databaseName: String
    let result: WormaCeptorQueryResult?
    let failure: String?
    let history: [String]
    let onPickHistory: (String) -> Void

    var body: some View {
        if let error = failure ?? result?.error {
            Text("Error: \(error)")
                .font(InspectorFont.body)
                .foregroundColor(InspectorTheme.error)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(InspectorTheme.Spacing.lg)
        } else if let result {
            VStack(alignment: .leading, spacing: 0) {
                Text(result.rowCount == 1 ? "1 row returned" : "\(result.rowCount) rows returned")
                    .font(InspectorFont.label)
                    .foregroundColor(InspectorTheme.secondaryText)
                    .padding(InspectorTheme.Spacing.md)
                QueryResultView(result: result)
            }
        } else if history.isEmpty {
            VStack(spacing: InspectorTheme.Spacing.sm) {
                Text("Enter a SQL query and press Execute")
                    .font(InspectorFont.listHeadline.weight(.regular))
                Text("Database: \(databaseName)")
                    .font(InspectorFont.bodySmall)
            }
            .foregroundColor(InspectorTheme.secondaryText)
            .multilineTextAlignment(.center)
            .padding(InspectorTheme.Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            historyList
        }
    }

    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Query history")
                    .font(InspectorFont.titleSmall.weight(.bold))
                    .foregroundColor(InspectorTheme.brand)
                    .padding(InspectorTheme.Spacing.md)
                    .accessibilityAddTraits(.isHeader)
                ForEach(history.reversed(), id: \.self) { query in
                    Button { onPickHistory(query) } label: {
                        HStack(spacing: InspectorTheme.Spacing.lg) {
                            InspectorRowIcon(systemImage: "clock.arrow.circlepath", color: InspectorTheme.secondaryText)
                            Text(query)
                                .font(InspectorFont.code)
                                .foregroundColor(InspectorTheme.textPrimary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, InspectorTheme.Spacing.lg)
                        .padding(.vertical, InspectorTheme.Spacing.md)
                        .frame(minHeight: InspectorTheme.minTouchTarget)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) { InspectorDivider() }
                    }
                    .buttonStyle(InspectorPressStyle())
                }
            }
        }
    }
}

/// Android's data table: a tinted header row with a thick rule, 200 pt monospaced cells, NULL in blue-grey.
/// Scrolls both ways with the header pinned; tap a row to see every value in full.
struct QueryResultView: View {
    let result: WormaCeptorQueryResult

    @State private var selectedRow: SelectedRow?

    private static let columnWidth: CGFloat = 200

    var body: some View {
        if result.rowCount == 0 {
            InspectorEmptyState(systemImage: "tablecells", title: "No data", message: "The query returned no rows.")
        } else {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    grid.frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .sheet(item: $selectedRow) { selected in
                NavigationView {
                    RowDetailView(result: result, row: selected.index)
                }
            }
        }
    }

    private var grid: some View {
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
                }
            } header: {
                header
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(Array(result.columns.enumerated()), id: \.offset) { _, column in
                Text(column)
                    .font(InspectorFont.label.weight(.bold))
                    .foregroundColor(InspectorTheme.textPrimary)
                    .lineLimit(1)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
            }
        }
        .frame(minHeight: InspectorTheme.minTouchTarget - InspectorTheme.Spacing.sm)
        .background(InspectorTheme.surfaceHigh)
        .overlay(alignment: .bottom) {
            Rectangle().fill(InspectorTheme.outlineVariant).frame(height: InspectorTheme.Border.thick)
        }
    }

    private func rowView(_ row: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<result.columns.count, id: \.self) { column in
                CellText(value: result.value(row: Int32(row), column: Int32(column)))
                    .lineLimit(2)
                    .frame(width: Self.columnWidth, alignment: .leading)
                    .padding(.horizontal, InspectorTheme.Spacing.sm)
            }
        }
        .padding(.vertical, InspectorTheme.Spacing.xs)
        .frame(minHeight: InspectorTheme.minTouchTarget)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { InspectorDivider() }
    }
}

private struct SelectedRow: Identifiable {
    let index: Int
    var id: Int { index }
}

/// A value, or NULL in Android's null color so it can't be mistaken for the text "NULL".
private struct CellText: View {
    let value: String?

    var body: some View {
        if let value {
            Text(value)
                .font(InspectorFont.code)
                .foregroundColor(InspectorTheme.textPrimary)
        } else {
            Text("NULL")
                .font(InspectorFont.code.italic())
                .foregroundColor(SQLiteColors.null)
        }
    }
}

private struct RowDetailView: View {
    let result: WormaCeptorQueryResult
    let row: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InspectorTheme.Spacing.lg) {
                ForEach(Array(result.columns.enumerated()), id: \.offset) { index, column in
                    let value = result.value(row: Int32(row), column: Int32(index))
                    InspectorDetailSection(column) {
                        if let value {
                            CopyButton(text: value, label: column)
                        }
                    } content: {
                        CellText(value: value).textSelection(.enabled)
                    }
                }
            }
            .padding(InspectorTheme.Spacing.lg)
        }
        .inspectorScreen()
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
#Preview("Rows") {
    NavigationView {
        QueryResultView(result: PreviewSamples.queryResult)
            .navigationTitle("ZORDER")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Rows, dark") {
    NavigationView {
        QueryResultView(result: PreviewSamples.queryResult)
            .navigationTitle("ZORDER")
            .navigationBarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}

#Preview("Query") {
    NavigationView {
        QueryScreen(database: PreviewSamples.databases[0], tables: ["ZORDER"])
    }
}
#endif
