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

public func requestUpdateChatListFilter(postbox: Postbox, network: Network, id: Int32, filter: ChatListFilter?) -> Signal<Never, RequestUpdateChatListFilterError> {
    return postbox.transaction { transaction -> Api.DialogFilter? in
        return filter?.apiFilter(transaction: transaction)
    }
    |> castError(RequestUpdateChatListFilterError.self)
    |> mapToSignal { inputFilter -> Signal<Never, RequestUpdateChatListFilterError> in
        var flags: Int32 = 0
        if inputFilter != nil {
            flags |= 1 << 0
        }
        return network.request(Api.functions.messages.updateDialogFilter(flags: flags, id: id, filter: inputFilter))
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
            
            var missingUsers: [Api.InputUser] = []
            var missingChannels: [Api.InputChannel] = []
            var missingGroups: [Int32] = []
            for peer in missingPeers {
                switch peer {
                case let .inputPeerUser(userId, accessHash):
                    missingUsers.append(.inputUser(userId: userId, accessHash: accessHash))
                case .inputPeerSelf:
                    missingUsers.append(.inputUserSelf)
                case let .inputPeerChannel(channelId, accessHash):
                    missingChannels.append(.inputChannel(channelId: channelId, accessHash: accessHash))
                case let .inputPeerChat(id):
                    missingGroups.append(id)
                case .inputPeerEmpty:
                    break
                }
            }
            
            let resolveMissingUsers: Signal<Never, NoError>
            if !missingUsers.isEmpty {
                resolveMissingUsers = network.request(Api.functions.users.getUsers(id: missingUsers))
                |> `catch` { _ -> Signal<[Api.User], NoError> in
                    return .single([])
                }
                |> mapToSignal { users -> Signal<Never, NoError> in
                    return postbox.transaction { transaction -> Void in
                        var peers: [Peer] = []
                        for user in users {
                            peers.append(TelegramUser(user: user))
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                            return updated
                        })
                    }
                    |> ignoreValues
                }
            } else {
                resolveMissingUsers = .complete()
            }
            
            let resolveMissingChannels: Signal<Never, NoError>
            if !missingChannels.isEmpty {
                resolveMissingChannels = network.request(Api.functions.channels.getChannels(id: missingChannels))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Never, NoError> in
                    return postbox.transaction { transaction -> Void in
                        if let result = result {
                            var peers: [Peer] = []
                            switch result {
                            case .chats(let chats), .chatsSlice(_, let chats):
                                for chat in chats {
                                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                        peers.append(peer)
                                    }
                                }
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                return updated
                            })
                        }
                    }
                    |> ignoreValues
                }
            } else {
                resolveMissingChannels = .complete()
            }
            
            let resolveMissingGroups: Signal<Never, NoError>
            if !missingGroups.isEmpty {
                resolveMissingGroups = network.request(Api.functions.messages.getChats(id: missingGroups))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Never, NoError> in
                    return postbox.transaction { transaction -> Void in
                        if let result = result {
                            var peers: [Peer] = []
                            switch result {
                            case .chats(let chats), .chatsSlice(_, let chats):
                                for chat in chats {
                                    if let peer = parseTelegramGroupOrChannel(chat: chat) {
                                        peers.append(peer)
                                    }
                                }
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                                return updated
                            })
                        }
                    }
                    |> ignoreValues
                }
            } else {
                resolveMissingGroups = .complete()
            }
            
            return (
                resolveMissingUsers
            )
            |> then(
                resolveMissingChannels
            )
            |> then(
                resolveMissingGroups
            )
            |> castError(RequestChatListFiltersError.self)
            |> mapToSignal { _ -> Signal<[ChatListFilter], RequestChatListFiltersError> in
                return .complete()
            }
            |> then(
                .single(filters)
            )
        }
    }
}

struct ChatListFiltersState: PreferencesEntry, Equatable {
    var filters: [ChatListFilter]
    var remoteFilters: [ChatListFilter]?
    
    static var `default` = ChatListFiltersState(filters: [], remoteFilters: nil)
    
    fileprivate init(filters: [ChatListFilter], remoteFilters: [ChatListFilter]?) {
        self.filters = filters
        self.remoteFilters = remoteFilters
    }
    
    init(decoder: PostboxDecoder) {
        self.filters = decoder.decodeObjectArrayWithDecoderForKey("filters")
        self.remoteFilters = decoder.decodeOptionalObjectArrayWithDecoderForKey("remoteFilters")
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.filters, forKey: "filters")
        if let remoteFilters = self.remoteFilters {
            encoder.encodeObjectArray(remoteFilters, forKey: "remoteFilters")
        } else {
            encoder.encodeNil(forKey: "remoteFilters")
        }
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFiltersState, self == to {
            return true
        } else {
            return false
        }
    }
}

public func generateNewChatListFilterId(filters: [ChatListFilter]) -> Int32 {
    while true {
        let id = Int32(2 + arc4random_uniform(255 - 2))
        if !filters.contains(where: { $0.id == id }) {
            return id
        }
    }
}

public func updateChatListFiltersInteractively(postbox: Postbox, _ f: @escaping ([ChatListFilter]) -> [ChatListFilter]) -> Signal<[ChatListFilter], NoError> {
    return postbox.transaction { transaction -> [ChatListFilter] in
        var updated: [ChatListFilter] = []
        var hasUpdates = false
        transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
            var state = entry as? ChatListFiltersState ?? ChatListFiltersState.default
            let updatedFilters = f(state.filters)
            if updatedFilters != state.filters {
                state.filters = updatedFilters
                hasUpdates = true
            }
            updated = updatedFilters
            return state
        })
        if hasUpdates {
            requestChatListFiltersSync(transaction: transaction)
        }
        return updated
    }
}

public func updatedChatListFilters(postbox: Postbox) -> Signal<[ChatListFilter], NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> [ChatListFilter] in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
        return filtersState.filters
    }
    |> distinctUntilChanged
}

public func currentChatListFilters(postbox: Postbox) -> Signal<[ChatListFilter], NoError> {
    return postbox.transaction { transaction -> [ChatListFilter] in
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
        return settings.filters
    }
}

func updateChatListFiltersState(transaction: Transaction, _ f: (ChatListFiltersState) -> ChatListFiltersState) -> ChatListFiltersState {
    var result: ChatListFiltersState?
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
        let settings = entry as? ChatListFiltersState ?? ChatListFiltersState.default
        let updated = f(settings)
        result = updated
        return updated
    })
    return result ?? .default
}

public struct ChatListFeaturedFilter: PostboxCoding, Equatable {
    public var title: String
    public var description: String
    public var data: ChatListFilterData
    
    fileprivate init(
        title: String,
        description: String,
        data: ChatListFilterData
    ) {
        self.title = title
        self.description = description
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.description = decoder.decodeStringForKey("description", orElse: "")
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
        encoder.encodeString(self.title, forKey: "title")
        encoder.encodeString(self.description, forKey: "description")
        encoder.encodeInt32(self.data.categories.rawValue, forKey: "categories")
        encoder.encodeInt32(self.data.excludeMuted ? 1 : 0, forKey: "excludeMuted")
        encoder.encodeInt32(self.data.excludeRead ? 1 : 0, forKey: "excludeRead")
        encoder.encodeInt32(self.data.excludeArchived ? 1 : 0, forKey: "excludeArchived")
        encoder.encodeInt64Array(self.data.includePeers.map { $0.toInt64() }, forKey: "includePeers")
        encoder.encodeInt64Array(self.data.excludePeers.map { $0.toInt64() }, forKey: "excludePeers")
    }
}

public struct ChatListFiltersFeaturedState: PreferencesEntry, Equatable {
    public var filters: [ChatListFeaturedFilter]
    public var isSeen: Bool
    
    fileprivate init(filters: [ChatListFeaturedFilter], isSeen: Bool) {
        self.filters = filters
        self.isSeen = isSeen
    }
    
    public init(decoder: PostboxDecoder) {
        self.filters = decoder.decodeObjectArrayWithDecoderForKey("filters")
        self.isSeen = decoder.decodeInt32ForKey("isSeen", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.filters, forKey: "filters")
        encoder.encodeInt32(self.isSeen ? 1 : 0, forKey: "isSeen")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? ChatListFiltersFeaturedState, self == to {
            return true
        } else {
            return false
        }
    }
}

public func markChatListFeaturedFiltersAsSeen(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
            guard var state = entry as? ChatListFiltersFeaturedState else {
                return entry
            }
            state.isSeen = true
            return state
        })
    }
    |> ignoreValues
}

public func unmarkChatListFeaturedFiltersAsSeen(transaction: Transaction) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
        guard var state = entry as? ChatListFiltersFeaturedState else {
            return entry
        }
        state.isSeen = false
        return state
    })
}

public func updateChatListFeaturedFilters(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return network.request(Api.functions.messages.getSuggestedDialogFilters())
    |> `catch` { _ -> Signal<[Api.DialogFilterSuggested], NoError> in
        return .single([])
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> Void in
            transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
                var state = entry as? ChatListFiltersFeaturedState ?? ChatListFiltersFeaturedState(filters: [], isSeen: false)
                state.filters = result.map { item -> ChatListFeaturedFilter in
                    switch item {
                    case let .dialogFilterSuggested(filter, description):
                        let parsedFilter = ChatListFilter(apiFilter: filter)
                        return ChatListFeaturedFilter(title: parsedFilter.title, description: description, data: parsedFilter.data)
                    }
                }
                return state
            })
        }
        |> ignoreValues
    }
}

private enum SynchronizeChatListFiltersOperationContentType: Int32 {
    case add
    case remove
    case sync
}

private enum SynchronizeChatListFiltersOperationContent: PostboxCoding {
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
        case SynchronizeChatListFiltersOperationContentType.sync.rawValue:
            self = .sync
        default:
            assertionFailure()
            self = .sync
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case .sync:
            encoder.encodeInt32(SynchronizeChatListFiltersOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

final class SynchronizeChatListFiltersOperation: PostboxCoding {
    fileprivate let content: SynchronizeChatListFiltersOperationContent
    
    fileprivate init(content: SynchronizeChatListFiltersOperationContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeChatListFiltersOperationContent(decoder: $0) }) as! SynchronizeChatListFiltersOperationContent
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}


private final class ManagedSynchronizeChatListFiltersOperationsHelper {
    var operationDisposables: [Int32: Disposable] = [:]
    
    func update(_ entries: [PeerMergedOperationLogEntry]) -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) {
        var disposeOperations: [Disposable] = []
        var beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)] = []
        
        var hasRunningOperationForPeerId = Set<PeerId>()
        var validMergedIndices = Set<Int32>()
        for entry in entries {
            if !hasRunningOperationForPeerId.contains(entry.peerId) {
                hasRunningOperationForPeerId.insert(entry.peerId)
                validMergedIndices.insert(entry.mergedIndex)
                
                if self.operationDisposables[entry.mergedIndex] == nil {
                    let disposable = MetaDisposable()
                    beginOperations.append((entry, disposable))
                    self.operationDisposables[entry.mergedIndex] = disposable
                }
            }
        }
        
        var removeMergedIndices: [Int32] = []
        for (mergedIndex, disposable) in self.operationDisposables {
            if !validMergedIndices.contains(mergedIndex) {
                removeMergedIndices.append(mergedIndex)
                disposeOperations.append(disposable)
            }
        }
        
        for mergedIndex in removeMergedIndices {
            self.operationDisposables.removeValue(forKey: mergedIndex)
        }
        
        return (disposeOperations, beginOperations)
    }
    
    func reset() -> [Disposable] {
        let disposables = Array(self.operationDisposables.values)
        self.operationDisposables.removeAll()
        return disposables
    }
}

private func withTakenOperation(postbox: Postbox, peerId: PeerId, tag: PeerOperationLogTag, tagLocalIndex: Int32, _ f: @escaping (Transaction, PeerMergedOperationLogEntry?) -> Signal<Never, NoError>) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var result: PeerMergedOperationLogEntry?
        transaction.operationLogUpdateEntry(peerId: peerId, tag: tag, tagLocalIndex: tagLocalIndex, { entry in
            if let entry = entry, let _ = entry.mergedIndex, entry.contents is SynchronizeChatListFiltersOperation  {
                result = entry.mergedEntry!
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            } else {
                return PeerOperationLogEntryUpdate(mergedIndex: .none, contents: .none)
            }
        })
        
        return f(transaction, result)
    }
    |> switchToLatest
}

func requestChatListFiltersSync(transaction: Transaction) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatListFilters
    let peerId = PeerId(namespace: 0, id: 0)
    
    var topOperation: (SynchronizeChatListFiltersOperation, Int32)?
    transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
        if let operation = entry.contents as? SynchronizeChatListFiltersOperation {
            topOperation = (operation, entry.tagLocalIndex)
        }
        return false
    })
    
    if let (topOperation, topLocalIndex) = topOperation, case .sync = topOperation.content {
        let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
    }
    
    transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeChatListFiltersOperation(content: .sync))
}

func managedChatListFilters(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return Signal { _ in
        let updateFeaturedDisposable = updateChatListFeaturedFilters(postbox: postbox, network: network).start()
        let _ = postbox.transaction({ transaction in
            requestChatListFiltersSync(transaction: transaction)
        }).start()
        
        let tag: PeerOperationLogTag = OperationLogTags.SynchronizeChatListFilters
        
        let helper = Atomic<ManagedSynchronizeChatListFiltersOperationsHelper>(value: ManagedSynchronizeChatListFiltersOperationsHelper())
        
        let disposable = postbox.mergedOperationLogView(tag: tag, limit: 10).start(next: { view in
            let (disposeOperations, beginOperations) = helper.with { helper -> (disposeOperations: [Disposable], beginOperations: [(PeerMergedOperationLogEntry, MetaDisposable)]) in
                return helper.update(view.entries)
            }
            
            for disposable in disposeOperations {
                disposable.dispose()
            }
            
            for (entry, disposable) in beginOperations {
                let signal = withTakenOperation(postbox: postbox, peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex, { transaction, entry -> Signal<Never, NoError> in
                    if let entry = entry {
                        if let operation = entry.contents as? SynchronizeChatListFiltersOperation {
                            return synchronizeChatListFilters(transaction: transaction, postbox: postbox, network: network, operation: operation)
                        } else {
                            assertionFailure()
                        }
                    }
                    return .complete()
                })
                |> then(
                    postbox.transaction { transaction -> Void in
                    let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
                    }
                    |> ignoreValues
                )
                
                disposable.set(signal.start())
            }
        })
        
        return ActionDisposable {
            updateFeaturedDisposable.dispose()
            
            let disposables = helper.with { helper -> [Disposable] in
                return helper.reset()
            }
            for disposable in disposables {
                disposable.dispose()
            }
            disposable.dispose()
        }
    }
}

private func synchronizeChatListFilters(transaction: Transaction, postbox: Postbox, network: Network, operation: SynchronizeChatListFiltersOperation) -> Signal<Never, NoError> {
    switch operation.content {
    case .sync:
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
        let localFilters = settings.filters
        let locallyKnownRemoteFilters = settings.remoteFilters ?? []
        
        return requestChatListFilters(postbox: postbox, network: network)
        |> `catch` { _ -> Signal<[ChatListFilter], NoError> in
            return .complete()
        }
        |> mapToSignal { remoteFilters -> Signal<Never, NoError> in
            if localFilters == locallyKnownRemoteFilters {
                return postbox.transaction { transaction -> Void in
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        state.filters = remoteFilters
                        state.remoteFilters = state.filters
                        return state
                    })
                }
                |> ignoreValues
            }
            
            let locallyKnownRemoteFilterIds = locallyKnownRemoteFilters.map { $0.id }
            
            let remoteFilterIds = remoteFilters.map { $0.id }
            let remotelyAddedFilters = Set(remoteFilterIds).subtracting(Set(locallyKnownRemoteFilterIds))
            let remotelyRemovedFilters = Set(Set(locallyKnownRemoteFilterIds)).subtracting(remoteFilterIds)
            
            var mergedFilters = localFilters
            
            for id in remotelyRemovedFilters {
                mergedFilters.removeAll(where: { $0.id == id })
            }
            
            for id in remotelyAddedFilters {
                if let filter = remoteFilters.first(where: { $0.id == id }) {
                    if let index = mergedFilters.firstIndex(where: { $0.id == id }) {
                        mergedFilters[index] = filter
                    } else {
                        mergedFilters.append(filter)
                    }
                }
            }
            
            let mergedFilterIds = mergedFilters.map { $0.id }
            
            var deleteSignals: Signal<Never, NoError> = .complete()
            for filter in remoteFilters {
                if !mergedFilterIds.contains(where: { $0 == filter.id }) {
                    deleteSignals = deleteSignals
                    |> then(
                        requestUpdateChatListFilter(postbox: postbox, network: network, id: filter.id, filter: nil)
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                        |> ignoreValues
                    )
                }
            }
            
            var addSignals: Signal<Never, NoError> = .complete()
            for filter in mergedFilters {
                let updated: Bool
                if let index = remoteFilters.firstIndex(where: { $0.id == filter.id }) {
                    updated = remoteFilters[index] != filter
                } else {
                    updated = true
                }
                if updated {
                    addSignals = addSignals
                    |> then(
                        requestUpdateChatListFilter(postbox: postbox, network: network, id: filter.id, filter: filter)
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                        |> ignoreValues
                    )
                }
            }
            
            let reorderFilters: Signal<Never, NoError>
            if mergedFilterIds != remoteFilterIds {
                reorderFilters = network.request(Api.functions.messages.updateDialogFiltersOrder(order: mergedFilters.map { $0.id }))
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            } else {
                reorderFilters = .complete()
            }
            
            return deleteSignals
            |> then(
                addSignals
            )
            |> then(
                reorderFilters
            )
            |> then(
                postbox.transaction { transaction -> Void in
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        state.filters = mergedFilters
                        state.remoteFilters = state.filters
                        return state
                    })
                }
                |> ignoreValues
            )
        }
    }
}
