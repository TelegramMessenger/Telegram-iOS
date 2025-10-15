import Foundation
import Postbox

func addSynchronizeChatInputStateOperation(transaction: Transaction, peerId: PeerId, threadId: Int64?) {
    var removeLocalIndices: [Int32] = []
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatInputStates
    
    var previousOperation: SynchronizeChatInputStateOperation?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeChatInputStateOperation {
            if operation.threadId == threadId {
                previousOperation = operation
                removeLocalIndices.append(entry.tagLocalIndex)
                return false
            }
        } else {
            removeLocalIndices.append(entry.tagLocalIndex)
        }
        return true
    })
    var previousState: SynchronizeableChatInputState?
    if let previousOperation = previousOperation {
        previousState = previousOperation.previousState
    } else {
        let peerChatInterfaceState: StoredPeerChatInterfaceState?
        if let threadId = threadId {
            peerChatInterfaceState = transaction.getPeerChatThreadInterfaceState(peerId, threadId: threadId)
        } else {
            peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId)
        }
        
        if let peerChatInterfaceState = peerChatInterfaceState, let data = peerChatInterfaceState.data {
            previousState = (try? AdaptedPostboxDecoder().decode(InternalChatInterfaceState.self, from: data))?.synchronizeableInputState
        }
    }
    let operationContents = SynchronizeChatInputStateOperation(previousState: previousState, threadId: threadId)
    for index in removeLocalIndices {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: index)
    }
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
