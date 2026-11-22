import Foundation

final class MutablePeerTimeoutAttributesView: MutablePostboxView {
    fileprivate var minValue: (peerId: PeerId, timestamp: UInt32)?
    
    init(postbox: PostboxImpl) {
        self.minValue = postbox.peerTimeoutPropertiesTable.min()
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.updatedPeerTimeoutAttributes {
            let minValue = postbox.peerTimeoutPropertiesTable.min()
            if self.minValue?.0 != minValue?.0 || self.minValue?.1 != minValue?.1 {
                updated = true
                self.minValue = minValue
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let minValue = postbox.peerTimeoutPropertiesTable.min()
        if self.minValue?.0 != minValue?.0 || self.minValue?.1 != minValue?.1 {
            self.minValue = minValue
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerTimeoutAttributesView(self)
    }
}

public final class PeerTimeoutAttributesView: PostboxView {
    public let minValue: (peerId: PeerId, timestamp: UInt32)?
    
    init(_ view: MutablePeerTimeoutAttributesView) {
        self.minValue = view.minValue
    }
}
