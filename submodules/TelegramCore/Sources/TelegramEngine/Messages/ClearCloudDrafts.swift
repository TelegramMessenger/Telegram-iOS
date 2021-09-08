import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


func _internal_clearCloudDraftsInteractively(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return network.request(Api.functions.messages.getAllDrafts())
    |> retryRequest
    |> mapToSignal { updates -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            var peerIds = Set<PeerId>()
            switch updates {
                case let .updates(updates, users, chats, _, _):
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
                    for update in updates {
                        switch update {
                            case let .updateDraftMessage(peer, _):
                                peerIds.insert(peer.peerId)
                            default:
                                break
                        }
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                    var signals: [Signal<Void, NoError>] = []
                    for peerId in peerIds {
                        _internal_updateChatInputState(transaction: transaction, peerId: peerId, inputState: nil)
                        
                        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
                            signals.append(network.request(Api.functions.messages.saveDraft(flags: 0, replyToMsgId: nil, peer: inputPeer, message: "", entities: nil))
                            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                                return .single(.boolFalse)
                            }
                            |> mapToSignal { _ -> Signal<Void, NoError> in
                                return .complete()
                            })
                        }
                    }
                    
                    return combineLatest(signals)
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
                default:
                    break
            }
            return .complete()
        } |> switchToLatest
    }
}
