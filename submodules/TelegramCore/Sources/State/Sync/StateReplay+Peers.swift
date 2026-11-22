import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Peers and their cached data: merged chats and users, peer updates, presences, auto-delete timers and wallpapers.
extension ReplayContext {
    func applyMergeApiChats(_ chats: [Api.Chat]) {
        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
    }
    
    func applyMergeApiUsers(_ users: [Api.User]) {
        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: [], users: users)
        if let updatedAccountPeer = parsedPeers.get(accountPeerId) as? TelegramUser, let previousAccountPeer = transaction.getPeer(accountPeerId) as? TelegramUser {
            if updatedAccountPeer.isPremium != previousAccountPeer.isPremium {
                isPremiumUpdated = true
            }
        }

        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
        updateContacts(transaction: transaction, apiUsers: users)
    }
    
    func applyUpdatePeer(_ id: PeerId, _ f: @escaping (Peer?) -> Peer?) {
        if let peer = f(transaction.getPeer(id)) {
            if id == accountPeerId, let updatedAccountPeer = peer as? TelegramUser, let previousAccountPeer = transaction.getPeer(accountPeerId) as? TelegramUser {
                if updatedAccountPeer.isPremium != previousAccountPeer.isPremium {
                    isPremiumUpdated = true
                }
            }

            updatePeersCustom(transaction: transaction, peers: [peer], update: { _, updated in
                return updated
            })
        }
    }
    
    func applyUpdateCachedPeerData(_ id: PeerId, _ f: @escaping (CachedPeerData?) -> CachedPeerData?) {
        transaction.updatePeerCachedData(peerIds: Set([id]), update: { _, current in
            return f(current)
        })
    }
    
    func applyMergePeerPresences(_ statuses: [PeerId: UpdatedApiPresence], _ explicit: Bool) {
        var presences: [PeerId: UpdatedApiPresence] = [:]
        for (peerId, status) in statuses {
            if peerId == accountPeerId {
                if explicit {
                    switch status.status {
                    case let .userStatusOnline(userStatusOnlineData):
                        let timestamp = userStatusOnlineData.expires
                        delayNotificatonsUntil = timestamp + 30
                    case let .userStatusOffline(userStatusOfflineData):
                        let timestamp = userStatusOfflineData.wasOnline
                        delayNotificatonsUntil = timestamp
                    default:
                        break
                    }
                }
            } else {
                presences[peerId] = status
            }
        }
        updatePeerPresencesClean(transaction: transaction, accountPeerId: accountPeerId, peerPresences: presences)
    }
    
    func applyUpdateAutoremoveTimeout(_ peer: Api.Peer, _ autoremoveValue: CachedPeerAutoremoveTimeout.Value?) {
        let peerId = peer.peerId
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            if peerId.namespace == Namespaces.Peer.CloudUser {
                let current = (current as? CachedUserData) ?? CachedUserData()
                return current.withUpdatedAutoremoveTimeout(.known(autoremoveValue))
            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                let current = (current as? CachedChannelData) ?? CachedChannelData()
                return current.withUpdatedAutoremoveTimeout(.known(autoremoveValue))
            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                let current = (current as? CachedGroupData) ?? CachedGroupData()
                return current.withUpdatedAutoremoveTimeout(.known(autoremoveValue))
            } else {
                return current
            }
        })
    }
    
    func applyUpdateWallpaper(_ peerId: PeerId, _ wallpaper: TelegramWallpaper?) {
        updatedWallpapers.updateValue(wallpaper, forKey: peerId)
    }
}
