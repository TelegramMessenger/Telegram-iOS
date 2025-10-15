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


public final class ServerSuggestionInfo: Codable, Equatable {
    public final class Item: Codable, Equatable {
        public final class Text: Codable, Equatable {
            public let string: String
            public let entities: [MessageTextEntity]
            
            public init(string: String, entities: [MessageTextEntity]) {
                self.string = string
                self.entities = entities
            }
            
            public static func ==(lhs: Text, rhs: Text) -> Bool {
                if lhs.string != rhs.string {
                    return false
                }
                if lhs.entities != rhs.entities {
                    return false
                }
                return true
            }
        }
        
        public enum Action: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case link
            }
            
            case link(url: String)
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self = .link(url: try container.decode(String.self, forKey: .link))
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case let .link(url):
                    try container.encode(url, forKey: .link)
                }
            }
        }
        
        public let id: String
        public let title: Text
        public let text: Text
        public let action: Action
        
        public init(id: String, title: Text, text: Text, action: Action) {
            self.id = id
            self.title = title
            self.text = text
            self.action = action
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            if lhs.action != rhs.action {
                return false
            }
            return true
        }
    }
    
    public let legacyItems: [String]
    public let items: [Item]
    public let dismissedIds: [String]
    
    public init(legacyItems: [String], items: [Item], dismissedIds: [String]) {
        self.legacyItems = legacyItems
        self.items = items
        self.dismissedIds = dismissedIds
    }
    
    public static func ==(lhs: ServerSuggestionInfo, rhs: ServerSuggestionInfo) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
}

extension ServerSuggestionInfo.Item.Text {
    convenience init(_ apiText: Api.TextWithEntities) {
        switch apiText {
        case let .textWithEntities(text, entities):
            self.init(string: text, entities: messageTextEntitiesFromApiEntities(entities))
        }
    }
}

extension ServerSuggestionInfo.Item {
    convenience init(_ apiItem: Api.PendingSuggestion) {
        switch apiItem {
        case let .pendingSuggestion(suggestion, title, description, url):
            self.init(
                id: suggestion,
                title: ServerSuggestionInfo.Item.Text(title),
                text: ServerSuggestionInfo.Item.Text(description),
                action: .link(url: url)
            )
        }
    }
}

func managedPromoInfoUpdates(accountPeerId: PeerId, postbox: Postbox, network: Network, viewTracker: AccountViewTracker) -> Signal<Void, NoError> {
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
                        
                        let suggestionInfo = ServerSuggestionInfo(
                            legacyItems: [],
                            items: [],
                            dismissedIds: []
                        )
                        
                        transaction.updatePreferencesEntry(key: PreferencesKeys.serverSuggestionInfo(), { _ in
                            return PreferencesEntry(suggestionInfo)
                        })
                    case let .promoData(flags, expires, peer, psaType, psaMessage, pendingSuggestions, dismissedSuggestions, customPendingSuggestion, chats, users):
                        let _ = expires
                        
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        
                        var kind: PromoChatListItem.Kind?
                        if let psaType {
                            kind = .psa(type: psaType, message: psaMessage)
                        } else if ((flags & 1) << 0) != 0 {
                            kind = .proxy
                        }
                        
                        var additionalChatListItems: [AdditionalChatListItem] = []
                        if let kind, let peer, let parsedPeer = transaction.getPeer(peer.peerId) {
                            additionalChatListItems.append(PromoChatListItem(peerId: parsedPeer.id, kind: kind))
                        }
                        transaction.replaceAdditionalChatListItems(additionalChatListItems)
                        
                        var customItems: [ServerSuggestionInfo.Item] = []
                        if let customPendingSuggestion {
                            customItems.append(ServerSuggestionInfo.Item(customPendingSuggestion))
                        }
                        let suggestionInfo = ServerSuggestionInfo(
                            legacyItems: pendingSuggestions,
                            items: customItems,
                            dismissedIds: dismissedSuggestions
                        )
                        
                        transaction.updatePreferencesEntry(key: PreferencesKeys.serverSuggestionInfo(), { _ in
                            return PreferencesEntry(suggestionInfo)
                        })
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
