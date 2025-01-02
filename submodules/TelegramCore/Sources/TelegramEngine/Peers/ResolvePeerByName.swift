import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum ResolvePeerByNameOptionCached {
    case none
    case cached
    case cachedIfLaterThan(timestamp: Int32)
}

public enum ResolvePeerByNameOptionRemote {
    case updateIfEarlierThan(timestamp: Int32)
    case update
}

public enum ResolvePeerIdByNameResult {
    case progress
    case result(PeerId?)
}

public enum ResolvePeerResult {
    case progress
    case result(EnginePeer?)
}

func _internal_resolvePeerByName(account: Account, name: String, referrer: String?, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerIdByNameResult, NoError> {
    return _internal_resolvePeerByName(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, name: name, referrer: referrer, ageLimit: ageLimit)
}
    
func _internal_resolvePeerByName(postbox: Postbox, network: Network, accountPeerId: PeerId, name: String, referrer: String?, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<ResolvePeerIdByNameResult, NoError> {
    var normalizedName = name
    if normalizedName.hasPrefix("@") {
       normalizedName = String(normalizedName[name.index(after: name.startIndex)...])
    }
    
    return postbox.transaction { transaction -> CachedResolvedByNamePeer? in
        return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)))?.get(CachedResolvedByNamePeer.self)
    }
    |> mapToSignal { cachedEntry -> Signal<ResolvePeerIdByNameResult, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if referrer == nil, let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(.result(cachedEntry.peerId))
        } else {
            var flags: Int32 = 0
            if referrer != nil {
                flags |= 1 << 0
            }
            return .single(.progress)
            |> then(network.request(Api.functions.contacts.resolveUsername(flags: flags, username: normalizedName, referer: referrer))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { result -> Signal<ResolvePeerIdByNameResult, Void> in
                return postbox.transaction { transaction -> ResolvePeerIdByNameResult in
                    var peerId: PeerId? = nil
                    
                    switch result {
                    case let .resolvedPeer(apiPeer, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                        if let peer = parsedPeers.get(apiPeer.peerId) {
                            peerId = peer.id
                            
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByNamePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)), entry: entry)
                    }
                    return .result(peerId)
                }
                |> castError(Void.self)
            }
            |> `catch` { _ -> Signal<ResolvePeerIdByNameResult, NoError> in
                return .single(.result(nil))
            })
        }
    }
}

func _internal_resolvePeerByPhone(account: Account, phone: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
    var normalizedPhone = phone
    if normalizedPhone.hasPrefix("+") {
        normalizedPhone = String(normalizedPhone[normalizedPhone.index(after: normalizedPhone.startIndex)...])
    }
    
    let accountPeerId = account.peerId
    
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
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                            if let peer = parsedPeers.get(apiPeer.peerId) {
                                peerId = peer.id
                                
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            }
                    }
                    
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    if let entry = CodableEntry(CachedResolvedByPhonePeer(peerId: peerId, timestamp: timestamp)) {
                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByPhonePeers, key: CachedResolvedByPhonePeer.key(name: normalizedPhone)), entry: entry)
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
