import Foundation
import Observation

/// Carrier for a pushed chat: the row plus its pre-built (warmed or warming)
/// `ChatHistoryStore`. Navigation identity is the chat id only — `ChatHistoryStore`
/// is a reference type and intentionally excluded from equality/hashing.
struct OpenChatTarget: Identifiable, Hashable {
    let row: ChatRow
    let store: ChatHistoryStore
    var id: Int64 { row.id }

    static func == (lhs: OpenChatTarget, rhs: OpenChatTarget) -> Bool { lhs.row.id == rhs.row.id }
    func hash(into hasher: inout Hasher) { hasher.combine(row.id) }
}

/// Coordinates "warm the store, then push" so a cached chat opens instantly and
/// correctly positioned, while an uncached chat still pushes promptly (with the
/// in-view spinner) instead of hanging the tap. Owned + injected by `ChatListView`.
@Observable
@MainActor
final class ChatOpener {
    /// Drives `.navigationDestination(item:)`. Non-nil → push. Cleared on pop.
    var target: OpenChatTarget?
    /// Chat id currently being warmed (available for a pressed/redacted row
    /// affordance during the wait; not wired by default — the wait is ~150ms).
    private(set) var pendingRowId: Int64?

    /// Max time to wait for `warm()` before pushing anyway with the in-view spinner.
    /// Instance-mutable so tests can shorten it. ~150ms: long enough that a local
    /// cache load wins, short enough that an uncached tap still feels responsive.
    var openTimeoutNs: UInt64 = 150_000_000

    /// `makeStore` returns the store to warm+push (or nil if dependencies are
    /// unavailable, e.g. no TDLib client). Kept as a closure so `ChatOpener` has no
    /// `TDClient` dependency and stays unit-testable.
    func open(_ row: ChatRow, makeStore: (ChatRow) -> ChatHistoryStore?) {
        guard target == nil, pendingRowId == nil, let store = makeStore(row) else { return }
        pendingRowId = row.id
        let timeoutNs = openTimeoutNs
        // Owned task: runs to completion regardless of the race below. Dropping a
        // Task handle does NOT cancel it, so the timeout-loser keeps loading.
        let warmTask = Task { await store.warm() }
        Task { [weak self] in
            await Self.waitForWarmOrTimeout(store: store, timeoutNs: timeoutNs)
            guard let self else { return }
            self.target = OpenChatTarget(row: row, store: store)
            self.pendingRowId = nil
        }
        _ = warmTask
    }

    /// Returns when `store.loadState` leaves `.loadingFirstPage` (warm finished) OR
    /// the deadline elapses, whichever is first. Polls rather than `await`-ing the
    /// warm task's value — `Task.value` is not cancellation-aware, so awaiting it
    /// inside a race would block until warm finished even after the timeout fired.
    private static func waitForWarmOrTimeout(store: ChatHistoryStore, timeoutNs: UInt64) async {
        let stepNs: UInt64 = 16_000_000   // ~one frame
        var waitedNs: UInt64 = 0
        while store.loadState == .loadingFirstPage && waitedNs < timeoutNs {
            try? await Task.sleep(nanoseconds: stepNs)
            waitedNs += stepNs
        }
    }
}
