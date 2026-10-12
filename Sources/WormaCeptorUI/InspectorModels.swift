import Combine
import WormaCeptor

// Thin holders for the Kotlin subscriptions. WormaCeptorInspectorData calls back on the main queue, so the published
// values change on the main thread.

final class TransactionListModel: ObservableObject {
    @Published private(set) var rows: [WormaCeptorTransactionRow] = []
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
        }
    }
}

final class TransactionDetailModel: ObservableObject {
    @Published private(set) var detail: WormaCeptorTransactionDetail?
    @Published private(set) var isLoaded = false

    private var subscription: WormaCeptorSubscription?

    init(id: String) {
        subscription = WormaCeptorInspectorData.shared.observeTransaction(id: id) { [weak self] detail in
            self?.detail = detail
            self?.isLoaded = true
        }
    }

    deinit {
        subscription?.cancel()
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
}
