import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class SynchronizeChatInputStateOperation: Coding {
    let previousState: SynchronizeableChatInputState?
    
    init(previousState: SynchronizeableChatInputState?) {
        self.previousState = previousState
    }
    
    init(decoder: Decoder) {
        self.previousState = decoder.decodeObjectForKey("p", decoder: { SynchronizeableChatInputState(decoder: $0) }) as? SynchronizeableChatInputState
    }
    
    func encode(_ encoder: Encoder) {
        if let previousState = self.previousState {
            encoder.encodeObject(previousState, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
    }
}

func addSynchronizeChatInputStateOperation(modifier: Modifier, peerId: PeerId) {
    var updateLocalIndex: Int32?
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatInputStates
    
    var previousOperation: SynchronizeChatInputStateOperation?
    modifier.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeChatInputStateOperation {
            previousOperation = operation
        }
        return false
    })
    var previousState: SynchronizeableChatInputState?
    if let previousOperation = previousOperation {
        previousState = previousOperation.previousState
    } else if let peerChatInterfaceState = modifier.getPeerChatInterfaceState(peerId) as? SynchronizeableChatInterfaceState {
        previousState = peerChatInterfaceState.synchronizeableInputState
    }
    let operationContents = SynchronizeChatInputStateOperation(previousState: previousState)
    if let updateLocalIndex = updateLocalIndex {
        let _ = modifier.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: updateLocalIndex)
    }
    modifier.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
