import Foundation

final class MutablePeerGroupStateView: MutablePostboxView {
    let groupId: PeerGroupId
    var state: PeerGroupState?
    
    init(postbox: Postbox, groupId: PeerGroupId) {
        self.groupId = groupId
        self.state = postbox.peerGroupStateTable.get(groupId)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if transaction.currentUpdatedPeerGroupStates.contains(self.groupId) {
            self.state = postbox.peerGroupStateTable.get(self.groupId)
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return PeerGroupStateView(self)
    }
}

public final class PeerGroupStateView: PostboxView {
    public let groupId: PeerGroupId
    public let state: PeerGroupState?
    
    init(_ view: MutablePeerGroupStateView) {
        self.groupId = view.groupId
        self.state = view.state
    }
}

