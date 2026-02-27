public extension Api {
    indirect enum Updates: TypeConstructorDescription {
        public class Cons_updateShort {
            public var update: Api.Update
            public var date: Int32
            public init(update: Api.Update, date: Int32) {
                self.update = update
                self.date = date
            }
        }
        public class Cons_updateShortChatMessage {
            public var flags: Int32
            public var id: Int32
            public var fromId: Int64
            public var chatId: Int64
            public var message: String
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, fromId: Int64, chatId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.chatId = chatId
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.replyTo = replyTo
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updateShortMessage {
            public var flags: Int32
            public var id: Int32
            public var userId: Int64
            public var message: String
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var fwdFrom: Api.MessageFwdHeader?
            public var viaBotId: Int64?
            public var replyTo: Api.MessageReplyHeader?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, userId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.userId = userId
                self.message = message
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.fwdFrom = fwdFrom
                self.viaBotId = viaBotId
                self.replyTo = replyTo
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updateShortSentMessage {
            public var flags: Int32
            public var id: Int32
            public var pts: Int32
            public var ptsCount: Int32
            public var date: Int32
            public var media: Api.MessageMedia?
            public var entities: [Api.MessageEntity]?
            public var ttlPeriod: Int32?
            public init(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
                self.flags = flags
                self.id = id
                self.pts = pts
                self.ptsCount = ptsCount
                self.date = date
                self.media = media
                self.entities = entities
                self.ttlPeriod = ttlPeriod
            }
        }
        public class Cons_updates {
            public var updates: [Api.Update]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public var date: Int32
            public var seq: Int32
            public init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32) {
                self.updates = updates
                self.users = users
                self.chats = chats
                self.date = date
                self.seq = seq
            }
        }
        public class Cons_updatesCombined {
            public var updates: [Api.Update]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public var date: Int32
            public var seqStart: Int32
            public var seq: Int32
            public init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32) {
                self.updates = updates
                self.users = users
                self.chats = chats
                self.date = date
                self.seqStart = seqStart
                self.seq = seq
            }
        }
        case updateShort(Cons_updateShort)
        case updateShortChatMessage(Cons_updateShortChatMessage)
        case updateShortMessage(Cons_updateShortMessage)
        case updateShortSentMessage(Cons_updateShortSentMessage)
        case updates(Cons_updates)
        case updatesCombined(Cons_updatesCombined)
        case updatesTooLong

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .updateShort(let _data):
                if boxed {
                    buffer.appendInt32(2027216577)
                }
                _data.update.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .updateShortChatMessage(let _data):
                if boxed {
                    buffer.appendInt32(1299050149)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.fromId, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.fwdFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt64(_data.viaBotId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            case .updateShortMessage(let _data):
                if boxed {
                    buffer.appendInt32(826001400)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.fwdFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt64(_data.viaBotId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            case .updateShortSentMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1877614335)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                break
            case .updates(let _data):
                if boxed {
                    buffer.appendInt32(1957577280)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.updates.count))
                for item in _data.updates {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.seq, buffer: buffer, boxed: false)
                break
            case .updatesCombined(let _data):
                if boxed {
                    buffer.appendInt32(1918567619)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.updates.count))
                for item in _data.updates {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.seqStart, buffer: buffer, boxed: false)
                serializeInt32(_data.seq, buffer: buffer, boxed: false)
                break
            case .updatesTooLong:
                if boxed {
                    buffer.appendInt32(-484987010)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .updateShort(let _data):
                return ("updateShort", [("update", _data.update as Any), ("date", _data.date as Any)])
            case .updateShortChatMessage(let _data):
                return ("updateShortChatMessage", [("flags", _data.flags as Any), ("id", _data.id as Any), ("fromId", _data.fromId as Any), ("chatId", _data.chatId as Any), ("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("date", _data.date as Any), ("fwdFrom", _data.fwdFrom as Any), ("viaBotId", _data.viaBotId as Any), ("replyTo", _data.replyTo as Any), ("entities", _data.entities as Any), ("ttlPeriod", _data.ttlPeriod as Any)])
            case .updateShortMessage(let _data):
                return ("updateShortMessage", [("flags", _data.flags as Any), ("id", _data.id as Any), ("userId", _data.userId as Any), ("message", _data.message as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("date", _data.date as Any), ("fwdFrom", _data.fwdFrom as Any), ("viaBotId", _data.viaBotId as Any), ("replyTo", _data.replyTo as Any), ("entities", _data.entities as Any), ("ttlPeriod", _data.ttlPeriod as Any)])
            case .updateShortSentMessage(let _data):
                return ("updateShortSentMessage", [("flags", _data.flags as Any), ("id", _data.id as Any), ("pts", _data.pts as Any), ("ptsCount", _data.ptsCount as Any), ("date", _data.date as Any), ("media", _data.media as Any), ("entities", _data.entities as Any), ("ttlPeriod", _data.ttlPeriod as Any)])
            case .updates(let _data):
                return ("updates", [("updates", _data.updates as Any), ("users", _data.users as Any), ("chats", _data.chats as Any), ("date", _data.date as Any), ("seq", _data.seq as Any)])
            case .updatesCombined(let _data):
                return ("updatesCombined", [("updates", _data.updates as Any), ("users", _data.users as Any), ("chats", _data.chats as Any), ("date", _data.date as Any), ("seqStart", _data.seqStart as Any), ("seq", _data.seq as Any)])
            case .updatesTooLong:
                return ("updatesTooLong", [])
            }
        }

        public static func parse_updateShort(_ reader: BufferReader) -> Updates? {
            var _1: Api.Update?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Update
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Updates.updateShort(Cons_updateShort(update: _1!, date: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortChatMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
                }
            }
            var _10: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {
                _10 = reader.readInt64()
            }
            var _11: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
                }
            }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {
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
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 25) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Updates.updateShortChatMessage(Cons_updateShortChatMessage(flags: _1!, id: _2!, fromId: _3!, chatId: _4!, message: _5!, pts: _6!, ptsCount: _7!, date: _8!, fwdFrom: _9, viaBotId: _10, replyTo: _11, entities: _12, ttlPeriod: _13))
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
                }
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {
                _9 = reader.readInt64()
            }
            var _10: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
                }
            }
            var _11: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {
                _12 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 11) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 25) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.Updates.updateShortMessage(Cons_updateShortMessage(flags: _1!, id: _2!, userId: _3!, message: _4!, pts: _5!, ptsCount: _6!, date: _7!, fwdFrom: _8, viaBotId: _9, replyTo: _10, entities: _11, ttlPeriod: _12))
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortSentMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _7: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 9) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 25) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Updates.updateShortSentMessage(Cons_updateShortSentMessage(flags: _1!, id: _2!, pts: _3!, ptsCount: _4!, date: _5!, media: _6, entities: _7, ttlPeriod: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_updates(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Updates.updates(Cons_updates(updates: _1!, users: _2!, chats: _3!, date: _4!, seq: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatesCombined(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Updates.updatesCombined(Cons_updatesCombined(updates: _1!, users: _2!, chats: _3!, date: _4!, seqStart: _5!, seq: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_updatesTooLong(_ reader: BufferReader) -> Updates? {
            return Api.Updates.updatesTooLong
        }
    }
}
public extension Api {
    enum UrlAuthResult: TypeConstructorDescription {
        public class Cons_urlAuthResultAccepted {
            public var flags: Int32
            public var url: String?
            public init(flags: Int32, url: String?) {
                self.flags = flags
                self.url = url
            }
        }
        public class Cons_urlAuthResultRequest {
            public var flags: Int32
            public var bot: Api.User
            public var domain: String
            public var browser: String?
            public var platform: String?
            public var ip: String?
            public var region: String?
            public init(flags: Int32, bot: Api.User, domain: String, browser: String?, platform: String?, ip: String?, region: String?) {
                self.flags = flags
                self.bot = bot
                self.domain = domain
                self.browser = browser
                self.platform = platform
                self.ip = ip
                self.region = region
            }
        }
        case urlAuthResultAccepted(Cons_urlAuthResultAccepted)
        case urlAuthResultDefault
        case urlAuthResultRequest(Cons_urlAuthResultRequest)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .urlAuthResultAccepted(let _data):
                if boxed {
                    buffer.appendInt32(1648005024)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                break
            case .urlAuthResultDefault:
                if boxed {
                    buffer.appendInt32(-1445536993)
                }
                break
            case .urlAuthResultRequest(let _data):
                if boxed {
                    buffer.appendInt32(855293722)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.bot.serialize(buffer, true)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.browser!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.platform!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.ip!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.region!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .urlAuthResultAccepted(let _data):
                return ("urlAuthResultAccepted", [("flags", _data.flags as Any), ("url", _data.url as Any)])
            case .urlAuthResultDefault:
                return ("urlAuthResultDefault", [])
            case .urlAuthResultRequest(let _data):
                return ("urlAuthResultRequest", [("flags", _data.flags as Any), ("bot", _data.bot as Any), ("domain", _data.domain as Any), ("browser", _data.browser as Any), ("platform", _data.platform as Any), ("ip", _data.ip as Any), ("region", _data.region as Any)])
            }
        }

        public static func parse_urlAuthResultAccepted(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.UrlAuthResult.urlAuthResultAccepted(Cons_urlAuthResultAccepted(flags: _1!, url: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_urlAuthResultDefault(_ reader: BufferReader) -> UrlAuthResult? {
            return Api.UrlAuthResult.urlAuthResultDefault
        }
        public static func parse_urlAuthResultRequest(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.UrlAuthResult.urlAuthResultRequest(Cons_urlAuthResultRequest(flags: _1!, bot: _2!, domain: _3!, browser: _4, platform: _5, ip: _6, region: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum User: TypeConstructorDescription {
        public class Cons_user {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var accessHash: Int64?
            public var firstName: String?
            public var lastName: String?
            public var username: String?
            public var phone: String?
            public var photo: Api.UserProfilePhoto?
            public var status: Api.UserStatus?
            public var botInfoVersion: Int32?
            public var restrictionReason: [Api.RestrictionReason]?
            public var botInlinePlaceholder: String?
            public var langCode: String?
            public var emojiStatus: Api.EmojiStatus?
            public var usernames: [Api.Username]?
            public var storiesMaxId: Api.RecentStory?
            public var color: Api.PeerColor?
            public var profileColor: Api.PeerColor?
            public var botActiveUsers: Int32?
            public var botVerificationIcon: Int64?
            public var sendPaidMessagesStars: Int64?
            public init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?, emojiStatus: Api.EmojiStatus?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, botActiveUsers: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.accessHash = accessHash
                self.firstName = firstName
                self.lastName = lastName
                self.username = username
                self.phone = phone
                self.photo = photo
                self.status = status
                self.botInfoVersion = botInfoVersion
                self.restrictionReason = restrictionReason
                self.botInlinePlaceholder = botInlinePlaceholder
                self.langCode = langCode
                self.emojiStatus = emojiStatus
                self.usernames = usernames
                self.storiesMaxId = storiesMaxId
                self.color = color
                self.profileColor = profileColor
                self.botActiveUsers = botActiveUsers
                self.botVerificationIcon = botVerificationIcon
                self.sendPaidMessagesStars = sendPaidMessagesStars
            }
        }
        public class Cons_userEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        case user(Cons_user)
        case userEmpty(Cons_userEmpty)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .user(let _data):
                if boxed {
                    buffer.appendInt32(829899656)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.flags2, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.accessHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.firstName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.lastName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.username!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.phone!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.status!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt32(_data.botInfoVersion!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.restrictionReason!.count))
                    for item in _data.restrictionReason! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    serializeString(_data.botInlinePlaceholder!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 22) != 0 {
                    serializeString(_data.langCode!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 30) != 0 {
                    _data.emojiStatus!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.usernames!.count))
                    for item in _data.usernames! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags2) & Int(1 << 5) != 0 {
                    _data.storiesMaxId!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 8) != 0 {
                    _data.color!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 9) != 0 {
                    _data.profileColor!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 12) != 0 {
                    serializeInt32(_data.botActiveUsers!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 14) != 0 {
                    serializeInt64(_data.botVerificationIcon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 15) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                break
            case .userEmpty(let _data):
                if boxed {
                    buffer.appendInt32(-742634630)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .user(let _data):
                return ("user", [("flags", _data.flags as Any), ("flags2", _data.flags2 as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("username", _data.username as Any), ("phone", _data.phone as Any), ("photo", _data.photo as Any), ("status", _data.status as Any), ("botInfoVersion", _data.botInfoVersion as Any), ("restrictionReason", _data.restrictionReason as Any), ("botInlinePlaceholder", _data.botInlinePlaceholder as Any), ("langCode", _data.langCode as Any), ("emojiStatus", _data.emojiStatus as Any), ("usernames", _data.usernames as Any), ("storiesMaxId", _data.storiesMaxId as Any), ("color", _data.color as Any), ("profileColor", _data.profileColor as Any), ("botActiveUsers", _data.botActiveUsers as Any), ("botVerificationIcon", _data.botVerificationIcon as Any), ("sendPaidMessagesStars", _data.sendPaidMessagesStars as Any)])
            case .userEmpty(let _data):
                return ("userEmpty", [("id", _data.id as Any)])
            }
        }

        public static func parse_user(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = parseString(reader)
            }
            var _9: Api.UserProfilePhoto?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
                }
            }
            var _10: Api.UserStatus?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.UserStatus
                }
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {
                _11 = reader.readInt32()
            }
            var _12: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let _ = reader.readInt32() {
                    _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
                }
            }
            var _13: String?
            if Int(_1!) & Int(1 << 19) != 0 {
                _13 = parseString(reader)
            }
            var _14: String?
            if Int(_1!) & Int(1 << 22) != 0 {
                _14 = parseString(reader)
            }
            var _15: Api.EmojiStatus?
            if Int(_1!) & Int(1 << 30) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
                }
            }
            var _16: [Api.Username]?
            if Int(_2!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
                }
            }
            var _17: Api.RecentStory?
            if Int(_2!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.RecentStory
                }
            }
            var _18: Api.PeerColor?
            if Int(_2!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _18 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _19: Api.PeerColor?
            if Int(_2!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _19 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _20: Int32?
            if Int(_2!) & Int(1 << 12) != 0 {
                _20 = reader.readInt32()
            }
            var _21: Int64?
            if Int(_2!) & Int(1 << 14) != 0 {
                _21 = reader.readInt64()
            }
            var _22: Int64?
            if Int(_2!) & Int(1 << 15) != 0 {
                _22 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 6) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 14) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 19) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 22) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 30) == 0) || _15 != nil
            let _c16 = (Int(_2!) & Int(1 << 0) == 0) || _16 != nil
            let _c17 = (Int(_2!) & Int(1 << 5) == 0) || _17 != nil
            let _c18 = (Int(_2!) & Int(1 << 8) == 0) || _18 != nil
            let _c19 = (Int(_2!) & Int(1 << 9) == 0) || _19 != nil
            let _c20 = (Int(_2!) & Int(1 << 12) == 0) || _20 != nil
            let _c21 = (Int(_2!) & Int(1 << 14) == 0) || _21 != nil
            let _c22 = (Int(_2!) & Int(1 << 15) == 0) || _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.User.user(Cons_user(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, firstName: _5, lastName: _6, username: _7, phone: _8, photo: _9, status: _10, botInfoVersion: _11, restrictionReason: _12, botInlinePlaceholder: _13, langCode: _14, emojiStatus: _15, usernames: _16, storiesMaxId: _17, color: _18, profileColor: _19, botActiveUsers: _20, botVerificationIcon: _21, sendPaidMessagesStars: _22))
            }
            else {
                return nil
            }
        }
        public static func parse_userEmpty(_ reader: BufferReader) -> User? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.User.userEmpty(Cons_userEmpty(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum UserFull: TypeConstructorDescription {
        public class Cons_userFull {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var about: String?
            public var settings: Api.PeerSettings
            public var personalPhoto: Api.Photo?
            public var profilePhoto: Api.Photo?
            public var fallbackPhoto: Api.Photo?
            public var notifySettings: Api.PeerNotifySettings
            public var botInfo: Api.BotInfo?
            public var pinnedMsgId: Int32?
            public var commonChatsCount: Int32
            public var folderId: Int32?
            public var ttlPeriod: Int32?
            public var theme: Api.ChatTheme?
            public var privateForwardName: String?
            public var botGroupAdminRights: Api.ChatAdminRights?
            public var botBroadcastAdminRights: Api.ChatAdminRights?
            public var wallpaper: Api.WallPaper?
            public var stories: Api.PeerStories?
            public var businessWorkHours: Api.BusinessWorkHours?
            public var businessLocation: Api.BusinessLocation?
            public var businessGreetingMessage: Api.BusinessGreetingMessage?
            public var businessAwayMessage: Api.BusinessAwayMessage?
            public var businessIntro: Api.BusinessIntro?
            public var birthday: Api.Birthday?
            public var personalChannelId: Int64?
            public var personalChannelMessage: Int32?
            public var stargiftsCount: Int32?
            public var starrefProgram: Api.StarRefProgram?
            public var botVerification: Api.BotVerification?
            public var sendPaidMessagesStars: Int64?
            public var disallowedGifts: Api.DisallowedGiftsSettings?
            public var starsRating: Api.StarsRating?
            public var starsMyPendingRating: Api.StarsRating?
            public var starsMyPendingRatingDate: Int32?
            public var mainTab: Api.ProfileTab?
            public var savedMusic: Api.Document?
            public var note: Api.TextWithEntities?
            public init(flags: Int32, flags2: Int32, id: Int64, about: String?, settings: Api.PeerSettings, personalPhoto: Api.Photo?, profilePhoto: Api.Photo?, fallbackPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?, ttlPeriod: Int32?, theme: Api.ChatTheme?, privateForwardName: String?, botGroupAdminRights: Api.ChatAdminRights?, botBroadcastAdminRights: Api.ChatAdminRights?, wallpaper: Api.WallPaper?, stories: Api.PeerStories?, businessWorkHours: Api.BusinessWorkHours?, businessLocation: Api.BusinessLocation?, businessGreetingMessage: Api.BusinessGreetingMessage?, businessAwayMessage: Api.BusinessAwayMessage?, businessIntro: Api.BusinessIntro?, birthday: Api.Birthday?, personalChannelId: Int64?, personalChannelMessage: Int32?, stargiftsCount: Int32?, starrefProgram: Api.StarRefProgram?, botVerification: Api.BotVerification?, sendPaidMessagesStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?, starsRating: Api.StarsRating?, starsMyPendingRating: Api.StarsRating?, starsMyPendingRatingDate: Int32?, mainTab: Api.ProfileTab?, savedMusic: Api.Document?, note: Api.TextWithEntities?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.about = about
                self.settings = settings
                self.personalPhoto = personalPhoto
                self.profilePhoto = profilePhoto
                self.fallbackPhoto = fallbackPhoto
                self.notifySettings = notifySettings
                self.botInfo = botInfo
                self.pinnedMsgId = pinnedMsgId
                self.commonChatsCount = commonChatsCount
                self.folderId = folderId
                self.ttlPeriod = ttlPeriod
                self.theme = theme
                self.privateForwardName = privateForwardName
                self.botGroupAdminRights = botGroupAdminRights
                self.botBroadcastAdminRights = botBroadcastAdminRights
                self.wallpaper = wallpaper
                self.stories = stories
                self.businessWorkHours = businessWorkHours
                self.businessLocation = businessLocation
                self.businessGreetingMessage = businessGreetingMessage
                self.businessAwayMessage = businessAwayMessage
                self.businessIntro = businessIntro
                self.birthday = birthday
                self.personalChannelId = personalChannelId
                self.personalChannelMessage = personalChannelMessage
                self.stargiftsCount = stargiftsCount
                self.starrefProgram = starrefProgram
                self.botVerification = botVerification
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.disallowedGifts = disallowedGifts
                self.starsRating = starsRating
                self.starsMyPendingRating = starsMyPendingRating
                self.starsMyPendingRatingDate = starsMyPendingRatingDate
                self.mainTab = mainTab
                self.savedMusic = savedMusic
                self.note = note
            }
        }
        case userFull(Cons_userFull)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userFull(let _data):
                if boxed {
                    buffer.appendInt32(-1607745218)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.flags2, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.about!, buffer: buffer, boxed: false)
                }
                _data.settings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 21) != 0 {
                    _data.personalPhoto!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.profilePhoto!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 22) != 0 {
                    _data.fallbackPhoto!.serialize(buffer, true)
                }
                _data.notifySettings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.botInfo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.pinnedMsgId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.commonChatsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.theme!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.privateForwardName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    _data.botGroupAdminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.botBroadcastAdminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 24) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    _data.stories!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 0) != 0 {
                    _data.businessWorkHours!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 1) != 0 {
                    _data.businessLocation!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 2) != 0 {
                    _data.businessGreetingMessage!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 3) != 0 {
                    _data.businessAwayMessage!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 4) != 0 {
                    _data.businessIntro!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 5) != 0 {
                    _data.birthday!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 6) != 0 {
                    serializeInt64(_data.personalChannelId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 6) != 0 {
                    serializeInt32(_data.personalChannelMessage!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 8) != 0 {
                    serializeInt32(_data.stargiftsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 11) != 0 {
                    _data.starrefProgram!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 12) != 0 {
                    _data.botVerification!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 14) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 15) != 0 {
                    _data.disallowedGifts!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 17) != 0 {
                    _data.starsRating!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 18) != 0 {
                    _data.starsMyPendingRating!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 18) != 0 {
                    serializeInt32(_data.starsMyPendingRatingDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 20) != 0 {
                    _data.mainTab!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 21) != 0 {
                    _data.savedMusic!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 22) != 0 {
                    _data.note!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .userFull(let _data):
                return ("userFull", [("flags", _data.flags as Any), ("flags2", _data.flags2 as Any), ("id", _data.id as Any), ("about", _data.about as Any), ("settings", _data.settings as Any), ("personalPhoto", _data.personalPhoto as Any), ("profilePhoto", _data.profilePhoto as Any), ("fallbackPhoto", _data.fallbackPhoto as Any), ("notifySettings", _data.notifySettings as Any), ("botInfo", _data.botInfo as Any), ("pinnedMsgId", _data.pinnedMsgId as Any), ("commonChatsCount", _data.commonChatsCount as Any), ("folderId", _data.folderId as Any), ("ttlPeriod", _data.ttlPeriod as Any), ("theme", _data.theme as Any), ("privateForwardName", _data.privateForwardName as Any), ("botGroupAdminRights", _data.botGroupAdminRights as Any), ("botBroadcastAdminRights", _data.botBroadcastAdminRights as Any), ("wallpaper", _data.wallpaper as Any), ("stories", _data.stories as Any), ("businessWorkHours", _data.businessWorkHours as Any), ("businessLocation", _data.businessLocation as Any), ("businessGreetingMessage", _data.businessGreetingMessage as Any), ("businessAwayMessage", _data.businessAwayMessage as Any), ("businessIntro", _data.businessIntro as Any), ("birthday", _data.birthday as Any), ("personalChannelId", _data.personalChannelId as Any), ("personalChannelMessage", _data.personalChannelMessage as Any), ("stargiftsCount", _data.stargiftsCount as Any), ("starrefProgram", _data.starrefProgram as Any), ("botVerification", _data.botVerification as Any), ("sendPaidMessagesStars", _data.sendPaidMessagesStars as Any), ("disallowedGifts", _data.disallowedGifts as Any), ("starsRating", _data.starsRating as Any), ("starsMyPendingRating", _data.starsMyPendingRating as Any), ("starsMyPendingRatingDate", _data.starsMyPendingRatingDate as Any), ("mainTab", _data.mainTab as Any), ("savedMusic", _data.savedMusic as Any), ("note", _data.note as Any)])
            }
        }

        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            var _6: Api.Photo?
            if Int(_1!) & Int(1 << 21) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _7: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _8: Api.Photo?
            if Int(_1!) & Int(1 << 22) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _9: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _10: Api.BotInfo?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.BotInfo
                }
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _11 = reader.readInt32()
            }
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _13 = reader.readInt32()
            }
            var _14: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {
                _14 = reader.readInt32()
            }
            var _15: Api.ChatTheme?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.ChatTheme
                }
            }
            var _16: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _16 = parseString(reader)
            }
            var _17: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _18: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _18 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _19: Api.WallPaper?
            if Int(_1!) & Int(1 << 24) != 0 {
                if let signature = reader.readInt32() {
                    _19 = Api.parse(reader, signature: signature) as? Api.WallPaper
                }
            }
            var _20: Api.PeerStories?
            if Int(_1!) & Int(1 << 25) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.PeerStories
                }
            }
            var _21: Api.BusinessWorkHours?
            if Int(_2!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _21 = Api.parse(reader, signature: signature) as? Api.BusinessWorkHours
                }
            }
            var _22: Api.BusinessLocation?
            if Int(_2!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _22 = Api.parse(reader, signature: signature) as? Api.BusinessLocation
                }
            }
            var _23: Api.BusinessGreetingMessage?
            if Int(_2!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _23 = Api.parse(reader, signature: signature) as? Api.BusinessGreetingMessage
                }
            }
            var _24: Api.BusinessAwayMessage?
            if Int(_2!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _24 = Api.parse(reader, signature: signature) as? Api.BusinessAwayMessage
                }
            }
            var _25: Api.BusinessIntro?
            if Int(_2!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _25 = Api.parse(reader, signature: signature) as? Api.BusinessIntro
                }
            }
            var _26: Api.Birthday?
            if Int(_2!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _26 = Api.parse(reader, signature: signature) as? Api.Birthday
                }
            }
            var _27: Int64?
            if Int(_2!) & Int(1 << 6) != 0 {
                _27 = reader.readInt64()
            }
            var _28: Int32?
            if Int(_2!) & Int(1 << 6) != 0 {
                _28 = reader.readInt32()
            }
            var _29: Int32?
            if Int(_2!) & Int(1 << 8) != 0 {
                _29 = reader.readInt32()
            }
            var _30: Api.StarRefProgram?
            if Int(_2!) & Int(1 << 11) != 0 {
                if let signature = reader.readInt32() {
                    _30 = Api.parse(reader, signature: signature) as? Api.StarRefProgram
                }
            }
            var _31: Api.BotVerification?
            if Int(_2!) & Int(1 << 12) != 0 {
                if let signature = reader.readInt32() {
                    _31 = Api.parse(reader, signature: signature) as? Api.BotVerification
                }
            }
            var _32: Int64?
            if Int(_2!) & Int(1 << 14) != 0 {
                _32 = reader.readInt64()
            }
            var _33: Api.DisallowedGiftsSettings?
            if Int(_2!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _33 = Api.parse(reader, signature: signature) as? Api.DisallowedGiftsSettings
                }
            }
            var _34: Api.StarsRating?
            if Int(_2!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _34 = Api.parse(reader, signature: signature) as? Api.StarsRating
                }
            }
            var _35: Api.StarsRating?
            if Int(_2!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _35 = Api.parse(reader, signature: signature) as? Api.StarsRating
                }
            }
            var _36: Int32?
            if Int(_2!) & Int(1 << 18) != 0 {
                _36 = reader.readInt32()
            }
            var _37: Api.ProfileTab?
            if Int(_2!) & Int(1 << 20) != 0 {
                if let signature = reader.readInt32() {
                    _37 = Api.parse(reader, signature: signature) as? Api.ProfileTab
                }
            }
            var _38: Api.Document?
            if Int(_2!) & Int(1 << 21) != 0 {
                if let signature = reader.readInt32() {
                    _38 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _39: Api.TextWithEntities?
            if Int(_2!) & Int(1 << 22) != 0 {
                if let signature = reader.readInt32() {
                    _39 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 21) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 22) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
            let _c12 = _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 11) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 14) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 15) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 16) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 17) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 18) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 24) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 25) == 0) || _20 != nil
            let _c21 = (Int(_2!) & Int(1 << 0) == 0) || _21 != nil
            let _c22 = (Int(_2!) & Int(1 << 1) == 0) || _22 != nil
            let _c23 = (Int(_2!) & Int(1 << 2) == 0) || _23 != nil
            let _c24 = (Int(_2!) & Int(1 << 3) == 0) || _24 != nil
            let _c25 = (Int(_2!) & Int(1 << 4) == 0) || _25 != nil
            let _c26 = (Int(_2!) & Int(1 << 5) == 0) || _26 != nil
            let _c27 = (Int(_2!) & Int(1 << 6) == 0) || _27 != nil
            let _c28 = (Int(_2!) & Int(1 << 6) == 0) || _28 != nil
            let _c29 = (Int(_2!) & Int(1 << 8) == 0) || _29 != nil
            let _c30 = (Int(_2!) & Int(1 << 11) == 0) || _30 != nil
            let _c31 = (Int(_2!) & Int(1 << 12) == 0) || _31 != nil
            let _c32 = (Int(_2!) & Int(1 << 14) == 0) || _32 != nil
            let _c33 = (Int(_2!) & Int(1 << 15) == 0) || _33 != nil
            let _c34 = (Int(_2!) & Int(1 << 17) == 0) || _34 != nil
            let _c35 = (Int(_2!) & Int(1 << 18) == 0) || _35 != nil
            let _c36 = (Int(_2!) & Int(1 << 18) == 0) || _36 != nil
            let _c37 = (Int(_2!) & Int(1 << 20) == 0) || _37 != nil
            let _c38 = (Int(_2!) & Int(1 << 21) == 0) || _38 != nil
            let _c39 = (Int(_2!) & Int(1 << 22) == 0) || _39 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 {
                return Api.UserFull.userFull(Cons_userFull(flags: _1!, flags2: _2!, id: _3!, about: _4, settings: _5!, personalPhoto: _6, profilePhoto: _7, fallbackPhoto: _8, notifySettings: _9!, botInfo: _10, pinnedMsgId: _11, commonChatsCount: _12!, folderId: _13, ttlPeriod: _14, theme: _15, privateForwardName: _16, botGroupAdminRights: _17, botBroadcastAdminRights: _18, wallpaper: _19, stories: _20, businessWorkHours: _21, businessLocation: _22, businessGreetingMessage: _23, businessAwayMessage: _24, businessIntro: _25, birthday: _26, personalChannelId: _27, personalChannelMessage: _28, stargiftsCount: _29, starrefProgram: _30, botVerification: _31, sendPaidMessagesStars: _32, disallowedGifts: _33, starsRating: _34, starsMyPendingRating: _35, starsMyPendingRatingDate: _36, mainTab: _37, savedMusic: _38, note: _39))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum UserProfilePhoto: TypeConstructorDescription {
        public class Cons_userProfilePhoto {
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
        case userProfilePhoto(Cons_userProfilePhoto)
        case userProfilePhotoEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userProfilePhoto(let _data):
                if boxed {
                    buffer.appendInt32(-2100168954)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeBytes(_data.strippedThumb!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                break
            case .userProfilePhotoEmpty:
                if boxed {
                    buffer.appendInt32(1326562017)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .userProfilePhoto(let _data):
                return ("userProfilePhoto", [("flags", _data.flags as Any), ("photoId", _data.photoId as Any), ("strippedThumb", _data.strippedThumb as Any), ("dcId", _data.dcId as Any)])
            case .userProfilePhotoEmpty:
                return ("userProfilePhotoEmpty", [])
            }
        }

        public static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
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
                return Api.UserProfilePhoto.userProfilePhoto(Cons_userProfilePhoto(flags: _1!, photoId: _2!, strippedThumb: _3, dcId: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            return Api.UserProfilePhoto.userProfilePhotoEmpty
        }
    }
}
public extension Api {
    enum UserStatus: TypeConstructorDescription {
        public class Cons_userStatusLastMonth {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_userStatusLastWeek {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_userStatusOffline {
            public var wasOnline: Int32
            public init(wasOnline: Int32) {
                self.wasOnline = wasOnline
            }
        }
        public class Cons_userStatusOnline {
            public var expires: Int32
            public init(expires: Int32) {
                self.expires = expires
            }
        }
        public class Cons_userStatusRecently {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case userStatusEmpty
        case userStatusLastMonth(Cons_userStatusLastMonth)
        case userStatusLastWeek(Cons_userStatusLastWeek)
        case userStatusOffline(Cons_userStatusOffline)
        case userStatusOnline(Cons_userStatusOnline)
        case userStatusRecently(Cons_userStatusRecently)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userStatusEmpty:
                if boxed {
                    buffer.appendInt32(164646985)
                }
                break
            case .userStatusLastMonth(let _data):
                if boxed {
                    buffer.appendInt32(1703516023)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .userStatusLastWeek(let _data):
                if boxed {
                    buffer.appendInt32(1410997530)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .userStatusOffline(let _data):
                if boxed {
                    buffer.appendInt32(9203775)
                }
                serializeInt32(_data.wasOnline, buffer: buffer, boxed: false)
                break
            case .userStatusOnline(let _data):
                if boxed {
                    buffer.appendInt32(-306628279)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            case .userStatusRecently(let _data):
                if boxed {
                    buffer.appendInt32(2065268168)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .userStatusEmpty:
                return ("userStatusEmpty", [])
            case .userStatusLastMonth(let _data):
                return ("userStatusLastMonth", [("flags", _data.flags as Any)])
            case .userStatusLastWeek(let _data):
                return ("userStatusLastWeek", [("flags", _data.flags as Any)])
            case .userStatusOffline(let _data):
                return ("userStatusOffline", [("wasOnline", _data.wasOnline as Any)])
            case .userStatusOnline(let _data):
                return ("userStatusOnline", [("expires", _data.expires as Any)])
            case .userStatusRecently(let _data):
                return ("userStatusRecently", [("flags", _data.flags as Any)])
            }
        }

        public static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusEmpty
        }
        public static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusLastMonth(Cons_userStatusLastMonth(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusLastWeek(Cons_userStatusLastWeek(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOffline(Cons_userStatusOffline(wasOnline: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOnline(Cons_userStatusOnline(expires: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusRecently(Cons_userStatusRecently(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Username: TypeConstructorDescription {
        public class Cons_username {
            public var flags: Int32
            public var username: String
            public init(flags: Int32, username: String) {
                self.flags = flags
                self.username = username
            }
        }
        case username(Cons_username)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .username(let _data):
                if boxed {
                    buffer.appendInt32(-1274595769)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.username, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .username(let _data):
                return ("username", [("flags", _data.flags as Any), ("username", _data.username as Any)])
            }
        }

        public static func parse_username(_ reader: BufferReader) -> Username? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Username.username(Cons_username(flags: _1!, username: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum VideoSize: TypeConstructorDescription {
        public class Cons_videoSize {
            public var flags: Int32
            public var type: String
            public var w: Int32
            public var h: Int32
            public var size: Int32
            public var videoStartTs: Double?
            public init(flags: Int32, type: String, w: Int32, h: Int32, size: Int32, videoStartTs: Double?) {
                self.flags = flags
                self.type = type
                self.w = w
                self.h = h
                self.size = size
                self.videoStartTs = videoStartTs
            }
        }
        public class Cons_videoSizeEmojiMarkup {
            public var emojiId: Int64
            public var backgroundColors: [Int32]
            public init(emojiId: Int64, backgroundColors: [Int32]) {
                self.emojiId = emojiId
                self.backgroundColors = backgroundColors
            }
        }
        public class Cons_videoSizeStickerMarkup {
            public var stickerset: Api.InputStickerSet
            public var stickerId: Int64
            public var backgroundColors: [Int32]
            public init(stickerset: Api.InputStickerSet, stickerId: Int64, backgroundColors: [Int32]) {
                self.stickerset = stickerset
                self.stickerId = stickerId
                self.backgroundColors = backgroundColors
            }
        }
        case videoSize(Cons_videoSize)
        case videoSizeEmojiMarkup(Cons_videoSizeEmojiMarkup)
        case videoSizeStickerMarkup(Cons_videoSizeStickerMarkup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .videoSize(let _data):
                if boxed {
                    buffer.appendInt32(-567037804)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeDouble(_data.videoStartTs!, buffer: buffer, boxed: false)
                }
                break
            case .videoSizeEmojiMarkup(let _data):
                if boxed {
                    buffer.appendInt32(-128171716)
                }
                serializeInt64(_data.emojiId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.backgroundColors.count))
                for item in _data.backgroundColors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .videoSizeStickerMarkup(let _data):
                if boxed {
                    buffer.appendInt32(228623102)
                }
                _data.stickerset.serialize(buffer, true)
                serializeInt64(_data.stickerId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.backgroundColors.count))
                for item in _data.backgroundColors {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .videoSize(let _data):
                return ("videoSize", [("flags", _data.flags as Any), ("type", _data.type as Any), ("w", _data.w as Any), ("h", _data.h as Any), ("size", _data.size as Any), ("videoStartTs", _data.videoStartTs as Any)])
            case .videoSizeEmojiMarkup(let _data):
                return ("videoSizeEmojiMarkup", [("emojiId", _data.emojiId as Any), ("backgroundColors", _data.backgroundColors as Any)])
            case .videoSizeStickerMarkup(let _data):
                return ("videoSizeStickerMarkup", [("stickerset", _data.stickerset as Any), ("stickerId", _data.stickerId as Any), ("backgroundColors", _data.backgroundColors as Any)])
            }
        }

        public static func parse_videoSize(_ reader: BufferReader) -> VideoSize? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Double?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readDouble()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.VideoSize.videoSize(Cons_videoSize(flags: _1!, type: _2!, w: _3!, h: _4!, size: _5!, videoStartTs: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_videoSizeEmojiMarkup(_ reader: BufferReader) -> VideoSize? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.VideoSize.videoSizeEmojiMarkup(Cons_videoSizeEmojiMarkup(emojiId: _1!, backgroundColors: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_videoSizeStickerMarkup(_ reader: BufferReader) -> VideoSize? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.VideoSize.videoSizeStickerMarkup(Cons_videoSizeStickerMarkup(stickerset: _1!, stickerId: _2!, backgroundColors: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WallPaper: TypeConstructorDescription {
        public class Cons_wallPaper {
            public var id: Int64
            public var flags: Int32
            public var accessHash: Int64
            public var slug: String
            public var document: Api.Document
            public var settings: Api.WallPaperSettings?
            public init(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?) {
                self.id = id
                self.flags = flags
                self.accessHash = accessHash
                self.slug = slug
                self.document = document
                self.settings = settings
            }
        }
        public class Cons_wallPaperNoFile {
            public var id: Int64
            public var flags: Int32
            public var settings: Api.WallPaperSettings?
            public init(id: Int64, flags: Int32, settings: Api.WallPaperSettings?) {
                self.id = id
                self.flags = flags
                self.settings = settings
            }
        }
        case wallPaper(Cons_wallPaper)
        case wallPaperNoFile(Cons_wallPaperNoFile)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .wallPaper(let _data):
                if boxed {
                    buffer.appendInt32(-1539849235)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                _data.document.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.settings!.serialize(buffer, true)
                }
                break
            case .wallPaperNoFile(let _data):
                if boxed {
                    buffer.appendInt32(-528465642)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.settings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .wallPaper(let _data):
                return ("wallPaper", [("id", _data.id as Any), ("flags", _data.flags as Any), ("accessHash", _data.accessHash as Any), ("slug", _data.slug as Any), ("document", _data.document as Any), ("settings", _data.settings as Any)])
            case .wallPaperNoFile(let _data):
                return ("wallPaperNoFile", [("id", _data.id as Any), ("flags", _data.flags as Any), ("settings", _data.settings as Any)])
            }
        }

        public static func parse_wallPaper(_ reader: BufferReader) -> WallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.Document?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _6: Api.WallPaperSettings?
            if Int(_2!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_2!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.WallPaper.wallPaper(Cons_wallPaper(id: _1!, flags: _2!, accessHash: _3!, slug: _4!, document: _5!, settings: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_wallPaperNoFile(_ reader: BufferReader) -> WallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.WallPaperSettings?
            if Int(_2!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_2!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WallPaper.wallPaperNoFile(Cons_wallPaperNoFile(id: _1!, flags: _2!, settings: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WallPaperSettings: TypeConstructorDescription {
        public class Cons_wallPaperSettings {
            public var flags: Int32
            public var backgroundColor: Int32?
            public var secondBackgroundColor: Int32?
            public var thirdBackgroundColor: Int32?
            public var fourthBackgroundColor: Int32?
            public var intensity: Int32?
            public var rotation: Int32?
            public var emoticon: String?
            public init(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, thirdBackgroundColor: Int32?, fourthBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?, emoticon: String?) {
                self.flags = flags
                self.backgroundColor = backgroundColor
                self.secondBackgroundColor = secondBackgroundColor
                self.thirdBackgroundColor = thirdBackgroundColor
                self.fourthBackgroundColor = fourthBackgroundColor
                self.intensity = intensity
                self.rotation = rotation
                self.emoticon = emoticon
            }
        }
        case wallPaperSettings(Cons_wallPaperSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .wallPaperSettings(let _data):
                if boxed {
                    buffer.appendInt32(925826256)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.backgroundColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.secondBackgroundColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.thirdBackgroundColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.fourthBackgroundColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.intensity!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.rotation!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeString(_data.emoticon!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .wallPaperSettings(let _data):
                return ("wallPaperSettings", [("flags", _data.flags as Any), ("backgroundColor", _data.backgroundColor as Any), ("secondBackgroundColor", _data.secondBackgroundColor as Any), ("thirdBackgroundColor", _data.thirdBackgroundColor as Any), ("fourthBackgroundColor", _data.fourthBackgroundColor as Any), ("intensity", _data.intensity as Any), ("rotation", _data.rotation as Any), ("emoticon", _data.emoticon as Any)])
            }
        }

        public static func parse_wallPaperSettings(_ reader: BufferReader) -> WallPaperSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = reader.readInt32()
            }
            var _8: String?
            if Int(_1!) & Int(1 << 7) != 0 {
                _8 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 5) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 6) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.WallPaperSettings.wallPaperSettings(Cons_wallPaperSettings(flags: _1!, backgroundColor: _2, secondBackgroundColor: _3, thirdBackgroundColor: _4, fourthBackgroundColor: _5, intensity: _6, rotation: _7, emoticon: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription {
        public class Cons_webAuthorization {
            public var hash: Int64
            public var botId: Int64
            public var domain: String
            public var browser: String
            public var platform: String
            public var dateCreated: Int32
            public var dateActive: Int32
            public var ip: String
            public var region: String
            public init(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String) {
                self.hash = hash
                self.botId = botId
                self.domain = domain
                self.browser = browser
                self.platform = platform
                self.dateCreated = dateCreated
                self.dateActive = dateActive
                self.ip = ip
                self.region = region
            }
        }
        case webAuthorization(Cons_webAuthorization)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webAuthorization(let _data):
                if boxed {
                    buffer.appendInt32(-1493633966)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                serializeString(_data.browser, buffer: buffer, boxed: false)
                serializeString(_data.platform, buffer: buffer, boxed: false)
                serializeInt32(_data.dateCreated, buffer: buffer, boxed: false)
                serializeInt32(_data.dateActive, buffer: buffer, boxed: false)
                serializeString(_data.ip, buffer: buffer, boxed: false)
                serializeString(_data.region, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .webAuthorization(let _data):
                return ("webAuthorization", [("hash", _data.hash as Any), ("botId", _data.botId as Any), ("domain", _data.domain as Any), ("browser", _data.browser as Any), ("platform", _data.platform as Any), ("dateCreated", _data.dateCreated as Any), ("dateActive", _data.dateActive as Any), ("ip", _data.ip as Any), ("region", _data.region as Any)])
            }
        }

        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
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
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.WebAuthorization.webAuthorization(Cons_webAuthorization(hash: _1!, botId: _2!, domain: _3!, browser: _4!, platform: _5!, dateCreated: _6!, dateActive: _7!, ip: _8!, region: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription {
        public class Cons_webDocument {
            public var url: String
            public var accessHash: Int64
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.accessHash = accessHash
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
        }
        public class Cons_webDocumentNoProxy {
            public var url: String
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
        }
        case webDocument(Cons_webDocument)
        case webDocumentNoProxy(Cons_webDocumentNoProxy)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webDocument(let _data):
                if boxed {
                    buffer.appendInt32(475467473)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            case .webDocumentNoProxy(let _data):
                if boxed {
                    buffer.appendInt32(-104284986)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .webDocument(let _data):
                return ("webDocument", [("url", _data.url as Any), ("accessHash", _data.accessHash as Any), ("size", _data.size as Any), ("mimeType", _data.mimeType as Any), ("attributes", _data.attributes as Any)])
            case .webDocumentNoProxy(let _data):
                return ("webDocumentNoProxy", [("url", _data.url as Any), ("size", _data.size as Any), ("mimeType", _data.mimeType as Any), ("attributes", _data.attributes as Any)])
            }
        }

        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WebDocument.webDocument(Cons_webDocument(url: _1!, accessHash: _2!, size: _3!, mimeType: _4!, attributes: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebDocument.webDocumentNoProxy(Cons_webDocumentNoProxy(url: _1!, size: _2!, mimeType: _3!, attributes: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription {
        public class Cons_webPage {
            public var flags: Int32
            public var id: Int64
            public var url: String
            public var displayUrl: String
            public var hash: Int32
            public var type: String?
            public var siteName: String?
            public var title: String?
            public var description: String?
            public var photo: Api.Photo?
            public var embedUrl: String?
            public var embedType: String?
            public var embedWidth: Int32?
            public var embedHeight: Int32?
            public var duration: Int32?
            public var author: String?
            public var document: Api.Document?
            public var cachedPage: Api.Page?
            public var attributes: [Api.WebPageAttribute]?
            public init(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?) {
                self.flags = flags
                self.id = id
                self.url = url
                self.displayUrl = displayUrl
                self.hash = hash
                self.type = type
                self.siteName = siteName
                self.title = title
                self.description = description
                self.photo = photo
                self.embedUrl = embedUrl
                self.embedType = embedType
                self.embedWidth = embedWidth
                self.embedHeight = embedHeight
                self.duration = duration
                self.author = author
                self.document = document
                self.cachedPage = cachedPage
                self.attributes = attributes
            }
        }
        public class Cons_webPageEmpty {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public init(flags: Int32, id: Int64, url: String?) {
                self.flags = flags
                self.id = id
                self.url = url
            }
        }
        public class Cons_webPageNotModified {
            public var flags: Int32
            public var cachedPageViews: Int32?
            public init(flags: Int32, cachedPageViews: Int32?) {
                self.flags = flags
                self.cachedPageViews = cachedPageViews
            }
        }
        public class Cons_webPagePending {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public var date: Int32
            public init(flags: Int32, id: Int64, url: String?, date: Int32) {
                self.flags = flags
                self.id = id
                self.url = url
                self.date = date
            }
        }
        case webPage(Cons_webPage)
        case webPageEmpty(Cons_webPageEmpty)
        case webPageNotModified(Cons_webPageNotModified)
        case webPagePending(Cons_webPagePending)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPage(let _data):
                if boxed {
                    buffer.appendInt32(-392411726)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.displayUrl, buffer: buffer, boxed: false)
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.type!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.siteName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.embedUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.embedType!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.embedWidth!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.embedHeight!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.author!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.cachedPage!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.attributes!.count))
                    for item in _data.attributes! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .webPageEmpty(let _data):
                if boxed {
                    buffer.appendInt32(555358088)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                break
            case .webPageNotModified(let _data):
                if boxed {
                    buffer.appendInt32(1930545681)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.cachedPageViews!, buffer: buffer, boxed: false)
                }
                break
            case .webPagePending(let _data):
                if boxed {
                    buffer.appendInt32(-1328464313)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .webPage(let _data):
                return ("webPage", [("flags", _data.flags as Any), ("id", _data.id as Any), ("url", _data.url as Any), ("displayUrl", _data.displayUrl as Any), ("hash", _data.hash as Any), ("type", _data.type as Any), ("siteName", _data.siteName as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("embedUrl", _data.embedUrl as Any), ("embedType", _data.embedType as Any), ("embedWidth", _data.embedWidth as Any), ("embedHeight", _data.embedHeight as Any), ("duration", _data.duration as Any), ("author", _data.author as Any), ("document", _data.document as Any), ("cachedPage", _data.cachedPage as Any), ("attributes", _data.attributes as Any)])
            case .webPageEmpty(let _data):
                return ("webPageEmpty", [("flags", _data.flags as Any), ("id", _data.id as Any), ("url", _data.url as Any)])
            case .webPageNotModified(let _data):
                return ("webPageNotModified", [("flags", _data.flags as Any), ("cachedPageViews", _data.cachedPageViews as Any)])
            case .webPagePending(let _data):
                return ("webPagePending", [("flags", _data.flags as Any), ("id", _data.id as Any), ("url", _data.url as Any), ("date", _data.date as Any)])
            }
        }

        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _8 = parseString(reader)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _9 = parseString(reader)
            }
            var _10: Api.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _11: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _11 = parseString(reader)
            }
            var _12: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _13 = reader.readInt32()
            }
            var _14: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _14 = reader.readInt32()
            }
            var _15: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _15 = reader.readInt32()
            }
            var _16: String?
            if Int(_1!) & Int(1 << 8) != 0 {
                _16 = parseString(reader)
            }
            var _17: Api.Document?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _18: Api.Page?
            if Int(_1!) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _18 = Api.parse(reader, signature: signature) as? Api.Page
                }
            }
            var _19: [Api.WebPageAttribute]?
            if Int(_1!) & Int(1 << 12) != 0 {
                if let _ = reader.readInt32() {
                    _19 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebPageAttribute.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 5) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 6) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 7) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 10) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 12) == 0) || _19 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 {
                return Api.WebPage.webPage(Cons_webPage(flags: _1!, id: _2!, url: _3!, displayUrl: _4!, hash: _5!, type: _6, siteName: _7, title: _8, description: _9, photo: _10, embedUrl: _11, embedType: _12, embedWidth: _13, embedHeight: _14, duration: _15, author: _16, document: _17, cachedPage: _18, attributes: _19))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPage.webPageEmpty(Cons_webPageEmpty(flags: _1!, id: _2!, url: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebPage.webPageNotModified(Cons_webPageNotModified(flags: _1!, cachedPageViews: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebPage.webPagePending(Cons_webPagePending(flags: _1!, id: _2!, url: _3, date: _4!))
            }
            else {
                return nil
            }
        }
    }
}
