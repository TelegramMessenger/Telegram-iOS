import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public final class PromoChatListItem: AdditionalChatListItem {
    public enum Kind: Equatable {
        case proxy
        case psa(type: String, message: String?)
    }
    
    public let peerId: PeerId
    public let kind: Kind
    
    public var includeIfNoHistory: Bool {
        switch self.kind {
        case .proxy:
            return false
        case let .psa(_, message):
            return message != nil
        }
    }
    
    public init(peerId: PeerId, kind: Kind) {
        self.peerId = peerId
        self.kind = kind
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        let kindType = decoder.decodeInt32ForKey("_kind", orElse: 0)
        switch kindType {
        case 0:
            self.kind = .proxy
        case 1:
            self.kind = .psa(type: decoder.decodeStringForKey("psa.type", orElse: "generic"), message: decoder.decodeOptionalStringForKey("psa.message"))
        default:
            assertionFailure()
            self.kind = .proxy
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        switch self.kind {
        case .proxy:
            encoder.encodeInt32(0, forKey: "_kind")
        case let .psa(type, message):
            encoder.encodeInt32(1, forKey: "_kind")
            encoder.encodeString(type, forKey: "psa.type")
            if let message = message {
                encoder.encodeString(message, forKey: "psa.message")
            } else {
                encoder.encodeNil(forKey: "psa.message")
            }
        }
    }
    
    public func isEqual(to other: AdditionalChatListItem) -> Bool {
        guard let other = other as? PromoChatListItem else {
            return false
        }
        if self.peerId != other.peerId {
            return false
        }
        if self.kind != other.kind {
            return false
        }
        return true
    }
}

func managedPromoInfoUpdates(postbox: Postbox, network: Network, viewTracker: AccountViewTracker) -> Signal<Void, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        let update = network.contextProxyId
        |> distinctUntilChanged
        |> deliverOn(queue)
        |> mapToSignal { _ -> Signal<Void, NoError> in
            let appliedOnce: Signal<Void, NoError> = network.request(Api.functions.help.getPromoData())
            |> `catch` { _ -> Signal<Api.help.PromoData, NoError> in
                return .single(.promoDataEmpty(expires: 10 * 60))
            }
            |> mapToSignal { data -> Signal<Void, NoError> in
                return postbox.transaction { transaction -> Void in
                    switch data {
                    case .promoDataEmpty:
                        transaction.replaceAdditionalChatListItems([])
                    case let .promoData(_, _, peer, chats, users, psaType, psaMessage):
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
                        
                        let kind: PromoChatListItem.Kind
                        if let psaType = psaType {
                            kind = .psa(type: psaType, message: psaMessage)
                        } else {
                            kind = .proxy
                        }
                        
                        var additionalChatListItems: [AdditionalChatListItem] = []
                        if let parsedPeer = transaction.getPeer(peer.peerId) {
                            additionalChatListItems.append(PromoChatListItem(peerId: parsedPeer.id, kind: kind))
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
        }
        
        let updateDisposable = update.start()
        
        let poll = postbox.combinedView(keys: [.additionalChatListItems])
        |> map { views -> Set<PeerId> in
            if let view = views.views[.additionalChatListItems] as? AdditionalChatListItemsView {
                return Set(view.items.map { $0.peerId })
            }
            return Set()
        }
        |> distinctUntilChanged
        |> mapToSignal { items -> Signal<Void, NoError> in
            return Signal { subscriber in
                let disposables = DisposableSet()
                for item in items {
                    if item.namespace == Namespaces.Peer.CloudChannel {
                        disposables.add(viewTracker.polledChannel(peerId: item).start())
                    }
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

public func hideAccountPromoInfoChat(account: Account, peerId: PeerId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.help.hidePromoData(peer: inputPeer))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            return account.postbox.transaction { transaction -> Void in
                transaction.replaceAdditionalChatListItems([])
            }
            |> ignoreValues
        }
    }
}
