import Foundation

final class MutablePeerChatInclusionView: MutablePostboxView {
    private let peerId: PeerId
    fileprivate var inclusion: Bool
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        
        self.inclusion = postbox.chatListIndexTable.get(peerId: self.peerId).includedIndex(peerId: peerId) != nil
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if transaction.currentUpdatedChatListInclusions[self.peerId] != nil {
            let inclusion = postbox.chatListIndexTable.get(peerId: self.peerId).includedIndex(peerId: self.peerId) != nil
            if self.inclusion != inclusion {
                self.inclusion = inclusion
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return PeerChatInclusionView(self)
    }
}

public final class PeerChatInclusionView: PostboxView {
    public let inclusion: Bool
    
    init(_ view: MutablePeerChatInclusionView) {
        self.inclusion = view.inclusion
    }
}
