import Foundation

final class MutableBasicPeerView: MutablePostboxView {
    private let peerId: PeerId
    fileprivate var peer: Peer?
    
    init(postbox: Postbox, peerId: PeerId) {
        self.peerId = peerId
        self.peer = postbox.peerTable.get(peerId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let peer = transaction.currentUpdatedPeers[self.peerId] {
            self.peer = peer
            updated = true
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return BasicPeerView(self)
    }
}

public final class BasicPeerView: PostboxView {
    public let peer: Peer?
    
    init(_ view: MutableBasicPeerView) {
        self.peer = view.peer
    }
}
