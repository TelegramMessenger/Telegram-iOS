import Foundation

final class MutableBasicPeerView: MutablePostboxView {
    private let peerId: PeerId
    fileprivate var peer: Peer?
    fileprivate var notificationSettings: PeerNotificationSettings?
    
    init(postbox: Postbox, peerId: PeerId) {
        self.peerId = peerId
        self.peer = postbox.peerTable.get(peerId)
        self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let peer = transaction.currentUpdatedPeers[self.peerId] {
            self.peer = peer
            updated = true
        }
        if transaction.currentUpdatedPeerNotificationSettings[self.peerId] != nil {
            self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
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
    public let notificationSettings: PeerNotificationSettings?
    
    init(_ view: MutableBasicPeerView) {
        self.peer = view.peer
        self.notificationSettings = view.notificationSettings
    }
}
