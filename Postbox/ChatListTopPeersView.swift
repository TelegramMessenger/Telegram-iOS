import Foundation

final class MutableChatListTopPeersView: MutablePostboxView {
    fileprivate let topPeers: ChatListGroupReferenceTopPeers
    
    init(postbox: Postbox, groupId: PeerGroupId) {
        self.topPeers = ChatListGroupReferenceTopPeers(postbox: postbox, groupId: groupId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if self.topPeers.replay(postbox: postbox, transaction: transaction) {
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return ChatListTopPeersView(self)
    }
}

public final class ChatListTopPeersView: PostboxView {
    public var peers: [Peer]
    
    init(_ view: MutableChatListTopPeersView) {
        self.peers = view.topPeers.getPeers()
    }
}

