import Foundation

final class MutableOrderedContactsView: MutablePostboxView {
    fileprivate let id: UInt32
    fileprivate var version: Int32 = 0
    
    fileprivate var updatedPresences: [PeerId: PeerPresence] = [:]
    fileprivate var updatedPeers: [Peer] = []
    
    init(postbox: Postbox) {
        self.id = postbox.takeNextUniqueId()
        
        for peerId in postbox.contactsTable.get() {
            if let peer = postbox.peerTable.get(peerId) {
                self.updatedPeers.append(peer)
                if let presence = postbox.peerPresenceTable.get(peerId) {
                    self.updatedPresences[peerId] = presence
                }
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if !transaction.currentUpdatedPeerPresences.isEmpty {
            
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return OrderedContactsView(self)
    }
}

public final class OrderedContactsView: PostboxView {
    public let id: UInt32
    public let version: Int32
    public let updatedPresences: [PeerId: PeerPresence]
    public let updatedPeers: [Peer]
    
    init(_ view: MutableOrderedContactsView) {
        self.id = view.id
        self.version = view.version
        self.updatedPresences = view.updatedPresences
        self.updatedPeers = view.updatedPeers
    }
}
