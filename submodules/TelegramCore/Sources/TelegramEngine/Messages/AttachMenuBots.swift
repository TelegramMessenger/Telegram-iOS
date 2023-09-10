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
            case flags
        }
        
        public enum IconName: Int32, Codable {
            case `default` = 0
            case iOSStatic
            case iOSAnimated
            case iOSSettingsStatic
            case macOSAnimated
            case macOSSettingsStatic
            case placeholder
            
            init?(string: String) {
                switch string {
                    case "default_static":
                        self = .default
                    case "ios_static":
                        self = .iOSStatic
                    case "ios_animated":
                        self = .iOSAnimated
                    case "ios_side_menu_static":
                        self = .iOSSettingsStatic
                    case "macos_side_menu_static":
                        self = .macOSSettingsStatic
                    case "macos_animated":
                        self = .macOSAnimated
                    case "placeholder_static":
                        self = .placeholder
                    default:
                        return nil
                }
            }
        }
        
        public struct Flags: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public init() {
                self.rawValue = 0
            }
            
            public static let hasSettings = Flags(rawValue: 1 << 0)
            public static let requiresWriteAccess = Flags(rawValue: 1 << 1)
            public static let showInAttachMenu = Flags(rawValue: 1 << 2)
            public static let showInSettings = Flags(rawValue: 1 << 3)
            public static let showInSettingsDisclaimer = Flags(rawValue: 1 << 4)
            public static let notActivated = Flags(rawValue: 1 << 5)
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
        public let flags: Flags
        
        public init(
            peerId: PeerId,
            name: String,
            icons: [IconName: TelegramMediaFile],
            peerTypes: PeerFlags,
            flags: Flags
        ) {
            self.peerId = peerId
            self.name = name
            self.icons = icons
            self.peerTypes = peerTypes
            self.flags = flags
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
            if lhs.flags != rhs.flags {
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
            
            if let flags = try container.decodeIfPresent(Int32.self, forKey: .flags) {
                self.flags = Flags(rawValue: flags)
            } else {
                let hasSettings = try container.decodeIfPresent(Bool.self, forKey: .hasSettings) ?? false
                self.flags = hasSettings ? [.hasSettings] : []
            }
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
            
            try container.encode(Int32(self.flags.rawValue), forKey: .flags)
        }
        
        func withUpdatedFlags(_ flags: Flags) -> Bot {
            return Bot(peerId: self.peerId, name: self.name, icons: self.icons, peerTypes: self.peerTypes, flags: flags)
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

func managedSynchronizeAttachMenuBots(accountPeerId: PeerId, postbox: Postbox, network: Network, force: Bool = false) -> Signal<Void, NoError> {
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
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))

                            var resultBots: [AttachMenuBots.Bot] = []
                            for bot in bots {
                                switch bot {
                                    case let .attachMenuBot(apiFlags, botId, name, apiPeerTypes, botIcons):
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
                                            for apiType in apiPeerTypes ?? [] {
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
                                            var flags: AttachMenuBots.Bot.Flags = []
                                            if (apiFlags & (1 << 0)) != 0 {
                                                flags.insert(.notActivated)
                                            }
                                            if (apiFlags & (1 << 1)) != 0 {
                                                flags.insert(.hasSettings)
                                            }
                                            if (apiFlags & (1 << 2)) != 0 {
                                                flags.insert(.requiresWriteAccess)
                                            }
                                            if (apiFlags & (1 << 3)) != 0 {
                                                flags.insert(.showInAttachMenu)
                                            }
                                            if (apiFlags & (1 << 4)) != 0 {
                                                flags.insert(.showInSettings)
                                            }
                                            if (apiFlags & (1 << 5)) != 0 {
                                                flags.insert(.showInSettingsDisclaimer)
                                            }
                                            resultBots.append(AttachMenuBots.Bot(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), name: name, icons: icons, peerTypes: peerTypes, flags: flags))
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


func _internal_addBotToAttachMenu(accountPeerId: PeerId, postbox: Postbox, network: Network, botId: PeerId, allowWrite: Bool) -> Signal<Bool, AddBotToAttachMenuError> {
    return postbox.transaction { transaction -> Signal<Bool, AddBotToAttachMenuError> in
        guard let peer = transaction.getPeer(botId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        var flags: Int32 = 0
        if allowWrite {
            flags |= (1 << 0)
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(flags: flags, bot: inputUser, enabled: .boolTrue))
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
                return managedSynchronizeAttachMenuBots(accountPeerId: accountPeerId, postbox: postbox, network: network, force: true)
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

func _internal_removeBotFromAttachMenu(accountPeerId: PeerId, postbox: Postbox, network: Network, botId: PeerId) -> Signal<Bool, NoError> {
    let _ = removeCachedAttachMenuBot(postbox: postbox, botId: botId).start()
    
    return postbox.transaction { transaction -> Signal<Bool, NoError> in
        guard let peer = transaction.getPeer(botId), let inputUser = apiInputUser(peer) else {
            return .complete()
        }
        return network.request(Api.functions.messages.toggleBotInAttachMenu(flags: 0, bot: inputUser, enabled: .boolFalse))
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
            let _ = (managedSynchronizeAttachMenuBots(accountPeerId: accountPeerId, postbox: postbox, network: network, force: true)
            |> take(1)).start(completed: {
                let _ = removeCachedAttachMenuBot(postbox: postbox, botId: botId).start()
            })
        }
    }
    |> switchToLatest
}

func _internal_acceptAttachMenuBotDisclaimer(postbox: Postbox, botId: PeerId) -> Signal<Never, NoError> {
    return postbox.transaction { transaction in
        if let attachMenuBots = cachedAttachMenuBots(transaction: transaction) {
            var updatedAttachMenuBots = attachMenuBots
            if let index = attachMenuBots.bots.firstIndex(where: { $0.peerId == botId }) {
                var updatedFlags = attachMenuBots.bots[index].flags
                updatedFlags.remove(.showInSettingsDisclaimer)
                let updatedBot = attachMenuBots.bots[index].withUpdatedFlags(updatedFlags)
                var updatedBots = attachMenuBots.bots
                updatedBots[index] = updatedBot
                updatedAttachMenuBots = AttachMenuBots(hash: attachMenuBots.hash, bots: updatedBots)
            }
            setCachedAttachMenuBots(transaction: transaction, attachMenuBots: updatedAttachMenuBots)
        }
    } |> ignoreValues
}

public struct AttachMenuBot {
    public let peer: EnginePeer
    public let shortName: String
    public let icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile]
    public let peerTypes: AttachMenuBots.Bot.PeerFlags
    public let flags: AttachMenuBots.Bot.Flags
    
    public init(peer: EnginePeer, shortName: String, icons: [AttachMenuBots.Bot.IconName: TelegramMediaFile], peerTypes: AttachMenuBots.Bot.PeerFlags, flags: AttachMenuBots.Bot.Flags) {
        self.peer = peer
        self.shortName = shortName
        self.icons = icons
        self.peerTypes = peerTypes
        self.flags = flags
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
                resultBots.append(AttachMenuBot(peer: EnginePeer(peer), shortName: bot.name, icons: bot.icons, peerTypes: bot.peerTypes, flags: bot.flags))
            }
        }
        return resultBots
    }
}

public enum GetAttachMenuBotError {
    case generic
}
 
func _internal_getAttachMenuBot(accountPeerId: PeerId, postbox: Postbox, network: Network, botId: PeerId, cached: Bool) -> Signal<AttachMenuBot, GetAttachMenuBotError> {
    return postbox.transaction { transaction -> Signal<AttachMenuBot, GetAttachMenuBotError> in
        if cached, let cachedBots = cachedAttachMenuBots(transaction: transaction)?.bots {
            if let bot = cachedBots.first(where: { $0.peerId == botId }), let peer = transaction.getPeer(bot.peerId) {
                return .single(AttachMenuBot(peer: EnginePeer(peer), shortName: bot.name, icons: bot.icons, peerTypes: bot.peerTypes, flags: bot.flags))
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
                        var peer: Peer?
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            if telegramUser.id == botId {
                                peer = telegramUser
                            }
                        }
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                    
                        guard let peer = peer else {
                            return .fail(.generic)
                        }
                    
                        switch bot {
                            case let .attachMenuBot(apiFlags, _, name, apiPeerTypes, botIcons):
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
                                for apiType in apiPeerTypes ?? [] {
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
                                var flags: AttachMenuBots.Bot.Flags = []
                                if (apiFlags & (1 << 1)) != 0 {
                                    flags.insert(.hasSettings)
                                }
                                if (apiFlags & (1 << 2)) != 0 {
                                    flags.insert(.requiresWriteAccess)
                                }
                                if (apiFlags & (1 << 3)) != 0 {
                                    flags.insert(.showInAttachMenu)
                                }
                                if (apiFlags & (1 << 4)) != 0 {
                                    flags.insert(.showInSettings)
                                }
                                if (apiFlags & (1 << 5)) != 0 {
                                    flags.insert(.showInSettingsDisclaimer)
                                }
                                return .single(AttachMenuBot(peer: EnginePeer(peer), shortName: name, icons: icons, peerTypes: peerTypes, flags: flags))
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

public enum BotAppReference {
    case id(id: Int64, accessHash: Int64)
    case shortName(peerId: PeerId, shortName: String)
}

public final class BotApp: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case accessHash
        case shortName
        case title
        case description
        case photo
        case document
        case hash
        case flags
    }
    
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public init() {
            self.rawValue = 0
        }
        
        public static let notActivated = Flags(rawValue: 1 << 0)
        public static let requiresWriteAccess = Flags(rawValue: 1 << 1)
        public static let hasSettings = Flags(rawValue: 1 << 2)
    }
    
    public let id: Int64
    public let accessHash: Int64
    public let shortName: String
    public let title: String
    public let description: String
    public let photo: TelegramMediaImage?
    public let document: TelegramMediaFile?
    public let hash: Int64
    public let flags: Flags
    
    public init(
        id: Int64,
        accessHash: Int64,
        shortName: String,
        title: String,
        description: String,
        photo: TelegramMediaImage?,
        document: TelegramMediaFile?,
        hash: Int64,
        flags: Flags
    ) {
        self.id = id
        self.accessHash = accessHash
        self.shortName = shortName
        self.title = title
        self.description = description
        self.photo = photo
        self.document = document
        self.hash = hash
        self.flags = flags
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(Int64.self, forKey: .id)
        self.accessHash = try container.decode(Int64.self, forKey: .accessHash)
        self.shortName = try container.decode(String.self, forKey: .shortName)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        
        if let data = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .photo) {
            self.photo = TelegramMediaImage(decoder: PostboxDecoder(buffer: MemoryBuffer(data: data.data)))
        } else {
            self.photo = nil
        }
        
        if let data = try container.decodeIfPresent(AdaptedPostboxDecoder.RawObjectData.self, forKey: .document) {
            self.document = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: data.data)))
        } else {
            self.document = nil
        }
        
        self.hash = try container.decode(Int64.self, forKey: .hash)
        self.flags = Flags(rawValue: try container.decode(Int32.self, forKey: .flags))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.id, forKey: .id)
        try container.encode(self.accessHash, forKey: .accessHash)
        try container.encode(self.shortName, forKey: .shortName)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.description, forKey: .description)
        try container.encodeIfPresent(self.photo, forKey: .photo)
        try container.encodeIfPresent(self.document, forKey: .document)
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.flags.rawValue, forKey: .flags)
    }
    
    public static func ==(lhs: BotApp, rhs: BotApp) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.accessHash != rhs.accessHash {
            return false
        }
        if lhs.shortName != rhs.shortName {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.description != rhs.description {
            return false
        }
        if lhs.photo != rhs.photo {
            return false
        }
        if lhs.document != rhs.document {
            return false
        }
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.flags != rhs.flags {
            return false
        }
        return true
    }
}

public enum GetBotAppError {
    case generic
}

func _internal_getBotApp(account: Account, reference: BotAppReference) -> Signal<BotApp, GetBotAppError> {
    return account.postbox.transaction { transaction -> Signal<BotApp, GetBotAppError> in
        let app: Api.InputBotApp
        switch reference {
        case let .id(id, accessHash):
            app = .inputBotAppID(id: id, accessHash: accessHash)
        case let .shortName(peerId, shortName):
            guard let bot = transaction.getPeer(peerId), let inputBot = apiInputUser(bot) else {
                return .fail(.generic)
            }
            app = .inputBotAppShortName(botId: inputBot, shortName: shortName)
        }
        
        return account.network.request(Api.functions.messages.getBotApp(app: app, hash: 0))
        |> mapError { _ -> GetBotAppError in
            return .generic
        }
        |> mapToSignal { result -> Signal<BotApp, GetBotAppError> in
            switch result {
            case let .botApp(botAppFlags, app):
                switch app {
                case let .botApp(flags, id, accessHash, shortName, title, description, photo, document, hash):
                    let _ = flags
                    var appFlags = BotApp.Flags()
                    if (botAppFlags & (1 << 0)) != 0 {
                        appFlags.insert(.notActivated)
                    }
                    if (botAppFlags & (1 << 1)) != 0 {
                        appFlags.insert(.requiresWriteAccess)
                    }
                    if (botAppFlags & (1 << 2)) != 0 {
                        appFlags.insert(.hasSettings)
                    }
                    return .single(BotApp(id: id, accessHash: accessHash, shortName: shortName, title: title, description: description, photo: telegramMediaImageFromApiPhoto(photo), document: document.flatMap(telegramMediaFileFromApiDocument), hash: hash, flags: appFlags))
            case .botAppNotModified:
                return .complete()
            }
            }
        }
    }
    |> castError(GetBotAppError.self)
    |> switchToLatest
}
