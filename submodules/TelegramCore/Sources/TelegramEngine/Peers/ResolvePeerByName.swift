import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


private let resolvedByNamePeersCollectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 150, highWaterItemCount: 200)

public enum ResolvePeerByNameOptionCached {
    case none
    case cached
    case cachedIfLaterThan(timestamp: Int32)
}

public enum ResolvePeerByNameOptionRemote {
    case updateIfEarlierThan(timestamp: Int32)
    case update
}

func _internal_resolvePeerByName(account: Account, name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    var normalizedName = name
    if normalizedName.hasPrefix("@") {
       normalizedName = String(normalizedName[name.index(after: name.startIndex)...])
    }
    
    return account.postbox.transaction { transaction -> CachedResolvedByNamePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)))?.get(CachedResolvedByNamePeer.self)
    } |> mapToSignal { cachedEntry -> Signal<PeerId?, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(cachedEntry.peerId)
        } else {
            return account.network.request(Api.functions.contacts.resolveUsername(username: normalizedName))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<PeerId?, Void> in
                return account.postbox.transaction { transaction -> PeerId? in
                    var peerId: PeerId? = nil
                    
                    switch result {
                        case let .resolvedPeer(apiPeer, chats, users):
                            var peers: [PeerId: Peer] = [:]
                            
                            for user in users {
                                if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                    peers[user.id] = user
                                }
                            }
                            
                            for chat in chats {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    peers[groupOrChannel.id] = groupOrChannel
                                }
                            }
                        
                            if let peer = peers[apiPeer.peerId] {
                                peerId = peer.id
                                
                                updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated -> Peer in
                                    return updated
                                })
                            }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByNamePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)), entry: entry, collectionSpec: resolvedByNamePeersCollectionSpec)
                    }
                    return peerId
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<PeerId?, NoError> in
                return .single(nil)
            }
        }
    }
}

private let resolvedByPhonePeersCollectionSpec = ItemCacheCollectionSpec(lowWaterItemCount: 150, highWaterItemCount: 200)

func _internal_resolvePeerByPhone(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    var normalizedPhone = phone
    if normalizedPhone.hasPrefix("+") {
        normalizedPhone = String(normalizedPhone[normalizedPhone.index(after: normalizedPhone.startIndex)...])
    }
    
    return account.postbox.transaction { transaction -> CachedResolvedByPhonePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)))?.get(CachedResolvedByPhonePeer.self)
    } |> mapToSignal { cachedEntry -> Signal<PeerId?, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(cachedEntry.peerId)
        } else {
            return account.network.request(Api.functions.contacts.resolvePhone(phone: normalizedPhone))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<PeerId?, Void> in
                return account.postbox.transaction { transaction -> PeerId? in
                    var peerId: PeerId? = nil
                    
                    switch result {
                        case let .resolvedPeer(apiPeer, chats, users):
                            var peers: [PeerId: Peer] = [:]
                            
                            for user in users {
                                if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                    peers[user.id] = user
                                }
                            }
                            
                            for chat in chats {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    peers[groupOrChannel.id] = groupOrChannel
                                }
                            }
                        
                            if let peer = peers[apiPeer.peerId] {
                                peerId = peer.id
                                
                                updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated -> Peer in
                                    return updated
                                })
                            }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByPhonePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)), entry: entry, collectionSpec: resolvedByNamePeersCollectionSpec)
                    }
                    return peerId
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<PeerId?, NoError> in
                return .single(nil)
            }
        }
    }
}
