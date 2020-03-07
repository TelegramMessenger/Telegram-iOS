import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

public struct ChatListFilteringConfiguration: Equatable {
    public let isEnabled: Bool
    
    public init(appConfiguration: AppConfiguration) {
        var isEnabled = false
        if let data = appConfiguration.data, let value = data["dialog_filters_enabled"] as? Bool, value {
            isEnabled = true
        }
        self.isEnabled = isEnabled
    }
}

public struct ChatListFilterPeerCategories: OptionSet, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let contacts = ChatListFilterPeerCategories(rawValue: 1 << 0)
    public static let nonContacts = ChatListFilterPeerCategories(rawValue: 1 << 1)
    public static let groups = ChatListFilterPeerCategories(rawValue: 1 << 2)
    public static let channels = ChatListFilterPeerCategories(rawValue: 1 << 3)
    public static let bots = ChatListFilterPeerCategories(rawValue: 1 << 4)
    
    public static let all: ChatListFilterPeerCategories = [
        .contacts,
        .nonContacts,
        .groups,
        .channels,
        .bots
    ]
}

private struct ChatListFilterPeerApiCategories: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let contacts = ChatListFilterPeerApiCategories(rawValue: 1 << 0)
    static let nonContacts = ChatListFilterPeerApiCategories(rawValue: 1 << 1)
    static let groups = ChatListFilterPeerApiCategories(rawValue: 1 << 2)
    static let channels = ChatListFilterPeerApiCategories(rawValue: 1 << 3)
    static let bots = ChatListFilterPeerApiCategories(rawValue: 1 << 4)
}

extension ChatListFilterPeerCategories {
    init(apiFlags: Int32) {
        let flags = ChatListFilterPeerApiCategories(rawValue: apiFlags)
        var result: ChatListFilterPeerCategories = []
        if flags.contains(.contacts) {
            result.insert(.contacts)
        }
        if flags.contains(.nonContacts) {
            result.insert(.nonContacts)
        }
        if flags.contains(.groups) {
            result.insert(.groups)
        }
        if flags.contains(.channels) {
            result.insert(.channels)
        }
        if flags.contains(.bots) {
            result.insert(.bots)
        }
        self = result
    }
    
    var apiFlags: Int32 {
        var result: ChatListFilterPeerApiCategories = []
        if self.contains(.contacts) {
            result.insert(.contacts)
        }
        if self.contains(.nonContacts) {
            result.insert(.nonContacts)
        }
        if self.contains(.groups) {
            result.insert(.groups)
        }
        if self.contains(.channels) {
            result.insert(.channels)
        }
        if self.contains(.bots) {
            result.insert(.bots)
        }
        return result.rawValue
    }
}

public struct ChatListFilterData: Equatable, Hashable {
    public var categories: ChatListFilterPeerCategories
    public var excludeMuted: Bool
    public var excludeRead: Bool
    public var excludeArchived: Bool
    public var includePeers: [PeerId]
    public var excludePeers: [PeerId]
    
    public init(
        categories: ChatListFilterPeerCategories,
        excludeMuted: Bool,
        excludeRead: Bool,
        excludeArchived: Bool,
        includePeers: [PeerId],
        excludePeers: [PeerId]
    ) {
        self.categories = categories
        self.excludeMuted = excludeMuted
        self.excludeRead = excludeRead
        self.excludeArchived = excludeArchived
        self.includePeers = includePeers
        self.excludePeers = excludePeers
    }
}

public struct ChatListFilter: PostboxCoding, Equatable {
    public var id: Int32
    public var title: String
    public var data: ChatListFilterData
    
    public init(
        id: Int32,
        title: String,
        data: ChatListFilterData
    ) {
        self.id = id
        self.title = title
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt32ForKey("id", orElse: 0)
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.data = ChatListFilterData(
            categories: ChatListFilterPeerCategories(rawValue: decoder.decodeInt32ForKey("categories", orElse: 0)),
            excludeMuted: decoder.decodeInt32ForKey("excludeMuted", orElse: 0) != 0,
            excludeRead: decoder.decodeInt32ForKey("excludeRead", orElse: 0) != 0,
            excludeArchived: decoder.decodeInt32ForKey("excludeArchived", orElse: 0) != 0,
            includePeers: decoder.decodeInt64ArrayForKey("includePeers").map(PeerId.init),
            excludePeers: decoder.decodeInt64ArrayForKey("excludePeers").map(PeerId.init)
        )
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.id, forKey: "id")
        encoder.encodeString(self.title, forKey: "title")
        encoder.encodeInt32(self.data.categories.rawValue, forKey: "categories")
        encoder.encodeInt32(self.data.excludeMuted ? 1 : 0, forKey: "excludeMuted")
        encoder.encodeInt32(self.data.excludeRead ? 1 : 0, forKey: "excludeRead")
        encoder.encodeInt32(self.data.excludeArchived ? 1 : 0, forKey: "excludeArchived")
        encoder.encodeInt64Array(self.data.includePeers.map { $0.toInt64() }, forKey: "includePeers")
        encoder.encodeInt64Array(self.data.excludePeers.map { $0.toInt64() }, forKey: "excludePeers")
    }
}

extension ChatListFilter {
    init(apiFilter: Api.DialogFilter) {
        switch apiFilter {
        case let .dialogFilter(flags, id, title, includePeers, excludePeers):
            self.init(
                id: id,
                title: title,
                data: ChatListFilterData(
                    categories: ChatListFilterPeerCategories(apiFlags: flags),
                    excludeMuted: (flags & (1 << 11)) != 0,
                    excludeRead: (flags & (1 << 12)) != 0,
                    excludeArchived: (flags & (1 << 13)) != 0,
                    includePeers: includePeers.compactMap { peer -> PeerId? in
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        case let .inputPeerChat(chatId):
                            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .inputPeerChannel(channelId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        default:
                            return nil
                        }
                    },
                    excludePeers: excludePeers.compactMap { peer -> PeerId? in
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        case let .inputPeerChat(chatId):
                            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .inputPeerChannel(channelId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        default:
                            return nil
                        }
                    }
                )
            )
        }
    }
    
    func apiFilter(transaction: Transaction) -> Api.DialogFilter {
        var flags: Int32 = 0
        if self.data.excludeMuted {
            flags |= 1 << 11
        }
        if self.data.excludeRead {
            flags |= 1 << 12
        }
        if self.data.excludeArchived {
            flags |= 1 << 13
        }
        flags |= self.data.categories.apiFlags
        return .dialogFilter(flags: flags, id: self.id, title: self.title, includePeers: self.data.includePeers.compactMap { peerId -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }, excludePeers: self.data.excludePeers.compactMap { peerId -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        })
    }
}

public enum RequestUpdateChatListFilterError {
    case generic
}

public func requestUpdateChatListFilter(account: Account, id: Int32, filter: ChatListFilter?) -> Signal<Never, RequestUpdateChatListFilterError> {
    return account.postbox.transaction { transaction -> Api.DialogFilter? in
        return filter?.apiFilter(transaction: transaction)
    }
    |> castError(RequestUpdateChatListFilterError.self)
    |> mapToSignal { inputFilter -> Signal<Never, RequestUpdateChatListFilterError> in
        var flags: Int32 = 0
        if inputFilter != nil {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.messages.updateDialogFilter(flags: flags, id: id, filter: inputFilter))
        |> mapError { _ -> RequestUpdateChatListFilterError in
            return .generic
        }
        |> mapToSignal { _ -> Signal<Never, RequestUpdateChatListFilterError> in
            return .complete()
        }
    }
}

public enum RequestUpdateChatListFilterOrderError {
    case generic
}

public func requestUpdateChatListFilterOrder(account: Account, ids: [Int32]) -> Signal<Never, RequestUpdateChatListFilterOrderError> {
    return account.network.request(Api.functions.messages.updateDialogFiltersOrder(order: ids))
    |> mapError { _ -> RequestUpdateChatListFilterOrderError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Never, RequestUpdateChatListFilterOrderError> in
        return .complete()
    }
}

private enum RequestChatListFiltersError {
    case generic
}

private func requestChatListFilters(postbox: Postbox, network: Network) -> Signal<[ChatListFilter], RequestChatListFiltersError> {
    return network.request(Api.functions.messages.getDialogFilters())
    |> mapError { _ -> RequestChatListFiltersError in
        return .generic
    }
    |> mapToSignal { result -> Signal<[ChatListFilter], RequestChatListFiltersError> in
        return postbox.transaction { transaction -> ([ChatListFilter], [Api.InputPeer]) in
            var filters: [ChatListFilter] = []
            var missingPeers: [Api.InputPeer] = []
            var missingPeerIds = Set<PeerId>()
            for apiFilter in result {
                let filter = ChatListFilter(apiFilter: apiFilter)
                filters.append(filter)
                switch apiFilter {
                case let .dialogFilter(_, _, _, includePeers, excludePeers):
                    for peer in includePeers {
                        var peerId: PeerId?
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        case let .inputPeerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .inputPeerChannel(channelId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        default:
                            break
                        }
                        if let peerId = peerId {
                            if transaction.getPeer(peerId) == nil && !missingPeerIds.contains(peerId) {
                                missingPeerIds.insert(peerId)
                                missingPeers.append(peer)
                            }
                        }
                    }
                    for peer in excludePeers {
                        var peerId: PeerId?
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                        case let .inputPeerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .inputPeerChannel(channelId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        default:
                            break
                        }
                        if let peerId = peerId {
                            if transaction.getPeer(peerId) == nil && !missingPeerIds.contains(peerId) {
                                missingPeerIds.insert(peerId)
                                missingPeers.append(peer)
                            }
                        }
                    }
                }
            }
            return (filters, missingPeers)
        }
        |> castError(RequestChatListFiltersError.self)
        |> mapToSignal { filtersAndMissingPeers -> Signal<[ChatListFilter], RequestChatListFiltersError> in
            let (filters, missingPeers) = filtersAndMissingPeers
            return .single(filters)
        }
    }
}

func managedChatListFilters(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return requestChatListFilters(postbox: postbox, network: network)
    |> `catch` { _ -> Signal<[ChatListFilter], NoError> in
        return .complete()
    }
    |> mapToSignal { filters -> Signal<Never, NoError> in
        return postbox.transaction { transaction in
            transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
                var settings = entry as? ChatListFiltersState ?? ChatListFiltersState.default
                settings.filters = filters
                return settings
            })
        }
        |> ignoreValues
    }
}

public func replaceRemoteChatListFilters(account: Account) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> [ChatListFilter] in
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
        return settings.filters
    }
    |> mapToSignal { filters -> Signal<Never, NoError> in
        return requestChatListFilters(postbox: account.postbox, network: account.network)
        |> `catch` { _ -> Signal<[ChatListFilter], NoError> in
            return .complete()
        }
        |> mapToSignal { remoteFilters -> Signal<Never, NoError> in
            var deleteSignals: [Signal<Never, NoError>] = []
            for filter in remoteFilters {
                if !filters.contains(where: { $0.id == filter.id }) {
                    deleteSignals.append(requestUpdateChatListFilter(account: account, id: filter.id, filter: nil)
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                    |> ignoreValues)
                }
            }
            
            let addFilters = account.postbox.transaction { transaction -> [(Int32, ChatListFilter)] in
                let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
                return settings.filters.map { filter -> (Int32, ChatListFilter) in
                    return (filter.id, filter)
                }
            }
            |> mapToSignal { filters -> Signal<Never, NoError> in
                var signals: [Signal<Never, NoError>] = []
                for (id, filter) in filters {
                    if !remoteFilters.contains(filter) {
                        signals.append(requestUpdateChatListFilter(account: account, id: id, filter: filter)
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                        |> ignoreValues)
                    }
                }
                return combineLatest(signals)
                |> ignoreValues
            }
            
            let reorderFilters: Signal<Never, NoError>
            if remoteFilters.map({ $0.id }) != filters.map({ $0.id }) {
                reorderFilters = account.network.request(Api.functions.messages.updateDialogFiltersOrder(order: filters.map { $0.id }))
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            } else {
                reorderFilters = .complete()
            }
            
            return combineLatest(
                deleteSignals
            )
            |> ignoreValues
            |> then(
                addFilters
            )
            |> then(
                reorderFilters
            )
        }
    }
}

public struct ChatListFiltersState: PreferencesEntry, Equatable {
    public var filters: [ChatListFilter]
    public var remoteFilters: [ChatListFilter]?
    
    public static var `default` = ChatListFiltersState(filters: [], remoteFilters: nil)
    
    public init(filters: [ChatListFilter], remoteFilters: [ChatListFilter]?) {
        self.filters = filters
        self.remoteFilters = remoteFilters
    }
    
    public init(decoder: PostboxDecoder) {
        self.filters = decoder.decodeObjectArrayWithDecoderForKey("filters")
        self.remoteFilters = decoder.decodeOptionalObjectArrayWithDecoderForKey("remoteFilters")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.filters, forKey: "filters")
        if let remoteFilters = self.remoteFilters {
            encoder.encodeObjectArray(remoteFilters, forKey: "remoteFilters")
        } else {
            encoder.encodeNil(forKey: "remoteFilters")
        }
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFiltersState, self == to {
            return true
        } else {
            return false
        }
    }
}

public func updateChatListFilterSettingsInteractively(postbox: Postbox, _ f: @escaping (ChatListFiltersState) -> ChatListFiltersState) -> Signal<ChatListFiltersState, NoError> {
    return postbox.transaction { transaction -> ChatListFiltersState in
        var result: ChatListFiltersState?
        transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
            let settings = entry as? ChatListFiltersState ?? ChatListFiltersState.default
            let updated = f(settings)
            result = updated
            return updated
        })
        return result ?? .default
    }
}

