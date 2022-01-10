import Foundation
import Postbox

private struct PreviousPeerItemId: PostboxCoding {
    public let id: PinnedItemId
    
    public init(_ id: PinnedItemId) {
        self.id = id
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self.id = .peer(PeerId(decoder.decodeInt64ForKey("i", orElse: 0)))
            default:
                preconditionFailure()
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self.id {
            case let .peer(peerId):
                encoder.encodeInt32(0, forKey: "_t")
                encoder.encodeInt64(peerId.toInt64(), forKey: "i")
        }
    }
}

public final class SynchronizePinnedChatsOperation: PostboxCoding {
    public let previousItemIds: [PinnedItemId]
    
    public init(previousItemIds: [PinnedItemId]) {
        self.previousItemIds = previousItemIds
    }
    
    public init(decoder: PostboxDecoder) {
        let wrappedIds: [PreviousPeerItemId] = decoder.decodeObjectArrayWithDecoderForKey("previousItemIds")
        self.previousItemIds = wrappedIds.map { $0.id }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.previousItemIds.map(PreviousPeerItemId.init), forKey: "previousItemIds")
    }
}

public func addSynchronizePinnedChatsOperation(transaction: Transaction, groupId: PeerGroupId) {
    let rawId: Int32 = groupId.rawValue
    var previousItemIds = transaction.getPinnedItemIds(groupId: groupId)
    var updateLocalIndex: Int32?
    
    transaction.operationLogEnumerateEntries(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(Int64(rawId))), tag: OperationLogTags.SynchronizePinnedChats, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let contents = entry.contents as? SynchronizePinnedChatsOperation {
            previousItemIds = contents.previousItemIds
        }
        return false
    })
    let operationContents = SynchronizePinnedChatsOperation(previousItemIds: previousItemIds)
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(Int64(rawId))), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(Int64(rawId))), tag: OperationLogTags.SynchronizePinnedChats, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
