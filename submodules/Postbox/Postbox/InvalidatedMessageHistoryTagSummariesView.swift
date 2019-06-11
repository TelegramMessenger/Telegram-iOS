
final class MutableInvalidatedMessageHistoryTagSummariesView: MutablePostboxView {
    private let namespace: MessageId.Namespace
    private let tagMask: MessageTags
    
    var entries = Set<InvalidatedMessageHistoryTagsSummaryEntry>()
    
    init(postbox: Postbox, tagMask: MessageTags, namespace: MessageId.Namespace) {
        self.tagMask = tagMask
        self.namespace = namespace
        
        for entry in postbox.invalidatedMessageHistoryTagsSummaryTable.get(tagMask: tagMask, namespace: namespace) {
            self.entries.insert(entry)
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
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
        return updated
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

