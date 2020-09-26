import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences

public final class MediaPlaybackStoredState: PostboxCoding {
    public let timestamp: Double
    public let playbackRate: AudioPlaybackRate
    
    public init(timestamp: Double, playbackRate: AudioPlaybackRate) {
        self.timestamp = timestamp
        self.playbackRate = playbackRate
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeDoubleForKey("timestamp", orElse: 0.0)
        self.playbackRate = AudioPlaybackRate(rawValue: decoder.decodeInt32ForKey("playbackRate", orElse: AudioPlaybackRate.x1.rawValue)) ?? .x1
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.timestamp, forKey: "timestamp")
        encoder.encodeInt32(self.playbackRate.rawValue, forKey: "playbackRate")
    }
}

public func mediaPlaybackStoredState(postbox: Postbox, messageId: MessageId) -> Signal<MediaPlaybackStoredState?, NoError> {
    return postbox.transaction { transaction -> MediaPlaybackStoredState? in
        let key = ValueBoxKey(length: 8)
        key.setInt32(0, value: messageId.namespace)
        key.setInt32(4, value: messageId.id)
        if let entry = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: ApplicationSpecificItemCacheCollectionId.mediaPlaybackStoredState, key: key)) as? MediaPlaybackStoredState {
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
        if let state = state {
            transaction.putItemCacheEntry(id: id, entry: state, collectionSpec: collectionSpec)
        } else {
            transaction.removeItemCacheEntry(id: id)
        }
    }
}
