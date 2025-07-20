import Foundation

public struct PeerViewComponents: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let cachedData = PeerViewComponents(rawValue: 1 << 0)
    public static let subPeers = PeerViewComponents(rawValue: 1 << 1)
    public static let messages = PeerViewComponents(rawValue: 1 << 2)
    public static let groupId = PeerViewComponents(rawValue: 1 << 3)
    public static let storyStats = PeerViewComponents(rawValue: 1 << 4)
    
    public static let all: PeerViewComponents = [.cachedData, .subPeers, .messages, .groupId, .storyStats]
}

final class MutablePeerView: MutablePostboxView {
    let peerId: PeerId
    let contactPeerId: PeerId
    let components: PeerViewComponents
    var notificationSettings: PeerNotificationSettings?
    var cachedData: CachedPeerData?
    var associatedCachedData: [PeerId: CachedPeerData] = [:]
    var peers: [PeerId: Peer] = [:]
    var peerPresences: [PeerId: PeerPresence] = [:]
    var messages: [MessageId: Message] = [:]
    var media: [MediaId: Media] = [:]
    var peerIsContact: Bool
    var groupId: PeerGroupId?
    var storyStats: PeerStoryStats?
    var memberStoryStats: [PeerId: PeerStoryStats] = [:]
    
    init(postbox: PostboxImpl, peerId: PeerId, components: PeerViewComponents) {
        self.components = components
        
        let getPeer: (PeerId) -> Peer? = { peerId in
            return postbox.peerTable.get(peerId)
        }
        
        let getPeerPresence: (PeerId) -> PeerPresence? = { peerId in
            return postbox.peerPresenceTable.get(peerId)
        }
        
        self.peerId = peerId
        self.groupId = postbox.chatListIndexTable.get(peerId: peerId).inclusion.groupId
        var peerIds = Set<PeerId>()
        var messageIds = Set<MessageId>()
        peerIds.insert(peerId)
        
        if let peer = getPeer(peerId) {
            if let associatedPeerId = peer.associatedPeerId {
                peerIds.insert(associatedPeerId)
                
                if peer.associatedPeerOverridesIdentity {
                    self.contactPeerId = associatedPeerId
                    self.peerIsContact = postbox.contactsTable.isContact(peerId: associatedPeerId)
                } else {
                    self.contactPeerId = peerId
                }
            } else {
                self.contactPeerId = peerId
            }
            
            if let additionalAssociatedPeerId = peer.additionalAssociatedPeerId {
                peerIds.insert(additionalAssociatedPeerId)
            }
        } else {
            self.contactPeerId = peerId
        }
        self.cachedData = postbox.cachedPeerDataTable.get(contactPeerId)
        self.peerIsContact = postbox.contactsTable.isContact(peerId: self.contactPeerId)
        var cachedDataPeerIds = Set<PeerId>()
        if let cachedData = self.cachedData {
            cachedDataPeerIds = cachedData.peerIds
            peerIds.formUnion(cachedDataPeerIds)
            messageIds.formUnion(cachedData.messageIds)
        }
        for id in peerIds {
            if let peer = getPeer(id) {
                self.peers[id] = peer
            }
            if let presence = getPeerPresence(id) {
                self.peerPresences[id] = presence
            }
        }
        for id in cachedDataPeerIds {
            if let value = fetchPeerStoryStats(postbox: postbox, peerId: id) {
                self.memberStoryStats[id] = value
            }
        }
        if let peer = self.peers[peerId], let associatedPeerId = peer.associatedPeerId {
            if let peer = getPeer(associatedPeerId) {
                self.peers[associatedPeerId] = peer
            }
            if let presence = getPeerPresence(associatedPeerId) {
                self.peerPresences[associatedPeerId] = presence
            }
            if peer.associatedPeerOverridesIdentity {
                self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(associatedPeerId)
            } else {
                self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
            }
            
            if let cachedData = postbox.cachedPeerDataTable.get(associatedPeerId) {
                self.associatedCachedData[associatedPeerId] = cachedData
            }
        } else {
            self.notificationSettings = postbox.peerNotificationSettingsTable.getEffective(peerId)
        }
        if let peer = self.peers[peerId], let additionalAssociatedPeerId = peer.additionalAssociatedPeerId {
            if let peer = getPeer(additionalAssociatedPeerId) {
                self.peers[additionalAssociatedPeerId] = peer
            }
        }
        for id in messageIds {
            if let message = postbox.getMessage(id) {
                self.messages[id] = message
            }
        }
        self.media = renderAssociatedMediaForPeers(postbox: postbox, peers: self.peers)
        
        if components.contains(.storyStats) {
            self.storyStats = fetchPeerStoryStats(postbox: postbox, peerId: self.peerId)
        }
    }
    
    func reset(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
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
        var peersUpdated = false
        var updateMessages = false
        
        if let cachedData = updatedCachedPeerData[self.contactPeerId], self.cachedData == nil || !self.cachedData!.isEqual(to: cachedData) {
            if self.cachedData?.messageIds != cachedData.messageIds {
                updateMessages = true
            }
            
            self.cachedData = cachedData
            updated = true
            
            var peerIds = Set<PeerId>()
            peerIds.insert(self.peerId)
            if let peer = getPeer(self.peerId) {
                if let associatedPeerId = peer.associatedPeerId {
                    peerIds.insert(associatedPeerId)
                }
                if let additionalAssociatedPeerId = peer.additionalAssociatedPeerId {
                    peerIds.insert(additionalAssociatedPeerId)
                }
            }
            peerIds.formUnion(cachedData.peerIds)
            
            for id in peerIds {
                if let peer = updatedPeers[id] {
                    self.peers[id] = peer
                    peersUpdated = true
                } else if let peer = getPeer(id) {
                    self.peers[id] = peer
                    peersUpdated = true
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
            if let peer = getPeer(self.peerId) {
                if let associatedPeerId = peer.associatedPeerId {
                    peerIds.insert(associatedPeerId)
                }
                if let additionalAssociatedPeerId = peer.additionalAssociatedPeerId {
                    peerIds.insert(additionalAssociatedPeerId)
                }
            }
            if let cachedData = self.cachedData {
                peerIds.formUnion(cachedData.peerIds)
            }
            
            for id in peerIds {
                if let peer = updatedPeers[id] {
                    self.peers[id] = peer
                    updated = true
                    peersUpdated = true
                }
                if let presence = updatedPeerPresences[id] {
                    self.peerPresences[id] = presence
                    updated = true
                }
            }
        }
        
        if peersUpdated {
            self.media = renderAssociatedMediaForPeers(postbox: postbox, peers: self.peers)
        }
        
        if let cachedData = self.cachedData, !cachedData.messageIds.isEmpty, let operations = transaction.currentOperationsByPeerId[self.peerId] {
            outer: for operation in operations {
                switch operation {
                    case let .InsertMessage(message):
                        if cachedData.messageIds.contains(message.id) {
                            updateMessages = true
                            break outer
                        }
                    case let .Remove(indicesWithTags):
                        for (index, _) in indicesWithTags {
                            if cachedData.messageIds.contains(index.id) {
                                updateMessages = true
                                break outer
                            }
                        }
                    default:
                        break
                }
            }
        }
        
        if updateMessages {
            var messages: [MessageId: Message] = [:]
            if let cachedData = self.cachedData {
                for id in cachedData.messageIds {
                    if let message = postbox.getMessage(id) {
                        messages[id] = message
                    }
                }
            }
            self.messages = messages
            updated = true
        }
        
        if let peer = self.peers[self.peerId] {
            if let associatedPeerId = peer.associatedPeerId, peer.associatedPeerOverridesIdentity {
                if let (_, notificationSettings) = updatedNotificationSettings[associatedPeerId] {
                    self.notificationSettings = notificationSettings
                    updated = true
                }
            } else {
                if let (_, notificationSettings) = updatedNotificationSettings[peer.id] {
                    self.notificationSettings = notificationSettings
                    updated = true
                }
            }
            
            if let associatedPeerId = peer.associatedPeerId {
                if let value = updatedCachedPeerData[associatedPeerId] {
                    if let current = self.associatedCachedData[associatedPeerId] {
                        if !current.isEqual(to: value) {
                            self.associatedCachedData[associatedPeerId] = value
                            updated = true
                        }
                    } else {
                        self.associatedCachedData[associatedPeerId] = value
                        updated = true
                    }
                }
            } else {
                if !self.associatedCachedData.isEmpty {
                    self.associatedCachedData.removeAll()
                    updated = true
                }
            }
        } else {
            if self.notificationSettings != nil {
                self.notificationSettings = nil
                updated = true
            }
            
            if !self.associatedCachedData.isEmpty {
                self.associatedCachedData.removeAll()
                updated = true
            }
        }
        
        if let replaceContactPeerIds = replaceContactPeerIds {
            if self.peerIsContact {
                if !replaceContactPeerIds.contains(self.contactPeerId) {
                    self.peerIsContact = false
                    updated = true
                }
            } else {
                if replaceContactPeerIds.contains(self.contactPeerId) {
                    self.peerIsContact = true
                    updated = true
                }
            }
        }
        
        if transaction.currentUpdatedChatListInclusions[self.peerId] != nil {
            let groupId = postbox.chatListIndexTable.get(peerId: peerId).inclusion.groupId
            if self.groupId != groupId {
                self.groupId = groupId
                updated = true
            }
        }
        
        if self.components.contains(.storyStats) {
            var refreshStoryStats = false
            for event in transaction.currentStoryTopItemEvents {
                if case .replace(peerId: self.peerId) = event {
                    refreshStoryStats = true
                }
            }
            if !refreshStoryStats {
                for event in transaction.storyPeerStatesEvents {
                    if case .set(.peer(self.peerId)) = event {
                        refreshStoryStats = true
                    }
                }
            }
            if refreshStoryStats {
                self.storyStats = fetchPeerStoryStats(postbox: postbox, peerId: self.peerId)
            }
        }
        
        if !transaction.storyPeerStatesEvents.isEmpty || !transaction.currentStoryTopItemEvents.isEmpty {
            if let cachedData = self.cachedData {
                var updatedPeerIds = Set<PeerId>()
                let cachedDataPeerIds = cachedData.peerIds
                for event in transaction.currentStoryTopItemEvents {
                    if case let .replace(id) = event, cachedDataPeerIds.contains(id) {
                        updatedPeerIds.insert(id)
                    }
                }
                for event in transaction.storyPeerStatesEvents {
                    if case let .set(key) = event, case let .peer(id) = key, cachedDataPeerIds.contains(id) {
                        updatedPeerIds.insert(id)
                    }
                }
                for id in updatedPeerIds {
                    let value = fetchPeerStoryStats(postbox: postbox, peerId: id)
                    if self.memberStoryStats[id] != value {
                        updated = true
                        if let value = value {
                            self.memberStoryStats[id] = value
                        } else {
                            self.memberStoryStats.removeValue(forKey: id)
                        }
                    }
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
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
    public let messages: [MessageId: Message]
    public let media: [MediaId: Media]
    public let peerIsContact: Bool
    public let groupId: PeerGroupId?
    public let storyStats: PeerStoryStats?
    public let memberStoryStats: [PeerId: PeerStoryStats]
    public let associatedCachedData: [PeerId: CachedPeerData]
    
    init(_ mutableView: MutablePeerView) {
        self.peerId = mutableView.peerId
        self.cachedData = mutableView.cachedData
        self.notificationSettings = mutableView.notificationSettings
        self.peers = mutableView.peers
        self.peerPresences = mutableView.peerPresences
        self.messages = mutableView.messages
        self.media = mutableView.media
        self.peerIsContact = mutableView.peerIsContact
        self.groupId = mutableView.groupId
        self.storyStats = mutableView.storyStats
        self.memberStoryStats = mutableView.memberStoryStats
        self.associatedCachedData = mutableView.associatedCachedData
    }
}
