import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func fetchAndUpdateCachedParticipants(peerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputChannel = apiInputChannel(peer) {
                return network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 200))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.modify { modifier -> Void in
                            switch result {
                                case let .channelParticipants(_, participants, users):
                                    var peers: [Peer] = []
                                    var peerPresences: [PeerId: PeerPresence] = [:]
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
                                
                                    let parsedParticipants = CachedChannelParticipants(apiParticipants: participants)
                                    modifier.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                                        if let currentData = currentData as? CachedChannelData {
                                            return currentData.withUpdatedTopParticipants(parsedParticipants)
                                        } else {
                                            return currentData
                                        }
                                    })
                            }
                            /*switch result {
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
                            }*/
                        }
                }
            } else {
                return .complete()
            }
    }
    return .never()
}
