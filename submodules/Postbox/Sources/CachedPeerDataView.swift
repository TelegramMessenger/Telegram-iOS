import Foundation

final class MutableCachedPeerDataView: MutablePostboxView {
    let peerId: PeerId
    var cachedPeerData: CachedPeerData?
    
    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        self.cachedPeerData = postbox.cachedPeerDataTable.get(peerId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if let cachedPeerData = transaction.currentUpdatedCachedPeerData[self.peerId] {
            self.cachedPeerData = cachedPeerData
            return true
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return CachedPeerDataView(self)
    }
}

public final class CachedPeerDataView: PostboxView {
    public let peerId: PeerId
    public let cachedPeerData: CachedPeerData?
    
    init(_ view: MutableCachedPeerDataView) {
        self.peerId = view.peerId
        self.cachedPeerData = view.cachedPeerData
    }
}
