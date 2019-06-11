import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

final class CachedChannelAdminIds: PostboxCoding {
    let ids: Set<PeerId>
    
    init(ids: Set<PeerId>) {
        self.ids = ids
    }
    
    init(decoder: PostboxDecoder) {
        self.ids = Set(decoder.decodeInt64ArrayForKey("ids").map(PeerId.init))
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64Array(Array(self.ids.map({ $0.toInt64() })), forKey: "ids")
    }
    
    static func cacheKey(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

func cachedChannelAdminIdsEntryId(peerId: PeerId) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminIds.cacheKey(peerId: peerId))
}

func updateCachedChannelAdminIds(postbox: Postbox, peerId: PeerId, ids: Set<PeerId>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminIds.cacheKey(peerId: peerId)), entry: CachedChannelAdminIds(ids: ids), collectionSpec: collectionSpec)
    }
}
