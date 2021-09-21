import Foundation

final class MutablePeerPresencesView: MutablePostboxView {
    fileprivate let ids: Set<PeerId>
    fileprivate var presences: [PeerId: PeerPresence] = [:]
    
    init(postbox: PostboxImpl, ids: Set<PeerId>) {
        self.ids = ids
        for id in ids {
            if let presence = postbox.peerPresenceTable.get(id) {
                self.presences[id] = presence
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.currentUpdatedPeerPresences.isEmpty {
            for (id, presence) in transaction.currentUpdatedPeerPresences {
                if self.ids.contains(id) {
                    self.presences[id] = presence
                    updated = true
                }
            }
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return PeerPresencesView(self)
    }
}

public final class PeerPresencesView: PostboxView {
    public let presences: [PeerId: PeerPresence]
    
    init(_ view: MutablePeerPresencesView) {
        self.presences = view.presences
    }
}
