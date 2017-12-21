import Foundation

final class MutableGroupFeedReadStateSyncOperationsView: MutablePostboxView {
    var entries: [PeerGroupId: GroupFeedReadStateSyncOperation] = [:]
    
    init(postbox: Postbox) {
        self.entries = postbox.groupFeedReadStateTable.getSyncOperations()
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.currentGroupFeedReadStateContext.updatedOperations.isEmpty {
            self.entries = postbox.groupFeedReadStateTable.getSyncOperations()
            updated = true
        }
        return updated
    }
    
    func immutableView() -> PostboxView {
        return GroupFeedReadStateSyncOperationsView(self)
    }
}

public final class GroupFeedReadStateSyncOperationsView: PostboxView {
    public var entries: [PeerGroupId: GroupFeedReadStateSyncOperation] = [:]
    
    init(_ view: MutableGroupFeedReadStateSyncOperationsView) {
        self.entries = view.entries
    }
}

