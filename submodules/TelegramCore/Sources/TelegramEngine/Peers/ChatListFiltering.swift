import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


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

public struct ChatListFilterIncludePeers: Equatable, Hashable {
    public private(set) var peers: [PeerId]
    public private(set) var pinnedPeers: [PeerId]
    
    public init() {
        self.peers = []
        self.pinnedPeers = []
    }
    
    init(peers: [PeerId], pinnedPeers: [PeerId]) {
        self.peers = peers
        self.pinnedPeers = pinnedPeers
    }
    
    public mutating func reorderPinnedPeers(_ pinnedPeers: [PeerId]) {
        if Set(self.pinnedPeers) == Set(pinnedPeers) {
            self.pinnedPeers = pinnedPeers
        }
    }
    
    public mutating func addPinnedPeer(_ peerId: PeerId) -> Bool {
        if self.pinnedPeers.contains(peerId) {
            return false
        }
        if self.peers.contains(peerId) {
            self.pinnedPeers.insert(peerId, at: 0)
            return true
        } else {
            if self.peers.count < 100 {
                self.peers.insert(peerId, at: 0)
                self.pinnedPeers.insert(peerId, at: 0)
                return true
            } else {
                return false
            }
        }
    }
    
    public mutating func removePinnedPeer(_ peerId: PeerId) {
        if self.pinnedPeers.contains(peerId) {
            self.pinnedPeers.removeAll(where: { $0 == peerId })
        }
    }
    
    public mutating func addPeer(_ peerId: PeerId) -> Bool {
        if self.pinnedPeers.contains(peerId) {
            return false
        }
        if self.peers.contains(peerId) {
            return false
        }
        
        if self.peers.count + self.pinnedPeers.count >= 100 {
            return false
        }
        self.peers.insert(peerId, at: 0)
        return true
    }
    
    public mutating func removePeer(_ peerId: PeerId) -> Bool {
        var found = false
        if let index = self.pinnedPeers.firstIndex(of: peerId) {
            self.pinnedPeers.remove(at: index)
            found = true
        }
        if let index = self.peers.firstIndex(of: peerId) {
            self.peers.remove(at: index)
            found = true
        }
        return found
    }
    
    public mutating func setPeers(_ peers: [PeerId]) {
        self.peers = peers
        self.pinnedPeers = self.pinnedPeers.filter { peers.contains($0) }
    }
}

extension ChatListFilterIncludePeers {
    init(rawPeers: [PeerId], rawPinnedPeers: [PeerId]) {
        self.peers = rawPinnedPeers + rawPeers.filter { !rawPinnedPeers.contains($0) }
        self.pinnedPeers = rawPinnedPeers
    }
}

public struct ChatListFilterData: Equatable, Hashable {
    public var categories: ChatListFilterPeerCategories
    public var excludeMuted: Bool
    public var excludeRead: Bool
    public var excludeArchived: Bool
    public var includePeers: ChatListFilterIncludePeers
    public var excludePeers: [PeerId]
    
    public init(
        categories: ChatListFilterPeerCategories,
        excludeMuted: Bool,
        excludeRead: Bool,
        excludeArchived: Bool,
        includePeers: ChatListFilterIncludePeers,
        excludePeers: [PeerId]
    ) {
        self.categories = categories
        self.excludeMuted = excludeMuted
        self.excludeRead = excludeRead
        self.excludeArchived = excludeArchived
        self.includePeers = includePeers
        self.excludePeers = excludePeers
    }
    
    public mutating func addIncludePeer(peerId: PeerId) -> Bool {
        if self.includePeers.peers.contains(peerId) || self.includePeers.pinnedPeers.contains(peerId) {
            return false
        }
        if self.includePeers.addPeer(peerId) {
            self.excludePeers.removeAll(where: { $0 == peerId })
            return true
        } else {
            return false
        }
    }
    
    public mutating func addExcludePeer(peerId: PeerId) -> Bool {
        if self.excludePeers.contains(peerId) {
            return false
        }
        if self.excludePeers.count >= 100 {
            return false
        }
        
        let _ = self.includePeers.removePeer(peerId)
        self.excludePeers.append(peerId)
        
        return true
    }
}

public struct ChatListFilter: PostboxCoding, Equatable {
    public var id: Int32
    public var title: String
    public var emoticon: String?
    public var data: ChatListFilterData
    
    public init(
        id: Int32,
        title: String,
        emoticon: String?,
        data: ChatListFilterData
    ) {
        self.id = id
        self.title = title
        self.emoticon = emoticon
        self.data = data
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt32ForKey("id", orElse: 0)
        self.title = decoder.decodeStringForKey("title", orElse: "")
        self.emoticon = decoder.decodeOptionalStringForKey("emoticon")
        self.data = ChatListFilterData(
            categories: ChatListFilterPeerCategories(rawValue: decoder.decodeInt32ForKey("categories", orElse: 0)),
            excludeMuted: decoder.decodeInt32ForKey("excludeMuted", orElse: 0) != 0,
            excludeRead: decoder.decodeInt32ForKey("excludeRead", orElse: 0) != 0,
            excludeArchived: decoder.decodeInt32ForKey("excludeArchived", orElse: 0) != 0,
            includePeers: ChatListFilterIncludePeers(peers: decoder.decodeInt64ArrayForKey("includePeers").map(PeerId.init), pinnedPeers: decoder.decodeInt64ArrayForKey("pinnedPeers").map(PeerId.init)),
            excludePeers: decoder.decodeInt64ArrayForKey("excludePeers").map(PeerId.init)
        )
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.id, forKey: "id")
        encoder.encodeString(self.title, forKey: "title")
        if let emoticon = self.emoticon {
            encoder.encodeString(emoticon, forKey: "emoticon")
        } else {
            encoder.encodeNil(forKey: "emoticon")
        }
        encoder.encodeInt32(self.data.categories.rawValue, forKey: "categories")
        encoder.encodeInt32(self.data.excludeMuted ? 1 : 0, forKey: "excludeMuted")
        encoder.encodeInt32(self.data.excludeRead ? 1 : 0, forKey: "excludeRead")
        encoder.encodeInt32(self.data.excludeArchived ? 1 : 0, forKey: "excludeArchived")
        encoder.encodeInt64Array(self.data.includePeers.peers.map { $0.toInt64() }, forKey: "includePeers")
        encoder.encodeInt64Array(self.data.includePeers.pinnedPeers.map { $0.toInt64() }, forKey: "pinnedPeers")
        encoder.encodeInt64Array(self.data.excludePeers.map { $0.toInt64() }, forKey: "excludePeers")
    }
}

extension ChatListFilter {
    init(apiFilter: Api.DialogFilter) {
        switch apiFilter {
        case let .dialogFilter(flags, id, title, emoticon, pinnedPeers, includePeers, excludePeers):
            self.init(
                id: id,
                title: title,
                emoticon: emoticon,
                data: ChatListFilterData(
                    categories: ChatListFilterPeerCategories(apiFlags: flags),
                    excludeMuted: (flags & (1 << 11)) != 0,
                    excludeRead: (flags & (1 << 12)) != 0,
                    excludeArchived: (flags & (1 << 13)) != 0,
                    includePeers: ChatListFilterIncludePeers(rawPeers: includePeers.compactMap { peer -> PeerId? in
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                        case let .inputPeerChat(chatId):
                            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        case let .inputPeerChannel(channelId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        default:
                            return nil
                        }
                    }, rawPinnedPeers: pinnedPeers.compactMap { peer -> PeerId? in
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                        case let .inputPeerChat(chatId):
                            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        case let .inputPeerChannel(channelId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        default:
                            return nil
                        }
                    }),
                    excludePeers: excludePeers.compactMap { peer -> PeerId? in
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                        case let .inputPeerChat(chatId):
                            return PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        case let .inputPeerChannel(channelId, _):
                            return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
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
        if self.emoticon != nil {
            flags |= 1 << 25
        }
        return .dialogFilter(flags: flags, id: self.id, title: self.title, emoticon: self.emoticon, pinnedPeers: self.data.includePeers.pinnedPeers.compactMap { peerId -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }, includePeers: self.data.includePeers.peers.compactMap { peerId -> Api.InputPeer? in
            if self.data.includePeers.pinnedPeers.contains(peerId) {
                return nil
            }
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }, excludePeers: self.data.excludePeers.compactMap { peerId -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        })
    }
}

public enum RequestUpdateChatListFilterError {
    case generic
}

func _internal_requestUpdateChatListFilter(postbox: Postbox, network: Network, id: Int32, filter: ChatListFilter?) -> Signal<Never, RequestUpdateChatListFilterError> {
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

func _internal_requestUpdateChatListFilterOrder(account: Account, ids: [Int32]) -> Signal<Never, RequestUpdateChatListFilterOrderError> {
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

private func requestChatListFilters(accountPeerId: PeerId, postbox: Postbox, network: Network) -> Signal<[ChatListFilter], RequestChatListFiltersError> {
    return network.request(Api.functions.messages.getDialogFilters())
    |> mapError { _ -> RequestChatListFiltersError in
        return .generic
    }
    |> mapToSignal { result -> Signal<[ChatListFilter], RequestChatListFiltersError> in
        return postbox.transaction { transaction -> ([ChatListFilter], [Api.InputPeer], [Api.InputPeer]) in
            var filters: [ChatListFilter] = []
            var missingPeers: [Api.InputPeer] = []
            var missingChats: [Api.InputPeer] = []
            var missingPeerIds = Set<PeerId>()
            var missingChatIds = Set<PeerId>()
            for apiFilter in result {
                let filter = ChatListFilter(apiFilter: apiFilter)
                filters.append(filter)
                switch apiFilter {
                case let .dialogFilter(_, _, _, _, pinnedPeers, includePeers, excludePeers):
                    for peer in pinnedPeers + includePeers + excludePeers {
                        var peerId: PeerId?
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                        case let .inputPeerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        case let .inputPeerChannel(channelId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
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
                    
                    for peer in pinnedPeers {
                        var peerId: PeerId?
                        switch peer {
                        case let .inputPeerUser(userId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                        case let .inputPeerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        case let .inputPeerChannel(channelId, _):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        default:
                            break
                        }
                        if let peerId = peerId, !missingChatIds.contains(peerId) {
                            if transaction.getPeerChatListIndex(peerId) == nil {
                                missingChatIds.insert(peerId)
                                missingChats.append(peer)
                            }
                        }
                    }
                }
            }
            return (filters, missingPeers, missingChats)
        }
        |> castError(RequestChatListFiltersError.self)
        |> mapToSignal { filtersAndMissingPeers -> Signal<[ChatListFilter], RequestChatListFiltersError> in
            let (filters, missingPeers, missingChats) = filtersAndMissingPeers
            
            var missingUsers: [Api.InputUser] = []
            var missingChannels: [Api.InputChannel] = []
            var missingGroups: [Int64] = []
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
                case .inputPeerUserFromMessage:
                    break
                case .inputPeerChannelFromMessage:
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
            
            let loadMissingChats: Signal<Never, NoError>
            if !missingChats.isEmpty {
                loadMissingChats = loadAndStorePeerChatInfos(accountPeerId: accountPeerId, postbox: postbox, network: network, peers: missingChats)
            } else {
                loadMissingChats = .complete()
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
            |> then(
                loadMissingChats
            )
            |> castError(RequestChatListFiltersError.self)
            |> mapToSignal { _ -> Signal<[ChatListFilter], RequestChatListFiltersError> in
                #if swift(<5.1)
                return .complete()
                #endif
            }
            |> then(
                .single(filters)
            )
        }
    }
}

private func loadAndStorePeerChatInfos(accountPeerId: PeerId, postbox: Postbox, network: Network, peers: [Api.InputPeer]) -> Signal<Never, NoError> {
    let signal = network.request(Api.functions.messages.getPeerDialogs(peers: peers.map(Api.InputDialogPeer.inputDialogPeer(peer:))))
    |> map(Optional.init)
        
    return signal
    |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result = result else {
            return .complete()
        }
        
        return postbox.transaction { transaction -> Void in
            var peers: [Peer] = []
            var peerPresences: [PeerId: PeerPresence] = [:]
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            var channelStates: [PeerId: Int32] = [:]
            
            switch result {
            case let .peerDialogs(dialogs, messages, chats, users, _):
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
                
                var topMessageIds = Set<MessageId>()
                
                for dialog in dialogs {
                    switch dialog {
                    case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, notifySettings, pts, _, folderId):
                        let peerId = peer.peerId
                        
                        if topMessage != 0 {
                            topMessageIds.insert(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: topMessage))
                        }
                        
                        var isExcludedFromChatList = false
                        for chat in chats {
                            if chat.peerId == peerId {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    if let group = groupOrChannel as? TelegramGroup {
                                        if group.flags.contains(.deactivated) {
                                            isExcludedFromChatList = true
                                        } else {
                                            switch group.membership {
                                            case .Member:
                                                break
                                            default:
                                                isExcludedFromChatList = true
                                            }
                                        }
                                    } else if let channel = groupOrChannel as? TelegramChannel {
                                        switch channel.participationStatus {
                                        case .member:
                                            break
                                        default:
                                            isExcludedFromChatList = true
                                        }
                                    }
                                }
                                break
                            }
                        }
                        
                        if !isExcludedFromChatList {
                            let groupId = PeerGroupId(rawValue: folderId ?? 0)
                            let currentInclusion = transaction.getPeerChatListInclusion(peerId)
                            var currentPinningIndex: UInt16?
                            var currentMinTimestamp: Int32?
                            switch currentInclusion {
                                case let .ifHasMessagesOrOneOf(currentGroupId, pinningIndex, minTimestamp):
                                    if currentGroupId == groupId {
                                        currentPinningIndex = pinningIndex
                                    }
                                    currentMinTimestamp = minTimestamp
                                default:
                                    break
                            }
                            transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: currentPinningIndex, minTimestamp: currentMinTimestamp))
                        }
                        
                        notificationSettings[peer.peerId] = TelegramPeerNotificationSettings(apiSettings: notifySettings)
                        
                        transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: false)]])
                        
                        transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: unreadMentionsCount, maxId: topMessage)
                        
                        if let pts = pts {
                            if transaction.getPeerChatState(peerId) == nil {
                                transaction.setPeerChatState(peerId, state: ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil))
                            }
                            channelStates[peer.peerId] = pts
                        }
                    case .dialogFolder:
                        assertionFailure()
                        break
                    }
                }
                
                var storeMessages: [StoreMessage] = []
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message) {
                        var updatedStoreMessage = storeMessage
                        if case let .Id(id) = storeMessage.id {
                            if let channelPts = channelStates[id.peerId] {
                                var updatedAttributes = storeMessage.attributes
                                updatedAttributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                updatedStoreMessage = updatedStoreMessage.withUpdatedAttributes(updatedAttributes)
                            }
                        }
                        storeMessages.append(updatedStoreMessage)
                    }
                }
                
                for message in storeMessages {
                    if case let .Id(id) = message.id {
                        let _ = transaction.addMessages([message], location: topMessageIds.contains(id) ? .UpperHistoryBlock : .Random)
                    }
                }
            }
            
            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                return updated
            })
            
            updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
            
            transaction.updateCurrentPeerNotificationSettings(notificationSettings)
        }
        |> ignoreValues
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

func _internal_generateNewChatListFilterId(filters: [ChatListFilter]) -> Int32 {
    while true {
        let id = Int32(2 + arc4random_uniform(255 - 2))
        if !filters.contains(where: { $0.id == id }) {
            return id
        }
    }
}

func _internal_updateChatListFiltersInteractively(postbox: Postbox, _ f: @escaping ([ChatListFilter]) -> [ChatListFilter]) -> Signal<[ChatListFilter], NoError> {
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

func _internal_updateChatListFiltersInteractively(transaction: Transaction, _ f: ([ChatListFilter]) -> [ChatListFilter]) {
    var hasUpdates = false
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
        var state = entry as? ChatListFiltersState ?? ChatListFiltersState.default
        let updatedFilters = f(state.filters)
        if updatedFilters != state.filters {
            state.filters = updatedFilters
            hasUpdates = true
        }
        return state
    })
    if hasUpdates {
        requestChatListFiltersSync(transaction: transaction)
    }
}


func _internal_updatedChatListFilters(postbox: Postbox) -> Signal<[ChatListFilter], NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> [ChatListFilter] in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
        return filtersState.filters
    }
    |> distinctUntilChanged
}

func _internal_updatedChatListFiltersInfo(postbox: Postbox) -> Signal<(filters: [ChatListFilter], synchronized: Bool), NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> (filters: [ChatListFilter], synchronized: Bool) in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState ?? ChatListFiltersState.default
        return (filtersState.filters, filtersState.remoteFilters != nil)
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
        if lhs.filters != rhs.filters {
            return false
        }
        if lhs.synchronized != rhs.synchronized {
            return false
        }
        return true
    })
}

func _internal_currentChatListFilters(postbox: Postbox) -> Signal<[ChatListFilter], NoError> {
    return postbox.transaction { transaction -> [ChatListFilter] in
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
        return settings.filters
    }
}

func _internal_currentChatListFilters(transaction: Transaction) -> [ChatListFilter] {
    let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
    return settings.filters
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
            includePeers: ChatListFilterIncludePeers(peers: decoder.decodeInt64ArrayForKey("includePeers").map(PeerId.init), pinnedPeers: decoder.decodeInt64ArrayForKey("pinnedPeers").map(PeerId.init)),
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
        encoder.encodeInt64Array(self.data.includePeers.peers.map { $0.toInt64() }, forKey: "includePeers")
        encoder.encodeInt64Array(self.data.includePeers.pinnedPeers.map { $0.toInt64() }, forKey: "pinnedPeers")
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

func _internal_markChatListFeaturedFiltersAsSeen(postbox: Postbox) -> Signal<Never, NoError> {
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

func _internal_unmarkChatListFeaturedFiltersAsSeen(transaction: Transaction) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
        guard var state = entry as? ChatListFiltersFeaturedState else {
            return entry
        }
        state.isSeen = false
        return state
    })
}

func _internal_updateChatListFeaturedFilters(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
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
    case sync
}

private enum SynchronizeChatListFiltersOperationContent: PostboxCoding {
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
        case SynchronizeChatListFiltersOperationContentType.sync.rawValue:
            self = .sync
        default:
            //assertionFailure()
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
    let peerId = PeerId(0)
    
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

func managedChatListFilters(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return Signal { _ in
        let updateFeaturedDisposable = _internal_updateChatListFeaturedFilters(postbox: postbox, network: network).start()
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
                            return synchronizeChatListFilters(transaction: transaction, accountPeerId: accountPeerId, postbox: postbox, network: network, operation: operation)
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

private func synchronizeChatListFilters(transaction: Transaction, accountPeerId: PeerId, postbox: Postbox, network: Network, operation: SynchronizeChatListFiltersOperation) -> Signal<Never, NoError> {
    switch operation.content {
    case .sync:
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters) as? ChatListFiltersState ?? ChatListFiltersState.default
        let localFilters = settings.filters
        let locallyKnownRemoteFilters = settings.remoteFilters ?? []
        
        return requestChatListFilters(accountPeerId: accountPeerId, postbox: postbox, network: network)
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
                        _internal_requestUpdateChatListFilter(postbox: postbox, network: network, id: filter.id, filter: nil)
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
                        _internal_requestUpdateChatListFilter(postbox: postbox, network: network, id: filter.id, filter: filter)
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
