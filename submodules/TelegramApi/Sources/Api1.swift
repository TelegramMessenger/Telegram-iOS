public extension Api {
    enum AccountDaysTTL: TypeConstructorDescription {
        public class Cons_accountDaysTTL {
            public var days: Int32
            public init(days: Int32) {
                self.days = days
            }
        }
        case accountDaysTTL(Cons_accountDaysTTL)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .accountDaysTTL(let _data):
                if boxed {
                    buffer.appendInt32(-1194283041)
                }
                serializeInt32(_data.days, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .accountDaysTTL(let _data):
                return ("accountDaysTTL", [("days", _data.days as Any)])
            }
        }

        public static func parse_accountDaysTTL(_ reader: BufferReader) -> AccountDaysTTL? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.AccountDaysTTL.accountDaysTTL(Cons_accountDaysTTL(days: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AttachMenuBot: TypeConstructorDescription {
        public class Cons_attachMenuBot {
            public var flags: Int32
            public var botId: Int64
            public var shortName: String
            public var peerTypes: [Api.AttachMenuPeerType]?
            public var icons: [Api.AttachMenuBotIcon]
            public init(flags: Int32, botId: Int64, shortName: String, peerTypes: [Api.AttachMenuPeerType]?, icons: [Api.AttachMenuBotIcon]) {
                self.flags = flags
                self.botId = botId
                self.shortName = shortName
                self.peerTypes = peerTypes
                self.icons = icons
            }
        }
        case attachMenuBot(Cons_attachMenuBot)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuBot(let _data):
                if boxed {
                    buffer.appendInt32(-653423106)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.peerTypes!.count))
                    for item in _data.peerTypes! {
                        item.serialize(buffer, true)
                    }
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.icons.count))
                for item in _data.icons {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuBot(let _data):
                return ("attachMenuBot", [("flags", _data.flags as Any), ("botId", _data.botId as Any), ("shortName", _data.shortName as Any), ("peerTypes", _data.peerTypes as Any), ("icons", _data.icons as Any)])
            }
        }

        public static func parse_attachMenuBot(_ reader: BufferReader) -> AttachMenuBot? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.AttachMenuPeerType]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuPeerType.self)
                }
            }
            var _5: [Api.AttachMenuBotIcon]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBotIcon.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.AttachMenuBot.attachMenuBot(Cons_attachMenuBot(flags: _1!, botId: _2!, shortName: _3!, peerTypes: _4, icons: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AttachMenuBotIcon: TypeConstructorDescription {
        public class Cons_attachMenuBotIcon {
            public var flags: Int32
            public var name: String
            public var icon: Api.Document
            public var colors: [Api.AttachMenuBotIconColor]?
            public init(flags: Int32, name: String, icon: Api.Document, colors: [Api.AttachMenuBotIconColor]?) {
                self.flags = flags
                self.name = name
                self.icon = icon
                self.colors = colors
            }
        }
        case attachMenuBotIcon(Cons_attachMenuBotIcon)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuBotIcon(let _data):
                if boxed {
                    buffer.appendInt32(-1297663893)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                _data.icon.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.colors!.count))
                    for item in _data.colors! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuBotIcon(let _data):
                return ("attachMenuBotIcon", [("flags", _data.flags as Any), ("name", _data.name as Any), ("icon", _data.icon as Any), ("colors", _data.colors as Any)])
            }
        }

        public static func parse_attachMenuBotIcon(_ reader: BufferReader) -> AttachMenuBotIcon? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Document?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _4: [Api.AttachMenuBotIconColor]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBotIconColor.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.AttachMenuBotIcon.attachMenuBotIcon(Cons_attachMenuBotIcon(flags: _1!, name: _2!, icon: _3!, colors: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AttachMenuBotIconColor: TypeConstructorDescription {
        public class Cons_attachMenuBotIconColor {
            public var name: String
            public var color: Int32
            public init(name: String, color: Int32) {
                self.name = name
                self.color = color
            }
        }
        case attachMenuBotIconColor(Cons_attachMenuBotIconColor)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuBotIconColor(let _data):
                if boxed {
                    buffer.appendInt32(1165423600)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeInt32(_data.color, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuBotIconColor(let _data):
                return ("attachMenuBotIconColor", [("name", _data.name as Any), ("color", _data.color as Any)])
            }
        }

        public static func parse_attachMenuBotIconColor(_ reader: BufferReader) -> AttachMenuBotIconColor? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AttachMenuBotIconColor.attachMenuBotIconColor(Cons_attachMenuBotIconColor(name: _1!, color: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AttachMenuBots: TypeConstructorDescription {
        public class Cons_attachMenuBots {
            public var hash: Int64
            public var bots: [Api.AttachMenuBot]
            public var users: [Api.User]
            public init(hash: Int64, bots: [Api.AttachMenuBot], users: [Api.User]) {
                self.hash = hash
                self.bots = bots
                self.users = users
            }
        }
        case attachMenuBots(Cons_attachMenuBots)
        case attachMenuBotsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuBots(let _data):
                if boxed {
                    buffer.appendInt32(1011024320)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.bots.count))
                for item in _data.bots {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .attachMenuBotsNotModified:
                if boxed {
                    buffer.appendInt32(-237467044)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuBots(let _data):
                return ("attachMenuBots", [("hash", _data.hash as Any), ("bots", _data.bots as Any), ("users", _data.users as Any)])
            case .attachMenuBotsNotModified:
                return ("attachMenuBotsNotModified", [])
            }
        }

        public static func parse_attachMenuBots(_ reader: BufferReader) -> AttachMenuBots? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.AttachMenuBot]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AttachMenuBot.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.AttachMenuBots.attachMenuBots(Cons_attachMenuBots(hash: _1!, bots: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_attachMenuBotsNotModified(_ reader: BufferReader) -> AttachMenuBots? {
            return Api.AttachMenuBots.attachMenuBotsNotModified
        }
    }
}
public extension Api {
    enum AttachMenuBotsBot: TypeConstructorDescription {
        public class Cons_attachMenuBotsBot {
            public var bot: Api.AttachMenuBot
            public var users: [Api.User]
            public init(bot: Api.AttachMenuBot, users: [Api.User]) {
                self.bot = bot
                self.users = users
            }
        }
        case attachMenuBotsBot(Cons_attachMenuBotsBot)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuBotsBot(let _data):
                if boxed {
                    buffer.appendInt32(-1816172929)
                }
                _data.bot.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuBotsBot(let _data):
                return ("attachMenuBotsBot", [("bot", _data.bot as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_attachMenuBotsBot(_ reader: BufferReader) -> AttachMenuBotsBot? {
            var _1: Api.AttachMenuBot?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AttachMenuBot
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AttachMenuBotsBot.attachMenuBotsBot(Cons_attachMenuBotsBot(bot: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AttachMenuPeerType: TypeConstructorDescription {
        case attachMenuPeerTypeBotPM
        case attachMenuPeerTypeBroadcast
        case attachMenuPeerTypeChat
        case attachMenuPeerTypePM
        case attachMenuPeerTypeSameBotPM

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .attachMenuPeerTypeBotPM:
                if boxed {
                    buffer.appendInt32(-1020528102)
                }
                break
            case .attachMenuPeerTypeBroadcast:
                if boxed {
                    buffer.appendInt32(2080104188)
                }
                break
            case .attachMenuPeerTypeChat:
                if boxed {
                    buffer.appendInt32(84480319)
                }
                break
            case .attachMenuPeerTypePM:
                if boxed {
                    buffer.appendInt32(-247016673)
                }
                break
            case .attachMenuPeerTypeSameBotPM:
                if boxed {
                    buffer.appendInt32(2104224014)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .attachMenuPeerTypeBotPM:
                return ("attachMenuPeerTypeBotPM", [])
            case .attachMenuPeerTypeBroadcast:
                return ("attachMenuPeerTypeBroadcast", [])
            case .attachMenuPeerTypeChat:
                return ("attachMenuPeerTypeChat", [])
            case .attachMenuPeerTypePM:
                return ("attachMenuPeerTypePM", [])
            case .attachMenuPeerTypeSameBotPM:
                return ("attachMenuPeerTypeSameBotPM", [])
            }
        }

        public static func parse_attachMenuPeerTypeBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeBotPM
        }
        public static func parse_attachMenuPeerTypeBroadcast(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeBroadcast
        }
        public static func parse_attachMenuPeerTypeChat(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeChat
        }
        public static func parse_attachMenuPeerTypePM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypePM
        }
        public static func parse_attachMenuPeerTypeSameBotPM(_ reader: BufferReader) -> AttachMenuPeerType? {
            return Api.AttachMenuPeerType.attachMenuPeerTypeSameBotPM
        }
    }
}
public extension Api {
    enum AuctionBidLevel: TypeConstructorDescription {
        public class Cons_auctionBidLevel {
            public var pos: Int32
            public var amount: Int64
            public var date: Int32
            public init(pos: Int32, amount: Int64, date: Int32) {
                self.pos = pos
                self.amount = amount
                self.date = date
            }
        }
        case auctionBidLevel(Cons_auctionBidLevel)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .auctionBidLevel(let _data):
                if boxed {
                    buffer.appendInt32(822231244)
                }
                serializeInt32(_data.pos, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .auctionBidLevel(let _data):
                return ("auctionBidLevel", [("pos", _data.pos as Any), ("amount", _data.amount as Any), ("date", _data.date as Any)])
            }
        }

        public static func parse_auctionBidLevel(_ reader: BufferReader) -> AuctionBidLevel? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.AuctionBidLevel.auctionBidLevel(Cons_auctionBidLevel(pos: _1!, amount: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Authorization: TypeConstructorDescription {
        public class Cons_authorization {
            public var flags: Int32
            public var hash: Int64
            public var deviceModel: String
            public var platform: String
            public var systemVersion: String
            public var apiId: Int32
            public var appName: String
            public var appVersion: String
            public var dateCreated: Int32
            public var dateActive: Int32
            public var ip: String
            public var country: String
            public var region: String
            public init(flags: Int32, hash: Int64, deviceModel: String, platform: String, systemVersion: String, apiId: Int32, appName: String, appVersion: String, dateCreated: Int32, dateActive: Int32, ip: String, country: String, region: String) {
                self.flags = flags
                self.hash = hash
                self.deviceModel = deviceModel
                self.platform = platform
                self.systemVersion = systemVersion
                self.apiId = apiId
                self.appName = appName
                self.appVersion = appVersion
                self.dateCreated = dateCreated
                self.dateActive = dateActive
                self.ip = ip
                self.country = country
                self.region = region
            }
        }
        case authorization(Cons_authorization)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .authorization(let _data):
                if boxed {
                    buffer.appendInt32(-1392388579)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                serializeString(_data.deviceModel, buffer: buffer, boxed: false)
                serializeString(_data.platform, buffer: buffer, boxed: false)
                serializeString(_data.systemVersion, buffer: buffer, boxed: false)
                serializeInt32(_data.apiId, buffer: buffer, boxed: false)
                serializeString(_data.appName, buffer: buffer, boxed: false)
                serializeString(_data.appVersion, buffer: buffer, boxed: false)
                serializeInt32(_data.dateCreated, buffer: buffer, boxed: false)
                serializeInt32(_data.dateActive, buffer: buffer, boxed: false)
                serializeString(_data.ip, buffer: buffer, boxed: false)
                serializeString(_data.country, buffer: buffer, boxed: false)
                serializeString(_data.region, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .authorization(let _data):
                return ("authorization", [("flags", _data.flags as Any), ("hash", _data.hash as Any), ("deviceModel", _data.deviceModel as Any), ("platform", _data.platform as Any), ("systemVersion", _data.systemVersion as Any), ("apiId", _data.apiId as Any), ("appName", _data.appName as Any), ("appVersion", _data.appVersion as Any), ("dateCreated", _data.dateCreated as Any), ("dateActive", _data.dateActive as Any), ("ip", _data.ip as Any), ("country", _data.country as Any), ("region", _data.region as Any)])
            }
        }

        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            _7 = parseString(reader)
            var _8: String?
            _8 = parseString(reader)
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: String?
            _11 = parseString(reader)
            var _12: String?
            _12 = parseString(reader)
            var _13: String?
            _13 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Authorization.authorization(Cons_authorization(flags: _1!, hash: _2!, deviceModel: _3!, platform: _4!, systemVersion: _5!, apiId: _6!, appName: _7!, appVersion: _8!, dateCreated: _9!, dateActive: _10!, ip: _11!, country: _12!, region: _13!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AutoDownloadSettings: TypeConstructorDescription {
        public class Cons_autoDownloadSettings {
            public var flags: Int32
            public var photoSizeMax: Int32
            public var videoSizeMax: Int64
            public var fileSizeMax: Int64
            public var videoUploadMaxbitrate: Int32
            public var smallQueueActiveOperationsMax: Int32
            public var largeQueueActiveOperationsMax: Int32
            public init(flags: Int32, photoSizeMax: Int32, videoSizeMax: Int64, fileSizeMax: Int64, videoUploadMaxbitrate: Int32, smallQueueActiveOperationsMax: Int32, largeQueueActiveOperationsMax: Int32) {
                self.flags = flags
                self.photoSizeMax = photoSizeMax
                self.videoSizeMax = videoSizeMax
                self.fileSizeMax = fileSizeMax
                self.videoUploadMaxbitrate = videoUploadMaxbitrate
                self.smallQueueActiveOperationsMax = smallQueueActiveOperationsMax
                self.largeQueueActiveOperationsMax = largeQueueActiveOperationsMax
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .autoDownloadSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1163561432)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.photoSizeMax, buffer: buffer, boxed: false)
                serializeInt64(_data.videoSizeMax, buffer: buffer, boxed: false)
                serializeInt64(_data.fileSizeMax, buffer: buffer, boxed: false)
                serializeInt32(_data.videoUploadMaxbitrate, buffer: buffer, boxed: false)
                serializeInt32(_data.smallQueueActiveOperationsMax, buffer: buffer, boxed: false)
                serializeInt32(_data.largeQueueActiveOperationsMax, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .autoDownloadSettings(let _data):
                return ("autoDownloadSettings", [("flags", _data.flags as Any), ("photoSizeMax", _data.photoSizeMax as Any), ("videoSizeMax", _data.videoSizeMax as Any), ("fileSizeMax", _data.fileSizeMax as Any), ("videoUploadMaxbitrate", _data.videoUploadMaxbitrate as Any), ("smallQueueActiveOperationsMax", _data.smallQueueActiveOperationsMax as Any), ("largeQueueActiveOperationsMax", _data.largeQueueActiveOperationsMax as Any)])
            }
        }

        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.AutoDownloadSettings.autoDownloadSettings(Cons_autoDownloadSettings(flags: _1!, photoSizeMax: _2!, videoSizeMax: _3!, fileSizeMax: _4!, videoUploadMaxbitrate: _5!, smallQueueActiveOperationsMax: _6!, largeQueueActiveOperationsMax: _7!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AutoSaveException: TypeConstructorDescription {
        public class Cons_autoSaveException {
            public var peer: Api.Peer
            public var settings: Api.AutoSaveSettings
            public init(peer: Api.Peer, settings: Api.AutoSaveSettings) {
                self.peer = peer
                self.settings = settings
            }
        }
        case autoSaveException(Cons_autoSaveException)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .autoSaveException(let _data):
                if boxed {
                    buffer.appendInt32(-2124403385)
                }
                _data.peer.serialize(buffer, true)
                _data.settings.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .autoSaveException(let _data):
                return ("autoSaveException", [("peer", _data.peer as Any), ("settings", _data.settings as Any)])
            }
        }

        public static func parse_autoSaveException(_ reader: BufferReader) -> AutoSaveException? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.AutoSaveSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoSaveSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.AutoSaveException.autoSaveException(Cons_autoSaveException(peer: _1!, settings: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AutoSaveSettings: TypeConstructorDescription {
        public class Cons_autoSaveSettings {
            public var flags: Int32
            public var videoMaxSize: Int64?
            public init(flags: Int32, videoMaxSize: Int64?) {
                self.flags = flags
                self.videoMaxSize = videoMaxSize
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .autoSaveSettings(let _data):
                if boxed {
                    buffer.appendInt32(-934791986)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.videoMaxSize!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .autoSaveSettings(let _data):
                return ("autoSaveSettings", [("flags", _data.flags as Any), ("videoMaxSize", _data.videoMaxSize as Any)])
            }
        }

        public static func parse_autoSaveSettings(_ reader: BufferReader) -> AutoSaveSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {
                _2 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.AutoSaveSettings.autoSaveSettings(Cons_autoSaveSettings(flags: _1!, videoMaxSize: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AvailableEffect: TypeConstructorDescription {
        public class Cons_availableEffect {
            public var flags: Int32
            public var id: Int64
            public var emoticon: String
            public var staticIconId: Int64?
            public var effectStickerId: Int64
            public var effectAnimationId: Int64?
            public init(flags: Int32, id: Int64, emoticon: String, staticIconId: Int64?, effectStickerId: Int64, effectAnimationId: Int64?) {
                self.flags = flags
                self.id = id
                self.emoticon = emoticon
                self.staticIconId = staticIconId
                self.effectStickerId = effectStickerId
                self.effectAnimationId = effectAnimationId
            }
        }
        case availableEffect(Cons_availableEffect)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .availableEffect(let _data):
                if boxed {
                    buffer.appendInt32(-1815879042)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.staticIconId!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.effectStickerId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.effectAnimationId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .availableEffect(let _data):
                return ("availableEffect", [("flags", _data.flags as Any), ("id", _data.id as Any), ("emoticon", _data.emoticon as Any), ("staticIconId", _data.staticIconId as Any), ("effectStickerId", _data.effectStickerId as Any), ("effectAnimationId", _data.effectAnimationId as Any)])
            }
        }

        public static func parse_availableEffect(_ reader: BufferReader) -> AvailableEffect? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.AvailableEffect.availableEffect(Cons_availableEffect(flags: _1!, id: _2!, emoticon: _3!, staticIconId: _4, effectStickerId: _5!, effectAnimationId: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum AvailableReaction: TypeConstructorDescription {
        public class Cons_availableReaction {
            public var flags: Int32
            public var reaction: String
            public var title: String
            public var staticIcon: Api.Document
            public var appearAnimation: Api.Document
            public var selectAnimation: Api.Document
            public var activateAnimation: Api.Document
            public var effectAnimation: Api.Document
            public var aroundAnimation: Api.Document?
            public var centerIcon: Api.Document?
            public init(flags: Int32, reaction: String, title: String, staticIcon: Api.Document, appearAnimation: Api.Document, selectAnimation: Api.Document, activateAnimation: Api.Document, effectAnimation: Api.Document, aroundAnimation: Api.Document?, centerIcon: Api.Document?) {
                self.flags = flags
                self.reaction = reaction
                self.title = title
                self.staticIcon = staticIcon
                self.appearAnimation = appearAnimation
                self.selectAnimation = selectAnimation
                self.activateAnimation = activateAnimation
                self.effectAnimation = effectAnimation
                self.aroundAnimation = aroundAnimation
                self.centerIcon = centerIcon
            }
        }
        case availableReaction(Cons_availableReaction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .availableReaction(let _data):
                if boxed {
                    buffer.appendInt32(-1065882623)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.reaction, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                _data.staticIcon.serialize(buffer, true)
                _data.appearAnimation.serialize(buffer, true)
                _data.selectAnimation.serialize(buffer, true)
                _data.activateAnimation.serialize(buffer, true)
                _data.effectAnimation.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.aroundAnimation!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.centerIcon!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .availableReaction(let _data):
                return ("availableReaction", [("flags", _data.flags as Any), ("reaction", _data.reaction as Any), ("title", _data.title as Any), ("staticIcon", _data.staticIcon as Any), ("appearAnimation", _data.appearAnimation as Any), ("selectAnimation", _data.selectAnimation as Any), ("activateAnimation", _data.activateAnimation as Any), ("effectAnimation", _data.effectAnimation as Any), ("aroundAnimation", _data.aroundAnimation as Any), ("centerIcon", _data.centerIcon as Any)])
            }
        }

        public static func parse_availableReaction(_ reader: BufferReader) -> AvailableReaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _5: Api.Document?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _6: Api.Document?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _7: Api.Document?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _8: Api.Document?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _9: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _10: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.AvailableReaction.availableReaction(Cons_availableReaction(flags: _1!, reaction: _2!, title: _3!, staticIcon: _4!, appearAnimation: _5!, selectAnimation: _6!, activateAnimation: _7!, effectAnimation: _8!, aroundAnimation: _9, centerIcon: _10))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BankCardOpenUrl: TypeConstructorDescription {
        public class Cons_bankCardOpenUrl {
            public var url: String
            public var name: String
            public init(url: String, name: String) {
                self.url = url
                self.name = name
            }
        }
        case bankCardOpenUrl(Cons_bankCardOpenUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .bankCardOpenUrl(let _data):
                if boxed {
                    buffer.appendInt32(-177732982)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .bankCardOpenUrl(let _data):
                return ("bankCardOpenUrl", [("url", _data.url as Any), ("name", _data.name as Any)])
            }
        }

        public static func parse_bankCardOpenUrl(_ reader: BufferReader) -> BankCardOpenUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BankCardOpenUrl.bankCardOpenUrl(Cons_bankCardOpenUrl(url: _1!, name: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BaseTheme: TypeConstructorDescription {
        case baseThemeArctic
        case baseThemeClassic
        case baseThemeDay
        case baseThemeNight
        case baseThemeTinted

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .baseThemeArctic:
                if boxed {
                    buffer.appendInt32(1527845466)
                }
                break
            case .baseThemeClassic:
                if boxed {
                    buffer.appendInt32(-1012849566)
                }
                break
            case .baseThemeDay:
                if boxed {
                    buffer.appendInt32(-69724536)
                }
                break
            case .baseThemeNight:
                if boxed {
                    buffer.appendInt32(-1212997976)
                }
                break
            case .baseThemeTinted:
                if boxed {
                    buffer.appendInt32(1834973166)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .baseThemeArctic:
                return ("baseThemeArctic", [])
            case .baseThemeClassic:
                return ("baseThemeClassic", [])
            case .baseThemeDay:
                return ("baseThemeDay", [])
            case .baseThemeNight:
                return ("baseThemeNight", [])
            case .baseThemeTinted:
                return ("baseThemeTinted", [])
            }
        }

        public static func parse_baseThemeArctic(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeArctic
        }
        public static func parse_baseThemeClassic(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeClassic
        }
        public static func parse_baseThemeDay(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeDay
        }
        public static func parse_baseThemeNight(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeNight
        }
        public static func parse_baseThemeTinted(_ reader: BufferReader) -> BaseTheme? {
            return Api.BaseTheme.baseThemeTinted
        }
    }
}
public extension Api {
    enum Birthday: TypeConstructorDescription {
        public class Cons_birthday {
            public var flags: Int32
            public var day: Int32
            public var month: Int32
            public var year: Int32?
            public init(flags: Int32, day: Int32, month: Int32, year: Int32?) {
                self.flags = flags
                self.day = day
                self.month = month
                self.year = year
            }
        }
        case birthday(Cons_birthday)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .birthday(let _data):
                if boxed {
                    buffer.appendInt32(1821253126)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.day, buffer: buffer, boxed: false)
                serializeInt32(_data.month, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.year!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .birthday(let _data):
                return ("birthday", [("flags", _data.flags as Any), ("day", _data.day as Any), ("month", _data.month as Any), ("year", _data.year as Any)])
            }
        }

        public static func parse_birthday(_ reader: BufferReader) -> Birthday? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Birthday.birthday(Cons_birthday(flags: _1!, day: _2!, month: _3!, year: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Bool: TypeConstructorDescription {
        case boolFalse
        case boolTrue

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .boolFalse:
                if boxed {
                    buffer.appendInt32(-1132882121)
                }
                break
            case .boolTrue:
                if boxed {
                    buffer.appendInt32(-1720552011)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .boolFalse:
                return ("boolFalse", [])
            case .boolTrue:
                return ("boolTrue", [])
            }
        }

        public static func parse_boolFalse(_ reader: BufferReader) -> Bool? {
            return Api.Bool.boolFalse
        }
        public static func parse_boolTrue(_ reader: BufferReader) -> Bool? {
            return Api.Bool.boolTrue
        }
    }
}
public extension Api {
    enum Boost: TypeConstructorDescription {
        public class Cons_boost {
            public var flags: Int32
            public var id: String
            public var userId: Int64?
            public var giveawayMsgId: Int32?
            public var date: Int32
            public var expires: Int32
            public var usedGiftSlug: String?
            public var multiplier: Int32?
            public var stars: Int64?
            public init(flags: Int32, id: String, userId: Int64?, giveawayMsgId: Int32?, date: Int32, expires: Int32, usedGiftSlug: String?, multiplier: Int32?, stars: Int64?) {
                self.flags = flags
                self.id = id
                self.userId = userId
                self.giveawayMsgId = giveawayMsgId
                self.date = date
                self.expires = expires
                self.usedGiftSlug = usedGiftSlug
                self.multiplier = multiplier
                self.stars = stars
            }
        }
        case boost(Cons_boost)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .boost(let _data):
                if boxed {
                    buffer.appendInt32(1262359766)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.userId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.giveawayMsgId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.usedGiftSlug!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.multiplier!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt64(_data.stars!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .boost(let _data):
                return ("boost", [("flags", _data.flags as Any), ("id", _data.id as Any), ("userId", _data.userId as Any), ("giveawayMsgId", _data.giveawayMsgId as Any), ("date", _data.date as Any), ("expires", _data.expires as Any), ("usedGiftSlug", _data.usedGiftSlug as Any), ("multiplier", _data.multiplier as Any), ("stars", _data.stars as Any)])
            }
        }

        public static func parse_boost(_ reader: BufferReader) -> Boost? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt64()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = parseString(reader)
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Boost.boost(Cons_boost(flags: _1!, id: _2!, userId: _3, giveawayMsgId: _4, date: _5!, expires: _6!, usedGiftSlug: _7, multiplier: _8, stars: _9))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotApp: TypeConstructorDescription {
        public class Cons_botApp {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var shortName: String
            public var title: String
            public var description: String
            public var photo: Api.Photo
            public var document: Api.Document?
            public var hash: Int64
            public init(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?, hash: Int64) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.shortName = shortName
                self.title = title
                self.description = description
                self.photo = photo
                self.document = document
                self.hash = hash
            }
        }
        case botApp(Cons_botApp)
        case botAppNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botApp(let _data):
                if boxed {
                    buffer.appendInt32(-1778593322)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                _data.photo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            case .botAppNotModified:
                if boxed {
                    buffer.appendInt32(1571189943)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botApp(let _data):
                return ("botApp", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("shortName", _data.shortName as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("document", _data.document as Any), ("hash", _data.hash as Any)])
            case .botAppNotModified:
                return ("botAppNotModified", [])
            }
        }

        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.Photo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _9: Int64?
            _9 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.BotApp.botApp(Cons_botApp(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8, hash: _9!))
            }
            else {
                return nil
            }
        }
        public static func parse_botAppNotModified(_ reader: BufferReader) -> BotApp? {
            return Api.BotApp.botAppNotModified
        }
    }
}
public extension Api {
    enum BotAppSettings: TypeConstructorDescription {
        public class Cons_botAppSettings {
            public var flags: Int32
            public var placeholderPath: Buffer?
            public var backgroundColor: Int32?
            public var backgroundDarkColor: Int32?
            public var headerColor: Int32?
            public var headerDarkColor: Int32?
            public init(flags: Int32, placeholderPath: Buffer?, backgroundColor: Int32?, backgroundDarkColor: Int32?, headerColor: Int32?, headerDarkColor: Int32?) {
                self.flags = flags
                self.placeholderPath = placeholderPath
                self.backgroundColor = backgroundColor
                self.backgroundDarkColor = backgroundDarkColor
                self.headerColor = headerColor
                self.headerDarkColor = headerDarkColor
            }
        }
        case botAppSettings(Cons_botAppSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botAppSettings(let _data):
                if boxed {
                    buffer.appendInt32(-912582320)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.placeholderPath!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.backgroundColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.backgroundDarkColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.headerColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.headerDarkColor!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botAppSettings(let _data):
                return ("botAppSettings", [("flags", _data.flags as Any), ("placeholderPath", _data.placeholderPath as Any), ("backgroundColor", _data.backgroundColor as Any), ("backgroundDarkColor", _data.backgroundDarkColor as Any), ("headerColor", _data.headerColor as Any), ("headerDarkColor", _data.headerDarkColor as Any)])
            }
        }

        public static func parse_botAppSettings(_ reader: BufferReader) -> BotAppSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseBytes(reader)
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BotAppSettings.botAppSettings(Cons_botAppSettings(flags: _1!, placeholderPath: _2, backgroundColor: _3, backgroundDarkColor: _4, headerColor: _5, headerDarkColor: _6))
            }
            else {
                return nil
            }
        }
    }
}
