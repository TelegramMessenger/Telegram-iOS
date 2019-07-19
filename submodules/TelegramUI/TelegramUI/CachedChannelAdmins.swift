import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

enum CachedChannelAdminRank: PostboxCoding, Equatable {
    case owner
    case admin
    case custom(String)
    
    init(decoder: PostboxDecoder) {
        let value: Int32 = decoder.decodeInt32ForKey("v", orElse: 0)
        switch value {
            case 0:
                self = .owner
            case 1:
                self = .admin
            case 2:
                self = .custom(decoder.decodeStringForKey("s", orElse: ""))
            default:
                self = .admin
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .owner:
                encoder.encodeInt32(0, forKey: "v")
            case .admin:
                encoder.encodeInt32(1, forKey: "v")
            case let .custom(rank):
                encoder.encodeInt32(2, forKey: "v")
                encoder.encodeString(rank, forKey: "s")
        }
    }
}

final class CachedChannelAdminRanks: PostboxCoding {
    let ranks: Dictionary<PeerId, CachedChannelAdminRank>
    
    init(ranks: Dictionary<PeerId, CachedChannelAdminRank>) {
        self.ranks = ranks
    }
    
    init(decoder: PostboxDecoder) {
        self.ranks = decoder.decodeObjectDictionaryForKey("ranks", keyDecoder: { decoder in
            return PeerId(decoder.decodeInt64ForKey("k", orElse: 0))
        }, valueDecoder: { decoder in
            return CachedChannelAdminRank(decoder: decoder)
        })
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.ranks, forKey: "ranks", keyEncoder: { key, encoder in
            encoder.encodeInt64(key.toInt64(), forKey: "k")
        })
    }
    
    static func cacheKey(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

func cachedChannelAdminRanksEntryId(peerId: PeerId) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId))
}

func updateCachedChannelAdminRanks(postbox: Postbox, peerId: PeerId, ranks: Dictionary<PeerId, CachedChannelAdminRank>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId)), entry: CachedChannelAdminRanks(ranks: ranks), collectionSpec: collectionSpec)
    }
}
