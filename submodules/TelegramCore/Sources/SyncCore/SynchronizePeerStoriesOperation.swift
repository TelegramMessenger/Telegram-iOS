import Foundation
import Postbox

public final class SynchronizePeerStoriesOperation: PostboxCoding {
    public init() {
    }
    
    public init(decoder: PostboxDecoder) {
    }
    
    public func encode(_ encoder: PostboxEncoder) {
    }
}

func _internal_addSynchronizePeerStoriesOperation(peerId: PeerId, transaction: Transaction) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizePeerStories
    
    var topOperation: (SynchronizePeerStoriesOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizePeerStoriesOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    var replace = false
    if topOperation == nil {
        replace = true
    }
    if replace {
        transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizePeerStoriesOperation())
    }
}
