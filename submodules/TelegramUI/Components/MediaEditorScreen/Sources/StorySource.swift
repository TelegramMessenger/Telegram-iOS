import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramUIPreferences
import MediaEditor
import AccountContext

public func updateStorySources(engine: TelegramEngine) {
    let currentTimestamp = Int32(Date().timeIntervalSince1970)
    let pendingIds = engine.account.postbox.transaction { transaction -> Set<Int64> in
        guard let state = transaction.getLocalStoryState()?.get(Stories.LocalState.self) else {
            return []
        }
        return Set(state.items.flatMap { [Int64($0.stableId), $0.randomId] })
    }
    let _ = combineLatest(
        engine.data.get(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources)),
        pendingIds
    ).start(next: { items, pendingIds in
        let signals: [Signal<(EngineDataBuffer, MediaEditorDraft?), NoError>] = items.map { item in
            let sourceKey = EngineDataBuffer(item.id)
            return getStorySource(engine: engine, key: sourceKey) |> map { (sourceKey, $0) }
        }
        let sources: Signal<[(EngineDataBuffer, MediaEditorDraft?)], NoError> = signals.isEmpty ? .single([]) : combineLatest(signals)
        let _ = sources.start(next: { sources in
            var retainedPaths: [String] = []
            for (sourceKey, source) in sources {
                if let source {
                    if let expiresOn = source.expiresOn, expiresOn < currentTimestamp, !pendingIds.contains(sourceKey.getInt64(8)) {
                        let _ = removeStorySource(engine: engine, key: sourceKey, delete: true).start()
                    } else {
                        retainedPaths.append(source.path)
                    }
                }
            }
            // An unreadable record may belong to a newer format. Do not collect its files.
            if sources.allSatisfy({ $0.1 != nil }) {
                cleanupStoryDraftPackages(engine: engine, retaining: retainedPaths)
            }
        })
    })
}

private func key(peerId: EnginePeer.Id, id: Int64) -> EngineDataBuffer {
    let key = EngineDataBuffer(length: 16)
    key.setInt64(0, value: peerId.toInt64())
    key.setInt64(8, value: id)
    return key
}

private class StorySourceItem: Codable {
}

private func removeStorySource(engine: TelegramEngine, peerId: EnginePeer.Id, id: Int64, delete: Bool) -> Signal<Never, NoError> {
    let key = key(peerId: peerId, id: id)
    return getStorySource(engine: engine, peerId: peerId, id: id)
    |> mapToSignal { source in
        if let source {
            let _ = engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key).start()
            removeStoryDraft(engine: engine, path: source.path, delete: delete)
        }
        return engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources, id: key.toMemoryBuffer())
    }
}

private func removeStorySource(engine: TelegramEngine, key: EngineDataBuffer, delete: Bool) -> Signal<Never, NoError> {
    return getStorySource(engine: engine, key: key)
    |> mapToSignal { source in
        if let source {
            let _ = engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key).start()
            removeStoryDraft(engine: engine, path: source.path, delete: delete)
        }
        return engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources, id: key.toMemoryBuffer())
    }
}

public func saveStorySource(engine: TelegramEngine, item: MediaEditorDraft, peerId: EnginePeer.Id, id: Int64) {
    let _ = storeStorySource(engine: engine, item: item, peerId: peerId, id: id).start()
}

func storeStorySource(engine: TelegramEngine, item: MediaEditorDraft, peerId: EnginePeer.Id, id: Int64) -> Signal<Never, NoError> {
    let key = key(peerId: peerId, id: id)
    return engine.account.postbox.transaction { transaction -> Void in
        guard let contents = CodableEntry(item), let indexEntry = CodableEntry(StorySourceItem()) else {
            return
        }
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, key: key), entry: contents)
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources, item: OrderedItemListEntry(id: key.toMemoryBuffer(), contents: indexEntry), removeTailIfCountExceeds: nil)
    }
    |> ignoreValues
}

public func getStorySource(engine: TelegramEngine, peerId: EnginePeer.Id, id: Int64) -> Signal<MediaEditorDraft?, NoError> {
    let key = key(peerId: peerId, id: id)
    return getStorySource(engine: engine, key: key)
}

private func getStorySource(engine: TelegramEngine, key: EngineDataBuffer) -> Signal<MediaEditorDraft?, NoError> {
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key))
    |> map { result -> MediaEditorDraft? in
        return result?.get(MediaEditorDraft.self)
    }
}

public func moveStorySource(engine: TelegramEngine, peerId: EnginePeer.Id, from fromId: Int64, to toId: Int64) {
    guard fromId != toId else {
        return
    }
    let fromKey = key(peerId: peerId, id: fromId)
    let toKey = key(peerId: peerId, id: toId)

    let _ = engine.account.postbox.transaction { transaction -> Void in
        let fromCacheId = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, key: fromKey)
        guard let contents = transaction.retrieveItemCacheEntry(id: fromCacheId), let indexEntry = CodableEntry(StorySourceItem()) else {
            return
        }
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, key: toKey), entry: contents)
        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources, item: OrderedItemListEntry(id: toKey.toMemoryBuffer(), contents: indexEntry), removeTailIfCountExceeds: nil)
        transaction.removeItemCacheEntry(id: fromCacheId)
        transaction.removeOrderedItemListItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources, itemId: fromKey.toMemoryBuffer())
    }.start()
}
