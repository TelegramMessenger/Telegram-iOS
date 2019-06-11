import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

final class SynchronizeMarkAllUnseenPersonalMessagesOperation: PostboxCoding {
    let maxId: MessageId.Id
    
    init(maxId: MessageId.Id) {
        self.maxId = maxId
    }
    
    init(decoder: PostboxDecoder) {
        self.maxId = decoder.decodeInt32ForKey("maxId", orElse: Int32.min + 1)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.maxId, forKey: "maxId")
    }
}

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
