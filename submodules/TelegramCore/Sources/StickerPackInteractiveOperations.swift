import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

public func addStickerPackInteractively(postbox: Postbox, info: StickerPackCollectionInfo, items: [ItemCollectionItem], positionInList: Int? = nil) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let namespace: SynchronizeInstalledStickerPacksOperationNamespace?
        switch info.id.namespace {
            case Namespaces.ItemCollection.CloudStickerPacks:
                namespace = .stickers
            case Namespaces.ItemCollection.CloudMaskPacks:
                namespace = .masks
            default:
                namespace = nil
        }
        if let namespace = namespace {
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: .add([info.id]))
            var updatedInfos = transaction.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
            if let index = updatedInfos.firstIndex(where: { $0.id == info.id }) {
                let currentInfo = updatedInfos[index]
                updatedInfos.remove(at: index)
                updatedInfos.insert(currentInfo, at: 0)
            } else {
                if let positionInList = positionInList, positionInList <= updatedInfos.count {
                    updatedInfos.insert(info, at: positionInList)
                } else {
                    updatedInfos.insert(info, at: 0)
                }
                transaction.replaceItemCollectionItems(collectionId: info.id, items: items)
            }
            transaction.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
        }
    }
}

public enum RemoveStickerPackOption {
    case delete
    case archive
}

public func removeStickerPackInteractively(postbox: Postbox, id: ItemCollectionId, option: RemoveStickerPackOption) -> Signal<(Int, [ItemCollectionItem])?, NoError> {
    return postbox.transaction { transaction -> (Int, [ItemCollectionItem])? in
        let namespace: SynchronizeInstalledStickerPacksOperationNamespace?
        switch id.namespace {
            case Namespaces.ItemCollection.CloudStickerPacks:
                namespace = .stickers
            case Namespaces.ItemCollection.CloudMaskPacks:
                namespace = .masks
            default:
                namespace = nil
        }
        if let namespace = namespace {
            let content: AddSynchronizeInstalledStickerPacksOperationContent
            switch option {
                case .delete:
                    content = .remove([id])
                case .archive:
                    content = .archive([id])
            }
            let index = transaction.getItemCollectionsInfos(namespace: id.namespace).index(where: { $0.0 == id })
            let items = transaction.getItemCollectionItems(collectionId: id)
            
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: content)
            transaction.removeItemCollection(collectionId: id)
            return index.flatMap { ($0, items) }
        } else {
            return nil
        }
    }
}

public func markFeaturedStickerPacksAsSeenInteractively(postbox: Postbox, ids: [ItemCollectionId]) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let idsSet = Set(ids)
        var items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
        var readIds = Set<ItemCollectionId>()
        for i in 0 ..< items.count {
            let item = (items[i].contents as! FeaturedStickerPackItem)
            if item.unread && idsSet.contains(item.info.id) {
                readIds.insert(item.info.id)
                items[i] = OrderedItemListEntry(id: items[i].id, contents: FeaturedStickerPackItem(info: item.info, topItems: item.topItems, unread: false))
            }
        }
        if !readIds.isEmpty {
            transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudFeaturedStickerPacks, items: items)
            addSynchronizeMarkFeaturedStickerPacksAsSeenOperation(transaction: transaction, ids: Array(readIds))
        }
    }
}
