import Foundation

final class MutablePeerChatStateView: MutablePostboxView {
    let peerId: PeerId
    var chatState: CodableEntry?
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        self.chatState = postbox.peerChatStateTable.get(peerId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if transaction.currentUpdatedPeerChatStates.contains(self.peerId) {
            self.chatState = postbox.peerChatStateTable.get(self.peerId)
            return true
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*let chatState = postbox.peerChatStateTable.get(self.peerId)
        if self.chatState != chatState {
            self.chatState = chatState
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return PeerChatStateView(self)
    }
}

public final class PeerChatStateView: PostboxView {
    public let peerId: PeerId
    public let chatState: CodableEntry?
    
    init(_ view: MutablePeerChatStateView) {
        self.peerId = view.peerId
        self.chatState = view.chatState
    }
}
