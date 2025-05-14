import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

final class CachedRecommendedChannels: Codable {
    public let peerIds: [EnginePeer.Id]
    public let count: Int32
    public let isHidden: Bool
    public let timestamp: Int32?
    
    public init(peerIds: [EnginePeer.Id], count: Int32, isHidden: Bool, timestamp: Int32?) {
        self.peerIds = peerIds
        self.count = count
        self.isHidden = isHidden
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = try container.decode([Int64].self, forKey: "l").map(EnginePeer.Id.init)
        self.count = try container.decodeIfPresent(Int32.self, forKey: "c") ?? 0
        self.isHidden = try container.decode(Bool.self, forKey: "h")
        self.timestamp = try container.decodeIfPresent(Int32.self, forKey: "ts")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "l")
        try container.encode(self.count, forKey: "c")
        try container.encode(self.isHidden, forKey: "h")
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
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.recommendedChannels, key: cacheKey)
}

private func appsEntryId() -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: 0)
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.recommendedApps, key: cacheKey)
}

func _internal_requestRecommendedChannels(account: Account, peerId: EnginePeer.Id?, forceUpdate: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Peer?, Bool) in
        if let peerId {
            guard let channel = transaction.getPeer(peerId) as? TelegramChannel, case .broadcast = channel.info else {
                return (nil, false)
            }
            if let entry = transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedRecommendedChannels.self), !entry.peerIds.isEmpty && !forceUpdate {
                return (nil, false)
            } else {
                return (channel, true)
            }
        } else {
            if let entry = transaction.retrieveItemCacheEntry(id: entryId(peerId: nil))?.get(CachedRecommendedChannels.self), !entry.peerIds.isEmpty && !forceUpdate {
                var shouldUpdate = false
                if let timestamp = entry.timestamp {
                    if timestamp + 60 * 60 < Int32(Date().timeIntervalSince1970) {
                        shouldUpdate = true
                    }
                } else {
                    shouldUpdate = true
                }
                return (nil, shouldUpdate)
            } else {
                return (nil, true)
            }
        }
    }
    |> mapToSignal { channel, shouldUpdate in
        if !shouldUpdate {
            return .complete()
        }
        var inputChannel: Api.InputChannel?
        if peerId != nil {
            if let inputChannelValue = channel.flatMap(apiInputChannel) {
                inputChannel = inputChannelValue
            } else {
                return .complete()
            }
        }
        
        var flags: Int32 = 0
        if inputChannel != nil {
            flags |= (1 << 0)
        }
        return account.network.request(Api.functions.channels.getChannelRecommendations(flags: flags, channel: inputChannel))
        |> retryRequest
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> [EnginePeer] in
                let chats: [Api.Chat]
                let parsedPeers: AccumulatedPeers
                var count: Int32
                switch result {
                case let .chats(apiChats):
                    chats = apiChats
                    count = Int32(apiChats.count)
                case let .chatsSlice(apiCount, apiChats):
                    chats = apiChats
                    count = apiCount
                }
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                var peers: [EnginePeer] = []
                for chat in chats {
                    if let peer = transaction.getPeer(chat.peerId) {
                        peers.append(EnginePeer(peer))
                        if case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _, _, _, _, _, _, _, _, _, _) = chat, let participantsCount = participantsCount {
                            transaction.updatePeerCachedData(peerIds: Set([peer.id]), update: { _, current in
                                var current = current as? CachedChannelData ?? CachedChannelData()
                                var participantsSummary = current.participantsSummary
                                
                                participantsSummary.memberCount = participantsCount
                                
                                current = current.withUpdatedParticipantsSummary(participantsSummary)
                                return current
                            })
                        }
                    }
                }
                if let entry = CodableEntry(CachedRecommendedChannels(peerIds: peers.map(\.id), count: count, isHidden: false, timestamp: Int32(Date().timeIntervalSince1970))) {
                    transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
                }
                return peers
            }
            |> ignoreValues
        }
    }
}

func _internal_requestRecommendedApps(account: Account, forceUpdate: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Peer?, Bool) in
        if let entry = transaction.retrieveItemCacheEntry(id: appsEntryId())?.get(CachedRecommendedChannels.self), !entry.peerIds.isEmpty && !forceUpdate {
            var shouldUpdate = false
            if let timestamp = entry.timestamp {
                if timestamp + 60 * 60 < Int32(Date().timeIntervalSince1970) {
                    shouldUpdate = true
                }
            } else {
                shouldUpdate = true
            }
            return (nil, shouldUpdate)
        } else {
            return (nil, true)
        }
    }
    |> mapToSignal { channel, shouldUpdate in
        if !shouldUpdate {
            return .complete()
        }
        return account.network.request(Api.functions.bots.getPopularAppBots(offset: "", limit: 100))
        |> retryRequest
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> [EnginePeer] in
                let users: [Api.User]
                let parsedPeers: AccumulatedPeers
                switch result {
                case let .popularAppBots(_, nextOffset, apiUsers):
                    let _ = nextOffset
                    users = apiUsers
                }
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                var peers: [EnginePeer] = []
                for user in users {
                    if let peer = transaction.getPeer(user.peerId) {
                        peers.append(EnginePeer(peer))
                    }
                }
                if let entry = CodableEntry(CachedRecommendedChannels(peerIds: peers.map(\.id), count: Int32(peers.count), isHidden: false, timestamp: Int32(Date().timeIntervalSince1970))) {
                    transaction.putItemCacheEntry(id: appsEntryId(), entry: entry)
                }
                return peers
            }
            |> ignoreValues
        }
    }
}

public struct RecommendedChannels: Equatable {
    public struct Channel: Equatable {
        public var peer: EnginePeer
        public var subscribers: Int32
        
        public init(peer: EnginePeer, subscribers: Int32) {
            self.peer = peer
            self.subscribers = subscribers
        }
    }
    
    public var channels: [Channel]
    public var count: Int32
    public var isHidden: Bool
    
    public init(channels: [Channel], count: Int32, isHidden: Bool) {
        self.channels = channels
        self.count = count
        self.isHidden = isHidden
    }
}

func _internal_recommendedChannelPeerIds(account: Account, peerId: EnginePeer.Id?) -> Signal<[EnginePeer.Id]?, NoError> {
    let key = PostboxViewKey.cachedItem(entryId(peerId: peerId))
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<[EnginePeer.Id]?, NoError> in
        guard let cachedChannels = (views.views[key] as? CachedItemView)?.value?.get(CachedRecommendedChannels.self), !cachedChannels.peerIds.isEmpty else {
            return .single(nil)
        }
        return .single(cachedChannels.peerIds)
    }
}

func _internal_recommendedAppPeerIds(account: Account) -> Signal<[EnginePeer.Id]?, NoError> {
    let key = PostboxViewKey.cachedItem(appsEntryId())
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<[EnginePeer.Id]?, NoError> in
        guard let cachedChannels = (views.views[key] as? CachedItemView)?.value?.get(CachedRecommendedChannels.self), !cachedChannels.peerIds.isEmpty else {
            return .single(nil)
        }
        return .single(cachedChannels.peerIds)
    }
}

func _internal_recommendedChannels(account: Account, peerId: EnginePeer.Id?) -> Signal<RecommendedChannels?, NoError> {
    let key = PostboxViewKey.cachedItem(entryId(peerId: peerId))
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<RecommendedChannels?, NoError> in
        guard let cachedChannels = (views.views[key] as? CachedItemView)?.value?.get(CachedRecommendedChannels.self) else {
            return .single(nil)
        }
        if cachedChannels.peerIds.isEmpty {
            if peerId != nil {
                return .single(nil)
            } else {
                return .single(RecommendedChannels(channels: [], count: 0, isHidden: false))
            }
        }
        return account.postbox.multiplePeersView(cachedChannels.peerIds)
        |> mapToSignal { view in
            return account.postbox.transaction { transaction -> RecommendedChannels? in
                var channels: [RecommendedChannels.Channel] = []
                for peerId in cachedChannels.peerIds {
                    if let peer = view.peers[peerId] as? TelegramChannel, let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
                        if case .member = peer.participationStatus {
                        } else {
                            channels.append(RecommendedChannels.Channel(peer: EnginePeer(peer), subscribers: cachedData.participantsSummary.memberCount ?? 0))
                        }
                    }
                }
                return RecommendedChannels(channels: channels, count: cachedChannels.count, isHidden: cachedChannels.isHidden)
            }
        }
    }
}

func _internal_toggleRecommendedChannelsHidden(account: Account, peerId: EnginePeer.Id, hidden: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction in
        if let cachedChannels = transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedRecommendedChannels.self) {
            if let entry = CodableEntry(CachedRecommendedChannels(peerIds: cachedChannels.peerIds, count: cachedChannels.count, isHidden: hidden, timestamp: cachedChannels.timestamp)) {
                transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
            }
        }
    }
    |> ignoreValues
}
