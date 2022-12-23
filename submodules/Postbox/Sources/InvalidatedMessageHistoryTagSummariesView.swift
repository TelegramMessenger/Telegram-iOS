
final class MutableInvalidatedMessageHistoryTagSummariesView: MutablePostboxView {
    private let peerId: PeerId?
    private let threadId: Int64?
    private let namespace: MessageId.Namespace
    private let tagMask: MessageTags
    
    var entries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
    
    init(postbox: PostboxImpl, peerId: PeerId?, threadId: Int64?, tagMask: MessageTags, namespace: MessageId.Namespace) {
        self.peerId = peerId
        self.threadId = threadId
        self.tagMask = tagMask
        self.namespace = namespace
        
        if let peerId = self.peerId {
            if let entry = postbox.invalidatedMessageHistoryTagsSummaryTable.get(peerId: peerId, threadId: self.threadId, tagMask: self.tagMask, namespace: self.namespace) {
                self.entries.insert(entry)
            }
        } else {
            for entry in postbox.invalidatedMessageHistoryTagsSummaryTable.get(tagMask: tagMask, namespace: namespace) {
                self.entries.insert(entry)
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if let peerId = self.peerId {
            var maybeUpdated = false
            loop: for operation in transaction.currentInvalidateMessageTagSummaries {
                switch operation {
                case let .add(entry):
                    if entry.key.peerId == peerId && entry.key.threadId == self.threadId {
                        maybeUpdated = true
                        break loop
                    }
                case let .remove(key):
                    if key.peerId == peerId && key.threadId == self.threadId {
                        maybeUpdated = true
                        break loop
                    }
                }
            }
            if maybeUpdated {
                self.entries.removeAll()
                if let entry = postbox.invalidatedMessageHistoryTagsSummaryTable.get(peerId: peerId, threadId: self.threadId, tagMask: self.tagMask, namespace: self.namespace) {
                    self.entries.insert(entry)
                }
                updated = true
            }
        } else {
            for operation in transaction.currentInvalidateMessageTagSummaries {
                switch operation {
                case let .add(entry):
                    if entry.key.namespace == self.namespace && entry.key.tagMask == self.tagMask {
                        self.entries.insert(entry)
                        updated = true
                    }
                case let .remove(key):
                    if key.namespace == self.namespace && key.tagMask == self.tagMask {
                        for entry in self.entries {
                            if entry.key == key {
                                self.entries.remove(entry)
                                break
                            }
                        }
                        updated = true
                    }
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*var entries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
        for entry in postbox.invalidatedMessageHistoryTagsSummaryTable.get(tagMask: tagMask, namespace: namespace) {
            entries.insert(entry)
        }
        if self.entries != entries {
            self.entries = entries
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return InvalidatedMessageHistoryTagSummariesView(self)
    }
}

public final class InvalidatedMessageHistoryTagSummariesView: PostboxView {
    public let entries: Set<InvalidatedMessageHistoryTagsSummaryEntry>
    
    init(_ view: MutableInvalidatedMessageHistoryTagSummariesView) {
        self.entries = view.entries
    }
}

