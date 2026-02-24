import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

public enum CachedChannelAdminRank: Codable, Equatable {
    case creator(String?)
    case admin(String?)
    case member(String?)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let value: Int32 = try container.decode(Int32.self, forKey: "v")
        switch value {
        case 0:
            self = .creator(try container.decodeIfPresent(String.self, forKey: "s"))
        case 1:
            self = .admin(try container.decodeIfPresent(String.self, forKey: "s"))
        case 2:
            self = .member(try container.decodeIfPresent(String.self, forKey: "s"))
        default:
            self = .member(nil)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
        case let .creator(rank):
            try container.encode(0 as Int32, forKey: "v")
            try container.encodeIfPresent(rank, forKey: "s")
        case let .admin(rank):
            try container.encode(1 as Int32, forKey: "v")
            try container.encodeIfPresent(rank, forKey: "s")
        case let .member(rank):
            try container.encode(2 as Int32, forKey: "v")
            try container.encodeIfPresent(rank, forKey: "s")
        }
    }
}

public final class CachedChannelAdminRanks: Codable {
    private struct DictionaryKey: Codable, Hashable {
        var key: PeerId

        init(_ key: PeerId) {
            self.key = key
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = PeerId(try container.decode(Int64.self, forKey: "k"))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key.toInt64(), forKey: "k")
        }
    }
    
    public let ranks: [PeerId: CachedChannelAdminRank]
    
    public init(ranks: [PeerId: CachedChannelAdminRank]) {
        self.ranks = ranks
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        let dict = try container.decode([DictionaryKey: CachedChannelAdminRank].self, forKey: "ranks")
        var mappedDict: [PeerId: CachedChannelAdminRank] = [:]
        for (key, value) in dict {
            mappedDict[key.key] = value
        }
        self.ranks = mappedDict
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        var mappedDict: [DictionaryKey: CachedChannelAdminRank] = [:]
        for (k, v) in self.ranks {
            mappedDict[DictionaryKey(k)] = v
        }
        try container.encode(mappedDict, forKey: "ranks")
    }
    
    public static func cacheKey(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
}

public func cachedChannelAdminRanksEntryId(peerId: PeerId) -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 100, key: CachedChannelAdminRanks.cacheKey(peerId: peerId))
}

func updateCachedChannelAdminRanks(engine: TelegramEngine, peerId: PeerId, ranks: Dictionary<PeerId, CachedChannelAdminRank>) -> Signal<Never, NoError> {
    return engine.itemCache.put(collectionId: 100, id: CachedChannelAdminRanks.cacheKey(peerId: peerId), item: CachedChannelAdminRanks(ranks: ranks))
}
