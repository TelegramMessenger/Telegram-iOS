import Foundation

final class MutableContactPeerIdsView {
    fileprivate var remoteTotalCount: Int32
    fileprivate var peerIds: Set<PeerId>
    
    init(remoteTotalCount: Int32, peerIds: Set<PeerId>) {
        self.remoteTotalCount = remoteTotalCount
        self.peerIds = peerIds
    }
    
    func replay(updateRemoteTotalCount: Int32?, replace replacePeerIds: Set<PeerId>) -> Bool {
        var updated = false
        if let updateRemoteTotalCount = updateRemoteTotalCount, self.remoteTotalCount != updateRemoteTotalCount {
            self.remoteTotalCount = updateRemoteTotalCount
            updated = true
        }
        if self.peerIds != replacePeerIds {
            self.peerIds = replacePeerIds
            updated = true
        }
        return updated
    }
}

public final class ContactPeerIdsView {
    public let remoteTotalCount: Int32
    public let peerIds: Set<PeerId>
    
    init(_ mutableView: MutableContactPeerIdsView) {
        self.remoteTotalCount = mutableView.remoteTotalCount
        self.peerIds = mutableView.peerIds
    }
}
