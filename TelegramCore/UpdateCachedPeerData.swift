import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func fetchAndUpdateCachedPeerData(peerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputUser = apiInputUser(peer) {
                return network.request(Api.functions.users.getFullUser(id: inputUser))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.modify { modifier -> Void in
                            switch result {
                                
                                case let .userFull(_, user, _, _, _, notifySettings, _, commonChatCount):
                                    let telegramUser = TelegramUser(user: user)
                                    updatePeers(modifier: modifier, peers: [telegramUser], update: { _, updated -> Peer in
                                        return updated
                                    })
                                    modifier.updatePeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                            }
                            modifier.updatePeerCachedData(peerIds: [peerId], update: { peerId, _ in
                                return CachedUserData(apiUserFull: result)
                            })
                        }
                    }
            } else if let _ = peer as? TelegramGroup {
                return network.request(Api.functions.messages.getFullChat(chatId: peerId.id))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.modify { modifier -> Void in
                            switch result {
                                case let .chatFull(fullChat, chats, users):
                                    switch fullChat {
                                        case let .chatFull(_, _, _, notifySettings, _, _):
                                            modifier.updatePeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                                        case .channelFull:
                                            break
                                    }
                                    
                                    if let cachedGroupData = CachedGroupData(apiChatFull: fullChat) {
                                        var peers: [Peer] = []
                                        var peerPresences: [PeerId: PeerPresence] = [:]
                                        for chat in chats {
                                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                                peers.append(groupOrChannel)
                                            }
                                        }
                                        for user in users {
                                            let telegramUser = TelegramUser(user: user)
                                            peers.append(telegramUser)
                                            if let presence = TelegramUserPresence(apiUser: user) {
                                                peerPresences[telegramUser.id] = presence
                                            }
                                        }
                                        
                                        updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                                            return updated
                                        })
                                        
                                        modifier.updatePeerPresences(peerPresences)
                                        
                                        modifier.updatePeerCachedData(peerIds: [peerId], update: { peerId, _ in
                                            return cachedGroupData
                                        })
                                    }
                            }
                        }
                    }
            } else if let inputChannel = apiInputChannel(peer) {
                return network.request(Api.functions.channels.getFullChannel(channel: inputChannel))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.modify { modifier -> Void in
                            switch result {
                                case let .chatFull(fullChat, chats, users):
                                    switch fullChat {
                                        case let .channelFull(_, _, _, _, _, _, readInboxMaxId, readOutboxMaxId, unreadCount, _, notifySettings, _, _, _, _, _):
                                            modifier.updatePeerNotificationSettings([peerId: TelegramPeerNotificationSettings(apiSettings: notifySettings)])
                                        case .chatFull:
                                            break
                                    }
                                    
                                    if let cachedChannelData = CachedChannelData(apiChatFull: fullChat) {
                                        var peers: [Peer] = []
                                        var peerPresences: [PeerId: PeerPresence] = [:]
                                        for chat in chats {
                                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                                peers.append(groupOrChannel)
                                            }
                                        }
                                        for user in users {
                                            let telegramUser = TelegramUser(user: user)
                                            peers.append(telegramUser)
                                            if let presence = TelegramUserPresence(apiUser: user) {
                                                peerPresences[telegramUser.id] = presence
                                            }
                                        }
                                        
                                        updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                                            return updated
                                        })
                                        
                                        modifier.updatePeerPresences(peerPresences)
                                        
                                        modifier.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                                            return cachedChannelData.withUpdatedTopParticipants((currentData as? CachedChannelData)?.topParticipants)
                                        })
                                    }
                            }
                        }
                    }
            } else {
                return .complete()
            }
        }
}
