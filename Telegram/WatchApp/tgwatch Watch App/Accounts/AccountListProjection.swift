import Foundation

/// View-model for a single row in `AccountsListView`. Identifiable by the
/// underlying account UUID so SwiftUI's diffing across switches is stable.
struct AccountListRow: Identifiable, Equatable, Sendable {
    let id: UUID
    let label: String
    let showsTestPill: Bool
    let isActive: Bool
}

/// Pure helpers — no `@MainActor`, no `@Observable`, no SwiftUI imports.
enum AccountListProjection {
    static func row(for account: Account, isActive: Bool) -> AccountListRow {
        AccountListRow(
            id: account.id,
            label: label(for: account),
            showsTestPill: account.useTestDc,
            isActive: isActive
        )
    }

    static func rows(accounts: [Account], activeAccountId: UUID?) -> [AccountListRow] {
        accounts
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
            .map { row(for: $0, isActive: $0.id == activeAccountId) }
    }

    private static func label(for account: Account) -> String {
        if let displayName = account.displayName, !displayName.isEmpty {
            return displayName
        }
        if let phone = account.phoneNumber, !phone.isEmpty {
            return "+\(phone)"
        }
        return "New account"
    }
}
