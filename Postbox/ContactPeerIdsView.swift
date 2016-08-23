import Foundation

final class MutableContactPeerIdsView {
    fileprivate var peerIds: Set<PeerId>
    
    init(peerIds: Set<PeerId>) {
        self.peerIds = peerIds
    }
    
    func replay(replace replacePeerIds: Set<PeerId>) -> Bool {
        if self.peerIds != replacePeerIds {
            self.peerIds = replacePeerIds
            return true
        } else {
            return false
        }
    }
}

public final class ContactPeerIdsView {
    public let peerIds: Set<PeerId>
    
    init(_ mutableView: MutableContactPeerIdsView) {
        self.peerIds = mutableView.peerIds
    }
}
