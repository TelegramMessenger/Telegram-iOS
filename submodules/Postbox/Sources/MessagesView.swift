import Foundation

final class MutableMessagesView: MutablePostboxView {
    fileprivate let ids: Set<MessageId>
    private let peerIds: Set<PeerId>
    fileprivate var messages: [MessageId: Message] = [:]
    
    init(postbox: PostboxImpl, ids: Set<MessageId>) {
        self.ids = ids
        self.peerIds = Set(ids.map { $0.peerId })
        for id in ids {
            if let message = postbox.getMessage(id) {
                self.messages[message.id] = message
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updatedIds = Set<MessageId>()
        for peerId in self.peerIds {
            if let operations = transaction.currentOperationsByPeerId[peerId] {
                for operation in operations {
                    switch operation {
                        case let .InsertMessage(message):
                            if self.ids.contains(message.id) {
                                updatedIds.insert(message.id)
                            }
                        case let .Remove(indices):
                            for index in indices {
                                if self.ids.contains(index.0.id) {
                                    updatedIds.insert(index.0.id)
                                }
                            }
                        default:
                            break
                    }
                }
            }
        }
        if !updatedIds.isEmpty {
            for id in updatedIds {
                if let message = postbox.getMessage(id) {
                    self.messages[message.id] = message
                } else {
                    self.messages.removeValue(forKey: id)
                }
            }
            
            return true
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessagesView(self)
    }
}

public final class MessagesView: PostboxView {
    public var messages: [MessageId: Message] = [:]
    
    init(_ view: MutableMessagesView) {
        self.messages = view.messages
    }
}
