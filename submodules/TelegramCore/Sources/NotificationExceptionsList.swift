import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

import SyncCore

public final class NotificationExceptionsList: Equatable {
    public let peers: [PeerId: Peer]
    public let settings: [PeerId: TelegramPeerNotificationSettings]
    
    public init(peers: [PeerId: Peer], settings: [PeerId: TelegramPeerNotificationSettings]) {
        self.peers = peers
        self.settings = settings
    }
    
    public static func ==(lhs: NotificationExceptionsList, rhs: NotificationExceptionsList) -> Bool {
        return lhs === rhs
    }
}

public func notificationExceptionsList(postbox: Postbox, network: Network) -> Signal<NotificationExceptionsList, NoError> {
    return network.request(Api.functions.account.getNotifyExceptions(flags: 1 << 1, peer: nil))
    |> retryRequest
    |> mapToSignal { result -> Signal<NotificationExceptionsList, NoError> in
        return postbox.transaction { transaction -> NotificationExceptionsList in
            switch result {
            case let .updates(updates, users, chats, _, _):
                var peers: [PeerId: Peer] = [:]
                var settings: [PeerId: TelegramPeerNotificationSettings] = [:]
                
                for user in users {
                    let peer = TelegramUser(user: user)
                    peers[peer.id] = peer
                }
                for chat in chats {
                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                        peers[peer.id] = peer
                    }
                }
                
                updatePeers(transaction: transaction, peers: Array(peers.values), update: { _, updated in updated })
                
                for update in updates {
                    switch update {
                    case let .updateNotifySettings(apiPeer, notifySettings):
                        switch apiPeer {
                        case let .notifyPeer(notifyPeer):
                            let peerId: PeerId
                            switch notifyPeer {
                            case let .peerUser(userId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            case let .peerChat(chatId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                            case let .peerChannel(channelId):
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                            }
                            settings[peerId] = TelegramPeerNotificationSettings(apiSettings: notifySettings)
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
                
                return NotificationExceptionsList(peers: peers, settings: settings)
            default:
                return NotificationExceptionsList(peers: [:], settings: [:])
            }
        }
    }
}
