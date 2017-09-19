import Foundation

final class MutablePeerView: MutablePostboxView {
    let peerId: PeerId
    var notificationSettings: PeerNotificationSettings?
    var cachedData: CachedPeerData?
    var peers: [PeerId: Peer] = [:]
    var peerPresences: [PeerId: PeerPresence] = [:]
    var peerIsContact: Bool
    
    init(postbox: Postbox, peerId: PeerId) {
        let notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
        let cachedData = postbox.cachedPeerDataTable.get(peerId)
        let peerIsContact = postbox.contactsTable.isContact(peerId: peerId)
        
        let getPeer: (PeerId) -> Peer? = { peerId in
            return postbox.peerTable.get(peerId)
        }
        
        let getPeerPresence: (PeerId) -> PeerPresence? = { peerId in
            return postbox.peerPresenceTable.get(peerId)
        }
        
        self.peerId = peerId
        self.notificationSettings = notificationSettings
        self.cachedData = cachedData
        self.peerIsContact = peerIsContact
        var peerIds = Set<PeerId>()
        peerIds.insert(peerId)
        if let peer = getPeer(peerId), let associatedPeerId = peer.associatedPeerId {
            peerIds.insert(associatedPeerId)
        }
        if let cachedData = cachedData {
            peerIds.formUnion(cachedData.peerIds)
        }
        for id in peerIds {
            if let peer = getPeer(id) {
                self.peers[id] = peer
            }
            if let presence = getPeerPresence(id) {
                self.peerPresences[id] = presence
            }
        }
        if let peer = self.peers[peerId], let associatedPeerId = peer.associatedPeerId {
            if let peer = getPeer(associatedPeerId) {
                self.peers[associatedPeerId] = peer
            }
            if let presence = getPeerPresence(associatedPeerId) {
                self.peerPresences[associatedPeerId] = presence
            }
        }
    }
    
    func reset(postbox: Postbox) -> Bool {
        return false
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        let updatedPeers = transaction.currentUpdatedPeers
        let updatedNotificationSettings = transaction.currentUpdatedPeerNotificationSettings
        let updatedCachedPeerData = transaction.currentUpdatedCachedPeerData
        let updatedPeerPresences = transaction.currentUpdatedPeerPresences
        let replaceContactPeerIds = transaction.replaceContactPeerIds
        
        let getPeer: (PeerId) -> Peer? = { peerId in
            return postbox.peerTable.get(peerId)
        }
        
        let getPeerPresence: (PeerId) -> PeerPresence? = { peerId in
            return postbox.peerPresenceTable.get(peerId)
        }
        
        var updated = false
        
        if let cachedData = updatedCachedPeerData[self.peerId], self.cachedData == nil || !self.cachedData!.isEqual(to: cachedData) {
            self.cachedData = cachedData
            updated = true
            
            var peerIds = Set<PeerId>()
            peerIds.insert(self.peerId)
            if let peer = getPeer(self.peerId), let associatedPeerId = peer.associatedPeerId {
                peerIds.insert(associatedPeerId)
            }
            peerIds.formUnion(cachedData.peerIds)
            
            for id in peerIds {
                if let peer = updatedPeers[id] {
                    self.peers[id] = peer
                } else if let peer = getPeer(id) {
                    self.peers[id] = peer
                }
                
                if let presence = updatedPeerPresences[id] {
                    self.peerPresences[id] = presence
                } else if let presence = getPeerPresence(id) {
                    self.peerPresences[id] = presence
                }
            }
            
            var removePeerIds: [PeerId] = []
            for peerId in self.peers.keys {
                if !peerIds.contains(peerId) {
                    removePeerIds.append(peerId)
                }
            }
            
            for peerId in removePeerIds {
                self.peers.removeValue(forKey: peerId)
            }
            
            removePeerIds.removeAll()
            for peerId in self.peerPresences.keys {
                if !peerIds.contains(peerId) {
                    removePeerIds.append(peerId)
                }
            }
            
            for peerId in removePeerIds {
                self.peerPresences.removeValue(forKey: peerId)
            }
        } else {
            var peerIds = Set<PeerId>()
            peerIds.insert(self.peerId)
            if let peer = getPeer(self.peerId), let associatedPeerId = peer.associatedPeerId {
                peerIds.insert(associatedPeerId)
            }
            if let cachedData = self.cachedData {
                peerIds.formUnion(cachedData.peerIds)
            }
            
            for id in peerIds {
                if let peer = updatedPeers[id] {
                    self.peers[id] = peer
                    updated = true
                }
                if let presence = updatedPeerPresences[id] {
                    self.peerPresences[id] = presence
                    updated = true
                }
            }
        }
        
        if let notificationSettings = updatedNotificationSettings[self.peerId] {
            self.notificationSettings = notificationSettings
            updated = true
        }
        
        if let replaceContactPeerIds = replaceContactPeerIds {
            if self.peerIsContact {
                if !replaceContactPeerIds.contains(self.peerId) {
                    self.peerIsContact = false
                    updated = true
                }
            } else {
                if replaceContactPeerIds.contains(self.peerId) {
                    self.peerIsContact = true
                    updated = true
                }
            }
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return PeerView(self)
    }
}

public final class PeerView: PostboxView {
    public let peerId: PeerId
    public let cachedData: CachedPeerData?
    public let notificationSettings: PeerNotificationSettings?
    public let peers: [PeerId: Peer]
    public let peerPresences: [PeerId: PeerPresence]
    public let peerIsContact: Bool
    
    init(_ mutableView: MutablePeerView) {
        self.peerId = mutableView.peerId
        self.cachedData = mutableView.cachedData
        self.notificationSettings = mutableView.notificationSettings
        self.peers = mutableView.peers
        self.peerPresences = mutableView.peerPresences
        self.peerIsContact = mutableView.peerIsContact
    }
}
