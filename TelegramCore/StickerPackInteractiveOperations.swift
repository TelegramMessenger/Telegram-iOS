import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func addStickerPackInteractively(postbox: Postbox, info: StickerPackCollectionInfo, items: [ItemCollectionItem]) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
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
            addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: namespace)
            var updatedInfos = modifier.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
            if let index = updatedInfos.index(where: { $0.id == info.id }) {
                let currentInfo = updatedInfos[index]
                updatedInfos.remove(at: index)
                updatedInfos.insert(currentInfo, at: 0)
            } else {
                updatedInfos.insert(info, at: 0)
                modifier.replaceItemCollectionItems(collectionId: info.id, items: items)
            }
            modifier.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
        }
    }
}


public func removeStickerPackInteractively(postbox: Postbox, id: ItemCollectionId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
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
            addSynchronizeInstalledStickerPacksOperation(modifier: modifier, namespace: namespace)
            modifier.removeItemCollection(collectionId: id)
        }
    }
}
