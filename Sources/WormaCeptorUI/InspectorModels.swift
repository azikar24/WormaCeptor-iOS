import Combine
import WormaCeptor

// Thin holders for the Kotlin subscriptions. WormaCeptorInspectorData calls back on the main queue, so the published
// values change on the main thread.

final class TransactionListModel: ObservableObject {
    @Published private(set) var rows: [WormaCeptorTransactionRow] = []
    /// False until the first delivery, so the list shows a skeleton instead of a flash of the empty state.
    @Published private(set) var isLoaded = false
    @Published var filters = TransactionFilters()
    @Published var search = "" {
        didSet { if search != oldValue { subscribe() } }
    }

    private var subscription: WormaCeptorSubscription?

    init() {
        subscribe()
    }

    deinit {
        subscription?.cancel()
    }

    func clear() {
        WormaCeptorInspectorData.shared.clearTransactions()
    }

    private func subscribe() {
        subscription?.cancel()
        subscription = WormaCeptorInspectorData.shared.observeTransactions(search: search) { [weak self] rows in
            self?.rows = rows
            self?.isLoaded = true
        }
    }
}

/// One transaction, followed live, plus the list order so the screen can step to the previous or next one.
final class TransactionDetailModel: ObservableObject {
    @Published private(set) var detail: WormaCeptorTransactionDetail?
    @Published private(set) var isLoaded = false
    /// +1 after stepping to an older transaction, -1 to a newer one; picks the slide direction.
    @Published private(set) var direction = 1
    @Published private var ids: [String] = []

    private var id: String
    private var subscription: WormaCeptorSubscription?
    private var listSubscription: WormaCeptorSubscription?

    init(id: String) {
        self.id = id
        observe(id)
        // Unfiltered, newest first: the list screen's order when its search is empty.
        listSubscription = WormaCeptorInspectorData.shared.observeTransactions(search: "") { [weak self] rows in
            self?.ids = rows.map(\.id)
        }
    }

    deinit {
        subscription?.cancel()
        listSubscription?.cancel()
    }

    var canGoNewer: Bool {
        (ids.firstIndex(of: id) ?? 0) > 0
    }

    var canGoOlder: Bool {
        guard let index = ids.firstIndex(of: id) else { return false }
        return index < ids.count - 1
    }

    /// `delta` +1 opens the next (older) transaction, -1 the previous (newer) one.
    func step(_ delta: Int) {
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + delta) else { return }
        direction = delta
        id = ids[index + delta]
        observe(id)
    }

    private func observe(_ id: String) {
        subscription?.cancel()
        subscription = WormaCeptorInspectorData.shared.observeTransaction(id: id) { [weak self] detail in
            self?.detail = detail
            self?.isLoaded = true
        }
    }
}

final class MockRulesModel: ObservableObject {
    @Published private(set) var rules: [WormaCeptorMockRuleRow] = []

    private var subscription: WormaCeptorSubscription?

    init() {
        subscription = WormaCeptorInspectorData.shared.observeMockRules { [weak self] rules in
            self?.rules = rules
        }
    }

    deinit {
        subscription?.cancel()
    }

    func setEnabled(_ rule: WormaCeptorMockRuleRow, _ enabled: Bool) {
        WormaCeptorInspectorData.shared.setMockRuleEnabled(id: rule.id, enabled: enabled)
    }

    func delete(_ rule: WormaCeptorMockRuleRow) {
        WormaCeptorInspectorData.shared.deleteMockRule(id: rule.id)
    }

    /// Kotlin has no delete-all, so one delete per rule.
    func deleteAll() {
        rules.forEach(delete)
    }
}
