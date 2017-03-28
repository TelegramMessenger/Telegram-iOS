import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class CachedResolvedByNamePeer: Coding {
    let peerId: PeerId?
    let timestamp: Int32
    
    static func key(name: String) -> ValueBoxKey {
        let key: ValueBoxKey
        if let nameData = name.data(using: .utf8) {
            key = ValueBoxKey(length: nameData.count)
            nameData.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                memcpy(key.memory, bytes, nameData.count)
            }
        } else {
            key = ValueBoxKey(length: 0)
        }
        return key
    }
    
    init(peerId: PeerId?, timestamp: Int32) {
        self.peerId = peerId
        self.timestamp = timestamp
    }
    
    init(decoder: Decoder) {
        if let peerId = (decoder.decodeInt64ForKey("p") as Int64?) {
            self.peerId = PeerId(peerId)
        } else {
            self.peerId = nil
        }
        self.timestamp = decoder.decodeInt32ForKey("t")
    }
    
    func encode(_ encoder: Encoder) {
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        encoder.encodeInt32(self.timestamp, forKey: "t")
    }
}

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
       normalizedName = normalizedName.substring(from: name.index(after: name.startIndex))
    }
    
    return account.postbox.modify { modifier -> CachedResolvedByNamePeer? in
        return modifier.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName))) as? CachedResolvedByNamePeer
    } |> mapToSignal { cachedEntry -> Signal<PeerId?, NoError> in
        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if let cachedEntry = cachedEntry, cachedEntry.timestamp <= timestamp && cachedEntry.timestamp >= timestamp - ageLimit {
            return .single(cachedEntry.peerId)
        } else {
            return account.network.request(Api.functions.contacts.resolveUsername(username: normalizedName))
                |> mapError { _ -> NoError in
                    return NoError()
                }
                |> mapToSignal { result -> Signal<PeerId?, NoError> in
                    return account.postbox.modify { modifier -> PeerId? in
                        var peerId: PeerId? = nil
                        
                        //contacts.resolvedPeer peer:Peer chats:Vector<Chat> users:Vector<User> = contacts.ResolvedPeer;
                        switch result {
                            case let .resolvedPeer(apiPeer, chats, users):
                                var peers: [PeerId: Peer] = [:]
                                
                                for user in users {
                                    if let user = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
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
                                    
                                    updatePeers(modifier: modifier, peers: Array(peers.values), update: { _, updated -> Peer in
                                        return updated
                                    })
                                }
                        }
                        
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                        modifier.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.resolvedByNamePeers, key: CachedResolvedByNamePeer.key(name: normalizedName)), entry: CachedResolvedByNamePeer(peerId: peerId, timestamp: timestamp), collectionSpec: resolvedByNamePeersCollectionSpec)
                        return peerId
                    }
                }
                |> `catch` { _ -> Signal<PeerId?, NoError> in
                    return .single(nil)
                }
        }
    }
}
