import Foundation
import Postbox

func addSynchronizeChatInputStateOperation(transaction: Transaction, peerId: PeerId) {
    var updateLocalIndex: Int32?
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatInputStates
    
    var previousOperation: SynchronizeChatInputStateOperation?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeChatInputStateOperation {
            previousOperation = operation
        }
        return false
    })
    var previousState: SynchronizeableChatInputState?
    if let previousOperation = previousOperation {
        previousState = previousOperation.previousState
    } else if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId), let data = peerChatInterfaceState.data {
        previousState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
    }
    let operationContents = SynchronizeChatInputStateOperation(previousState: previousState)
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
