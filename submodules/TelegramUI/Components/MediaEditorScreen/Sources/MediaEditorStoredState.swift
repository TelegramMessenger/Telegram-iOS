import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import MediaEditor

public final class MediaEditorStoredState: Codable {
    private enum CodingKeys: String, CodingKey {
        case privacy
    }
    
    public let privacy: MediaEditorResultPrivacy?
    
    public init(privacy: MediaEditorResultPrivacy?) {
        self.privacy = privacy
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let data = try container.decodeIfPresent(Data.self, forKey: .privacy), let privacy = try? JSONDecoder().decode(MediaEditorResultPrivacy.self, from: data) {
            self.privacy = privacy
        } else {
            self.privacy = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let privacy = self .privacy {
            if let data = try? JSONEncoder().encode(privacy) {
                try container.encode(data, forKey: .privacy)
            } else {
                try container.encodeNil(forKey: .privacy)
            }
        } else {
            try container.encodeNil(forKey: .privacy)
        }
    }
}

func mediaEditorStoredState(engine: TelegramEngine) -> Signal<MediaEditorStoredState?, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key))
    |> map { entry -> MediaEditorStoredState? in
        return entry?.get(MediaEditorStoredState.self)
    }
}

func updateMediaEditorStoredStateInteractively(engine: TelegramEngine, state: MediaEditorStoredState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    if let state = state {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key, item: state)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key)
    }
}
