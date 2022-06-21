import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

public final class MediaPlaybackStoredState: Codable {
    public let timestamp: Double
    public let playbackRate: AudioPlaybackRate
    
    public init(timestamp: Double, playbackRate: AudioPlaybackRate) {
        self.timestamp = timestamp
        self.playbackRate = playbackRate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.timestamp = try container.decode(Double.self, forKey: "timestamp")
        self.playbackRate = AudioPlaybackRate(rawValue: try container.decode(Int32.self, forKey: "playbackRate")) ?? .x1
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "timestamp")
        try container.encode(self.playbackRate.rawValue, forKey: "playbackRate")
    }
}

public func mediaPlaybackStoredState(postbox: Postbox, messageId: MessageId) -> Signal<MediaPlaybackStoredState?, NoError> {
    return postbox.transaction { transaction -> MediaPlaybackStoredState? in
        let key = ValueBoxKey(length: 8)
        key.setInt32(0, value: messageId.namespace)
        key.setInt32(4, value: messageId.id)
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, key: key))?.get(MediaPlaybackStoredState.self) {
            return entry
        } else {
            return nil
        }
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 25, highWaterItemCount: 50)

public func updateMediaPlaybackStoredStateInteractively(postbox: Postbox, messageId: MessageId, state: MediaPlaybackStoredState?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let key = ValueBoxKey(length: 8)
        key.setInt32(0, value: messageId.namespace)
        key.setInt32(4, value: messageId.id)
        let id = ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, key: key)
        if let state = state, let entry = CodableEntry(state) {
            transaction.putItemCacheEntry(id: id, entry: entry, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}
