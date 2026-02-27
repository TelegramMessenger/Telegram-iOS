public extension Api {
    enum ChatInviteImporter: TypeConstructorDescription {
        public class Cons_chatInviteImporter {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var about: String?
            public var approvedBy: Int64?
            public init(flags: Int32, userId: Int64, date: Int32, about: String?, approvedBy: Int64?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.about = about
                self.approvedBy = approvedBy
            }
        }
        case chatInviteImporter(Cons_chatInviteImporter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatInviteImporter(let _data):
                if boxed {
                    buffer.appendInt32(-1940201511)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.about!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.approvedBy!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatInviteImporter(let _data):
                return ("chatInviteImporter", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("date", _data.date as Any), ("about", _data.about as Any), ("approvedBy", _data.approvedBy as Any)])
            }
        }

        public static func parse_chatInviteImporter(_ reader: BufferReader) -> ChatInviteImporter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChatInviteImporter.chatInviteImporter(Cons_chatInviteImporter(flags: _1!, userId: _2!, date: _3!, about: _4, approvedBy: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatOnlines: TypeConstructorDescription {
        public class Cons_chatOnlines {
            public var onlines: Int32
            public init(onlines: Int32) {
                self.onlines = onlines
            }
        }
        case chatOnlines(Cons_chatOnlines)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatOnlines(let _data):
                if boxed {
                    buffer.appendInt32(-264117680)
                }
                serializeInt32(_data.onlines, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatOnlines(let _data):
                return ("chatOnlines", [("onlines", _data.onlines as Any)])
            }
        }

        public static func parse_chatOnlines(_ reader: BufferReader) -> ChatOnlines? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatOnlines.chatOnlines(Cons_chatOnlines(onlines: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatParticipant: TypeConstructorDescription {
        public class Cons_chatParticipant {
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public init(userId: Int64, inviterId: Int64, date: Int32) {
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
            }
        }
        public class Cons_chatParticipantAdmin {
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public init(userId: Int64, inviterId: Int64, date: Int32) {
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
            }
        }
        public class Cons_chatParticipantCreator {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
        }
        case chatParticipant(Cons_chatParticipant)
        case chatParticipantAdmin(Cons_chatParticipantAdmin)
        case chatParticipantCreator(Cons_chatParticipantCreator)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatParticipant(let _data):
                if boxed {
                    buffer.appendInt32(-1070776313)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .chatParticipantAdmin(let _data):
                if boxed {
                    buffer.appendInt32(-1600962725)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .chatParticipantCreator(let _data):
                if boxed {
                    buffer.appendInt32(-462696732)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatParticipant(let _data):
                return ("chatParticipant", [("userId", _data.userId as Any), ("inviterId", _data.inviterId as Any), ("date", _data.date as Any)])
            case .chatParticipantAdmin(let _data):
                return ("chatParticipantAdmin", [("userId", _data.userId as Any), ("inviterId", _data.inviterId as Any), ("date", _data.date as Any)])
            case .chatParticipantCreator(let _data):
                return ("chatParticipantCreator", [("userId", _data.userId as Any)])
            }
        }

        public static func parse_chatParticipant(_ reader: BufferReader) -> ChatParticipant? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipant.chatParticipant(Cons_chatParticipant(userId: _1!, inviterId: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantAdmin(_ reader: BufferReader) -> ChatParticipant? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipant.chatParticipantAdmin(Cons_chatParticipantAdmin(userId: _1!, inviterId: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantCreator(_ reader: BufferReader) -> ChatParticipant? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatParticipant.chatParticipantCreator(Cons_chatParticipantCreator(userId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatParticipants: TypeConstructorDescription {
        public class Cons_chatParticipants {
            public var chatId: Int64
            public var participants: [Api.ChatParticipant]
            public var version: Int32
            public init(chatId: Int64, participants: [Api.ChatParticipant], version: Int32) {
                self.chatId = chatId
                self.participants = participants
                self.version = version
            }
        }
        public class Cons_chatParticipantsForbidden {
            public var flags: Int32
            public var chatId: Int64
            public var selfParticipant: Api.ChatParticipant?
            public init(flags: Int32, chatId: Int64, selfParticipant: Api.ChatParticipant?) {
                self.flags = flags
                self.chatId = chatId
                self.selfParticipant = selfParticipant
            }
        }
        case chatParticipants(Cons_chatParticipants)
        case chatParticipantsForbidden(Cons_chatParticipantsForbidden)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(1018991608)
                }
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.participants.count))
                for item in _data.participants {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            case .chatParticipantsForbidden(let _data):
                if boxed {
                    buffer.appendInt32(-2023500831)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.selfParticipant!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatParticipants(let _data):
                return ("chatParticipants", [("chatId", _data.chatId as Any), ("participants", _data.participants as Any), ("version", _data.version as Any)])
            case .chatParticipantsForbidden(let _data):
                return ("chatParticipantsForbidden", [("flags", _data.flags as Any), ("chatId", _data.chatId as Any), ("selfParticipant", _data.selfParticipant as Any)])
            }
        }

        public static func parse_chatParticipants(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.ChatParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatParticipant.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipants.chatParticipants(Cons_chatParticipants(chatId: _1!, participants: _2!, version: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatParticipantsForbidden(_ reader: BufferReader) -> ChatParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChatParticipants.chatParticipantsForbidden(Cons_chatParticipantsForbidden(flags: _1!, chatId: _2!, selfParticipant: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatPhoto: TypeConstructorDescription {
        public class Cons_chatPhoto {
            public var flags: Int32
            public var photoId: Int64
            public var strippedThumb: Buffer?
            public var dcId: Int32
            public init(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32) {
                self.flags = flags
                self.photoId = photoId
                self.strippedThumb = strippedThumb
                self.dcId = dcId
            }
        }
        case chatPhoto(Cons_chatPhoto)
        case chatPhotoEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatPhoto(let _data):
                if boxed {
                    buffer.appendInt32(476978193)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeBytes(_data.strippedThumb!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                break
            case .chatPhotoEmpty:
                if boxed {
                    buffer.appendInt32(935395612)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatPhoto(let _data):
                return ("chatPhoto", [("flags", _data.flags as Any), ("photoId", _data.photoId as Any), ("strippedThumb", _data.strippedThumb as Any), ("dcId", _data.dcId as Any)])
            case .chatPhotoEmpty:
                return ("chatPhotoEmpty", [])
            }
        }

        public static func parse_chatPhoto(_ reader: BufferReader) -> ChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChatPhoto.chatPhoto(Cons_chatPhoto(flags: _1!, photoId: _2!, strippedThumb: _3, dcId: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatPhotoEmpty(_ reader: BufferReader) -> ChatPhoto? {
            return Api.ChatPhoto.chatPhotoEmpty
        }
    }
}
public extension Api {
    enum ChatReactions: TypeConstructorDescription {
        public class Cons_chatReactionsAll {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_chatReactionsSome {
            public var reactions: [Api.Reaction]
            public init(reactions: [Api.Reaction]) {
                self.reactions = reactions
            }
        }
        case chatReactionsAll(Cons_chatReactionsAll)
        case chatReactionsNone
        case chatReactionsSome(Cons_chatReactionsSome)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatReactionsAll(let _data):
                if boxed {
                    buffer.appendInt32(1385335754)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .chatReactionsNone:
                if boxed {
                    buffer.appendInt32(-352570692)
                }
                break
            case .chatReactionsSome(let _data):
                if boxed {
                    buffer.appendInt32(1713193015)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatReactionsAll(let _data):
                return ("chatReactionsAll", [("flags", _data.flags as Any)])
            case .chatReactionsNone:
                return ("chatReactionsNone", [])
            case .chatReactionsSome(let _data):
                return ("chatReactionsSome", [("reactions", _data.reactions as Any)])
            }
        }

        public static func parse_chatReactionsAll(_ reader: BufferReader) -> ChatReactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatReactions.chatReactionsAll(Cons_chatReactionsAll(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatReactionsNone(_ reader: BufferReader) -> ChatReactions? {
            return Api.ChatReactions.chatReactionsNone
        }
        public static func parse_chatReactionsSome(_ reader: BufferReader) -> ChatReactions? {
            var _1: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatReactions.chatReactionsSome(Cons_chatReactionsSome(reactions: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatTheme: TypeConstructorDescription {
        public class Cons_chatTheme {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_chatThemeUniqueGift {
            public var gift: Api.StarGift
            public var themeSettings: [Api.ThemeSettings]
            public init(gift: Api.StarGift, themeSettings: [Api.ThemeSettings]) {
                self.gift = gift
                self.themeSettings = themeSettings
            }
        }
        case chatTheme(Cons_chatTheme)
        case chatThemeUniqueGift(Cons_chatThemeUniqueGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatTheme(let _data):
                if boxed {
                    buffer.appendInt32(-1008731132)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .chatThemeUniqueGift(let _data):
                if boxed {
                    buffer.appendInt32(878246344)
                }
                _data.gift.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.themeSettings.count))
                for item in _data.themeSettings {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatTheme(let _data):
                return ("chatTheme", [("emoticon", _data.emoticon as Any)])
            case .chatThemeUniqueGift(let _data):
                return ("chatThemeUniqueGift", [("gift", _data.gift as Any), ("themeSettings", _data.themeSettings as Any)])
            }
        }

        public static func parse_chatTheme(_ reader: BufferReader) -> ChatTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatTheme.chatTheme(Cons_chatTheme(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatThemeUniqueGift(_ reader: BufferReader) -> ChatTheme? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _2: [Api.ThemeSettings]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ThemeSettings.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChatTheme.chatThemeUniqueGift(Cons_chatThemeUniqueGift(gift: _1!, themeSettings: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum CodeSettings: TypeConstructorDescription {
        public class Cons_codeSettings {
            public var flags: Int32
            public var logoutTokens: [Buffer]?
            public var token: String?
            public var appSandbox: Api.Bool?
            public init(flags: Int32, logoutTokens: [Buffer]?, token: String?, appSandbox: Api.Bool?) {
                self.flags = flags
                self.logoutTokens = logoutTokens
                self.token = token
                self.appSandbox = appSandbox
            }
        }
        case codeSettings(Cons_codeSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .codeSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1390068360)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.logoutTokens!.count))
                    for item in _data.logoutTokens! {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.token!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.appSandbox!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .codeSettings(let _data):
                return ("codeSettings", [("flags", _data.flags as Any), ("logoutTokens", _data.logoutTokens as Any), ("token", _data.token as Any), ("appSandbox", _data.appSandbox as Any)])
            }
        }

        public static func parse_codeSettings(_ reader: BufferReader) -> CodeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Buffer]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
                }
            }
            var _3: String?
            if Int(_1!) & Int(1 << 8) != 0 {
                _3 = parseString(reader)
            }
            var _4: Api.Bool?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 6) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 8) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.CodeSettings.codeSettings(Cons_codeSettings(flags: _1!, logoutTokens: _2, token: _3, appSandbox: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Config: TypeConstructorDescription {
        public class Cons_config {
            public var flags: Int32
            public var date: Int32
            public var expires: Int32
            public var testMode: Api.Bool
            public var thisDc: Int32
            public var dcOptions: [Api.DcOption]
            public var dcTxtDomainName: String
            public var chatSizeMax: Int32
            public var megagroupSizeMax: Int32
            public var forwardedCountMax: Int32
            public var onlineUpdatePeriodMs: Int32
            public var offlineBlurTimeoutMs: Int32
            public var offlineIdleTimeoutMs: Int32
            public var onlineCloudTimeoutMs: Int32
            public var notifyCloudDelayMs: Int32
            public var notifyDefaultDelayMs: Int32
            public var pushChatPeriodMs: Int32
            public var pushChatLimit: Int32
            public var editTimeLimit: Int32
            public var revokeTimeLimit: Int32
            public var revokePmTimeLimit: Int32
            public var ratingEDecay: Int32
            public var stickersRecentLimit: Int32
            public var channelsReadMediaPeriod: Int32
            public var tmpSessions: Int32?
            public var callReceiveTimeoutMs: Int32
            public var callRingTimeoutMs: Int32
            public var callConnectTimeoutMs: Int32
            public var callPacketTimeoutMs: Int32
            public var meUrlPrefix: String
            public var autoupdateUrlPrefix: String?
            public var gifSearchUsername: String?
            public var venueSearchUsername: String?
            public var imgSearchUsername: String?
            public var staticMapsProvider: String?
            public var captionLengthMax: Int32
            public var messageLengthMax: Int32
            public var webfileDcId: Int32
            public var suggestedLangCode: String?
            public var langPackVersion: Int32?
            public var baseLangPackVersion: Int32?
            public var reactionsDefault: Api.Reaction?
            public var autologinToken: String?
            public init(flags: Int32, date: Int32, expires: Int32, testMode: Api.Bool, thisDc: Int32, dcOptions: [Api.DcOption], dcTxtDomainName: String, chatSizeMax: Int32, megagroupSizeMax: Int32, forwardedCountMax: Int32, onlineUpdatePeriodMs: Int32, offlineBlurTimeoutMs: Int32, offlineIdleTimeoutMs: Int32, onlineCloudTimeoutMs: Int32, notifyCloudDelayMs: Int32, notifyDefaultDelayMs: Int32, pushChatPeriodMs: Int32, pushChatLimit: Int32, editTimeLimit: Int32, revokeTimeLimit: Int32, revokePmTimeLimit: Int32, ratingEDecay: Int32, stickersRecentLimit: Int32, channelsReadMediaPeriod: Int32, tmpSessions: Int32?, callReceiveTimeoutMs: Int32, callRingTimeoutMs: Int32, callConnectTimeoutMs: Int32, callPacketTimeoutMs: Int32, meUrlPrefix: String, autoupdateUrlPrefix: String?, gifSearchUsername: String?, venueSearchUsername: String?, imgSearchUsername: String?, staticMapsProvider: String?, captionLengthMax: Int32, messageLengthMax: Int32, webfileDcId: Int32, suggestedLangCode: String?, langPackVersion: Int32?, baseLangPackVersion: Int32?, reactionsDefault: Api.Reaction?, autologinToken: String?) {
                self.flags = flags
                self.date = date
                self.expires = expires
                self.testMode = testMode
                self.thisDc = thisDc
                self.dcOptions = dcOptions
                self.dcTxtDomainName = dcTxtDomainName
                self.chatSizeMax = chatSizeMax
                self.megagroupSizeMax = megagroupSizeMax
                self.forwardedCountMax = forwardedCountMax
                self.onlineUpdatePeriodMs = onlineUpdatePeriodMs
                self.offlineBlurTimeoutMs = offlineBlurTimeoutMs
                self.offlineIdleTimeoutMs = offlineIdleTimeoutMs
                self.onlineCloudTimeoutMs = onlineCloudTimeoutMs
                self.notifyCloudDelayMs = notifyCloudDelayMs
                self.notifyDefaultDelayMs = notifyDefaultDelayMs
                self.pushChatPeriodMs = pushChatPeriodMs
                self.pushChatLimit = pushChatLimit
                self.editTimeLimit = editTimeLimit
                self.revokeTimeLimit = revokeTimeLimit
                self.revokePmTimeLimit = revokePmTimeLimit
                self.ratingEDecay = ratingEDecay
                self.stickersRecentLimit = stickersRecentLimit
                self.channelsReadMediaPeriod = channelsReadMediaPeriod
                self.tmpSessions = tmpSessions
                self.callReceiveTimeoutMs = callReceiveTimeoutMs
                self.callRingTimeoutMs = callRingTimeoutMs
                self.callConnectTimeoutMs = callConnectTimeoutMs
                self.callPacketTimeoutMs = callPacketTimeoutMs
                self.meUrlPrefix = meUrlPrefix
                self.autoupdateUrlPrefix = autoupdateUrlPrefix
                self.gifSearchUsername = gifSearchUsername
                self.venueSearchUsername = venueSearchUsername
                self.imgSearchUsername = imgSearchUsername
                self.staticMapsProvider = staticMapsProvider
                self.captionLengthMax = captionLengthMax
                self.messageLengthMax = messageLengthMax
                self.webfileDcId = webfileDcId
                self.suggestedLangCode = suggestedLangCode
                self.langPackVersion = langPackVersion
                self.baseLangPackVersion = baseLangPackVersion
                self.reactionsDefault = reactionsDefault
                self.autologinToken = autologinToken
            }
        }
        case config(Cons_config)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .config(let _data):
                if boxed {
                    buffer.appendInt32(-870702050)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                _data.testMode.serialize(buffer, true)
                serializeInt32(_data.thisDc, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dcOptions.count))
                for item in _data.dcOptions {
                    item.serialize(buffer, true)
                }
                serializeString(_data.dcTxtDomainName, buffer: buffer, boxed: false)
                serializeInt32(_data.chatSizeMax, buffer: buffer, boxed: false)
                serializeInt32(_data.megagroupSizeMax, buffer: buffer, boxed: false)
                serializeInt32(_data.forwardedCountMax, buffer: buffer, boxed: false)
                serializeInt32(_data.onlineUpdatePeriodMs, buffer: buffer, boxed: false)
                serializeInt32(_data.offlineBlurTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.offlineIdleTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.onlineCloudTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.notifyCloudDelayMs, buffer: buffer, boxed: false)
                serializeInt32(_data.notifyDefaultDelayMs, buffer: buffer, boxed: false)
                serializeInt32(_data.pushChatPeriodMs, buffer: buffer, boxed: false)
                serializeInt32(_data.pushChatLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.editTimeLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.revokeTimeLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.revokePmTimeLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.ratingEDecay, buffer: buffer, boxed: false)
                serializeInt32(_data.stickersRecentLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.channelsReadMediaPeriod, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.tmpSessions!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.callReceiveTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.callRingTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.callConnectTimeoutMs, buffer: buffer, boxed: false)
                serializeInt32(_data.callPacketTimeoutMs, buffer: buffer, boxed: false)
                serializeString(_data.meUrlPrefix, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeString(_data.autoupdateUrlPrefix!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeString(_data.gifSearchUsername!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeString(_data.venueSearchUsername!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeString(_data.imgSearchUsername!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeString(_data.staticMapsProvider!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.captionLengthMax, buffer: buffer, boxed: false)
                serializeInt32(_data.messageLengthMax, buffer: buffer, boxed: false)
                serializeInt32(_data.webfileDcId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.suggestedLangCode!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.langPackVersion!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.baseLangPackVersion!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.reactionsDefault!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.autologinToken!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .config(let _data):
                return ("config", [("flags", _data.flags as Any), ("date", _data.date as Any), ("expires", _data.expires as Any), ("testMode", _data.testMode as Any), ("thisDc", _data.thisDc as Any), ("dcOptions", _data.dcOptions as Any), ("dcTxtDomainName", _data.dcTxtDomainName as Any), ("chatSizeMax", _data.chatSizeMax as Any), ("megagroupSizeMax", _data.megagroupSizeMax as Any), ("forwardedCountMax", _data.forwardedCountMax as Any), ("onlineUpdatePeriodMs", _data.onlineUpdatePeriodMs as Any), ("offlineBlurTimeoutMs", _data.offlineBlurTimeoutMs as Any), ("offlineIdleTimeoutMs", _data.offlineIdleTimeoutMs as Any), ("onlineCloudTimeoutMs", _data.onlineCloudTimeoutMs as Any), ("notifyCloudDelayMs", _data.notifyCloudDelayMs as Any), ("notifyDefaultDelayMs", _data.notifyDefaultDelayMs as Any), ("pushChatPeriodMs", _data.pushChatPeriodMs as Any), ("pushChatLimit", _data.pushChatLimit as Any), ("editTimeLimit", _data.editTimeLimit as Any), ("revokeTimeLimit", _data.revokeTimeLimit as Any), ("revokePmTimeLimit", _data.revokePmTimeLimit as Any), ("ratingEDecay", _data.ratingEDecay as Any), ("stickersRecentLimit", _data.stickersRecentLimit as Any), ("channelsReadMediaPeriod", _data.channelsReadMediaPeriod as Any), ("tmpSessions", _data.tmpSessions as Any), ("callReceiveTimeoutMs", _data.callReceiveTimeoutMs as Any), ("callRingTimeoutMs", _data.callRingTimeoutMs as Any), ("callConnectTimeoutMs", _data.callConnectTimeoutMs as Any), ("callPacketTimeoutMs", _data.callPacketTimeoutMs as Any), ("meUrlPrefix", _data.meUrlPrefix as Any), ("autoupdateUrlPrefix", _data.autoupdateUrlPrefix as Any), ("gifSearchUsername", _data.gifSearchUsername as Any), ("venueSearchUsername", _data.venueSearchUsername as Any), ("imgSearchUsername", _data.imgSearchUsername as Any), ("staticMapsProvider", _data.staticMapsProvider as Any), ("captionLengthMax", _data.captionLengthMax as Any), ("messageLengthMax", _data.messageLengthMax as Any), ("webfileDcId", _data.webfileDcId as Any), ("suggestedLangCode", _data.suggestedLangCode as Any), ("langPackVersion", _data.langPackVersion as Any), ("baseLangPackVersion", _data.baseLangPackVersion as Any), ("reactionsDefault", _data.reactionsDefault as Any), ("autologinToken", _data.autologinToken as Any)])
            }
        }

        public static func parse_config(_ reader: BufferReader) -> Config? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Bool?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.DcOption]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DcOption.self)
            }
            var _7: String?
            _7 = parseString(reader)
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Int32?
            _13 = reader.readInt32()
            var _14: Int32?
            _14 = reader.readInt32()
            var _15: Int32?
            _15 = reader.readInt32()
            var _16: Int32?
            _16 = reader.readInt32()
            var _17: Int32?
            _17 = reader.readInt32()
            var _18: Int32?
            _18 = reader.readInt32()
            var _19: Int32?
            _19 = reader.readInt32()
            var _20: Int32?
            _20 = reader.readInt32()
            var _21: Int32?
            _21 = reader.readInt32()
            var _22: Int32?
            _22 = reader.readInt32()
            var _23: Int32?
            _23 = reader.readInt32()
            var _24: Int32?
            _24 = reader.readInt32()
            var _25: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _25 = reader.readInt32()
            }
            var _26: Int32?
            _26 = reader.readInt32()
            var _27: Int32?
            _27 = reader.readInt32()
            var _28: Int32?
            _28 = reader.readInt32()
            var _29: Int32?
            _29 = reader.readInt32()
            var _30: String?
            _30 = parseString(reader)
            var _31: String?
            if Int(_1!) & Int(1 << 7) != 0 {
                _31 = parseString(reader)
            }
            var _32: String?
            if Int(_1!) & Int(1 << 9) != 0 {
                _32 = parseString(reader)
            }
            var _33: String?
            if Int(_1!) & Int(1 << 10) != 0 {
                _33 = parseString(reader)
            }
            var _34: String?
            if Int(_1!) & Int(1 << 11) != 0 {
                _34 = parseString(reader)
            }
            var _35: String?
            if Int(_1!) & Int(1 << 12) != 0 {
                _35 = parseString(reader)
            }
            var _36: Int32?
            _36 = reader.readInt32()
            var _37: Int32?
            _37 = reader.readInt32()
            var _38: Int32?
            _38 = reader.readInt32()
            var _39: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _39 = parseString(reader)
            }
            var _40: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _40 = reader.readInt32()
            }
            var _41: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _41 = reader.readInt32()
            }
            var _42: Api.Reaction?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _42 = Api.parse(reader, signature: signature) as? Api.Reaction
                }
            }
            var _43: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _43 = parseString(reader)
            }
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
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            let _c18 = _18 != nil
            let _c19 = _19 != nil
            let _c20 = _20 != nil
            let _c21 = _21 != nil
            let _c22 = _22 != nil
            let _c23 = _23 != nil
            let _c24 = _24 != nil
            let _c25 = (Int(_1!) & Int(1 << 0) == 0) || _25 != nil
            let _c26 = _26 != nil
            let _c27 = _27 != nil
            let _c28 = _28 != nil
            let _c29 = _29 != nil
            let _c30 = _30 != nil
            let _c31 = (Int(_1!) & Int(1 << 7) == 0) || _31 != nil
            let _c32 = (Int(_1!) & Int(1 << 9) == 0) || _32 != nil
            let _c33 = (Int(_1!) & Int(1 << 10) == 0) || _33 != nil
            let _c34 = (Int(_1!) & Int(1 << 11) == 0) || _34 != nil
            let _c35 = (Int(_1!) & Int(1 << 12) == 0) || _35 != nil
            let _c36 = _36 != nil
            let _c37 = _37 != nil
            let _c38 = _38 != nil
            let _c39 = (Int(_1!) & Int(1 << 2) == 0) || _39 != nil
            let _c40 = (Int(_1!) & Int(1 << 2) == 0) || _40 != nil
            let _c41 = (Int(_1!) & Int(1 << 2) == 0) || _41 != nil
            let _c42 = (Int(_1!) & Int(1 << 15) == 0) || _42 != nil
            let _c43 = (Int(_1!) & Int(1 << 16) == 0) || _43 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 && _c40 && _c41 && _c42 && _c43 {
                return Api.Config.config(Cons_config(flags: _1!, date: _2!, expires: _3!, testMode: _4!, thisDc: _5!, dcOptions: _6!, dcTxtDomainName: _7!, chatSizeMax: _8!, megagroupSizeMax: _9!, forwardedCountMax: _10!, onlineUpdatePeriodMs: _11!, offlineBlurTimeoutMs: _12!, offlineIdleTimeoutMs: _13!, onlineCloudTimeoutMs: _14!, notifyCloudDelayMs: _15!, notifyDefaultDelayMs: _16!, pushChatPeriodMs: _17!, pushChatLimit: _18!, editTimeLimit: _19!, revokeTimeLimit: _20!, revokePmTimeLimit: _21!, ratingEDecay: _22!, stickersRecentLimit: _23!, channelsReadMediaPeriod: _24!, tmpSessions: _25, callReceiveTimeoutMs: _26!, callRingTimeoutMs: _27!, callConnectTimeoutMs: _28!, callPacketTimeoutMs: _29!, meUrlPrefix: _30!, autoupdateUrlPrefix: _31, gifSearchUsername: _32, venueSearchUsername: _33, imgSearchUsername: _34, staticMapsProvider: _35, captionLengthMax: _36!, messageLengthMax: _37!, webfileDcId: _38!, suggestedLangCode: _39, langPackVersion: _40, baseLangPackVersion: _41, reactionsDefault: _42, autologinToken: _43))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ConnectedBot: TypeConstructorDescription {
        public class Cons_connectedBot {
            public var flags: Int32
            public var botId: Int64
            public var recipients: Api.BusinessBotRecipients
            public var rights: Api.BusinessBotRights
            public init(flags: Int32, botId: Int64, recipients: Api.BusinessBotRecipients, rights: Api.BusinessBotRights) {
                self.flags = flags
                self.botId = botId
                self.recipients = recipients
                self.rights = rights
            }
        }
        case connectedBot(Cons_connectedBot)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .connectedBot(let _data):
                if boxed {
                    buffer.appendInt32(-849058964)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                _data.recipients.serialize(buffer, true)
                _data.rights.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .connectedBot(let _data):
                return ("connectedBot", [("flags", _data.flags as Any), ("botId", _data.botId as Any), ("recipients", _data.recipients as Any), ("rights", _data.rights as Any)])
            }
        }

        public static func parse_connectedBot(_ reader: BufferReader) -> ConnectedBot? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.BusinessBotRecipients?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.BusinessBotRecipients
            }
            var _4: Api.BusinessBotRights?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.BusinessBotRights
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ConnectedBot.connectedBot(Cons_connectedBot(flags: _1!, botId: _2!, recipients: _3!, rights: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ConnectedBotStarRef: TypeConstructorDescription {
        public class Cons_connectedBotStarRef {
            public var flags: Int32
            public var url: String
            public var date: Int32
            public var botId: Int64
            public var commissionPermille: Int32
            public var durationMonths: Int32?
            public var participants: Int64
            public var revenue: Int64
            public init(flags: Int32, url: String, date: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, participants: Int64, revenue: Int64) {
                self.flags = flags
                self.url = url
                self.date = date
                self.botId = botId
                self.commissionPermille = commissionPermille
                self.durationMonths = durationMonths
                self.participants = participants
                self.revenue = revenue
            }
        }
        case connectedBotStarRef(Cons_connectedBotStarRef)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .connectedBotStarRef(let _data):
                if boxed {
                    buffer.appendInt32(429997937)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeInt32(_data.commissionPermille, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.durationMonths!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.participants, buffer: buffer, boxed: false)
                serializeInt64(_data.revenue, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .connectedBotStarRef(let _data):
                return ("connectedBotStarRef", [("flags", _data.flags as Any), ("url", _data.url as Any), ("date", _data.date as Any), ("botId", _data.botId as Any), ("commissionPermille", _data.commissionPermille as Any), ("durationMonths", _data.durationMonths as Any), ("participants", _data.participants as Any), ("revenue", _data.revenue as Any)])
            }
        }

        public static func parse_connectedBotStarRef(_ reader: BufferReader) -> ConnectedBotStarRef? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Int64?
            _8 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.ConnectedBotStarRef.connectedBotStarRef(Cons_connectedBotStarRef(flags: _1!, url: _2!, date: _3!, botId: _4!, commissionPermille: _5!, durationMonths: _6, participants: _7!, revenue: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Contact: TypeConstructorDescription {
        public class Cons_contact {
            public var userId: Int64
            public var mutual: Api.Bool
            public init(userId: Int64, mutual: Api.Bool) {
                self.userId = userId
                self.mutual = mutual
            }
        }
        case contact(Cons_contact)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contact(let _data):
                if boxed {
                    buffer.appendInt32(341499403)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.mutual.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .contact(let _data):
                return ("contact", [("userId", _data.userId as Any), ("mutual", _data.mutual as Any)])
            }
        }

        public static func parse_contact(_ reader: BufferReader) -> Contact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Contact.contact(Cons_contact(userId: _1!, mutual: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ContactBirthday: TypeConstructorDescription {
        public class Cons_contactBirthday {
            public var contactId: Int64
            public var birthday: Api.Birthday
            public init(contactId: Int64, birthday: Api.Birthday) {
                self.contactId = contactId
                self.birthday = birthday
            }
        }
        case contactBirthday(Cons_contactBirthday)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contactBirthday(let _data):
                if boxed {
                    buffer.appendInt32(496600883)
                }
                serializeInt64(_data.contactId, buffer: buffer, boxed: false)
                _data.birthday.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .contactBirthday(let _data):
                return ("contactBirthday", [("contactId", _data.contactId as Any), ("birthday", _data.birthday as Any)])
            }
        }

        public static func parse_contactBirthday(_ reader: BufferReader) -> ContactBirthday? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Birthday?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Birthday
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ContactBirthday.contactBirthday(Cons_contactBirthday(contactId: _1!, birthday: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ContactStatus: TypeConstructorDescription {
        public class Cons_contactStatus {
            public var userId: Int64
            public var status: Api.UserStatus
            public init(userId: Int64, status: Api.UserStatus) {
                self.userId = userId
                self.status = status
            }
        }
        case contactStatus(Cons_contactStatus)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contactStatus(let _data):
                if boxed {
                    buffer.appendInt32(383348795)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.status.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .contactStatus(let _data):
                return ("contactStatus", [("userId", _data.userId as Any), ("status", _data.status as Any)])
            }
        }

        public static func parse_contactStatus(_ reader: BufferReader) -> ContactStatus? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.UserStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ContactStatus.contactStatus(Cons_contactStatus(userId: _1!, status: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DataJSON: TypeConstructorDescription {
        public class Cons_dataJSON {
            public var data: String
            public init(data: String) {
                self.data = data
            }
        }
        case dataJSON(Cons_dataJSON)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dataJSON(let _data):
                if boxed {
                    buffer.appendInt32(2104790276)
                }
                serializeString(_data.data, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dataJSON(let _data):
                return ("dataJSON", [("data", _data.data as Any)])
            }
        }

        public static func parse_dataJSON(_ reader: BufferReader) -> DataJSON? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.DataJSON.dataJSON(Cons_dataJSON(data: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DcOption: TypeConstructorDescription {
        public class Cons_dcOption {
            public var flags: Int32
            public var id: Int32
            public var ipAddress: String
            public var port: Int32
            public var secret: Buffer?
            public init(flags: Int32, id: Int32, ipAddress: String, port: Int32, secret: Buffer?) {
                self.flags = flags
                self.id = id
                self.ipAddress = ipAddress
                self.port = port
                self.secret = secret
            }
        }
        case dcOption(Cons_dcOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dcOption(let _data):
                if boxed {
                    buffer.appendInt32(414687501)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.ipAddress, buffer: buffer, boxed: false)
                serializeInt32(_data.port, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeBytes(_data.secret!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dcOption(let _data):
                return ("dcOption", [("flags", _data.flags as Any), ("id", _data.id as Any), ("ipAddress", _data.ipAddress as Any), ("port", _data.port as Any), ("secret", _data.secret as Any)])
            }
        }

        public static func parse_dcOption(_ reader: BufferReader) -> DcOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            if Int(_1!) & Int(1 << 10) != 0 {
                _5 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 10) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DcOption.dcOption(Cons_dcOption(flags: _1!, id: _2!, ipAddress: _3!, port: _4!, secret: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DefaultHistoryTTL: TypeConstructorDescription {
        public class Cons_defaultHistoryTTL {
            public var period: Int32
            public init(period: Int32) {
                self.period = period
            }
        }
        case defaultHistoryTTL(Cons_defaultHistoryTTL)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .defaultHistoryTTL(let _data):
                if boxed {
                    buffer.appendInt32(1135897376)
                }
                serializeInt32(_data.period, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .defaultHistoryTTL(let _data):
                return ("defaultHistoryTTL", [("period", _data.period as Any)])
            }
        }

        public static func parse_defaultHistoryTTL(_ reader: BufferReader) -> DefaultHistoryTTL? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.DefaultHistoryTTL.defaultHistoryTTL(Cons_defaultHistoryTTL(period: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum Dialog: TypeConstructorDescription {
        public class Cons_dialog {
            public var flags: Int32
            public var peer: Api.Peer
            public var topMessage: Int32
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var unreadMentionsCount: Int32
            public var unreadReactionsCount: Int32
            public var notifySettings: Api.PeerNotifySettings
            public var pts: Int32?
            public var draft: Api.DraftMessage?
            public var folderId: Int32?
            public var ttlPeriod: Int32?
            public init(flags: Int32, peer: Api.Peer, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, notifySettings: Api.PeerNotifySettings, pts: Int32?, draft: Api.DraftMessage?, folderId: Int32?, ttlPeriod: Int32?) {
                self.flags = flags
                self.peer = peer
                self.topMessage = topMessage
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.unreadMentionsCount = unreadMentionsCount
                self.unreadReactionsCount = unreadReactionsCount
                self.notifySettings = notifySettings
                self.pts = pts
                self.draft = draft
                self.folderId = folderId
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_dialogFolder {
            public var flags: Int32
            public var folder: Api.Folder
            public var peer: Api.Peer
            public var topMessage: Int32
            public var unreadMutedPeersCount: Int32
            public var unreadUnmutedPeersCount: Int32
            public var unreadMutedMessagesCount: Int32
            public var unreadUnmutedMessagesCount: Int32
            public init(flags: Int32, folder: Api.Folder, peer: Api.Peer, topMessage: Int32, unreadMutedPeersCount: Int32, unreadUnmutedPeersCount: Int32, unreadMutedMessagesCount: Int32, unreadUnmutedMessagesCount: Int32) {
                self.flags = flags
                self.folder = folder
                self.peer = peer
                self.topMessage = topMessage
                self.unreadMutedPeersCount = unreadMutedPeersCount
                self.unreadUnmutedPeersCount = unreadUnmutedPeersCount
                self.unreadMutedMessagesCount = unreadMutedMessagesCount
                self.unreadUnmutedMessagesCount = unreadUnmutedMessagesCount
            }
        }
        case dialog(Cons_dialog)
        case dialogFolder(Cons_dialogFolder)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialog(let _data):
                if boxed {
                    buffer.appendInt32(-712374074)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                serializeInt32(_data.readInboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.readOutboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadMentionsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadReactionsCount, buffer: buffer, boxed: false)
                _data.notifySettings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.pts!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.draft!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            case .dialogFolder(let _data):
                if boxed {
                    buffer.appendInt32(1908216652)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.folder.serialize(buffer, true)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadMutedPeersCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadUnmutedPeersCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadMutedMessagesCount, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadUnmutedMessagesCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dialog(let _data):
                return ("dialog", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("topMessage", _data.topMessage as Any), ("readInboxMaxId", _data.readInboxMaxId as Any), ("readOutboxMaxId", _data.readOutboxMaxId as Any), ("unreadCount", _data.unreadCount as Any), ("unreadMentionsCount", _data.unreadMentionsCount as Any), ("unreadReactionsCount", _data.unreadReactionsCount as Any), ("notifySettings", _data.notifySettings as Any), ("pts", _data.pts as Any), ("draft", _data.draft as Any), ("folderId", _data.folderId as Any), ("ttlPeriod", _data.ttlPeriod as Any)])
            case .dialogFolder(let _data):
                return ("dialogFolder", [("flags", _data.flags as Any), ("folder", _data.folder as Any), ("peer", _data.peer as Any), ("topMessage", _data.topMessage as Any), ("unreadMutedPeersCount", _data.unreadMutedPeersCount as Any), ("unreadUnmutedPeersCount", _data.unreadUnmutedPeersCount as Any), ("unreadMutedMessagesCount", _data.unreadMutedMessagesCount as Any), ("unreadUnmutedMessagesCount", _data.unreadUnmutedMessagesCount as Any)])
            }
        }

        public static func parse_dialog(_ reader: BufferReader) -> Dialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Api.DraftMessage?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.DraftMessage
                }
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _12 = reader.readInt32()
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _13 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 0) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 1) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 4) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 5) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Dialog.dialog(Cons_dialog(flags: _1!, peer: _2!, topMessage: _3!, readInboxMaxId: _4!, readOutboxMaxId: _5!, unreadCount: _6!, unreadMentionsCount: _7!, unreadReactionsCount: _8!, notifySettings: _9!, pts: _10, draft: _11, folderId: _12, ttlPeriod: _13))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogFolder(_ reader: BufferReader) -> Dialog? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Folder?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Folder
            }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Dialog.dialogFolder(Cons_dialogFolder(flags: _1!, folder: _2!, peer: _3!, topMessage: _4!, unreadMutedPeersCount: _5!, unreadUnmutedPeersCount: _6!, unreadMutedMessagesCount: _7!, unreadUnmutedMessagesCount: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DialogFilter: TypeConstructorDescription {
        public class Cons_dialogFilter {
            public var flags: Int32
            public var id: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var color: Int32?
            public var pinnedPeers: [Api.InputPeer]
            public var includePeers: [Api.InputPeer]
            public var excludePeers: [Api.InputPeer]
            public init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer], excludePeers: [Api.InputPeer]) {
                self.flags = flags
                self.id = id
                self.title = title
                self.emoticon = emoticon
                self.color = color
                self.pinnedPeers = pinnedPeers
                self.includePeers = includePeers
                self.excludePeers = excludePeers
            }
        }
        public class Cons_dialogFilterChatlist {
            public var flags: Int32
            public var id: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var color: Int32?
            public var pinnedPeers: [Api.InputPeer]
            public var includePeers: [Api.InputPeer]
            public init(flags: Int32, id: Int32, title: Api.TextWithEntities, emoticon: String?, color: Int32?, pinnedPeers: [Api.InputPeer], includePeers: [Api.InputPeer]) {
                self.flags = flags
                self.id = id
                self.title = title
                self.emoticon = emoticon
                self.color = color
                self.pinnedPeers = pinnedPeers
                self.includePeers = includePeers
            }
        }
        case dialogFilter(Cons_dialogFilter)
        case dialogFilterChatlist(Cons_dialogFilterChatlist)
        case dialogFilterDefault

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialogFilter(let _data):
                if boxed {
                    buffer.appendInt32(-1438177711)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeString(_data.emoticon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 27) != 0 {
                    serializeInt32(_data.color!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.pinnedPeers.count))
                for item in _data.pinnedPeers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.includePeers.count))
                for item in _data.includePeers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.excludePeers.count))
                for item in _data.excludePeers {
                    item.serialize(buffer, true)
                }
                break
            case .dialogFilterChatlist(let _data):
                if boxed {
                    buffer.appendInt32(-1772913705)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeString(_data.emoticon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 27) != 0 {
                    serializeInt32(_data.color!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.pinnedPeers.count))
                for item in _data.pinnedPeers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.includePeers.count))
                for item in _data.includePeers {
                    item.serialize(buffer, true)
                }
                break
            case .dialogFilterDefault:
                if boxed {
                    buffer.appendInt32(909284270)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dialogFilter(let _data):
                return ("dialogFilter", [("flags", _data.flags as Any), ("id", _data.id as Any), ("title", _data.title as Any), ("emoticon", _data.emoticon as Any), ("color", _data.color as Any), ("pinnedPeers", _data.pinnedPeers as Any), ("includePeers", _data.includePeers as Any), ("excludePeers", _data.excludePeers as Any)])
            case .dialogFilterChatlist(let _data):
                return ("dialogFilterChatlist", [("flags", _data.flags as Any), ("id", _data.id as Any), ("title", _data.title as Any), ("emoticon", _data.emoticon as Any), ("color", _data.color as Any), ("pinnedPeers", _data.pinnedPeers as Any), ("includePeers", _data.includePeers as Any)])
            case .dialogFilterDefault:
                return ("dialogFilterDefault", [])
            }
        }

        public static func parse_dialogFilter(_ reader: BufferReader) -> DialogFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _4: String?
            if Int(_1!) & Int(1 << 25) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 27) != 0 {
                _5 = reader.readInt32()
            }
            var _6: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            var _7: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            var _8: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 25) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 27) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.DialogFilter.dialogFilter(Cons_dialogFilter(flags: _1!, id: _2!, title: _3!, emoticon: _4, color: _5, pinnedPeers: _6!, includePeers: _7!, excludePeers: _8!))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogFilterChatlist(_ reader: BufferReader) -> DialogFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _4: String?
            if Int(_1!) & Int(1 << 25) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 27) != 0 {
                _5 = reader.readInt32()
            }
            var _6: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            var _7: [Api.InputPeer]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 25) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 27) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.DialogFilter.dialogFilterChatlist(Cons_dialogFilterChatlist(flags: _1!, id: _2!, title: _3!, emoticon: _4, color: _5, pinnedPeers: _6!, includePeers: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogFilterDefault(_ reader: BufferReader) -> DialogFilter? {
            return Api.DialogFilter.dialogFilterDefault
        }
    }
}
public extension Api {
    enum DialogFilterSuggested: TypeConstructorDescription {
        public class Cons_dialogFilterSuggested {
            public var filter: Api.DialogFilter
            public var description: String
            public init(filter: Api.DialogFilter, description: String) {
                self.filter = filter
                self.description = description
            }
        }
        case dialogFilterSuggested(Cons_dialogFilterSuggested)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialogFilterSuggested(let _data):
                if boxed {
                    buffer.appendInt32(2004110666)
                }
                _data.filter.serialize(buffer, true)
                serializeString(_data.description, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dialogFilterSuggested(let _data):
                return ("dialogFilterSuggested", [("filter", _data.filter as Any), ("description", _data.description as Any)])
            }
        }

        public static func parse_dialogFilterSuggested(_ reader: BufferReader) -> DialogFilterSuggested? {
            var _1: Api.DialogFilter?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DialogFilter
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.DialogFilterSuggested.dialogFilterSuggested(Cons_dialogFilterSuggested(filter: _1!, description: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DialogPeer: TypeConstructorDescription {
        public class Cons_dialogPeer {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        public class Cons_dialogPeerFolder {
            public var folderId: Int32
            public init(folderId: Int32) {
                self.folderId = folderId
            }
        }
        case dialogPeer(Cons_dialogPeer)
        case dialogPeerFolder(Cons_dialogPeerFolder)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialogPeer(let _data):
                if boxed {
                    buffer.appendInt32(-445792507)
                }
                _data.peer.serialize(buffer, true)
                break
            case .dialogPeerFolder(let _data):
                if boxed {
                    buffer.appendInt32(1363483106)
                }
                serializeInt32(_data.folderId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .dialogPeer(let _data):
                return ("dialogPeer", [("peer", _data.peer as Any)])
            case .dialogPeerFolder(let _data):
                return ("dialogPeerFolder", [("folderId", _data.folderId as Any)])
            }
        }

        public static func parse_dialogPeer(_ reader: BufferReader) -> DialogPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.DialogPeer.dialogPeer(Cons_dialogPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogPeerFolder(_ reader: BufferReader) -> DialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.DialogPeer.dialogPeerFolder(Cons_dialogPeerFolder(folderId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
