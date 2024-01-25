import Foundation

final class MutableMessageHistoryCustomTagSummariesView: MutablePostboxView {
    private let peerId: PeerId
    private let threadId: Int64?
    private let namespace: MessageId.Namespace
    
    fileprivate var tags: [MemoryBuffer: Int] = [:]
    
    init(postbox: PostboxImpl, peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) {
        self.peerId = peerId
        self.threadId = threadId
        self.namespace = namespace

        self.reload(postbox: postbox)
    }
    
    private func reload(postbox: PostboxImpl) {
        self.tags.removeAll()
        
        for tag in postbox.messageHistoryTagsSummaryTable.getCustomTags(tag: [], peerId: self.peerId, threadId: self.threadId, namespace: self.namespace) {
            if let summary = postbox.messageHistoryTagsSummaryTable.get(MessageHistoryTagsSummaryKey(tag: [], peerId: self.peerId, threadId: self.threadId, namespace: self.namespace, customTag: tag)) {
                if summary.count > 0 {
                    self.tags[tag] = Int(summary.count)
                }
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var hasChanges = false
        
        for key in transaction.currentUpdatedMessageTagSummaries.keys {
            if key.peerId == self.peerId && key.namespace == self.namespace && key.customTag != nil && key.threadId == self.threadId {
                hasChanges = true
                break
            }
        }
        if hasChanges {
            self.reload(postbox: postbox)
        }
        
        return hasChanges
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageHistoryCustomTagSummariesView(self)
    }
}

public final class MessageHistoryCustomTagSummariesView: PostboxView {
    public let tags: [MemoryBuffer: Int]
    
    init(_ view: MutableMessageHistoryCustomTagSummariesView) {
        self.tags = view.tags
    }
}
