import Foundation

final class MutableLocalMessageTagsView: MutablePostboxView {
    private let tag: LocalMessageTags
    fileprivate var messages: [MessageId: Message] = [:]
    
    init(postbox: PostboxImpl, tag: LocalMessageTags) {
        self.tag = tag
        for id in postbox.localMessageHistoryTagsTable.get(tag: tag) {
            if let message = postbox.getMessage(id) {
                self.messages[message.id] = message
            } else {
                //assertionFailure()
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for operation in transaction.currentLocalTagsOperations {
            switch operation {
                case let .Insert(tag, id):
                    if tag == self.tag {
                        if let message = postbox.getMessage(id) {
                            self.messages[id] = message
                            updated = true
                        } else {
                            assertionFailure()
                        }
                    }
                case let .Remove(tag, id):
                    if tag == self.tag {
                        if self.messages[id] != nil {
                            self.messages.removeValue(forKey: id)
                            updated = true
                        }
                    }
                case let .Update(tag, id):
                    if tag == self.tag {
                        if self.messages[id] != nil {
                            if let message = postbox.getMessage(id) {
                                self.messages[id] = message
                                updated = true
                            } else {
                                assertionFailure()
                            }
                        }
                    }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return LocalMessageTagsView(self)
    }
}

public final class LocalMessageTagsView: PostboxView {
    public var messages: [MessageId: Message] = [:]
    
    init(_ view: MutableLocalMessageTagsView) {
        self.messages = view.messages
    }
}


