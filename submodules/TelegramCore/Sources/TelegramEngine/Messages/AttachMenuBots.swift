import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class AttachMenuBots: Equatable, Codable {
    public final class Bot: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case peerId
            case name
            case botIcons
            case peerTypes
            case hasSettings
        }
        
        public enum IconName: Int32, Codable {
            case `default` = 0
            case iOSStatic
            case iOSAnimated
            case macOSAnimated
            case placeholder
            
            init?(string: String) {
                switch string {
                    case "default_static":
                        self = .default
                    case "ios_static":
                        self = .iOSStatic
                    case "ios_animated":
                        self = .iOSAnimated
                    case "macos_animated":
                        self = .macOSAnimated
                    case "placeholder_static":
                        self = .placeholder
                    default:
                        return nil
                }
            }
        }
        
        public struct PeerFlags: OptionSet, Codable {
            public var rawValue: UInt32
            
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }
            
            public init() {
                self.rawValue = 0
            }
            
            public static let sameBot = PeerFlags(rawValue: 1 << 0)
            public static let bot = PeerFlags(rawValue: 1 << 1)
            public static let user = PeerFlags(rawValue: 1 << 2)
            public static let group = PeerFlags(rawValue: 1 << 3)
            public static let channel = PeerFlags(rawValue: 1 << 4)
            
            public static var all: PeerFlags {
                return [.sameBot, .bot, .user, .group, .channel]
            }
            
            public static var `default`: PeerFlags {
                return [.sameBot, .bot, .user]
            }
        }
        
        private struct IconPair: Codable {
            var name: IconName
            var value: TelegramMediaFile
            
            init(_ name: IconName, value: TelegramMediaFile) {
                self.name = name
                self.value = value
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: StringCodingKey.self)

                self.name = IconName(rawValue: try container.decode(Int32.self, forKey: "k")) ?? .default
                
                let data = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: "v")
                self.value = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: data.data)))
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: StringCodingKey.self)

                try container.encode(self.name.rawValue, forKey: "k")
                try container.encode(PostboxEncoder().encodeObjectToRawData(self.value), forKey: "v")
            }
        }
        
        public let peerId: PeerId
        public let name: String
        public let icons: [IconName: TelegramMediaFile]
        public let peerTypes: PeerFlags
        public let hasSettings: Bool
        
        public init(
            peerId: PeerId,
            name: String,
            icons: [IconName: TelegramMediaFile],
            peerTypes: PeerFlags,
            hasSettings: Bool
        ) {
            self.peerId = peerId
            self.name = name
            self.icons = icons
            self.peerTypes = peerTypes
            self.hasSettings = hasSettings
        }
        
        public static func ==(lhs: Bot, rhs: Bot) -> Bool {
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.name != rhs.name {
                return false
            }
            if lhs.icons != rhs.icons {
                return false
            }
            if lhs.peerTypes != rhs.peerTypes {
                return false
            }
            if lhs.hasSettings != rhs.hasSettings {
                return false
            }
            return true
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let peerIdValue = try container.decode(Int64.self, forKey: .peerId)
            self.peerId = PeerId(peerIdValue)
            
            self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            
            let iconPairs = try container.decodeIfPresent([IconPair].self, forKey: .botIcons) ?? []
            var icons: [IconName: TelegramMediaFile] = [:]
            for iconPair in iconPairs {
                icons[iconPair.name] = iconPair.value
            }
            self.icons = icons
            
            let value = try container.decodeIfPresent(Int32.self, forKey: .peerTypes) ?? Int32(PeerFlags.default.rawValue)
            self.peerTypes = PeerFlags(rawValue: UInt32(value))
            
            self.hasSettings = try container.decodeIfPresent(Bool.self, forKey: .hasSettings) ?? false
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.peerId.toInt64(), forKey: .peerId)
            try container.encode(self.name, forKey: .name)
            
            var iconPairs: [IconPair] = []
            for (key, value) in self.icons {
                iconPairs.append(IconPair(key, value: value))
            }
            try container.encode(iconPairs, forKey: .botIcons)
            
            try container.encode(Int32(self.peerTypes.rawValue), forKey: .peerTypes)
            
            try container.encode(self.hasSettings, forKey: .hasSettings)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case hash
        case bots
    }
    
    public let hash: Int64
    public let bots: [Bot]
    
    public init(
        hash: Int64,
        bots: [Bot]
    ) {
        self.hash = hash
        self.bots = bots
    }
    
    public static func ==(lhs: AttachMenuBots, rhs: AttachMenuBots) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.bots != rhs.bots {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decode(Int64.self, forKey: .hash)
        self.bots = try container.decode([Bot].self, forKey: .bots)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.bots, forKey: .bots)
    }
}

private func cachedAttachMenuBots(postbox: Postbox) -> Signal<AttachMenuBots?, NoError> {
    return postbox.transaction { transaction -> AttachMenuBots? in
        return cachedAttachMenuBots(transaction: transaction)
    }
}

private func cachedAttachMenuBots(transaction: Transaction) -> AttachMenuBots? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)

    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.attachMenuBots, key: key))?.get(AttachMenuBots.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

private func setCachedAttachMenuBots(transaction: Transaction, attachMenuBots: AttachMenuBots) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    let entryId = ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.attachMenuBots, key: key)
    if let entry = CodableEntry(attachMenuBots) {
        transaction.putItemCacheEntry(id: entryId, entry: entry)
    } else {
        transaction.removeItemCacheEntry(id: entryId)
    }
}

private func removeCachedAttachMenuBot(postbox: Postbox, botId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction in
        if let bots = cachedAttachMenuBots(transaction: transaction) {
            let updatedBots = bots.bots.filter { $0.peerId != botId }
            setCachedAttachMenuBots(transaction: transaction, attachMenuBots: AttachMenuBots(hash: bots.hash, bots: updatedBots))
        }
    }
}

func managedSynchronizeAttachMenuBots(postbox: Postbox, network: Network, force: Bool = false) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        let signal: Signal<Void, NoError> = cachedAttachMenuBots(postbox: postbox)
        |> mapToSignal { current in
            return (network.request(Api.functions.messages.getAttachMenuBots(hash: force ? 0 : (current?.hash ?? 0)))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.AttachMenuBots?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Void, NoError> in
                guard let result = result else {
                    return .complete()
                }
                return postbox.transaction { transaction -> Void in
                    switch result {
                        case let .attachMenuBots(hash, bots, users):
                            var peers: [Peer] = []
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                            }
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })

                            var resultBots: [AttachMenuBots.Bot] = []
                            for bot in bots {
                                switch bot {
                                    case let .attachMenuBot(flags, botId, name, apiPeerTypes, botIcons):
                                        var icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile] = [:]
                                        for icon in botIcons {
                                            switch icon {
                                                case let .attachMenuBotIcon(_, name, icon, _):
                                                    if let iconName = AttachMenuBots.Bot.IconName(string: name), let icon = telegramMediaFileFromApiDocument(icon) {
                                                        icons[iconName] = icon
                                                    }
                                            }
                                        }
                                        if !icons.isEmpty {
                                            var peerTypes: AttachMenuBots.Bot.PeerFlags = []
                                            for apiType in apiPeerTypes {
                                                switch apiType {
                                                    case .attachMenuPeerTypeSameBotPM:
                                                        peerTypes.insert(.sameBot)
                                                    case .attachMenuPeerTypeBotPM:
                                                        peerTypes.insert(.bot)
                                                    case .attachMenuPeerTypePM:
                                                        peerTypes.insert(.user)
                                                    case .attachMenuPeerTypeChat:
                                                        peerTypes.insert(.group)
                                                    case .attachMenuPeerTypeBroadcast:
                                                        peerTypes.insert(.channel)
                                                }
                                            }
                                            resultBots.append(AttachMenuBots.Bot(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), name: name, icons: icons, peerTypes: peerTypes, hasSettings: (flags & (1 << 1)) != 0))
                                        }
                                }
                            }
                            
                            let attachMenuBots = AttachMenuBots(hash: hash, bots: resultBots)
                            setCachedAttachMenuBots(transaction: transaction, attachMenuBots: attachMenuBots)
                        case .attachMenuBotsNotModified:
                            break
                    }
                    return Void()
                }
            })
        }
                
        return signal.start(next: { value in
            subscriber.putNext(value)
        }, completed: {
            subscriber.putCompletion()
        })
    }
    
    return (
        poll
        |> then(
            .complete()
            |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
        )
    )
    |> restart
}


public enum AddBotToAttachMenuError {
    case generic
}


func _internal_addBotToAttachMenu(postbox: Postbox, network: Network, botId: PeerId) -> Signal<Bool, AddBotToAttachMenuError> {
    return postbox.transaction { transaction -> Signal<Bool, AddBotToAttachMenuError> in
        guard let peer = transaction.getPeer(botId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(bot: inputUser, enabled: .boolTrue))
        |> map { value -> Bool in
            switch value {
                case .boolTrue:
                    return true
                default:
                    return false
            }
        }
        |> mapError { _ -> AddBotToAttachMenuError in
            return .generic
        }
        |> mapToSignal { value -> Signal<Bool, AddBotToAttachMenuError> in
            if value {
                return managedSynchronizeAttachMenuBots(postbox: postbox, network: network, force: true)
                |> castError(AddBotToAttachMenuError.self)
                |> take(1)
                |> map { _ -> Bool in
                    return true
                }
            } else {
                return .fail(.generic)
            }
        }
    }
    |> castError(AddBotToAttachMenuError.self)
    |> switchToLatest
}

func _internal_removeBotFromAttachMenu(postbox: Postbox, network: Network, botId: PeerId) -> Signal<Bool, NoError> {
    return postbox.transaction { transaction -> Signal<Bool, NoError> in
        guard let peer = transaction.getPeer(botId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(bot: inputUser, enabled: .boolFalse))
        |> map { value -> Bool in
            switch value {
                case .boolTrue:
                    return true
                default:
                    return false
            }
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            return .single(false)
        }
        |> afterCompleted {
            let _ = (managedSynchronizeAttachMenuBots(postbox: postbox, network: network, force: true)
            |> take(1)).start(completed: {
                let _ = removeCachedAttachMenuBot(postbox: postbox, botId: botId)
            })
        }
    }
    |> switchToLatest
}

public struct AttachMenuBot {
    public let peer: Peer
    public let shortName: String
    public let icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile]
    public let peerTypes: AttachMenuBots.Bot.PeerFlags
    public let hasSettings: Bool
    
    init(peer: Peer, shortName: String, icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile], peerTypes: AttachMenuBots.Bot.PeerFlags, hasSettings: Bool) {
        self.peer = peer
        self.shortName = shortName
        self.icons = icons
        self.peerTypes = peerTypes
        self.hasSettings = hasSettings
    }
}

func _internal_attachMenuBots(postbox: Postbox) -> Signal<[AttachMenuBot], NoError> {
    return postbox.transaction { transaction -> [AttachMenuBot] in
        guard let cachedBots = cachedAttachMenuBots(transaction: transaction)?.bots else {
            return []
        }
        var resultBots: [AttachMenuBot] = []
        for bot in cachedBots {
            if let peer = transaction.getPeer(bot.peerId) {
                resultBots.append(AttachMenuBot(peer: peer, shortName: bot.name, icons: bot.icons, peerTypes: bot.peerTypes, hasSettings: bot.hasSettings))
            }
        }
        return resultBots
    }
}

public enum GetAttachMenuBotError {
    case generic
}

public func _internal_getAttachMenuBot(postbox: Postbox, network: Network, botId: PeerId, cached: Bool) -> Signal<AttachMenuBot, GetAttachMenuBotError> {
    return postbox.transaction { transaction -> Signal<AttachMenuBot, GetAttachMenuBotError> in
        if cached, let cachedBots = cachedAttachMenuBots(transaction: transaction)?.bots {
            if let bot = cachedBots.first(where: { $0.peerId == botId }), let peer = transaction.getPeer(bot.peerId) {
                return .single(AttachMenuBot(peer: peer, shortName: bot.name, icons: bot.icons, peerTypes: bot.peerTypes, hasSettings: bot.hasSettings))
            }
        }
        
        guard let peer = transaction.getPeer(botId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.getAttachMenuBot(bot: inputUser))
        |> mapError { _ -> GetAttachMenuBotError in
            return .generic
        }
        |> mapToSignal { result -> Signal<AttachMenuBot, GetAttachMenuBotError> in
            return postbox.transaction { transaction -> Signal<AttachMenuBot, GetAttachMenuBotError> in
                switch result {
                    case let .attachMenuBotsBot(bot, users):
                        var peers: [Peer] = []
                        var peer: Peer?
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            
                            if telegramUser.id == botId {
                                peer = telegramUser
                            }
                        }
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                    
                        guard let peer = peer else {
                            return .fail(.generic)
                        }
                    
                        switch bot {
                            case let .attachMenuBot(flags, _, name, apiPeerTypes, botIcons):
                                var icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile] = [:]
                                for icon in botIcons {
                                    switch icon {
                                        case let .attachMenuBotIcon(_, name, icon, _):
                                            if let iconName = AttachMenuBots.Bot.IconName(string: name), let icon = telegramMediaFileFromApiDocument(icon) {
                                                icons[iconName] = icon
                                            }
                                    }
                                }
                                var peerTypes: AttachMenuBots.Bot.PeerFlags = []
                                for apiType in apiPeerTypes {
                                    switch apiType {
                                        case .attachMenuPeerTypeSameBotPM:
                                            peerTypes.insert(.sameBot)
                                        case .attachMenuPeerTypeBotPM:
                                            peerTypes.insert(.bot)
                                        case .attachMenuPeerTypePM:
                                            peerTypes.insert(.user)
                                        case .attachMenuPeerTypeChat:
                                            peerTypes.insert(.group)
                                        case .attachMenuPeerTypeBroadcast:
                                            peerTypes.insert(.channel)
                                    }
                                }
                                return .single(AttachMenuBot(peer: peer, shortName: name, icons: icons, peerTypes: peerTypes, hasSettings: (flags & (1 << 1)) != 0))
                        }
                }
            }
            |> castError(GetAttachMenuBotError.self)
            |> switchToLatest
        }
    }
    |> castError(GetAttachMenuBotError.self)
    |> switchToLatest
}
