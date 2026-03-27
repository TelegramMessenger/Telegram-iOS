public extension Api.messages {
    enum AffectedHistory: TypeConstructorDescription {
        public class Cons_affectedHistory: TypeConstructorDescription {
            public var pts: Int32
            public var ptsCount: Int32
            public var offset: Int32
            public init(pts: Int32, ptsCount: Int32, offset: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
                self.offset = offset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("affectedHistory", [("pts", ConstructorParameterDescription(self.pts)), ("ptsCount", ConstructorParameterDescription(self.ptsCount)), ("offset", ConstructorParameterDescription(self.offset))])
            }
        }
        case affectedHistory(Cons_affectedHistory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .affectedHistory(let _data):
                if boxed {
                    buffer.appendInt32(-1269012015)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .affectedHistory(let _data):
                return ("affectedHistory", [("pts", ConstructorParameterDescription(_data.pts)), ("ptsCount", ConstructorParameterDescription(_data.ptsCount)), ("offset", ConstructorParameterDescription(_data.offset))])
            }
        }

        public static func parse_affectedHistory(_ reader: BufferReader) -> AffectedHistory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.AffectedHistory.affectedHistory(Cons_affectedHistory(pts: _1!, ptsCount: _2!, offset: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum AffectedMessages: TypeConstructorDescription {
        public class Cons_affectedMessages: TypeConstructorDescription {
            public var pts: Int32
            public var ptsCount: Int32
            public init(pts: Int32, ptsCount: Int32) {
                self.pts = pts
                self.ptsCount = ptsCount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("affectedMessages", [("pts", ConstructorParameterDescription(self.pts)), ("ptsCount", ConstructorParameterDescription(self.ptsCount))])
            }
        }
        case affectedMessages(Cons_affectedMessages)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .affectedMessages(let _data):
                if boxed {
                    buffer.appendInt32(-2066640507)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.ptsCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .affectedMessages(let _data):
                return ("affectedMessages", [("pts", ConstructorParameterDescription(_data.pts)), ("ptsCount", ConstructorParameterDescription(_data.ptsCount))])
            }
        }

        public static func parse_affectedMessages(_ reader: BufferReader) -> AffectedMessages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AffectedMessages.affectedMessages(Cons_affectedMessages(pts: _1!, ptsCount: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum AllStickers: TypeConstructorDescription {
        public class Cons_allStickers: TypeConstructorDescription {
            public var hash: Int64
            public var sets: [Api.StickerSet]
            public init(hash: Int64, sets: [Api.StickerSet]) {
                self.hash = hash
                self.sets = sets
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("allStickers", [("hash", ConstructorParameterDescription(self.hash)), ("sets", ConstructorParameterDescription(self.sets))])
            }
        }
        case allStickers(Cons_allStickers)
        case allStickersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .allStickers(let _data):
                if boxed {
                    buffer.appendInt32(-843329861)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                break
            case .allStickersNotModified:
                if boxed {
                    buffer.appendInt32(-395967805)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .allStickers(let _data):
                return ("allStickers", [("hash", ConstructorParameterDescription(_data.hash)), ("sets", ConstructorParameterDescription(_data.sets))])
            case .allStickersNotModified:
                return ("allStickersNotModified", [])
            }
        }

        public static func parse_allStickers(_ reader: BufferReader) -> AllStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerSet]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSet.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AllStickers.allStickers(Cons_allStickers(hash: _1!, sets: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_allStickersNotModified(_ reader: BufferReader) -> AllStickers? {
            return Api.messages.AllStickers.allStickersNotModified
        }
    }
}
public extension Api.messages {
    enum ArchivedStickers: TypeConstructorDescription {
        public class Cons_archivedStickers: TypeConstructorDescription {
            public var count: Int32
            public var sets: [Api.StickerSetCovered]
            public init(count: Int32, sets: [Api.StickerSetCovered]) {
                self.count = count
                self.sets = sets
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("archivedStickers", [("count", ConstructorParameterDescription(self.count)), ("sets", ConstructorParameterDescription(self.sets))])
            }
        }
        case archivedStickers(Cons_archivedStickers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .archivedStickers(let _data):
                if boxed {
                    buffer.appendInt32(1338747336)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .archivedStickers(let _data):
                return ("archivedStickers", [("count", ConstructorParameterDescription(_data.count)), ("sets", ConstructorParameterDescription(_data.sets))])
            }
        }

        public static func parse_archivedStickers(_ reader: BufferReader) -> ArchivedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ArchivedStickers.archivedStickers(Cons_archivedStickers(count: _1!, sets: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum AvailableEffects: TypeConstructorDescription {
        public class Cons_availableEffects: TypeConstructorDescription {
            public var hash: Int32
            public var effects: [Api.AvailableEffect]
            public var documents: [Api.Document]
            public init(hash: Int32, effects: [Api.AvailableEffect], documents: [Api.Document]) {
                self.hash = hash
                self.effects = effects
                self.documents = documents
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("availableEffects", [("hash", ConstructorParameterDescription(self.hash)), ("effects", ConstructorParameterDescription(self.effects)), ("documents", ConstructorParameterDescription(self.documents))])
            }
        }
        case availableEffects(Cons_availableEffects)
        case availableEffectsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .availableEffects(let _data):
                if boxed {
                    buffer.appendInt32(-1109696146)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.effects.count))
                for item in _data.effects {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    item.serialize(buffer, true)
                }
                break
            case .availableEffectsNotModified:
                if boxed {
                    buffer.appendInt32(-772957605)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .availableEffects(let _data):
                return ("availableEffects", [("hash", ConstructorParameterDescription(_data.hash)), ("effects", ConstructorParameterDescription(_data.effects)), ("documents", ConstructorParameterDescription(_data.documents))])
            case .availableEffectsNotModified:
                return ("availableEffectsNotModified", [])
            }
        }

        public static func parse_availableEffects(_ reader: BufferReader) -> AvailableEffects? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.AvailableEffect]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AvailableEffect.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.AvailableEffects.availableEffects(Cons_availableEffects(hash: _1!, effects: _2!, documents: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_availableEffectsNotModified(_ reader: BufferReader) -> AvailableEffects? {
            return Api.messages.AvailableEffects.availableEffectsNotModified
        }
    }
}
public extension Api.messages {
    enum AvailableReactions: TypeConstructorDescription {
        public class Cons_availableReactions: TypeConstructorDescription {
            public var hash: Int32
            public var reactions: [Api.AvailableReaction]
            public init(hash: Int32, reactions: [Api.AvailableReaction]) {
                self.hash = hash
                self.reactions = reactions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("availableReactions", [("hash", ConstructorParameterDescription(self.hash)), ("reactions", ConstructorParameterDescription(self.reactions))])
            }
        }
        case availableReactions(Cons_availableReactions)
        case availableReactionsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .availableReactions(let _data):
                if boxed {
                    buffer.appendInt32(1989032621)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                break
            case .availableReactionsNotModified:
                if boxed {
                    buffer.appendInt32(-1626924713)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .availableReactions(let _data):
                return ("availableReactions", [("hash", ConstructorParameterDescription(_data.hash)), ("reactions", ConstructorParameterDescription(_data.reactions))])
            case .availableReactionsNotModified:
                return ("availableReactionsNotModified", [])
            }
        }

        public static func parse_availableReactions(_ reader: BufferReader) -> AvailableReactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.AvailableReaction]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AvailableReaction.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.AvailableReactions.availableReactions(Cons_availableReactions(hash: _1!, reactions: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_availableReactionsNotModified(_ reader: BufferReader) -> AvailableReactions? {
            return Api.messages.AvailableReactions.availableReactionsNotModified
        }
    }
}
public extension Api.messages {
    enum BotApp: TypeConstructorDescription {
        public class Cons_botApp: TypeConstructorDescription {
            public var flags: Int32
            public var app: Api.BotApp
            public init(flags: Int32, app: Api.BotApp) {
                self.flags = flags
                self.app = app
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("botApp", [("flags", ConstructorParameterDescription(self.flags)), ("app", ConstructorParameterDescription(self.app))])
            }
        }
        case botApp(Cons_botApp)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botApp(let _data):
                if boxed {
                    buffer.appendInt32(-347034123)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.app.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .botApp(let _data):
                return ("botApp", [("flags", ConstructorParameterDescription(_data.flags)), ("app", ConstructorParameterDescription(_data.app))])
            }
        }

        public static func parse_botApp(_ reader: BufferReader) -> BotApp? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BotApp?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotApp
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.BotApp.botApp(Cons_botApp(flags: _1!, app: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum BotCallbackAnswer: TypeConstructorDescription {
        public class Cons_botCallbackAnswer: TypeConstructorDescription {
            public var flags: Int32
            public var message: String?
            public var url: String?
            public var cacheTime: Int32
            public init(flags: Int32, message: String?, url: String?, cacheTime: Int32) {
                self.flags = flags
                self.message = message
                self.url = url
                self.cacheTime = cacheTime
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("botCallbackAnswer", [("flags", ConstructorParameterDescription(self.flags)), ("message", ConstructorParameterDescription(self.message)), ("url", ConstructorParameterDescription(self.url)), ("cacheTime", ConstructorParameterDescription(self.cacheTime))])
            }
        }
        case botCallbackAnswer(Cons_botCallbackAnswer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botCallbackAnswer(let _data):
                if boxed {
                    buffer.appendInt32(911761060)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.message!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.cacheTime, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .botCallbackAnswer(let _data):
                return ("botCallbackAnswer", [("flags", ConstructorParameterDescription(_data.flags)), ("message", ConstructorParameterDescription(_data.message)), ("url", ConstructorParameterDescription(_data.url)), ("cacheTime", ConstructorParameterDescription(_data.cacheTime))])
            }
        }

        public static func parse_botCallbackAnswer(_ reader: BufferReader) -> BotCallbackAnswer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.BotCallbackAnswer.botCallbackAnswer(Cons_botCallbackAnswer(flags: _1!, message: _2, url: _3, cacheTime: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum BotPreparedInlineMessage: TypeConstructorDescription {
        public class Cons_botPreparedInlineMessage: TypeConstructorDescription {
            public var id: String
            public var expireDate: Int32
            public init(id: String, expireDate: Int32) {
                self.id = id
                self.expireDate = expireDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("botPreparedInlineMessage", [("id", ConstructorParameterDescription(self.id)), ("expireDate", ConstructorParameterDescription(self.expireDate))])
            }
        }
        case botPreparedInlineMessage(Cons_botPreparedInlineMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botPreparedInlineMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1899035375)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.expireDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .botPreparedInlineMessage(let _data):
                return ("botPreparedInlineMessage", [("id", ConstructorParameterDescription(_data.id)), ("expireDate", ConstructorParameterDescription(_data.expireDate))])
            }
        }

        public static func parse_botPreparedInlineMessage(_ reader: BufferReader) -> BotPreparedInlineMessage? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.BotPreparedInlineMessage.botPreparedInlineMessage(Cons_botPreparedInlineMessage(id: _1!, expireDate: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum BotResults: TypeConstructorDescription {
        public class Cons_botResults: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64
            public var nextOffset: String?
            public var switchPm: Api.InlineBotSwitchPM?
            public var switchWebview: Api.InlineBotWebView?
            public var results: [Api.BotInlineResult]
            public var cacheTime: Int32
            public var users: [Api.User]
            public init(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User]) {
                self.flags = flags
                self.queryId = queryId
                self.nextOffset = nextOffset
                self.switchPm = switchPm
                self.switchWebview = switchWebview
                self.results = results
                self.cacheTime = cacheTime
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("botResults", [("flags", ConstructorParameterDescription(self.flags)), ("queryId", ConstructorParameterDescription(self.queryId)), ("nextOffset", ConstructorParameterDescription(self.nextOffset)), ("switchPm", ConstructorParameterDescription(self.switchPm)), ("switchWebview", ConstructorParameterDescription(self.switchWebview)), ("results", ConstructorParameterDescription(self.results)), ("cacheTime", ConstructorParameterDescription(self.cacheTime)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case botResults(Cons_botResults)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botResults(let _data):
                if boxed {
                    buffer.appendInt32(-534646026)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.switchPm!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.switchWebview!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.results.count))
                for item in _data.results {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.cacheTime, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .botResults(let _data):
                return ("botResults", [("flags", ConstructorParameterDescription(_data.flags)), ("queryId", ConstructorParameterDescription(_data.queryId)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset)), ("switchPm", ConstructorParameterDescription(_data.switchPm)), ("switchWebview", ConstructorParameterDescription(_data.switchWebview)), ("results", ConstructorParameterDescription(_data.results)), ("cacheTime", ConstructorParameterDescription(_data.cacheTime)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_botResults(_ reader: BufferReader) -> BotResults? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: Api.InlineBotSwitchPM?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InlineBotSwitchPM
                }
            }
            var _5: Api.InlineBotWebView?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InlineBotWebView
                }
            }
            var _6: [Api.BotInlineResult]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInlineResult.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.messages.BotResults.botResults(Cons_botResults(flags: _1!, queryId: _2!, nextOffset: _3, switchPm: _4, switchWebview: _5, results: _6!, cacheTime: _7!, users: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ChatAdminsWithInvites: TypeConstructorDescription {
        public class Cons_chatAdminsWithInvites: TypeConstructorDescription {
            public var admins: [Api.ChatAdminWithInvites]
            public var users: [Api.User]
            public init(admins: [Api.ChatAdminWithInvites], users: [Api.User]) {
                self.admins = admins
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatAdminsWithInvites", [("admins", ConstructorParameterDescription(self.admins)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case chatAdminsWithInvites(Cons_chatAdminsWithInvites)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatAdminsWithInvites(let _data):
                if boxed {
                    buffer.appendInt32(-1231326505)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.admins.count))
                for item in _data.admins {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatAdminsWithInvites(let _data):
                return ("chatAdminsWithInvites", [("admins", ConstructorParameterDescription(_data.admins)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_chatAdminsWithInvites(_ reader: BufferReader) -> ChatAdminsWithInvites? {
            var _1: [Api.ChatAdminWithInvites]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatAdminWithInvites.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ChatAdminsWithInvites.chatAdminsWithInvites(Cons_chatAdminsWithInvites(admins: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ChatFull: TypeConstructorDescription {
        public class Cons_chatFull: TypeConstructorDescription {
            public var fullChat: Api.ChatFull
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(fullChat: Api.ChatFull, chats: [Api.Chat], users: [Api.User]) {
                self.fullChat = fullChat
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatFull", [("fullChat", ConstructorParameterDescription(self.fullChat)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case chatFull(Cons_chatFull)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatFull(let _data):
                if boxed {
                    buffer.appendInt32(-438840932)
                }
                _data.fullChat.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatFull(let _data):
                return ("chatFull", [("fullChat", ConstructorParameterDescription(_data.fullChat)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Api.ChatFull?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatFull
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ChatFull.chatFull(Cons_chatFull(fullChat: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ChatInviteImporters: TypeConstructorDescription {
        public class Cons_chatInviteImporters: TypeConstructorDescription {
            public var count: Int32
            public var importers: [Api.ChatInviteImporter]
            public var users: [Api.User]
            public init(count: Int32, importers: [Api.ChatInviteImporter], users: [Api.User]) {
                self.count = count
                self.importers = importers
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatInviteImporters", [("count", ConstructorParameterDescription(self.count)), ("importers", ConstructorParameterDescription(self.importers)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case chatInviteImporters(Cons_chatInviteImporters)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatInviteImporters(let _data):
                if boxed {
                    buffer.appendInt32(-2118733814)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.importers.count))
                for item in _data.importers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatInviteImporters(let _data):
                return ("chatInviteImporters", [("count", ConstructorParameterDescription(_data.count)), ("importers", ConstructorParameterDescription(_data.importers)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_chatInviteImporters(_ reader: BufferReader) -> ChatInviteImporters? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ChatInviteImporter]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatInviteImporter.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ChatInviteImporters.chatInviteImporters(Cons_chatInviteImporters(count: _1!, importers: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum Chats: TypeConstructorDescription {
        public class Cons_chats: TypeConstructorDescription {
            public var chats: [Api.Chat]
            public init(chats: [Api.Chat]) {
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chats", [("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        public class Cons_chatsSlice: TypeConstructorDescription {
            public var count: Int32
            public var chats: [Api.Chat]
            public init(count: Int32, chats: [Api.Chat]) {
                self.count = count
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatsSlice", [("count", ConstructorParameterDescription(self.count)), ("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        case chats(Cons_chats)
        case chatsSlice(Cons_chatsSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chats(let _data):
                if boxed {
                    buffer.appendInt32(1694474197)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                break
            case .chatsSlice(let _data):
                if boxed {
                    buffer.appendInt32(-1663561404)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chats(let _data):
                return ("chats", [("chats", ConstructorParameterDescription(_data.chats))])
            case .chatsSlice(let _data):
                return ("chatsSlice", [("count", ConstructorParameterDescription(_data.count)), ("chats", ConstructorParameterDescription(_data.chats))])
            }
        }

        public static func parse_chats(_ reader: BufferReader) -> Chats? {
            var _1: [Api.Chat]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Chats.chats(Cons_chats(chats: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatsSlice(_ reader: BufferReader) -> Chats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Chats.chatsSlice(Cons_chatsSlice(count: _1!, chats: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum CheckedHistoryImportPeer: TypeConstructorDescription {
        public class Cons_checkedHistoryImportPeer: TypeConstructorDescription {
            public var confirmText: String
            public init(confirmText: String) {
                self.confirmText = confirmText
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("checkedHistoryImportPeer", [("confirmText", ConstructorParameterDescription(self.confirmText))])
            }
        }
        case checkedHistoryImportPeer(Cons_checkedHistoryImportPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .checkedHistoryImportPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1571952873)
                }
                serializeString(_data.confirmText, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .checkedHistoryImportPeer(let _data):
                return ("checkedHistoryImportPeer", [("confirmText", ConstructorParameterDescription(_data.confirmText))])
            }
        }

        public static func parse_checkedHistoryImportPeer(_ reader: BufferReader) -> CheckedHistoryImportPeer? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.CheckedHistoryImportPeer.checkedHistoryImportPeer(Cons_checkedHistoryImportPeer(confirmText: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum ComposedMessageWithAI: TypeConstructorDescription {
        public class Cons_composedMessageWithAI: TypeConstructorDescription {
            public var flags: Int32
            public var resultText: Api.TextWithEntities
            public var diffText: Api.TextWithEntities?
            public init(flags: Int32, resultText: Api.TextWithEntities, diffText: Api.TextWithEntities?) {
                self.flags = flags
                self.resultText = resultText
                self.diffText = diffText
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("composedMessageWithAI", [("flags", ConstructorParameterDescription(self.flags)), ("resultText", ConstructorParameterDescription(self.resultText)), ("diffText", ConstructorParameterDescription(self.diffText))])
            }
        }
        case composedMessageWithAI(Cons_composedMessageWithAI)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .composedMessageWithAI(let _data):
                if boxed {
                    buffer.appendInt32(-1864913414)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.resultText.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.diffText!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .composedMessageWithAI(let _data):
                return ("composedMessageWithAI", [("flags", ConstructorParameterDescription(_data.flags)), ("resultText", ConstructorParameterDescription(_data.resultText)), ("diffText", ConstructorParameterDescription(_data.diffText))])
            }
        }

        public static func parse_composedMessageWithAI(_ reader: BufferReader) -> ComposedMessageWithAI? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _3: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ComposedMessageWithAI.composedMessageWithAI(Cons_composedMessageWithAI(flags: _1!, resultText: _2!, diffText: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum DhConfig: TypeConstructorDescription {
        public class Cons_dhConfig: TypeConstructorDescription {
            public var g: Int32
            public var p: Buffer
            public var version: Int32
            public var random: Buffer
            public init(g: Int32, p: Buffer, version: Int32, random: Buffer) {
                self.g = g
                self.p = p
                self.version = version
                self.random = random
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dhConfig", [("g", ConstructorParameterDescription(self.g)), ("p", ConstructorParameterDescription(self.p)), ("version", ConstructorParameterDescription(self.version)), ("random", ConstructorParameterDescription(self.random))])
            }
        }
        public class Cons_dhConfigNotModified: TypeConstructorDescription {
            public var random: Buffer
            public init(random: Buffer) {
                self.random = random
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dhConfigNotModified", [("random", ConstructorParameterDescription(self.random))])
            }
        }
        case dhConfig(Cons_dhConfig)
        case dhConfigNotModified(Cons_dhConfigNotModified)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dhConfig(let _data):
                if boxed {
                    buffer.appendInt32(740433629)
                }
                serializeInt32(_data.g, buffer: buffer, boxed: false)
                serializeBytes(_data.p, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                serializeBytes(_data.random, buffer: buffer, boxed: false)
                break
            case .dhConfigNotModified(let _data):
                if boxed {
                    buffer.appendInt32(-1058912715)
                }
                serializeBytes(_data.random, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .dhConfig(let _data):
                return ("dhConfig", [("g", ConstructorParameterDescription(_data.g)), ("p", ConstructorParameterDescription(_data.p)), ("version", ConstructorParameterDescription(_data.version)), ("random", ConstructorParameterDescription(_data.random))])
            case .dhConfigNotModified(let _data):
                return ("dhConfigNotModified", [("random", ConstructorParameterDescription(_data.random))])
            }
        }

        public static func parse_dhConfig(_ reader: BufferReader) -> DhConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.DhConfig.dhConfig(Cons_dhConfig(g: _1!, p: _2!, version: _3!, random: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_dhConfigNotModified(_ reader: BufferReader) -> DhConfig? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.DhConfig.dhConfigNotModified(Cons_dhConfigNotModified(random: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum DialogFilters: TypeConstructorDescription {
        public class Cons_dialogFilters: TypeConstructorDescription {
            public var flags: Int32
            public var filters: [Api.DialogFilter]
            public init(flags: Int32, filters: [Api.DialogFilter]) {
                self.flags = flags
                self.filters = filters
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dialogFilters", [("flags", ConstructorParameterDescription(self.flags)), ("filters", ConstructorParameterDescription(self.filters))])
            }
        }
        case dialogFilters(Cons_dialogFilters)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialogFilters(let _data):
                if boxed {
                    buffer.appendInt32(718878489)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.filters.count))
                for item in _data.filters {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .dialogFilters(let _data):
                return ("dialogFilters", [("flags", ConstructorParameterDescription(_data.flags)), ("filters", ConstructorParameterDescription(_data.filters))])
            }
        }

        public static func parse_dialogFilters(_ reader: BufferReader) -> DialogFilters? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.DialogFilter]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogFilter.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.DialogFilters.dialogFilters(Cons_dialogFilters(flags: _1!, filters: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum Dialogs: TypeConstructorDescription {
        public class Cons_dialogs: TypeConstructorDescription {
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dialogs", [("dialogs", ConstructorParameterDescription(self.dialogs)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_dialogsNotModified: TypeConstructorDescription {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dialogsNotModified", [("count", ConstructorParameterDescription(self.count))])
            }
        }
        public class Cons_dialogsSlice: TypeConstructorDescription {
            public var count: Int32
            public var dialogs: [Api.Dialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("dialogsSlice", [("count", ConstructorParameterDescription(self.count)), ("dialogs", ConstructorParameterDescription(self.dialogs)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case dialogs(Cons_dialogs)
        case dialogsNotModified(Cons_dialogsNotModified)
        case dialogsSlice(Cons_dialogsSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .dialogs(let _data):
                if boxed {
                    buffer.appendInt32(364538944)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dialogs.count))
                for item in _data.dialogs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .dialogsNotModified(let _data):
                if boxed {
                    buffer.appendInt32(-253500010)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            case .dialogsSlice(let _data):
                if boxed {
                    buffer.appendInt32(1910543603)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dialogs.count))
                for item in _data.dialogs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .dialogs(let _data):
                return ("dialogs", [("dialogs", ConstructorParameterDescription(_data.dialogs)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .dialogsNotModified(let _data):
                return ("dialogsNotModified", [("count", ConstructorParameterDescription(_data.count))])
            case .dialogsSlice(let _data):
                return ("dialogsSlice", [("count", ConstructorParameterDescription(_data.count)), ("dialogs", ConstructorParameterDescription(_data.dialogs)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_dialogs(_ reader: BufferReader) -> Dialogs? {
            var _1: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.Dialogs.dialogs(Cons_dialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogsNotModified(_ reader: BufferReader) -> Dialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Dialogs.dialogsNotModified(Cons_dialogsNotModified(count: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_dialogsSlice(_ reader: BufferReader) -> Dialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Dialog]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Dialog.self)
            }
            var _3: [Api.Message]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.Dialogs.dialogsSlice(Cons_dialogsSlice(count: _1!, dialogs: _2!, messages: _3!, chats: _4!, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum DiscussionMessage: TypeConstructorDescription {
        public class Cons_discussionMessage: TypeConstructorDescription {
            public var flags: Int32
            public var messages: [Api.Message]
            public var maxId: Int32?
            public var readInboxMaxId: Int32?
            public var readOutboxMaxId: Int32?
            public var unreadCount: Int32
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, messages: [Api.Message], maxId: Int32?, readInboxMaxId: Int32?, readOutboxMaxId: Int32?, unreadCount: Int32, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.messages = messages
                self.maxId = maxId
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("discussionMessage", [("flags", ConstructorParameterDescription(self.flags)), ("messages", ConstructorParameterDescription(self.messages)), ("maxId", ConstructorParameterDescription(self.maxId)), ("readInboxMaxId", ConstructorParameterDescription(self.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(self.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(self.unreadCount)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case discussionMessage(Cons_discussionMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .discussionMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1506535550)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.maxId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.readInboxMaxId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.readOutboxMaxId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .discussionMessage(let _data):
                return ("discussionMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("messages", ConstructorParameterDescription(_data.messages)), ("maxId", ConstructorParameterDescription(_data.maxId)), ("readInboxMaxId", ConstructorParameterDescription(_data.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(_data.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(_data.unreadCount)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_discussionMessage(_ reader: BufferReader) -> DiscussionMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.messages.DiscussionMessage.discussionMessage(Cons_discussionMessage(flags: _1!, messages: _2!, maxId: _3, readInboxMaxId: _4, readOutboxMaxId: _5, unreadCount: _6!, chats: _7!, users: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum EmojiGameInfo: TypeConstructorDescription {
        public class Cons_emojiGameDiceInfo: TypeConstructorDescription {
            public var flags: Int32
            public var gameHash: String
            public var prevStake: Int64
            public var currentStreak: Int32
            public var params: [Int32]
            public var playsLeft: Int32?
            public init(flags: Int32, gameHash: String, prevStake: Int64, currentStreak: Int32, params: [Int32], playsLeft: Int32?) {
                self.flags = flags
                self.gameHash = gameHash
                self.prevStake = prevStake
                self.currentStreak = currentStreak
                self.params = params
                self.playsLeft = playsLeft
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGameDiceInfo", [("flags", ConstructorParameterDescription(self.flags)), ("gameHash", ConstructorParameterDescription(self.gameHash)), ("prevStake", ConstructorParameterDescription(self.prevStake)), ("currentStreak", ConstructorParameterDescription(self.currentStreak)), ("params", ConstructorParameterDescription(self.params)), ("playsLeft", ConstructorParameterDescription(self.playsLeft))])
            }
        }
        case emojiGameDiceInfo(Cons_emojiGameDiceInfo)
        case emojiGameUnavailable

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiGameDiceInfo(let _data):
                if boxed {
                    buffer.appendInt32(1155883043)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.gameHash, buffer: buffer, boxed: false)
                serializeInt64(_data.prevStake, buffer: buffer, boxed: false)
                serializeInt32(_data.currentStreak, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.params.count))
                for item in _data.params {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.playsLeft!, buffer: buffer, boxed: false)
                }
                break
            case .emojiGameUnavailable:
                if boxed {
                    buffer.appendInt32(1508266805)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiGameDiceInfo(let _data):
                return ("emojiGameDiceInfo", [("flags", ConstructorParameterDescription(_data.flags)), ("gameHash", ConstructorParameterDescription(_data.gameHash)), ("prevStake", ConstructorParameterDescription(_data.prevStake)), ("currentStreak", ConstructorParameterDescription(_data.currentStreak)), ("params", ConstructorParameterDescription(_data.params)), ("playsLeft", ConstructorParameterDescription(_data.playsLeft))])
            case .emojiGameUnavailable:
                return ("emojiGameUnavailable", [])
            }
        }

        public static func parse_emojiGameDiceInfo(_ reader: BufferReader) -> EmojiGameInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: [Int32]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.EmojiGameInfo.emojiGameDiceInfo(Cons_emojiGameDiceInfo(flags: _1!, gameHash: _2!, prevStake: _3!, currentStreak: _4!, params: _5!, playsLeft: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGameUnavailable(_ reader: BufferReader) -> EmojiGameInfo? {
            return Api.messages.EmojiGameInfo.emojiGameUnavailable
        }
    }
}
public extension Api.messages {
    enum EmojiGameOutcome: TypeConstructorDescription {
        public class Cons_emojiGameOutcome: TypeConstructorDescription {
            public var seed: Buffer
            public var stakeTonAmount: Int64
            public var tonAmount: Int64
            public init(seed: Buffer, stakeTonAmount: Int64, tonAmount: Int64) {
                self.seed = seed
                self.stakeTonAmount = stakeTonAmount
                self.tonAmount = tonAmount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGameOutcome", [("seed", ConstructorParameterDescription(self.seed)), ("stakeTonAmount", ConstructorParameterDescription(self.stakeTonAmount)), ("tonAmount", ConstructorParameterDescription(self.tonAmount))])
            }
        }
        case emojiGameOutcome(Cons_emojiGameOutcome)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiGameOutcome(let _data):
                if boxed {
                    buffer.appendInt32(-634726841)
                }
                serializeBytes(_data.seed, buffer: buffer, boxed: false)
                serializeInt64(_data.stakeTonAmount, buffer: buffer, boxed: false)
                serializeInt64(_data.tonAmount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiGameOutcome(let _data):
                return ("emojiGameOutcome", [("seed", ConstructorParameterDescription(_data.seed)), ("stakeTonAmount", ConstructorParameterDescription(_data.stakeTonAmount)), ("tonAmount", ConstructorParameterDescription(_data.tonAmount))])
            }
        }

        public static func parse_emojiGameOutcome(_ reader: BufferReader) -> EmojiGameOutcome? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.EmojiGameOutcome.emojiGameOutcome(Cons_emojiGameOutcome(seed: _1!, stakeTonAmount: _2!, tonAmount: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum EmojiGroups: TypeConstructorDescription {
        public class Cons_emojiGroups: TypeConstructorDescription {
            public var hash: Int32
            public var groups: [Api.EmojiGroup]
            public init(hash: Int32, groups: [Api.EmojiGroup]) {
                self.hash = hash
                self.groups = groups
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGroups", [("hash", ConstructorParameterDescription(self.hash)), ("groups", ConstructorParameterDescription(self.groups))])
            }
        }
        case emojiGroups(Cons_emojiGroups)
        case emojiGroupsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiGroups(let _data):
                if boxed {
                    buffer.appendInt32(-2011186869)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.groups.count))
                for item in _data.groups {
                    item.serialize(buffer, true)
                }
                break
            case .emojiGroupsNotModified:
                if boxed {
                    buffer.appendInt32(1874111879)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiGroups(let _data):
                return ("emojiGroups", [("hash", ConstructorParameterDescription(_data.hash)), ("groups", ConstructorParameterDescription(_data.groups))])
            case .emojiGroupsNotModified:
                return ("emojiGroupsNotModified", [])
            }
        }

        public static func parse_emojiGroups(_ reader: BufferReader) -> EmojiGroups? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.EmojiGroup]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiGroup.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.EmojiGroups.emojiGroups(Cons_emojiGroups(hash: _1!, groups: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGroupsNotModified(_ reader: BufferReader) -> EmojiGroups? {
            return Api.messages.EmojiGroups.emojiGroupsNotModified
        }
    }
}
