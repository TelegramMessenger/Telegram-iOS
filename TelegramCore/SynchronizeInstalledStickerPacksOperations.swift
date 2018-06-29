import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum SynchronizeInstalledStickerPacksOperationNamespace: Int32 {
    case stickers = 0
    case masks = 1
}

final class SynchronizeInstalledStickerPacksOperation: PostboxCoding {
    let previousPacks: [ItemCollectionId]
    let archivedPacks: [ItemCollectionId]
    
    init(previousPacks: [ItemCollectionId], archivedPacks: [ItemCollectionId]) {
        self.previousPacks = previousPacks
        self.archivedPacks = archivedPacks
    }
    
    init(decoder: PostboxDecoder) {
        self.previousPacks = ItemCollectionId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
        self.archivedPacks = decoder.decodeBytesForKey("ap").flatMap(ItemCollectionId.decodeArrayFromBuffer) ?? []
    }
    
    func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        ItemCollectionId.encodeArrayToBuffer(self.previousPacks, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
        buffer.reset()
        ItemCollectionId.encodeArrayToBuffer(self.archivedPacks, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "ap")
    }
}

final class SynchronizeMarkFeaturedStickerPacksAsSeenOperation: PostboxCoding {
    let ids: [ItemCollectionId]
    
    init(ids: [ItemCollectionId]) {
        self.ids = ids
    }
    
    init(decoder: PostboxDecoder) {
        self.ids = ItemCollectionId.decodeArrayFromBuffer(decoder.decodeBytesForKey("p")!)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        let buffer = WriteBuffer()
        ItemCollectionId.encodeArrayToBuffer(self.ids, buffer: buffer)
        encoder.encodeBytes(buffer, forKey: "p")
    }
}

public enum AddSynchronizeInstalledStickerPacksOperationContent {
    case sync
    case add([ItemCollectionId])
    case remove([ItemCollectionId])
    case archive([ItemCollectionId])
}

public func addSynchronizeInstalledStickerPacksOperation(transaction: Transaction, namespace: ItemCollectionId.Namespace, content: AddSynchronizeInstalledStickerPacksOperationContent) {
    let operationNamespace: SynchronizeInstalledStickerPacksOperationNamespace
    switch namespace {
        case Namespaces.ItemCollection.CloudStickerPacks:
            operationNamespace = .stickers
        case Namespaces.ItemCollection.CloudMaskPacks:
            operationNamespace = .masks
        default:
            return
    }
    addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: operationNamespace, content: content)
}

func addSynchronizeInstalledStickerPacksOperation(transaction: Transaction, namespace: SynchronizeInstalledStickerPacksOperationNamespace, content: AddSynchronizeInstalledStickerPacksOperationContent) {
    var updateLocalIndex: Int32?
    let tag: PeerOperationLogTag
    let itemCollectionNamespace: ItemCollectionId.Namespace
    switch namespace {
        case .stickers:
            tag = OperationLogTags.SynchronizeInstalledStickerPacks
            itemCollectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
        case .masks:
            tag = OperationLogTags.SynchronizeInstalledMasks
            itemCollectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
    }
    var previousStickerPackIds: [ItemCollectionId]?
    var archivedPacks: [ItemCollectionId] = []
    transaction.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: 0), tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeInstalledStickerPacksOperation {
            previousStickerPackIds = operation.previousPacks
            archivedPacks = operation.archivedPacks
        } else {
            assertionFailure()
        }
        return false
    })
    let previousPacks = previousStickerPackIds ?? transaction.getItemCollectionsInfos(namespace: itemCollectionNamespace).map { $0.0 }
    switch content {
        case .sync:
            break
        case let .add(ids):
            let idsSet = Set(ids)
            archivedPacks = archivedPacks.filter({ !idsSet.contains($0) })
        case let .remove(ids):
            let idsSet = Set(ids)
            archivedPacks = archivedPacks.filter({ !idsSet.contains($0) })
        case let .archive(ids):
            for id in ids {
                if !archivedPacks.contains(id) {
                    archivedPacks.append(id)
                }
            }
    }
    let operationContents = SynchronizeInstalledStickerPacksOperation(previousPacks: previousPacks, archivedPacks: archivedPacks)
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}

func addSynchronizeMarkFeaturedStickerPacksAsSeenOperation(transaction: Transaction, ids: [ItemCollectionId]) {
    var updateLocalIndex: Int32?
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeMarkFeaturedStickerPacksAsSeen
    var previousIds = Set<ItemCollectionId>()
    transaction.operationLogEnumerateEntries(peerId: PeerId(namespace: 0, id: 0), tag: tag, { entry in
        updateLocalIndex = entry.tagLocalIndex
        if let operation = entry.contents as? SynchronizeMarkFeaturedStickerPacksAsSeenOperation {
            previousIds = Set(operation.ids)
        } else {
            assertionFailure()
        }
        return false
    })
    let operationContents = SynchronizeMarkFeaturedStickerPacksAsSeenOperation(ids: Array(previousIds.union(Set(ids))))
    if let updateLocalIndex = updateLocalIndex {
        let _ = transaction.operationLogRemoveEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: updateLocalIndex)
    }
    transaction.operationLogAddEntry(peerId: PeerId(namespace: 0, id: 0), tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operationContents)
}
