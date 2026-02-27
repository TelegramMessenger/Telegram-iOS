import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi


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

func _internal_notificationExceptionsList(accountPeerId: PeerId, postbox: Postbox, network: Network, isStories: Bool) -> Signal<NotificationExceptionsList, NoError> {
    var flags: Int32 = 0
    if isStories {
        flags |= 1 << 2
    } else {
        flags |= 1 << 1
    }
    
    return network.request(Api.functions.account.getNotifyExceptions(flags: flags, peer: nil))
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<NotificationExceptionsList, NoError> in
        guard let result else {
            return .single(NotificationExceptionsList(peers: [:], settings: [:]))
        }
        return postbox.transaction { transaction -> NotificationExceptionsList in
            switch result {
            case let .updates(updatesData):
                let (updates, users, chats) = (updatesData.updates, updatesData.users, updatesData.chats)
                var settings: [PeerId: TelegramPeerNotificationSettings] = [:]

                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction,  accountPeerId: accountPeerId,peers: parsedPeers)

                var peers: [PeerId: Peer] = [:]
                for id in parsedPeers.allIds {
                    if let peer = transaction.getPeer(id) {
                        peers[peer.id] = peer
                    }
                }

                for update in updates {
                    switch update {
                    case let .updateNotifySettings(updateNotifySettingsData):
                        let (apiPeer, notifySettings) = (updateNotifySettingsData.peer, updateNotifySettingsData.notifySettings)
                        switch apiPeer {
                        case let .notifyPeer(notifyPeerData):
                            let notifyPeer = notifyPeerData.peer
                            let peerId: PeerId
                            switch notifyPeer {
                            case let .peerUser(peerUserData):
                                let userId = peerUserData.userId
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                            case let .peerChat(peerChatData):
                                let chatId = peerChatData.chatId
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                            case let .peerChannel(peerChannelData):
                                let channelId = peerChannelData.channelId
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
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
