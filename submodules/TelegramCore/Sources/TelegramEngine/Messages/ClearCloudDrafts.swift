import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


func _internal_clearCloudDraftsInteractively(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return network.request(Api.functions.messages.getAllDrafts())
    |> retryRequest
    |> mapToSignal { updates -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Signal<Void, NoError> in
            struct Key: Hashable {
                var peerId: PeerId
                var threadId: Int64?
            }
            var keys = Set<Key>()
            switch updates {
                case let .updates(updates, users, chats, _, _):
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(groupOrChannel)
                        }
                    }
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        peerPresences[telegramUser.id] = user
                    }
                    for update in updates {
                        switch update {
                            case let .updateDraftMessage(_, peer, topMsgId, _):
                                var threadId: Int64?
                                if let topMsgId = topMsgId {
                                    threadId = Int64(topMsgId)
                                }
                                keys.insert(Key(peerId: peer.peerId, threadId: threadId))
                            default:
                                break
                        }
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                    var signals: [Signal<Void, NoError>] = []
                    for key in keys {
                        _internal_updateChatInputState(transaction: transaction, peerId: key.peerId, threadId: key.threadId,  inputState: nil)
                        
                        if let peer = transaction.getPeer(key.peerId), let inputPeer = apiInputPeer(peer) {
                            var flags: Int32 = 0
                            var topMsgId: Int32?
                            if let threadId = key.threadId {
                                flags |= (1 << 2)
                                topMsgId = Int32(clamping: threadId)
                            }
                            signals.append(network.request(Api.functions.messages.saveDraft(flags: flags, replyToMsgId: nil, topMsgId: topMsgId, peer: inputPeer, message: "", entities: nil))
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
