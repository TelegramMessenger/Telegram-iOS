
final class MutablePendingMessageActionsView: MutablePostboxView {
    let type: PendingMessageActionType
    var entries: [PendingMessageActionsEntry]
    
    init(postbox: PostboxImpl, type: PendingMessageActionType) {
        self.type = type
        self.entries = postbox.pendingMessageActionsTable.getActions(type: type)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for operation in transaction.currentPendingMessageActionsOperations {
            switch operation {
                case let .add(type, id, data):
                    if type == self.type {
                        var insertIndex = self.entries.count
                        while insertIndex > 0 {
                            if self.entries[insertIndex - 1].id < id {
                                break
                            }
                            insertIndex -= 1
                        }
                        self.entries.insert(PendingMessageActionsEntry(id: id, action: data), at: insertIndex)
                        updated = true
                    }
                case let .remove(type, id):
                    if type == self.type {
                        loop: for i in 0 ..< self.entries.count {
                            if self.entries[i].id == id {
                                self.entries.remove(at: i)
                                updated = true
                                break loop
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
        return PendingMessageActionsView(self)
    }
}

public final class PendingMessageActionsView: PostboxView {
    public let entries: [PendingMessageActionsEntry]
    
    init(_ view: MutablePendingMessageActionsView) {
        self.entries = view.entries
    }
}
