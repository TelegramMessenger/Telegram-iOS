import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

import SyncCore

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

public func resolvePeerByName(account: Account, name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    var normalizedName = name
    if normalizedName.hasPrefix("@") {
       normalizedName = String(normalizedName[name.index(after: name.startIndex)...])
    }
    
    return account.postbox.transaction { transaction -> CachedResolvedByNamePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName))) as? CachedResolvedByNamePeer
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
                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)), entry: CachedResolvedByNamePeer(peerId: peerId, timestamp: timestamp), collectionSpec: resolvedByNamePeersCollectionSpec)
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
