import Foundation

final class MutablePeerChatStateView: MutablePostboxView {
    let peerId: PeerId
    var chatState: PostboxCoding?
    
    init(postbox: Postbox, peerId: PeerId) {
        self.peerId = peerId
        self.chatState = postbox.peerChatStateTable.get(peerId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if transaction.currentUpdatedPeerChatStates.contains(self.peerId) {
            self.chatState = postbox.peerChatStateTable.get(self.peerId)
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerChatStateView(self)
    }
}

public final class PeerChatStateView: PostboxView {
    public let peerId: PeerId
    public let chatState: PostboxCoding?
    
    init(_ view: MutablePeerChatStateView) {
        self.peerId = view.peerId
        self.chatState = view.chatState
    }
}
