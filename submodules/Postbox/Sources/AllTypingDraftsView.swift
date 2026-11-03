import Foundation

final class MutableAllTypingDraftsView: MutablePostboxView {
    fileprivate var keys: Set<PeerAndThreadId>

    init(postbox: PostboxImpl) {
        self.keys = Set(postbox.currentTypingDrafts.filter({ !$0.value.isStopped }).keys)
    }

    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if transaction.updatedTypingDrafts.isEmpty {
            return false
        }
        var updated = false
        for (key, update) in transaction.updatedTypingDrafts {
            // A draft transitioning to stopped arrives as a non-nil value: it stays on
            // screen, but it must drop out of this view so the send gate opens.
            if let value = update.value, !value.isStopped {
                if self.keys.insert(key).inserted {
                    updated = true
                }
            } else {
                if self.keys.remove(key) != nil {
                    updated = true
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let new = Set(postbox.currentTypingDrafts.filter({ !$0.value.isStopped }).keys)
        if new == self.keys {
            return false
        }
        self.keys = new
        return true
    }

    func immutableView() -> PostboxView {
        return AllTypingDraftsView(self)
    }
}

public final class AllTypingDraftsView: PostboxView {
    public let keys: Set<PeerAndThreadId>

    init(_ view: MutableAllTypingDraftsView) {
        self.keys = view.keys
    }
}
