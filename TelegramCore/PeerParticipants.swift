import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func peerParticipants(account: Account, id: PeerId) -> Signal<[Peer], NoError> {
    if id.namespace == Namespaces.Peer.CloudGroup || id.namespace == Namespaces.Peer.CloudChannel {
        return account.postbox.loadedPeerWithId(id)
            |> take(1)
            |> mapToSignal { peer -> Signal<[Peer], NoError> in
                if let group = peer as? TelegramGroup {
                    return account.network.request(Api.functions.messages.getFullChat(chatId: group.id.id))
                        |> retryRequest
                        |> map { result -> [Peer] in
                            switch result {
                                case let .chatFull(fullChat, chats, users):
                                    var peerIds = Set<PeerId>()
                                    switch fullChat {
                                        case let .chatFull(_, participants, _, _, _, _):
                                            switch participants {
                                                case let .chatParticipants(_, participants, _):
                                                    for participant in participants {
                                                        let peerId: PeerId
                                                        switch participant {
                                                            case let .chatParticipant(userId, _, _):
                                                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                            case let .chatParticipantAdmin(userId, _, _):
                                                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                            case let .chatParticipantCreator(userId):
                                                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                        }
                                                        peerIds.insert(peerId)
                                                    }
                                                case .chatParticipantsForbidden:
                                                    break
                                            }
                                        case .channelFull:
                                            break
                                    }
                                    let peers: [Peer] = users.filter({ user in
                                        return peerIds.contains(user.peerId)
                                    }).map({ user in
                                        return TelegramUser(user: user)
                                    })
                                    return peers
                            }
                            return []
                        }
                } else if let channel = peer as? TelegramChannel {
                    if let inputChannel = apiInputChannel(channel) {
                        return account.network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: .channelParticipantsRecent, offset: 0, limit: 32))
                            |> retryRequest
                            |> map { result -> [Peer] in
                                switch result {
                                    case let .channelParticipants(_, participants, users):
                                        var peerIds = Set<PeerId>()
                                        for participant in participants {
                                            let peerId: PeerId
                                            switch participant {
                                                case let .channelParticipant(userId, _):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                case let .channelParticipantCreator(userId):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                case let .channelParticipantEditor(userId, _, _):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                case let .channelParticipantKicked(userId, _, _):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                case let .channelParticipantModerator(userId, _, _):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                                case let .channelParticipantSelf(userId, _, _):
                                                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                            }
                                            peerIds.insert(peerId)
                                        }
                                        let peers: [Peer] = users.filter({ user in
                                            return peerIds.contains(user.peerId)
                                        }).map({ user in
                                            return TelegramUser(user: user)
                                        })
                                        return peers
                                }
                            }
                } else {
                    return .single([])
                }
            }
            return .single([])
        }
    } else {
        return .single([])
    }
}
