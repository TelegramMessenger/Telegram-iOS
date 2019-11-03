import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit

import SyncCore

func managedProxyInfoUpdates(postbox: Postbox, network: Network, viewTracker: AccountViewTracker) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        let update = network.contextProxyId
        |> distinctUntilChanged
        |> deliverOn(queue)
        |> mapToSignal { value -> Signal<Void, NoError> in
            if value != nil {
                let appliedOnce: Signal<Void, NoError> = network.request(Api.functions.help.getProxyData())
                |> `catch` { _ -> Signal<Api.help.ProxyData, NoError> in
                    return .single(.proxyDataEmpty(expires: 10 * 60))
                }
                |> mapToSignal { data -> Signal<Void, NoError> in
                    return postbox.transaction { transaction -> Void in
                        switch data {
                            case .proxyDataEmpty:
                                transaction.replaceAdditionalChatListItems([])
                            case let .proxyDataPromo(_, peer, chats, users):
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
                                
                                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                    return updated
                                })
                            
                                var additionalChatListItems: [PeerId] = []
                                if let channel = transaction.getPeer(peer.peerId) as? TelegramChannel {
                                    additionalChatListItems.append(channel.id)
                                }
                            
                                transaction.replaceAdditionalChatListItems(additionalChatListItems)
                        }
                    }
                }
                
                return (appliedOnce
                |> then(
                    Signal<Void, NoError>.complete()
                    |> delay(10.0 * 60.0, queue: Queue.concurrentDefaultQueue()))
                )
                |> restart
            } else {
                return postbox.transaction { transaction -> Void in
                    transaction.replaceAdditionalChatListItems([])
                }
            }
        }
        
        let updateDisposable = update.start()
        
        let poll = postbox.combinedView(keys: [.additionalChatListItems])
        |> map { views -> Set<PeerId> in
            if let view = views.views[.additionalChatListItems] as? AdditionalChatListItemsView {
                return view.items
            }
            return Set()
        }
        |> distinctUntilChanged
        |> mapToSignal { items -> Signal<Void, NoError> in
            return Signal { subscriber in
                let disposables = DisposableSet()
                for item in items {
                    disposables.add(viewTracker.polledChannel(peerId: item).start())
                }
                
                return ActionDisposable {
                    disposables.dispose()
                }
            }
        }
        
        let pollDisposable = poll.start()
        
        return ActionDisposable {
            updateDisposable.dispose()
            pollDisposable.dispose()
        }
    }
}
