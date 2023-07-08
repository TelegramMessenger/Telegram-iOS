import Foundation

final class MutablePeerStoryStatsView: MutablePostboxView {
    let peerIds: Set<PeerId>
    var storyStats: [PeerId: PeerStoryStats] = [:]

    init(postbox: PostboxImpl, peerIds: Set<PeerId>) {
        self.peerIds = peerIds
        for id in self.peerIds {
            if let value = fetchPeerStoryStats(postbox: postbox, peerId: id) {
                self.storyStats[id] = value
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        var updatedPeerIds = Set<PeerId>()
        for event in transaction.currentStoryTopItemEvents {
            if case let .replace(peerId) = event {
                if self.peerIds.contains(peerId) {
                    updatedPeerIds.insert(peerId)
                }
            }
        }
        for event in transaction.storyPeerStatesEvents {
            if case let .set(key) = event, case let .peer(peerId) = key {
                if self.peerIds.contains(peerId) {
                    updatedPeerIds.insert(peerId)
                }
            }
        }
        
        for id in updatedPeerIds {
            let value = fetchPeerStoryStats(postbox: postbox, peerId: id)
            if self.storyStats[id] != value {
                updated = true
                
                if let value = value {
                    self.storyStats[id] = value
                } else {
                    self.storyStats.removeValue(forKey: id)
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        var storyStats: [PeerId: PeerStoryStats] = [:]
        for id in self.peerIds {
            if let value = fetchPeerStoryStats(postbox: postbox, peerId: id) {
                storyStats[id] = value
            }
        }
        if self.storyStats != storyStats {
            self.storyStats = storyStats
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerStoryStatsView(self)
    }
}

public final class PeerStoryStatsView: PostboxView {
    public let storyStats: [PeerId: PeerStoryStats]
    
    init(_ view: MutablePeerStoryStatsView) {
        self.storyStats = view.storyStats
    }
}
