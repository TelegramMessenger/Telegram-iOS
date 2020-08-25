import Foundation
import SyncCore
import Postbox
import SwiftSignalKit

private class ReplyThreadHistoryContextImpl {
    private let queue: Queue
    private let account: Account
    
    struct NamespaceState: Equatable {
        var sortedMessageIds: [MessageId]
        var holeIndices: IndexSet
    }
    
    init(queue: Queue, account: Account) {
        self.queue = queue
        self.account = account
    }
}

class ReplyThreadHistoryContext {
    private let queue = Queue()
    private let impl: QueueLocalObject<ReplyThreadHistoryContextImpl>
    
    public init(account: Account, peerId: PeerId, threadMessageId: MessageId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ReplyThreadHistoryContextImpl(queue: queue, account: account)
        })
    }
}
