import Foundation

/// Tracks which holders currently want the WEB carrier running.
///
/// The carrier is process-wide and serves every account, so start and stop must be
/// idempotent: `set` reports whether this call actually changed the aggregate
/// answer, letting the transport ignore the many no-op updates that arrive as
/// individual accounts come and go.
struct WebProxyDemandSet {
    private var tokens = Set<AnyHashable>()

    var isEmpty: Bool {
        return self.tokens.isEmpty
    }

    /// Adds or removes one holder. Returns true when `isEmpty` flipped as a result.
    mutating func set(_ token: AnyHashable, wanted: Bool) -> Bool {
        let wasEmpty = self.tokens.isEmpty
        if wanted {
            self.tokens.insert(token)
        } else {
            self.tokens.remove(token)
        }
        return wasEmpty != self.tokens.isEmpty
    }
}
