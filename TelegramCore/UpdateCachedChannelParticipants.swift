import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func fetchAndUpdateCachedParticipants(accountPeerId: PeerId, peerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(peerId)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputChannel = apiInputChannel(peer) {
                return network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 200, hash: 0))
                    |> retryRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return postbox.transaction { transaction -> Void in
                            switch result {
                                case let .channelParticipants(count, participants, users):
                                    var peers: [Peer] = []
                                    var peerPresences: [PeerId: PeerPresence] = [:]
                                    for user in users {
                                        let telegramUser = TelegramUser(user: user)
                                        peers.append(telegramUser)
                                        if let presence = TelegramUserPresence(apiUser: user) {
                                            peerPresences[telegramUser.id] = presence
                                        }
                                    }
                                    
                                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                        return updated
                                    })
                                
                                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                                
                                    let parsedParticipants = CachedChannelParticipants(apiParticipants: participants)

                                    transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, currentData in
                                        if let currentData = currentData as? CachedChannelData {
                                            return currentData.withUpdatedTopParticipants(parsedParticipants)
                                        } else {
                                            return currentData
                                        }
                                    })
                                case .channelParticipantsNotModified:
                                    break
                            }
                        }
                }
            } else {
                return .complete()
            }
    }
}
