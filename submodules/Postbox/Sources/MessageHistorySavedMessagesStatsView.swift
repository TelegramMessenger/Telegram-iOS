import Foundation

final class MutableMessageHistorySavedMessagesStatsView: MutablePostboxView {
    fileprivate let peerId: PeerId
    fileprivate var count: Int = 0
    fileprivate var isLoading: Bool = false
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        
        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        let validIndexBoundary = postbox.peerThreadCombinedStateTable.get(peerId: peerId)?.validIndexBoundary
        self.isLoading = validIndexBoundary == nil
        
        if !self.isLoading {
            self.count = postbox.messageHistoryThreadIndexTable.getCount(peerId: self.peerId)
        } else {
            self.count = 0
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.updatedMessageThreadPeerIds.contains(self.peerId) {
            self.reload(postbox: postbox)
            updated = true
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        self.reload(postbox: postbox)
        
        return true
    }
    
    func immutableView() -> PostboxView {
        return MessageHistorySavedMessagesStatsView(self)
    }
}

public final class MessageHistorySavedMessagesStatsView: PostboxView {
    public let isLoading: Bool
    public let count: Int
    
    init(_ view: MutableMessageHistorySavedMessagesStatsView) {
        self.isLoading = view.isLoading
        self.count = view.count
    }
}
