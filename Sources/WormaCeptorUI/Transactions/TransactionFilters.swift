import SwiftUI
import WormaCeptor

/// Android's status-range filter: one 100-code band.
enum StatusRangeFilter: Int, CaseIterable, Identifiable {
    case success = 200
    case redirect = 300
    case clientError = 400
    case serverError = 500

    var id: Int { rawValue }

    var label: String { "\(rawValue / 100)xx" }

    var sublabel: String {
        switch self {
        case .success: return "Success"
        case .redirect: return "Redirect"
        case .clientError: return "Client Error"
        case .serverError: return "Server Error"
        }
    }

    var color: Color {
        switch self {
        case .success: return InspectorTheme.color(for: .success)
        case .redirect: return InspectorTheme.color(for: .redirect)
        case .clientError: return InspectorTheme.color(for: .warning)
        case .serverError: return InspectorTheme.color(for: .error)
        }
    }

    func contains(_ row: WormaCeptorTransactionRow) -> Bool {
        guard let code = row.statusCode?.intValue else { return false }
        return code >= rawValue && code < rawValue + 100
    }
}

/// The method and status filters Android's filter sheet sets. Search stays on the Kotlin side.
struct TransactionFilters: Equatable {
    /// The methods Android's sheet offers, in its order.
    static let methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]

    var methods: Set<String> = []
    var statusRanges: Set<StatusRangeFilter> = []

    var isEmpty: Bool { methods.isEmpty && statusRanges.isEmpty }

    var count: Int { methods.count + statusRanges.count }

    /// Rows matching every active group; an empty group matches everything.
    func apply(to rows: [WormaCeptorTransactionRow]) -> [WormaCeptorTransactionRow] {
        guard !isEmpty else { return rows }
        return rows.filter { row in
            (methods.isEmpty || methods.contains(row.method.uppercased()))
                && (statusRanges.isEmpty || statusRanges.contains { $0.contains(row) })
        }
    }

    /// Android's filter sheet colors methods with the status palette, not the badge palette.
    static func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return InspectorTheme.color(for: .success)
        case "POST": return InspectorTheme.color(for: .redirect)
        case "PUT": return InspectorTheme.color(for: .warning)
        case "DELETE": return InspectorTheme.color(for: .error)
        case "PATCH": return InspectorTheme.methodColor("PATCH")
        default: return InspectorTheme.color(for: .neutral)
        }
    }
}
