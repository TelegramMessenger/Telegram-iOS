import Foundation

final class MutableMessageGroupView: MutablePostboxView {
    fileprivate let id: MessageId
    fileprivate let groupingKey: Int64?
    fileprivate var messages: [Message] = []
    
    init(postbox: PostboxImpl, id: MessageId) {
        self.id = id
        self.messages = postbox.getMessageGroup(at: id) ?? []
        self.groupingKey = self.messages.first?.groupingKey
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let operations = transaction.currentOperationsByPeerId[self.id.peerId] {
            outer: for operation in operations {
                switch operation {
                case let .InsertMessage(message):
                    if let groupingKey = self.groupingKey, message.groupingKey == groupingKey {
                        updated = true
                        break outer
                    } else if message.id == self.id {
                        updated = true
                        break outer
                    }
                case let .Remove(indices):
                    for index in indices {
                        for message in self.messages {
                            if index.0.id == message.id {
                                updated = true
                                break outer
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
        if updated {
            self.messages = postbox.getMessageGroup(at: self.id) ?? []
            
            return true
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageGroupView(self)
    }
}

public final class MessageGroupView: PostboxView {
    public let messages: [Message]
    
    init(_ view: MutableMessageGroupView) {
        self.messages = view.messages
    }
}
