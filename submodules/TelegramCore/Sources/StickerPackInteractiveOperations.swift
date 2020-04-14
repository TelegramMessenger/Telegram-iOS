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
            var mappedInfo = info
            if items.isEmpty {
                mappedInfo = StickerPackCollectionInfo(id: info.id, flags: info.flags, accessHash: info.accessHash, title: info.title, shortName: info.shortName, thumbnail: info.thumbnail, hash: Int32(bitPattern: arc4random()), count: info.count)
            }
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: .add([mappedInfo.id]), noDelay: items.isEmpty)
            var updatedInfos = transaction.getItemCollectionsInfos(namespace: mappedInfo.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
            if let index = updatedInfos.firstIndex(where: { $0.id == mappedInfo.id }) {
                let currentInfo = updatedInfos[index]
                updatedInfos.remove(at: index)
                updatedInfos.insert(currentInfo, at: 0)
            } else {
                if let positionInList = positionInList, positionInList <= updatedInfos.count {
                    updatedInfos.insert(mappedInfo, at: positionInList)
                } else {
                    updatedInfos.insert(mappedInfo, at: 0)
                }
                transaction.replaceItemCollectionItems(collectionId: mappedInfo.id, items: items)
            }
            transaction.replaceItemCollectionInfos(namespace: mappedInfo.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
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
            let index = transaction.getItemCollectionsInfos(namespace: id.namespace).firstIndex(where: { $0.0 == id })
            let items = transaction.getItemCollectionItems(collectionId: id)
            
            addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: content, noDelay: false)
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
