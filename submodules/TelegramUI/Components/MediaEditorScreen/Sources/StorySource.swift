import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import MediaEditor


public func saveStorySource(engine: TelegramEngine, item: MediaEditorDraft, id: Int64) {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: id)
    let _ = engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key, item: item).start()
}

public func removeStorySource(engine: TelegramEngine, id: Int64) {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: id)
    let _ = engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key).start()
}

public func getStorySource(engine: TelegramEngine, id: Int64) -> Signal<MediaEditorDraft?, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: id)
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: key))
    |> map { result -> MediaEditorDraft? in
        return result?.get(MediaEditorDraft.self)
    }
}

public func moveStorySource(engine: TelegramEngine, from fromId: Int64, to toId: Int64) {
    let fromKey = EngineDataBuffer(length: 8)
    fromKey.setInt64(0, value: fromId)
    
    let toKey = EngineDataBuffer(length: 8)
    toKey.setInt64(0, value: toId)
    
    let _ = (engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: fromKey))
    |> mapToSignal { item -> Signal<Never, NoError> in
        if let item = item?.get(MediaEditorDraft.self) {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: toKey, item: item)
            |> then(
                engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storySource, id: fromKey)
            )
        } else {
            return .complete()
        }
    }).start()
}
