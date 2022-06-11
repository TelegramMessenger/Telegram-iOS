//import Foundation
//import UIKit
//import SwiftSignalKit
//import Postbox
//import TelegramCore
//import TelegramUIPreferences
//
//final class StoredTransactionState: Codable {
//    let timestamp: Double
//    let playbackRate: AudioPlaybackRate
//    
//    init(timestamp: Double, playbackRate: AudioPlaybackRate) {
//        self.timestamp = timestamp
//        self.playbackRate = playbackRate
//    }
//    
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: StringCodingKey.self)
//
//        self.timestamp = try container.decode(Double.self, forKey: "timestamp")
//        self.playbackRate = AudioPlaybackRate(rawValue: try container.decode(Int32.self, forKey: "playbackRate")) ?? .x1
//    }
//    
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: StringCodingKey.self)
//
//        try container.encode(self.timestamp, forKey: "timestamp")
//        try container.encode(self.playbackRate.rawValue, forKey: "playbackRate")
//    }
//}
//
//public func storedState(engine: TelegramEngine, : MessageId) -> Signal<MediaPlaybackStoredState?, NoError> {
//    let key = ValueBoxKey(length: 20)
//    key.setInt32(0, value: messageId.namespace)
//    key.setInt32(4, value: messageId.peerId.namespace._internalGetInt32Value())
//    key.setInt64(8, value: messageId.peerId.id._internalGetInt64Value())
//    key.setInt32(16, value: messageId.id)
//    
//    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, id: key))
//    |> map { entry -> MediaPlaybackStoredState? in
//        return entry?.get(MediaPlaybackStoredState.self)
//    }
//}
//
//public func updateMediaPlaybackStoredStateInteractively(engine: TelegramEngine, messageId: MessageId, state: MediaPlaybackStoredState?) -> Signal<Never, NoError> {
//    let key = ValueBoxKey(length: 20)
//    key.setInt32(0, value: messageId.namespace)
//    key.setInt32(4, value: messageId.peerId.namespace._internalGetInt32Value())
//    key.setInt64(8, value: messageId.peerId.id._internalGetInt64Value())
//    key.setInt32(16, value: messageId.id)
//    
//    if let state = state {
//        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, id: key, item: state)
//    } else {
//        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, id: key)
//    }
//}
