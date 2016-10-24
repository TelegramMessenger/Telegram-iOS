import Foundation

final class MutablePeerView {
    let peerId: PeerId
    var notificationSettings: PeerNotificationSettings?
    var cachedData: CachedPeerData?
    var peers: [PeerId: Peer] = [:]
    var peerPresences: [PeerId: PeerPresence] = [:]
    var peerIsContact: Bool
    
    init(peerId: PeerId, notificationSettings: PeerNotificationSettings?, cachedData: CachedPeerData?, peerIsContact: Bool, getPeer: (PeerId) -> Peer?, getPeerPresence: (PeerId) -> PeerPresence?) {
        self.peerId = peerId
        self.notificationSettings = notificationSettings
        self.cachedData = cachedData
        self.peerIsContact = peerIsContact
        var peerIds = Set<PeerId>()
        peerIds.insert(peerId)
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
    }
    
    func replay(updatedPeers: [PeerId: Peer], updatedNotificationSettings: [PeerId: PeerNotificationSettings], updatedCachedPeerData: [PeerId: CachedPeerData], updatedPeerPresences: [PeerId: PeerPresence], replaceContactPeerIds: Set<PeerId>?, getPeer: (PeerId) -> Peer?, getPeerPresence: (PeerId) -> PeerPresence?) -> Bool {
        var updated = false
        
        if let cachedData = updatedCachedPeerData[self.peerId], self.cachedData == nil || self.cachedData!.peerIds != cachedData.peerIds {
            self.cachedData = cachedData
            updated = true
            
            var peerIds = Set<PeerId>()
            peerIds.insert(self.peerId)
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
            self.notificationSettings =  notificationSettings
            updated = true
        }
        
        return updated
    }
}

public final class PeerView {
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
