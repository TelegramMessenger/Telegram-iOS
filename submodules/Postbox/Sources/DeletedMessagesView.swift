import Foundation

final class MutableDeletedMessagesView: MutablePostboxView {
    let peerId: PeerId
    var currentDeletedMessages: [MessageId] = []

    init(peerId: PeerId) {
        self.peerId = peerId
    }

    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let operations = transaction.currentOperationsByPeerId[self.peerId] {
            var testMessageIds: [MessageId] = []
            for operation in operations {
                switch operation {
                    case let .Remove(indices):
                        for (index, _) in indices {
                            testMessageIds.append(index.id)
                        }
                    default:
                        break
                }
            }
            self.currentDeletedMessages.removeAll()
            for id in testMessageIds {
                if !postbox.messageHistoryIndexTable.exists(id) {
                    self.currentDeletedMessages.append(id)
                    updated = true
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }

    func immutableView() -> PostboxView {
        return DeletedMessagesView(self)
    }
}

public final class DeletedMessagesView: PostboxView {
    public let currentDeletedMessages: [MessageId]

    init(_ view: MutableDeletedMessagesView) {
        self.currentDeletedMessages = view.currentDeletedMessages
    }
}
