import Foundation

final class PeerTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let reverseAssociatedTable: ReverseAssociatedPeerTable
    private let peerTimeoutPropertiesTable: PeerTimeoutPropertiesTable
    
    private let sharedEncoder = PostboxEncoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedPeers: [PeerId: Peer] = [:]
    private var updatedInitialPeers: [PeerId: Peer?] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, reverseAssociatedTable: ReverseAssociatedPeerTable, peerTimeoutPropertiesTable: PeerTimeoutPropertiesTable) {
        self.reverseAssociatedTable = reverseAssociatedTable
        self.peerTimeoutPropertiesTable = peerTimeoutPropertiesTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(_ peer: Peer) {
        let previous = self.get(peer.id)
        self.cachedPeers[peer.id] = peer
        if self.updatedInitialPeers[peer.id] == nil {
            self.updatedInitialPeers[peer.id] = previous
        }
    }
    
    func get(_ id: PeerId) -> Peer? {
        if let peer = self.cachedPeers[id] {
            return peer
        }
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            if let peer = PostboxDecoder(buffer: value).decodeRootObject() as? Peer {
                self.cachedPeers[id] = peer
                return peer
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedPeers.removeAll()
        assert(self.updatedInitialPeers.isEmpty)
    }
    
    func transactionUpdatedPeers(contactsTable: ContactTable) -> [((Peer, Bool)?, (Peer, Bool))] {
        var result: [((Peer, Bool)?, (Peer, Bool))] = []
        for (peerId, initialPeer) in self.updatedInitialPeers {
            if let peer = self.get(peerId) {
                let isContact = contactsTable.isContact(peerId: peerId)
                result.append((initialPeer.flatMap { ($0, isContact) }, (peer, isContact)))
            } else {
                assertionFailure()
            }
        }
        return result
    }
    
    func commitDependentTables() {
        for (peerId, previousPeer) in self.updatedInitialPeers {
            if let peer = self.cachedPeers[peerId] {
                let previousTimeout = previousPeer?.timeoutAttribute
                if previousTimeout != peer.timeoutAttribute {
                    if let previousTimeout = previousTimeout {
                        self.peerTimeoutPropertiesTable.remove(peerId: peerId, timestamp: previousTimeout)
                    }
                    if let updatedTimeout = peer.timeoutAttribute {
                        self.peerTimeoutPropertiesTable.add(peerId: peerId, timestamp: updatedTimeout)
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    override func beforeCommit() {
        if !self.updatedInitialPeers.isEmpty {
            for (peerId, previousPeer) in self.updatedInitialPeers {
                if let peer = self.cachedPeers[peerId] {
                    self.sharedEncoder.reset()
                    self.sharedEncoder.encodeRootObject(peer)
                    
                    self.valueBox.set(self.table, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
                    
                    let previousAssociation = previousPeer?.associatedPeerId
                    if previousAssociation != peer.associatedPeerId {
                        if let previousAssociation = previousAssociation {
                            self.reverseAssociatedTable.removeReverseAssociation(target: previousAssociation, from: peerId)
                        }
                        if let associatedPeerId = peer.associatedPeerId {
                            self.reverseAssociatedTable.addReverseAssociation(target: associatedPeerId, from: peerId)
                        }
                    }
                } else {
                    assertionFailure()
                }
            }
            
            self.updatedInitialPeers.removeAll()
            if !self.useCaches {
                self.cachedPeers.removeAll()
            }
        }
    }
}
