import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

final class CachedRecommendedBots: Codable {
    public let peerIds: [EnginePeer.Id]
    public let count: Int32
    public let timestamp: Int32?
    
    public init(peerIds: [EnginePeer.Id], count: Int32, timestamp: Int32?) {
        self.peerIds = peerIds
        self.count = count
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = try container.decode([Int64].self, forKey: "l").map(EnginePeer.Id.init)
        self.count = try container.decodeIfPresent(Int32.self, forKey: "c") ?? 0
        self.timestamp = try container.decodeIfPresent(Int32.self, forKey: "ts")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "l")
        try container.encode(self.count, forKey: "c")
        try container.encodeIfPresent(self.timestamp, forKey: "ts")
    }
}

private func entryId(peerId: EnginePeer.Id?) -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    if let peerId {
        cacheKey.setInt64(0, value: peerId.toInt64())
    } else {
        cacheKey.setInt64(0, value: 0)
    }
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.recommendedBots, key: cacheKey)
}

func _internal_requestRecommendedBots(account: Account, peerId: EnginePeer.Id, forceUpdate: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Peer?, Bool) in
        guard let user = transaction.getPeer(peerId) as? TelegramUser, let _ = user.botInfo else {
            return (nil, false)
        }
        if let entry = transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedRecommendedBots.self), !entry.peerIds.isEmpty && !forceUpdate {
            return (nil, false)
        } else {
            return (user, true)
        }
    }
    |> mapToSignal { user, shouldUpdate in
        guard shouldUpdate, let user, let inputUser = apiInputUser(user) else {
            return .complete()
        }
        return account.network.request(Api.functions.bots.getBotRecommendations(bot: inputUser))
        |> retryRequest
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> [EnginePeer] in
                let users: [Api.User]
                let parsedPeers: AccumulatedPeers
                var count: Int32
                switch result {
                case let .users(apiUsers):
                    users = apiUsers
                    count = Int32(apiUsers.count)
                case let .usersSlice(apiCount, apiUsers):
                    users = apiUsers
                    count = apiCount
                }
                parsedPeers = AccumulatedPeers(users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                let peers = users.map { EnginePeer(TelegramUser(user: $0)) }
                if let entry = CodableEntry(CachedRecommendedBots(peerIds: peers.map(\.id), count: count, timestamp: Int32(Date().timeIntervalSince1970))) {
                    transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
                }
                return peers
            }
            |> ignoreValues
        }
    }
}

public struct RecommendedBots: Equatable {
    public var bots: [EnginePeer]
    public var count: Int32
    
    public init(bots: [EnginePeer], count: Int32) {
        self.bots = bots
        self.count = count
    }
}

func _internal_recommendedBotPeerIds(account: Account, peerId: EnginePeer.Id) -> Signal<[EnginePeer.Id]?, NoError> {
    let key = PostboxViewKey.cachedItem(entryId(peerId: peerId))
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<[EnginePeer.Id]?, NoError> in
        guard let cachedBots = (views.views[key] as? CachedItemView)?.value?.get(CachedRecommendedBots.self), !cachedBots.peerIds.isEmpty else {
            return .single(nil)
        }
        return .single(cachedBots.peerIds)
    }
}

func _internal_recommendedBots(account: Account, peerId: EnginePeer.Id) -> Signal<RecommendedBots?, NoError> {
    let key = PostboxViewKey.cachedItem(entryId(peerId: peerId))
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<RecommendedBots?, NoError> in
        guard let cachedBots = (views.views[key] as? CachedItemView)?.value?.get(CachedRecommendedBots.self) else {
            return .single(nil)
        }
        if cachedBots.peerIds.isEmpty {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> RecommendedBots? in
            var bots: [EnginePeer] = []
            for peerId in cachedBots.peerIds {
                if let peer = transaction.getPeer(peerId) {
                    bots.append(EnginePeer(peer))
                }
            }
            return RecommendedBots(bots: bots, count: cachedBots.count)
        }
    }
}
