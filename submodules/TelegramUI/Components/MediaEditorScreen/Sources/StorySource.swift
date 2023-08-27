import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import MediaEditor
import AccountContext

public func updateStorySources(engine: TelegramEngine) {
    let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    let _ = engine.data.get(
        TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources)
    ).start(next: { items in
        for item in items {
            let key = EngineDataBuffer(item.id)
            let _ = getStorySource(engine: engine, key: key).start(next: { source in
                if let source {
                    if let expiresOn = source.expiresOn, expiresOn < currentTimestamp {
                        let _ = removeStorySource(engine: engine, key: key, delete: true).start()
                    }
                }
            })
                
        }
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

private func addStorySource(engine: TelegramEngine, key: EngineDataBuffer) {
    let _ = engine.orderedLists.addOrMoveToFirstPosition(
        collectionId: ApplicationSpecificOrderedItemListCollectionId.storySources,
        id: key.toMemoryBuffer(),
        item: StorySourceItem(),
        removeTailIfCountExceeds: nil
    ).start()
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
    let key = key(peerId: peerId, id: id)
    addStorySource(engine: engine, key: key)
    let _ = engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key, item: item).start()
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
    let fromKey = key(peerId: peerId, id: fromId)
    let toKey = key(peerId: peerId, id: toId)
    
    let _ = (engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: fromKey))
    |> mapToSignal { item -> Signal<Never, NoError> in
        if let item = item?.get(MediaEditorDraft.self) {
            addStorySource(engine: engine, key: toKey)
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: toKey, item: item)
            |> then(
                removeStorySource(engine: engine, key: fromKey, delete: false)
            )
        } else {
            return .complete()
        }
    }).start()
}
