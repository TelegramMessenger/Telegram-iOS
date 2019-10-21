import Foundation
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit

public enum CachedChannelAdminRank: PostboxCoding, Equatable {
    case owner
    case admin
    case custom(String)
    
    public init(decoder: PostboxDecoder) {
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
    
    public func encode(_ encoder: PostboxEncoder) {
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

public final class CachedChannelAdminRanks: PostboxCoding {
    public let ranks: Dictionary<PeerId, CachedChannelAdminRank>
    
    public init(ranks: Dictionary<PeerId, CachedChannelAdminRank>) {
        self.ranks = ranks
    }
    
    public init(decoder: PostboxDecoder) {
        self.ranks = decoder.decodeObjectDictionaryForKey("ranks", keyDecoder: { decoder in
            return PeerId(decoder.decodeInt64ForKey("k", orElse: 0))
        }, valueDecoder: { decoder in
            return CachedChannelAdminRank(decoder: decoder)
        })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectDictionary(self.ranks, forKey: "ranks", keyEncoder: { key, encoder in
            encoder.encodeInt64(key.toInt64(), forKey: "k")
        })
    }
    
    public static func cacheKey(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
}

private let collectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 100, highWaterItemCount: 200)

public func cachedChannelAdminRanksEntryId(peerId: PeerId) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId))
}

public func updateCachedChannelAdminRanks(postbox: Postbox, peerId: PeerId, ranks: Dictionary<PeerId, CachedChannelAdminRank>) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId)), entry: CachedChannelAdminRanks(ranks: ranks), collectionSpec: collectionSpec)
    }
}
