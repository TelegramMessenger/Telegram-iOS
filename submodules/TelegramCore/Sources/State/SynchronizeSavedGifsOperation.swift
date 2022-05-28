import Foundation
import Postbox
import SwiftSignalKit


func addSynchronizeSavedGifsOperation(transaction: Transaction, operation: SynchronizeSavedGifsOperationContent) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeSavedGifs
    let peerId = PeerId(0)
    
    var topOperation: (SynchronizeSavedGifsOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeSavedGifsOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: operation))
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeSavedGifsOperation(content: .sync))
}

public func getIsGifSaved(transaction: Transaction, mediaId: MediaId) -> Bool {
    if transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: RecentMediaItemId(mediaId).rawValue) != nil {
        return true
    }
    return false
}

public func addSavedGif(postbox: Postbox, fileReference: FileMediaReference, limit: Int = 200) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let resource = fileReference.media.resource as? CloudDocumentMediaResource {
            if let entry = CodableEntry(RecentMediaItem(fileReference.media)) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(fileReference.media.fileId).rawValue, contents: entry), removeTailIfCountExceeds: limit)
            }
            addSynchronizeSavedGifsOperation(transaction: transaction, operation: .add(id: resource.fileId, accessHash: resource.accessHash, fileReference: fileReference))
        }
    }
}

public func removeSavedGif(postbox: Postbox, mediaId: MediaId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        if let entry = transaction.getOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: RecentMediaItemId(mediaId).rawValue), let item = entry.contents.get(RecentMediaItem.self) {
            let file = item.media
            if let resource = file.resource as? CloudDocumentMediaResource {
                transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, itemId: entry.id)
                addSynchronizeSavedGifsOperation(transaction: transaction, operation: .remove(id: resource.fileId, accessHash: resource.accessHash))
            }
        }
    }
}


public enum SavedGifResult {
    case generic
    case limitExceeded(Int32, Int32)
}

public func toggleGifSaved(account: Account, fileReference: FileMediaReference, saved: Bool) -> Signal<SavedGifResult, NoError> {
    if saved {
        return account.postbox.transaction { transaction -> Signal<SavedGifResult, NoError> in
            let isPremium = transaction.getPeer(account.peerId)?.isPremium ?? false
            let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs)
            
            let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
            let limitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: false)
            let premiumLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: true)
            
            let result: SavedGifResult
            if isPremium && items.count >= premiumLimitsConfiguration.maxSavedGifCount {
                result = .limitExceeded(premiumLimitsConfiguration.maxSavedGifCount, premiumLimitsConfiguration.maxSavedGifCount)
            } else if !isPremium && items.count >= limitsConfiguration.maxSavedGifCount {
                result = .limitExceeded(limitsConfiguration.maxSavedGifCount, premiumLimitsConfiguration.maxSavedGifCount)
            } else {
                result = .generic
            }
            
            return addSavedGif(postbox: account.postbox, fileReference: fileReference, limit: Int(isPremium ? premiumLimitsConfiguration.maxSavedGifCount : limitsConfiguration.maxSavedGifCount))
            |> map { _ -> SavedGifResult in
                return .generic
            }
            |> filter { _ in
                return false
            }
            |> then(
                .single(result)
            )
        }
        |> switchToLatest
    } else {
        return removeSavedSticker(postbox: account.postbox, mediaId: fileReference.media.fileId)
        |> map { _ -> SavedGifResult in
            return .generic
        }
    }
}
