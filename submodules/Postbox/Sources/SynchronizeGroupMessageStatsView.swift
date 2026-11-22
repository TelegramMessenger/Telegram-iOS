import Foundation

final class MutableSynchronizeGroupMessageStatsView: MutablePostboxView {
    fileprivate var groupsAndNamespaces: Set<PeerGroupAndNamespace>
    
    init(postbox: PostboxImpl) {
        self.groupsAndNamespaces = postbox.synchronizeGroupMessageStatsTable.get()
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.currentUpdatedGroupSummarySynchronizeOperations.isEmpty {
            for (groupIdAndNamespace, value) in transaction.currentUpdatedGroupSummarySynchronizeOperations {
                if value {
                    if !self.groupsAndNamespaces.contains(groupIdAndNamespace) {
                        self.groupsAndNamespaces.insert(groupIdAndNamespace)
                        updated = true
                    }
                } else {
                    if self.groupsAndNamespaces.contains(groupIdAndNamespace) {
                        self.groupsAndNamespaces.remove(groupIdAndNamespace)
                        updated = true
                    }
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*let groupsAndNamespaces = postbox.synchronizeGroupMessageStatsTable.get()
        if self.groupsAndNamespaces != groupsAndNamespaces {
            self.groupsAndNamespaces = groupsAndNamespaces
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return SynchronizeGroupMessageStatsView(self)
    }
}

public final class SynchronizeGroupMessageStatsView: PostboxView {
    public let groupsAndNamespaces: Set<PeerGroupAndNamespace>
    
    init(_ view: MutableSynchronizeGroupMessageStatsView) {
        self.groupsAndNamespaces = view.groupsAndNamespaces
    }
}
