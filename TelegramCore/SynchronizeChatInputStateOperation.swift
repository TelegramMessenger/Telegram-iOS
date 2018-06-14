import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class SynchronizeChatInputStateOperation: PostboxCoding {
    let previousState: SynchronizeableChatInputState?
    
    init(previousState: SynchronizeableChatInputState?) {
        self.previousState = previousState
    }
    
    init(decoder: PostboxDecoder) {
        self.previousState = decoder.decodeObjectForKey("p", decoder: { SynchronizeableChatInputState(decoder: $0) }) as? SynchronizeableChatInputState
    }
    
    func encode(_ encoder: PostboxEncoder) {
        if let previousState = self.previousState {
            encoder.encodeObject(previousState, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
    }
}

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
    } else if let peerChatInterfaceState = transaction.getPeerChatInterfaceState(peerId) as? SynchronizeableChatInterfaceState {
        previousState = peerChatInterfaceState.synchronizeableInputState
    }
    let operationContents = SynchronizeChatInputStateOperation(previousState: previousState)
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
