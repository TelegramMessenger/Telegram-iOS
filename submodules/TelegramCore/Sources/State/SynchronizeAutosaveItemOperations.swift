import Foundation
import Postbox
import SwiftSignalKit

public final class SynchronizeAutosaveItemOperation: PostboxCoding {
    public struct Content: Codable {
        public var messageId: MessageId
        public var mediaId: MediaId
        
        public init(messageId: MessageId, mediaId: MediaId) {
            self.messageId = messageId
            self.mediaId = mediaId
        }
    }
    
    public let messageId: MessageId
    public let mediaId: MediaId
    
    public init(messageId: MessageId, mediaId: MediaId) {
        self.messageId = messageId
        self.mediaId = mediaId
    }
    
    public init(decoder: PostboxDecoder) {
        if let content = decoder.decode(Content.self, forKey: "c") {
            self.messageId = content.messageId
            self.mediaId = content.mediaId
        } else {
            self.messageId = MessageId(peerId: PeerId(0), namespace: 0, id: 0)
            self.mediaId = MediaId(namespace: 0, id: 0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encode(Content(messageId: self.messageId, mediaId: self.mediaId), forKey: "c")
    }
}

public func addSynchronizeAutosaveItemOperation(transaction: Transaction, messageId: MessageId, mediaId: MediaId) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAutosaveItems
    let peerId = PeerId(0)
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAutosaveItemOperation(messageId: messageId, mediaId: mediaId))
}

public func addSynchronizeAutosaveItemOperation(postbox: Postbox, messageId: MessageId, mediaId: MediaId) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        addSynchronizeAutosaveItemOperation(transaction: transaction, messageId: messageId, mediaId: mediaId)
    }
    |> ignoreValues
}

public func _internal_getSynchronizeAutosaveItemOperations(transaction: Transaction) -> [(index: Int32, message: Message, mediaId: MediaId)] {
    let peerId = PeerId(0)
    var result: [(index: Int32, message: Message, mediaId: MediaId)] = []
    var removeIndices: [Int32] = []
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SynchronizeAutosaveItems, { entry in
        if let operation = entry.contents as? SynchronizeAutosaveItemOperation {
            if let message = transaction.getMessage(operation.messageId) {
                result.append((index: entry.tagLocalIndex, message: message, mediaId: operation.mediaId))
            } else {
                removeIndices.append(entry.tagLocalIndex)
            }
        }
        return true
    })
    for index in removeIndices {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(0), tag: OperationLogTags.SynchronizeAutosaveItems, tagLocalIndex: index)
    }
    
    return result
}

public func _internal_removeSyncrhonizeAutosaveItemOperations(transaction: Transaction, indices: [Int32]) {
    for index in indices {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(0), tag: OperationLogTags.SynchronizeAutosaveItems, tagLocalIndex: index)
    }
}
