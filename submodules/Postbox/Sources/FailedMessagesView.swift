final class MutableFailedMessageIdsView {
    let peerId: PeerId
    var ids: Set<MessageId>
    
    init(peerId: PeerId, ids: [MessageId]) {
        self.peerId = peerId
        self.ids = Set(ids)
    }
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        let ids = transaction.updatedFailedMessageIds.filter { $0.peerId == self.peerId }
        let updated = ids != self.ids
        self.ids = ids
        return updated
    }
    
    func immutableView() -> FailedMessageIdsView {
        return FailedMessageIdsView(self.ids)
    }
    
}



public final class FailedMessageIdsView {
    public let ids: Set<MessageId>

    fileprivate init(_ ids: Set<MessageId>) {
        self.ids = ids
    }
}
