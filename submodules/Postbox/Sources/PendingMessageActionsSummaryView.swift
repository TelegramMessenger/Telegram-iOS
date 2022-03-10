
final class MutablePendingMessageActionsSummaryView: MutablePostboxView {
    let key: PendingMessageActionsSummaryKey
    var count: Int32
    
    init(postbox: PostboxImpl, type: PendingMessageActionType, peerId: PeerId, namespace: MessageId.Namespace) {
        self.key = PendingMessageActionsSummaryKey(type: type, peerId: peerId, namespace: namespace)
        self.count = postbox.pendingMessageActionsMetadataTable.getCount(.peerNamespaceAction(peerId, namespace, type))
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let updatedCount = transaction.currentUpdatedMessageActionsSummaries[self.key] {
            updated = true
            self.count = updatedCount
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return PendingMessageActionsSummaryView(self)
    }
}

public final class PendingMessageActionsSummaryView: PostboxView {
    public let count: Int32
    
    init(_ view: MutablePendingMessageActionsSummaryView) {
        self.count = view.count
    }
}
