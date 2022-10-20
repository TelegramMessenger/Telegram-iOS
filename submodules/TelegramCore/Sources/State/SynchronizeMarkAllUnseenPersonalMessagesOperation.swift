import Foundation
import Postbox
import SwiftSignalKit

func addSynchronizeMarkAllUnseenPersonalMessagesOperation(transaction: Transaction, peerId: PeerId, maxId: MessageId.Id) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeMarkAllUnseenPersonalMessages
    
    var topLocalIndex: Int32?
    var currentMaxId: MessageId.Id?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        topLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeMarkAllUnseenPersonalMessagesOperation {
            currentMaxId = operation.maxId
        }
        return false
    })
    
    if let topLocalIndex = topLocalIndex {
        if let currentMaxId = currentMaxId, currentMaxId >= maxId {
            return
        }
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeMarkAllUnseenPersonalMessagesOperation(maxId: maxId))
}

func addSynchronizeMarkAllUnseenReactionsOperation(transaction: Transaction, peerId: PeerId, maxId: MessageId.Id) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeMarkAllUnseenReactions
    var topLocalIndex: Int32?
    var currentMaxId: MessageId.Id?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        topLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeMarkAllUnseenReactionsOperation {
            currentMaxId = operation.maxId
        }
        return false
    })
    
    if let topLocalIndex = topLocalIndex {
        if let currentMaxId = currentMaxId, currentMaxId >= maxId {
            return
        }
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeMarkAllUnseenReactionsOperation(maxId: maxId))
}
