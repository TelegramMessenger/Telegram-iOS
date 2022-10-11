import Foundation

final class MutableMessageHistoryTagSummaryView: MutablePostboxView {
    private let tag: MessageTags
    private let peerId: PeerId
    private let threadId: Int64?
    private let namespace: MessageId.Namespace
    
    fileprivate var count: Int32?
    
    init(postbox: PostboxImpl, tag: MessageTags, peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) {
        self.tag = tag
        self.peerId = peerId
        self.threadId = threadId
        self.namespace = namespace
        
        self.count = postbox.messageHistoryTagsSummaryTable.get(MessageHistoryTagsSummaryKey(tag: tag, peerId: peerId, threadId: threadId, namespace: namespace))?.count
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var hasChanges = false
        
        if let summary = transaction.currentUpdatedMessageTagSummaries[MessageHistoryTagsSummaryKey(tag: self.tag, peerId: self.peerId, threadId: self.threadId, namespace: self.namespace)] {
            self.count = summary.count
            hasChanges = true
        }
        
        return hasChanges
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*let count = postbox.messageHistoryTagsSummaryTable.get(MessageHistoryTagsSummaryKey(tag: self.tag, peerId: self.peerId, namespace: self.namespace))?.count
        if self.count != count {
            self.count = count
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageHistoryTagSummaryView(self)
    }
}

public final class MessageHistoryTagSummaryView: PostboxView {
    public let count: Int32?
    
    init(_ view: MutableMessageHistoryTagSummaryView) {
        self.count = view.count
    }
}
