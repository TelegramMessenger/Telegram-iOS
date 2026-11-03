import Foundation

/// One Telegram account managed by tgwatch. The on-disk dir name is
/// `id.uuidString`; everything else is metadata harvested from TDLib
/// after a successful login.
struct Account: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    /// Immutable: the account is bound to its datacenter for its lifetime.
    let useTestDc: Bool
    /// First+last name from `getMe()`. nil until the account completes login.
    var displayName: String?
    /// Bare digits, no leading `+`. nil until login completes.
    var phoneNumber: String?
    /// TDLib user id. nil until login completes.
    var userId: Int64?
    var createdAt: Foundation.Date
    var lastActiveAt: Foundation.Date
}
