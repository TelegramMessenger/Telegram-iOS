import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public struct SendAsPeer: Equatable {
    public let peer: Peer
    public let subscribers: Int32?
    public let isPremiumRequired: Bool
    
    public init(peer: Peer, subscribers: Int32?, isPremiumRequired: Bool) {
        self.peer = peer
        self.subscribers = subscribers
        self.isPremiumRequired = isPremiumRequired
    }
    
    public static func ==(lhs: SendAsPeer, rhs: SendAsPeer) -> Bool {
        return lhs.peer.isEqual(rhs.peer) && lhs.subscribers == rhs.subscribers && lhs.isPremiumRequired == rhs.isPremiumRequired
    }
}

public final class CachedSendAsPeers: Codable {
    public let peerIds: [PeerId]
    public let premiumRequiredPeerIds: Set<PeerId>
    public let timestamp: Int32
    
    public init(peerIds: [PeerId], premiumRequiredPeerIds: Set<PeerId>, timestamp: Int32) {
        self.peerIds = peerIds
        self.premiumRequiredPeerIds = premiumRequiredPeerIds
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.peerIds = (try container.decode([Int64].self, forKey: "peerIds")).map(PeerId.init)
        self.premiumRequiredPeerIds = Set((try container.decodeIfPresent([Int64].self, forKey: "premiumRequiredPeerIds") ?? []).map(PeerId.init))
        self.timestamp = try container.decode(Int32.self, forKey: "timestamp")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: "peerIds")
        try container.encode(Array(self.premiumRequiredPeerIds).map { $0.toInt64() }, forKey: "premiumRequiredPeerIds")
        try container.encode(self.timestamp, forKey: "timestamp")
    }
}

func _internal_cachedPeerSendAsAvailablePeers(account: Account, peerId: PeerId) -> Signal<[SendAsPeer], NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.toInt64())
    return account.postbox.transaction { transaction -> ([SendAsPeer], Int32)? in
        let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSendAsPeers, key: key))?.get(CachedSendAsPeers.self)
        if let cached = cached {
            var peers: [SendAsPeer] = []
            for peerId in cached.peerIds {
                if let peer = transaction.getPeer(peerId) {
                    var subscribers: Int32?
                    if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
                        subscribers = cachedData.participantsSummary.memberCount
                    }
                    peers.append(SendAsPeer(peer: peer, subscribers: subscribers, isPremiumRequired: cached.premiumRequiredPeerIds.contains(peer.id)))
                }
            }
            return (peers, cached.timestamp)
        } else {
            return nil
        }
    }
    |> mapToSignal { cachedPeersAndTimestamp -> Signal<[SendAsPeer], NoError> in
        let initialSignal: Signal<[SendAsPeer], NoError>
        if let (cachedPeers, _) = cachedPeersAndTimestamp {
            initialSignal = .single(cachedPeers)
        } else {
            initialSignal = .complete()
        }
        return initialSignal
        |> then(_internal_peerSendAsAvailablePeers(network: account.network, postbox: account.postbox, peerId: peerId)
        |> mapToSignal { peers -> Signal<[SendAsPeer], NoError> in
            return account.postbox.transaction { transaction -> [SendAsPeer] in
                let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                var premiumRequiredPeerIds = Set<PeerId>()
                for peer in peers {
                    if peer.isPremiumRequired {
                        premiumRequiredPeerIds.insert(peer.peer.id)
                    }
                }
                if let entry = CodableEntry(CachedSendAsPeers(peerIds: peers.map { $0.peer.id }, premiumRequiredPeerIds: premiumRequiredPeerIds, timestamp: currentTimestamp)) {
                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedSendAsPeers, key: key), entry: entry)
                }
                return peers
            }
        })
    }
}


func _internal_peerSendAsAvailablePeers(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<[SendAsPeer], NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    } |> mapToSignal { inputPeer in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return network.request(Api.functions.channels.getSendAs(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.channels.SendAsPeers?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result in
            guard let result = result else {
                return .single([])
            }
            switch result {
            case let .sendAsPeers(sendAsPeers, chats, _):
                var subscribers: [PeerId: Int32] = [:]
                let peers = chats.compactMap(parseTelegramGroupOrChannel)
                var premiumRequiredPeerIds = Set<PeerId>()
                for sendAsPeer in sendAsPeers {
                    if case let .sendAsPeer(flags, peer) = sendAsPeer, (flags & (1 << 0)) != 0 {
                        premiumRequiredPeerIds.insert(peer.peerId)
                    }
                }
                for chat in chats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        switch chat {
                        case let .channel(_, _, _, _, _, _, _, _, _, _, _, _, participantsCount, _):
                            if let participantsCount = participantsCount {
                                subscribers[groupOrChannel.id] = participantsCount
                            }
                        case let .chat(_, _, _, _, participantsCount, _, _, _, _, _):
                            subscribers[groupOrChannel.id] = participantsCount
                        default:
                            break
                        }
                    }
                }
                return postbox.transaction { transaction -> [Peer] in
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                        return updated
                    })
                    return peers
                } |> map { peers -> [SendAsPeer] in
                    return peers.map { SendAsPeer(peer: $0, subscribers: subscribers[$0.id], isPremiumRequired: premiumRequiredPeerIds.contains($0.id)) }
                }
            }
        }
        
    }
}

public enum UpdatePeerSendAsPeerError {
    case generic
}

func _internal_updatePeerSendAsPeer(account: Account, peerId: PeerId, sendAs: PeerId) -> Signal<Never, UpdatePeerSendAsPeerError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputPeer)? in
        if let peer = transaction.getPeer(peerId), let sendAsPeer = transaction.getPeer(sendAs), let inputPeer = apiInputPeer(peer), let sendAsInputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: account.peerId) {
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                if let cachedData = cachedData as? CachedChannelData {
                    return cachedData.withUpdatedSendAsPeerId(sendAs)
                } else {
                    return cachedData
                }
            })
            
            return (inputPeer, sendAsInputPeer)
        } else {
            return nil
        }
    }
    |> castError(UpdatePeerSendAsPeerError.self)
    |> mapToSignal { result in
        guard let (inputPeer, sendAsInputPeer) = result else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.saveDefaultSendAs(peer: inputPeer, sendAs: sendAsInputPeer))
        |> mapError { _ -> UpdatePeerSendAsPeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, UpdatePeerSendAsPeerError> in
            return account.postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
                    if let cachedData = cachedData as? CachedChannelData {
                        return cachedData.withUpdatedSendAsPeerId(sendAs)
                    } else {
                        return cachedData
                    }
                })
            }
            |> castError(UpdatePeerSendAsPeerError.self)
            |> ignoreValues
        }
    }
}
