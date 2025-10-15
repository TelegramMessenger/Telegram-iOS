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
            self.peers.insert(peerId, at: 0)
            self.pinnedPeers.insert(peerId, at: 0)
            return true
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
    public var isShared: Bool
    public var hasSharedLinks: Bool
    public var categories: ChatListFilterPeerCategories
    public var excludeMuted: Bool
    public var excludeRead: Bool
    public var excludeArchived: Bool
    public var includePeers: ChatListFilterIncludePeers
    public var excludePeers: [PeerId]
    public var color: PeerNameColor?
    
    public init(
        isShared: Bool,
        hasSharedLinks: Bool,
        categories: ChatListFilterPeerCategories,
        excludeMuted: Bool,
        excludeRead: Bool,
        excludeArchived: Bool,
        includePeers: ChatListFilterIncludePeers,
        excludePeers: [PeerId],
        color: PeerNameColor?
    ) {
        self.isShared = isShared
        self.hasSharedLinks = hasSharedLinks
        self.categories = categories
        self.excludeMuted = excludeMuted
        self.excludeRead = excludeRead
        self.excludeArchived = excludeArchived
        self.includePeers = includePeers
        self.excludePeers = excludePeers
        self.color = color
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
 
        let _ = self.includePeers.removePeer(peerId)
        self.excludePeers.append(peerId)
        
        return true
    }
}

public struct ChatFolderTitle: Codable, Equatable {
    public let text: String
    public let entities: [MessageTextEntity]
    public var enableAnimations: Bool
    
    public init(text: String, entities: [MessageTextEntity], enableAnimations: Bool) {
        self.text = text
        self.entities = entities
        self.enableAnimations = enableAnimations
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.text = try container.decode(String.self, forKey: "text")
        self.entities = try container.decode([MessageTextEntity].self, forKey: "entities")
        self.enableAnimations = try container.decodeIfPresent(Bool.self, forKey: "enableAnimations") ?? true
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.text, forKey: "text")
        try container.encode(self.entities, forKey: "entities")
        try container.encode(self.enableAnimations, forKey: "enableAnimations")
    }
}

public enum ChatListFilter: Codable, Equatable {
    case allChats
    case filter(id: Int32, title: ChatFolderTitle, emoticon: String?, data: ChatListFilterData)
    
    public var id: Int32 {
        switch self {
            case .allChats:
                return 0
            case let .filter(id, _, _, _):
                return id
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        let type = try container.decodeIfPresent(Int32.self, forKey: "t") ?? 1
        if type == 0 {
            self = .allChats
        } else {
            let id = try container.decode(Int32.self, forKey: "id")
            
            let title: ChatFolderTitle
            if let titleWithEntities = try container.decodeIfPresent(ChatFolderTitle.self, forKey: "titleWithEntities") {
                title = titleWithEntities
            } else {
                title = ChatFolderTitle(text: try container.decode(String.self, forKey: "title"), entities: [], enableAnimations: true)
            }
            
            let emoticon = try container.decodeIfPresent(String.self, forKey: "emoticon")
            
            let data = ChatListFilterData(
                isShared: try container.decodeIfPresent(Bool.self, forKey: "isShared") ?? false,
                hasSharedLinks: try container.decodeIfPresent(Bool.self, forKey: "hasSharedLinks") ?? false,
                categories: ChatListFilterPeerCategories(rawValue: try container.decode(Int32.self, forKey: "categories")),
                excludeMuted: (try container.decode(Int32.self, forKey: "excludeMuted")) != 0,
                excludeRead: (try container.decode(Int32.self, forKey: "excludeRead")) != 0,
                excludeArchived: (try container.decode(Int32.self, forKey: "excludeArchived")) != 0,
                includePeers: ChatListFilterIncludePeers(
                    peers: (try container.decode([Int64].self, forKey: "includePeers")).map(PeerId.init),
                    pinnedPeers: (try container.decode([Int64].self, forKey: "pinnedPeers")).map(PeerId.init)
                ),
                excludePeers: (try container.decode([Int64].self, forKey: "excludePeers")).map(PeerId.init),
                color: (try container.decodeIfPresent(Int32.self, forKey: "color")).flatMap(PeerNameColor.init(rawValue:))
            )
            self = .filter(id: id, title: title, emoticon: emoticon, data: data)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case .allChats:
                let type: Int32 = 0
                try container.encode(type, forKey: "t")
            case let .filter(id, title, emoticon, data):
                let type: Int32 = 1
                try container.encode(type, forKey: "t")
               
                try container.encode(id, forKey: "id")
                try container.encode(title, forKey: "titleWithEntities")
                try container.encodeIfPresent(emoticon, forKey: "emoticon")
            
                try container.encode(data.isShared, forKey: "isShared")
                try container.encode(data.hasSharedLinks, forKey: "hasSharedLinks")
                try container.encode(data.categories.rawValue, forKey: "categories")
                try container.encode((data.excludeMuted ? 1 : 0) as Int32, forKey: "excludeMuted")
                try container.encode((data.excludeRead ? 1 : 0) as Int32, forKey: "excludeRead")
                try container.encode((data.excludeArchived ? 1 : 0) as Int32, forKey: "excludeArchived")
                try container.encode(data.includePeers.peers.map { $0.toInt64() }, forKey: "includePeers")
                try container.encode(data.includePeers.pinnedPeers.map { $0.toInt64() }, forKey: "pinnedPeers")
                try container.encode(data.excludePeers.map { $0.toInt64() }, forKey: "excludePeers")
                try container.encodeIfPresent(data.color?.rawValue, forKey: "color")
        }
    }
}

extension ChatListFilter {
    init(apiFilter: Api.DialogFilter) {
        switch apiFilter {
        case .dialogFilterDefault:
            self = .allChats
        case let .dialogFilter(flags, id, title, emoticon, color, pinnedPeers, includePeers, excludePeers):
            let titleText: String
            let titleEntities: [MessageTextEntity]
            switch title {
            case let .textWithEntities(text, entities):
                titleText = text
                titleEntities = messageTextEntitiesFromApiEntities(entities)
            }
            let disableTitleAnimations = (flags & (1 << 28)) != 0
            self = .filter(
                id: id,
                title: ChatFolderTitle(text: titleText, entities: titleEntities, enableAnimations: !disableTitleAnimations),
                emoticon: emoticon,
                data: ChatListFilterData(
                    isShared: false,
                    hasSharedLinks: false,
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
                    },
                    color: color.flatMap(PeerNameColor.init(rawValue:))
                )
            )
        case let .dialogFilterChatlist(flags, id, title, emoticon, color, pinnedPeers, includePeers):
            let titleText: String
            let titleEntities: [MessageTextEntity]
            switch title {
            case let .textWithEntities(text, entities):
                titleText = text
                titleEntities = messageTextEntitiesFromApiEntities(entities)
            }
            let disableTitleAnimations = (flags & (1 << 28)) != 0
            
            self = .filter(
                id: id,
                title: ChatFolderTitle(text: titleText, entities: titleEntities, enableAnimations: !disableTitleAnimations),
                emoticon: emoticon,
                data: ChatListFilterData(
                    isShared: true,
                    hasSharedLinks: (flags & (1 << 26)) != 0,
                    categories: [],
                    excludeMuted: false,
                    excludeRead: false,
                    excludeArchived: false,
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
                    excludePeers: [],
                    color: color.flatMap(PeerNameColor.init(rawValue:))
                )
            )
        }
    }
    
    func apiFilter(transaction: Transaction) -> Api.DialogFilter? {
        switch self {
        case .allChats:
            return nil
        case let .filter(id, title, emoticon, data):
            if data.isShared {
                var flags: Int32 = 0
                if emoticon != nil {
                    flags |= 1 << 25
                }
                if data.color != nil {
                    flags |= 1 << 27
                }
                if !title.enableAnimations {
                    flags |= 1 << 28
                }
                return .dialogFilterChatlist(flags: flags, id: id, title: .textWithEntities(text: title.text, entities: apiEntitiesFromMessageTextEntities(title.entities, associatedPeers: SimpleDictionary())), emoticon: emoticon, color: data.color?.rawValue, pinnedPeers: data.includePeers.pinnedPeers.compactMap { peerId -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }, includePeers: data.includePeers.peers.compactMap { peerId -> Api.InputPeer? in
                    if data.includePeers.pinnedPeers.contains(peerId) {
                        return nil
                    }
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                })
            } else {
                var flags: Int32 = 0
                if data.excludeMuted {
                    flags |= 1 << 11
                }
                if data.excludeRead {
                    flags |= 1 << 12
                }
                if data.excludeArchived {
                    flags |= 1 << 13
                }
                flags |= data.categories.apiFlags
                if emoticon != nil {
                    flags |= 1 << 25
                }
                if data.color != nil {
                    flags |= 1 << 27
                }
                if !title.enableAnimations {
                    flags |= 1 << 28
                }
                return .dialogFilter(flags: flags, id: id, title: .textWithEntities(text: title.text, entities: apiEntitiesFromMessageTextEntities(title.entities, associatedPeers: SimpleDictionary())), emoticon: emoticon, color: data.color?.rawValue, pinnedPeers: data.includePeers.pinnedPeers.compactMap { peerId -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }, includePeers: data.includePeers.peers.compactMap { peerId -> Api.InputPeer? in
                    if data.includePeers.pinnedPeers.contains(peerId) {
                        return nil
                    }
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                }, excludePeers: data.excludePeers.compactMap { peerId -> Api.InputPeer? in
                    return transaction.getPeer(peerId).flatMap(apiInputPeer)
                })
            }
        }
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

private func requestChatListFilters(accountPeerId: PeerId, postbox: Postbox, network: Network) -> Signal<([ChatListFilter], Bool), RequestChatListFiltersError> {
    return network.request(Api.functions.messages.getDialogFilters())
    |> mapError { _ -> RequestChatListFiltersError in
        return .generic
    }
    |> mapToSignal { result -> Signal<([ChatListFilter], Bool), RequestChatListFiltersError> in
        return postbox.transaction { transaction -> ([ChatListFilter], [Api.InputPeer], [Api.InputPeer], Bool) in
            switch result {
            case let .dialogFilters(flags, apiFilters):
                let tagsEnabled = (flags & (1 << 0)) != 0
                
                var filters: [ChatListFilter] = []
                var missingPeers: [Api.InputPeer] = []
                var missingChats: [Api.InputPeer] = []
                var missingPeerIds = Set<PeerId>()
                var missingChatIds = Set<PeerId>()
                for apiFilter in apiFilters {
                    let filter = ChatListFilter(apiFilter: apiFilter)
                    filters.append(filter)
                    switch apiFilter {
                    case .dialogFilterDefault:
                        break
                    case let .dialogFilter(_, _, _, _, _, pinnedPeers, includePeers, excludePeers):
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
                    case let .dialogFilterChatlist(_, _, _, _, _, pinnedPeers, includePeers):
                        for peer in pinnedPeers + includePeers {
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
                return (filters, missingPeers, missingChats, tagsEnabled)
            }
        }
        |> castError(RequestChatListFiltersError.self)
        |> mapToSignal { filtersAndMissingPeers -> Signal<([ChatListFilter], Bool), RequestChatListFiltersError> in
            let (filters, missingPeers, missingChats, tagsEnabled) = filtersAndMissingPeers
            
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
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
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
                            let parsedPeers: AccumulatedPeers
                            switch result {
                            case .chats(let chats), .chatsSlice(_, let chats):
                                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                            }
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
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
                            let parsedPeers: AccumulatedPeers
                            switch result {
                            case .chats(let chats), .chatsSlice(_, let chats):
                                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
                            }
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
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
            |> mapToSignal { _ -> Signal<([ChatListFilter], Bool), RequestChatListFiltersError> in
            }
            |> then(
                Signal<([ChatListFilter], Bool), RequestChatListFiltersError>.single((filters, tagsEnabled))
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
            var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
            var ttlPeriods: [PeerId: CachedPeerAutoremoveTimeout] = [:]
            var channelStates: [PeerId: Int32] = [:]
            
            let parsedPeers: AccumulatedPeers
            
            switch result {
            case let .peerDialogs(dialogs, messages, chats, users, _):
                parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                
                var topMessageIds = Set<MessageId>()
                
                for dialog in dialogs {
                    switch dialog {
                    case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, unreadReactionsCount, notifySettings, pts, _, folderId, ttlPeriod):
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
                        
                        ttlPeriods[peer.peerId] = .known(ttlPeriod.flatMap(CachedPeerAutoremoveTimeout.Value.init(peerValue:)))
                        
                        transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: readInboxMaxId, maxOutgoingReadId: readOutboxMaxId, maxKnownId: topMessage, count: unreadCount, markedUnread: false)]])
                        
                        transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadMentionsCount, maxId: topMessage)
                        transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: unreadReactionsCount, maxId: topMessage)
                        
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
                    var peerIsForum = false
                    if let peerId = message.peerId, let peer = parsedPeers.get(peerId), peer.isForumOrMonoForum {
                        peerIsForum = true
                    }
                    if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum) {
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
            
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            
            transaction.updateCurrentPeerNotificationSettings(notificationSettings)
            
            for (peerId, autoremoveValue) in ttlPeriods {
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if peerId.namespace == Namespaces.Peer.CloudUser {
                        let current = (current as? CachedUserData) ?? CachedUserData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        let current = (current as? CachedChannelData) ?? CachedChannelData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let current = (current as? CachedGroupData) ?? CachedGroupData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else {
                        return current
                    }
                })
            }
        }
        |> ignoreValues
    }
}

struct ChatListFiltersState: Codable, Equatable {
    struct ChatListFilterUpdates: Codable, Equatable {
        struct MemberCount: Codable, Equatable {
            var id: PeerId
            var count: Int32
        }
        
        var folderId: Int32
        var timestamp: Int32
        var peerIds: [PeerId]
        var memberCounts: [MemberCount]
        
        init(folderId: Int32, timestamp: Int32, peerIds: [PeerId], memberCounts: [MemberCount]) {
            self.folderId = folderId
            self.timestamp = timestamp
            self.peerIds = peerIds
            self.memberCounts = memberCounts
        }
    }
    
    var filters: [ChatListFilter]
    var remoteFilters: [ChatListFilter]?
    
    var updates: [ChatListFilterUpdates]
    
    var remoteDisplayTags: Bool?
    var displayTags: Bool
    
    static var `default` = ChatListFiltersState(filters: [], remoteFilters: nil, updates: [], remoteDisplayTags: nil, displayTags: false)
    
    fileprivate init(filters: [ChatListFilter], remoteFilters: [ChatListFilter]?, updates: [ChatListFilterUpdates], remoteDisplayTags: Bool?, displayTags: Bool) {
        self.filters = filters
        self.remoteFilters = remoteFilters
        self.updates = updates
        self.remoteDisplayTags = remoteDisplayTags
        self.displayTags = displayTags
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.filters = try container.decode([ChatListFilter].self, forKey: "filters")
        self.remoteFilters = try container.decodeIfPresent([ChatListFilter].self, forKey: "remoteFilters")
        self.updates = try container.decodeIfPresent([ChatListFilterUpdates].self, forKey: "updates") ?? []
        self.remoteDisplayTags = try container.decodeIfPresent(Bool.self, forKey: "remoteDisplayTags")
        self.displayTags = try container.decodeIfPresent(Bool.self, forKey: "displayTags") ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.filters, forKey: "filters")
        try container.encodeIfPresent(self.remoteFilters, forKey: "remoteFilters")
        try container.encode(self.updates, forKey: "updates")
        try container.encodeIfPresent(self.remoteDisplayTags, forKey: "remoteDisplayTags")
        try container.encode(self.displayTags, forKey: "displayTags")
    }
    
    mutating func normalize() {
        if self.updates.isEmpty {
            return
        }
        self.updates.removeAll(where: { update in !self.filters.contains(where: { $0.id == update.folderId }) })
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
            var state = entry?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
            let updatedFilters = f(state.filters)
            if updatedFilters != state.filters {
                state.filters = updatedFilters
                hasUpdates = true
            }
            updated = updatedFilters
            
            state.normalize()
            
            return PreferencesEntry(state)
        })
        if hasUpdates {
            requestChatListFiltersSync(transaction: transaction)
        }
        return updated
    }
}

func _internal_updateChatListFiltersDisplayTagsInteractively(postbox: Postbox, displayTags: Bool) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        var hasUpdates = false
        transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
            var state = entry?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
            if displayTags != state.displayTags {
                state.displayTags = displayTags
                
                if state.displayTags {
                    for i in 0 ..< state.filters.count {
                        switch state.filters[i] {
                        case .allChats:
                            break
                        case let .filter(id, title, emoticon, data):
                            if data.color == nil {
                                var data = data
                                data.color = PeerNameColor(rawValue: Int32.random(in: 0 ... 7))
                                state.filters[i] = .filter(id: id, title: title, emoticon: emoticon, data: data)
                            }
                        }
                    }
                }
                
                hasUpdates = true
            }
            
            state.normalize()
            
            return PreferencesEntry(state)
        })
        if hasUpdates {
            requestChatListFiltersSync(transaction: transaction)
        }
    }
    |> ignoreValues
}

func _internal_updateChatListFiltersInteractively(transaction: Transaction, _ f: ([ChatListFilter]) -> [ChatListFilter]) {
    var hasUpdates = false
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
        var state = entry?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        let updatedFilters = f(state.filters)
        if updatedFilters != state.filters {
            state.filters = updatedFilters
            hasUpdates = true
        }
        state.normalize()
        return PreferencesEntry(state)
    })
    if hasUpdates {
        requestChatListFiltersSync(transaction: transaction)
    }
}

func _internal_updatedChatListFilters(postbox: Postbox, hiddenIds: Signal<Set<Int32>, NoError> = .single(Set())) -> Signal<[ChatListFilter], NoError> {
    return combineLatest(
        postbox.preferencesView(keys: [PreferencesKeys.chatListFilters]),
        hiddenIds
    )
    |> map { preferences, hiddenIds -> [ChatListFilter] in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        return filtersState.filters.filter { filter in
            if hiddenIds.contains(filter.id) {
                return false
            } else {
                return true
            }
        }
    }
    |> distinctUntilChanged
}

func _internal_updatedChatListFiltersState(postbox: Postbox) -> Signal<ChatListFiltersState, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> ChatListFiltersState in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        return filtersState
    }
    |> distinctUntilChanged
}

func _internal_updatedChatListFiltersInfo(postbox: Postbox) -> Signal<(filters: [ChatListFilter], synchronized: Bool), NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { preferences -> (filters: [ChatListFilter], synchronized: Bool) in
        let filtersState = preferences.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
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
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters)?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        return settings.filters
    }
}

func _internal_currentChatListFilters(transaction: Transaction) -> [ChatListFilter] {
    let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters)?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
    return settings.filters
}

func _internal_currentChatListFiltersState(transaction: Transaction) -> ChatListFiltersState {
    let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters)?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
    return settings
}

func updateChatListFiltersState(transaction: Transaction, _ f: (ChatListFiltersState) -> ChatListFiltersState) -> ChatListFiltersState {
    var result: ChatListFiltersState?
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFilters, { entry in
        let settings = entry?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        var updated = f(settings)
        updated.normalize()
        result = updated
        return PreferencesEntry(updated)
    })
    return result ?? .default
}

public struct ChatListFeaturedFilter: Codable, Equatable {
    public var title: ChatFolderTitle
    public var description: String
    public var data: ChatListFilterData
    
    fileprivate init(
        title: ChatFolderTitle,
        description: String,
        data: ChatListFilterData
    ) {
        self.title = title
        self.description = description
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let title = try container.decodeIfPresent(ChatFolderTitle.self, forKey: "titleWithEntities") {
            self.title = title
        } else {
            self.title = ChatFolderTitle(text: try container.decode(String.self, forKey: "title"), entities: [], enableAnimations: true)
        }
        self.description = try container.decode(String.self, forKey: "description")
        self.data = ChatListFilterData(
            isShared: false,
            hasSharedLinks: false,
            categories: ChatListFilterPeerCategories(rawValue: try container.decode(Int32.self, forKey: "categories")),
            excludeMuted: (try container.decode(Int32.self, forKey: "excludeMuted")) != 0,
            excludeRead: (try container.decode(Int32.self, forKey: "excludeRead")) != 0,
            excludeArchived: (try container.decode(Int32.self, forKey: "excludeArchived")) != 0,
            includePeers: ChatListFilterIncludePeers(
                peers: (try container.decode([Int64].self, forKey: ("includePeers"))).map(PeerId.init),
                pinnedPeers: (try container.decode([Int64].self, forKey: ("pinnedPeers"))).map(PeerId.init)
            ),
            excludePeers: (try container.decode([Int64].self, forKey: ("excludePeers"))).map(PeerId.init),
            color: nil
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.title, forKey: "titleWithEntities")
        try container.encode(self.description, forKey: "description")
        try container.encode(self.data.categories.rawValue, forKey: "categories")
        try container.encode((self.data.excludeMuted ? 1 : 0) as Int32, forKey: "excludeMuted")
        try container.encode((self.data.excludeRead ? 1 : 0) as Int32, forKey: "excludeRead")
        try container.encode((self.data.excludeArchived ? 1 : 0) as Int32, forKey: "excludeArchived")
        try container.encode(self.data.includePeers.peers.map { $0.toInt64() }, forKey: "includePeers")
        try container.encode(self.data.includePeers.pinnedPeers.map { $0.toInt64() }, forKey: "pinnedPeers")
        try container.encode(self.data.excludePeers.map { $0.toInt64() }, forKey: "excludePeers")
    }
}

public struct ChatListFiltersFeaturedState: Codable, Equatable {
    public var filters: [ChatListFeaturedFilter]
    public var isSeen: Bool
    
    fileprivate init(filters: [ChatListFeaturedFilter], isSeen: Bool) {
        self.filters = filters
        self.isSeen = isSeen
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.filters = try container.decode([ChatListFeaturedFilter].self, forKey: "filters")
        self.isSeen = (try container.decode(Int32.self, forKey: "isSeen")) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.filters, forKey: "filters")
        try container.encode((self.isSeen ? 1 : 0) as Int32, forKey: "isSeen")
    }
}

func _internal_markChatListFeaturedFiltersAsSeen(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
            guard var state = entry?.get(ChatListFiltersFeaturedState.self) else {
                return entry
            }
            state.isSeen = true
            return PreferencesEntry(state)
        })
    }
    |> ignoreValues
}

func _internal_unmarkChatListFeaturedFiltersAsSeen(transaction: Transaction) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.chatListFiltersFeaturedState, { entry in
        guard var state = entry?.get(ChatListFiltersFeaturedState.self) else {
            return entry
        }
        state.isSeen = false
        return PreferencesEntry(state)
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
                var state = entry?.get(ChatListFiltersFeaturedState.self) ?? ChatListFiltersFeaturedState(filters: [], isSeen: false)
                state.filters = result.compactMap { item -> ChatListFeaturedFilter? in
                    switch item {
                    case let .dialogFilterSuggested(filter, description):
                        let parsedFilter = ChatListFilter(apiFilter: filter)
                        if case let .filter(_, title, _, data) = parsedFilter {
                            return ChatListFeaturedFilter(title: title, description: description, data: data)
                        } else {
                            return nil
                        }
                    }
                }
                return PreferencesEntry(state)
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

func _internal_chatListFiltersAreSynced(postbox: Postbox) -> Signal<Bool, NoError> {
    return postbox.mergedOperationLogView(tag: OperationLogTags.SynchronizeChatListFilters, limit: 1)
    |> map { view -> Bool in
        return view.entries.isEmpty
    }
    |> distinctUntilChanged
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
        let settings = transaction.getPreferencesEntry(key: PreferencesKeys.chatListFilters)?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        let localFilters = settings.filters
        let locallyKnownRemoteFilters = settings.remoteFilters ?? []
        let localDisplayTags = settings.displayTags
        let locallyKnownRemoteDisplayTags = settings.remoteDisplayTags ?? false
        
        return requestChatListFilters(accountPeerId: accountPeerId, postbox: postbox, network: network)
        |> `catch` { _ -> Signal<([ChatListFilter], Bool), NoError> in
            return .complete()
        }
        |> mapToSignal { remoteFilters, remoteTagsEnabled -> Signal<Never, NoError> in
            if localFilters == locallyKnownRemoteFilters && localDisplayTags == locallyKnownRemoteDisplayTags {
                return postbox.transaction { transaction -> Void in
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        state.filters = remoteFilters
                        state.remoteFilters = state.filters
                        state.displayTags = remoteTagsEnabled
                        state.remoteDisplayTags = state.displayTags
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
            
            let updateTagsEnabled: Signal<Never, NoError>
            if localDisplayTags != remoteTagsEnabled {
                updateTagsEnabled = network.request(Api.functions.messages.toggleDialogFilterTags(enabled: localDisplayTags ? .boolTrue : .boolFalse))
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            } else {
                updateTagsEnabled = .complete()
            }
            
            return deleteSignals
            |> then(
                addSignals
            )
            |> then(
                reorderFilters
            )
            |> then(
                updateTagsEnabled
            )
            |> then(
                postbox.transaction { transaction -> Void in
                    let _ = updateChatListFiltersState(transaction: transaction, { state in
                        var state = state
                        state.filters = mergedFilters
                        state.remoteFilters = state.filters
                        state.remoteDisplayTags = state.displayTags
                        return state
                    })
                }
                |> ignoreValues
            )
        }
    }
}
