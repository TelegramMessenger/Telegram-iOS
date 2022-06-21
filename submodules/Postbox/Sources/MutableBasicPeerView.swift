import Foundation

final class MutableBasicPeerView: MutablePostboxView {
    private let peerId: PeerId
    fileprivate var peer: Peer?
    fileprivate var notificationSettings: PeerNotificationSettings?
    fileprivate var isContact: Bool
    fileprivate var groupId: PeerGroupId?
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        self.peer = postbox.peerTable.get(peerId)
        self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
        self.isContact = postbox.contactsTable.isContact(peerId: self.peerId)
        self.groupId = postbox.chatListIndexTable.get(peerId: peerId).inclusion.groupId
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let peer = transaction.currentUpdatedPeers[self.peerId] {
            self.peer = peer
            updated = true
        }
        if transaction.currentUpdatedPeerNotificationSettings[self.peerId] != nil {
            self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
            updated = true
        }
        if transaction.replaceContactPeerIds != nil {
            let isContact = postbox.contactsTable.isContact(peerId: self.peerId)
            if isContact != self.isContact {
                self.isContact = isContact
                updated = true
            }
        }
        if transaction.currentUpdatedChatListInclusions[self.peerId] != nil {
            let groupId = postbox.chatListIndexTable.get(peerId: peerId).inclusion.groupId
            if self.groupId != groupId {
                self.groupId = groupId
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return BasicPeerView(self)
    }
}

public final class BasicPeerView: PostboxView {
    public let peer: Peer?
    public let notificationSettings: PeerNotificationSettings?
    public let isContact: Bool
    public let groupId: PeerGroupId?
    
    init(_ view: MutableBasicPeerView) {
        self.peer = view.peer
        self.notificationSettings = view.notificationSettings
        self.isContact = view.isContact
        self.groupId = view.groupId
    }
}
