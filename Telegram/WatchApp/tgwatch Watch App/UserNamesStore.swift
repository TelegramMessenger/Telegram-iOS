import Foundation
import Observation
import TDShim

/// Single source of truth for `[userId: firstName]` resolved from TDLib's
/// `updateUser` events. Owned by `TDClient`; injected into `ChatListStore`
/// and `ChatHistoryStore` at construction. Lifetime tied to the active
/// `TDClient` — account switch rebuilds it.
///
/// Stores `firstName` only (matches the existing single-field shape used
/// by `senderName(...)`, `senderPrefix(...)`, `replyPreview(...)`,
/// `serviceActor(...)`). If the codebase ever needs a richer display
/// name, swap the dict's value type here.
@Observable @MainActor
final class UserNamesStore {
    private(set) var names: [Int64: String] = [:]

    /// Absorbs `.updateUser` events. Other update kinds are ignored. Idempotent.
    func handle(_ update: Update) {
        if case .updateUser(let upd) = update {
            names[upd.user.id] = upd.user.firstName
        }
    }
}
