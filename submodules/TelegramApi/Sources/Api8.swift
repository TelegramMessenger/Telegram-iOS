public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription {
        public class Cons_groupCallParticipant {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var activeDate: Int32?
            public var source: Int32
            public var volume: Int32?
            public var about: String?
            public var raiseHandRating: Int64?
            public var video: Api.GroupCallParticipantVideo?
            public var presentation: Api.GroupCallParticipantVideo?
            public var paidStarsTotal: Int64?
            public init(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?, paidStarsTotal: Int64?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.activeDate = activeDate
                self.source = source
                self.volume = volume
                self.about = about
                self.raiseHandRating = raiseHandRating
                self.video = video
                self.presentation = presentation
                self.paidStarsTotal = paidStarsTotal
            }
        }
        case groupCallParticipant(Cons_groupCallParticipant)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipant(let _data):
                if boxed {
                    buffer.appendInt32(708691884)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.activeDate!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.source, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.volume!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeString(_data.about!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt64(_data.raiseHandRating!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.presentation!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt64(_data.paidStarsTotal!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallParticipant(let _data):
                return ("groupCallParticipant", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("date", _data.date as Any), ("activeDate", _data.activeDate as Any), ("source", _data.source as Any), ("volume", _data.volume as Any), ("about", _data.about as Any), ("raiseHandRating", _data.raiseHandRating as Any), ("video", _data.video as Any), ("presentation", _data.presentation as Any), ("paidStarsTotal", _data.paidStarsTotal as Any)])
            }
        }

        public static func parse_groupCallParticipant(_ reader: BufferReader) -> GroupCallParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _6 = reader.readInt32()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 11) != 0 {
                _7 = parseString(reader)
            }
            var _8: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
                }
            }
            var _10: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
                }
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 16) != 0 {
                _11 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 7) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 13) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 16) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.GroupCallParticipant.groupCallParticipant(Cons_groupCallParticipant(flags: _1!, peer: _2!, date: _3!, activeDate: _4, source: _5!, volume: _6, about: _7, raiseHandRating: _8, video: _9, presentation: _10, paidStarsTotal: _11))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideo {
            public var flags: Int32
            public var endpoint: String
            public var sourceGroups: [Api.GroupCallParticipantVideoSourceGroup]
            public var audioSource: Int32?
            public init(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?) {
                self.flags = flags
                self.endpoint = endpoint
                self.sourceGroups = sourceGroups
                self.audioSource = audioSource
            }
        }
        case groupCallParticipantVideo(Cons_groupCallParticipantVideo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipantVideo(let _data):
                if boxed {
                    buffer.appendInt32(1735736008)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.endpoint, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sourceGroups.count))
                for item in _data.sourceGroups {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.audioSource!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallParticipantVideo(let _data):
                return ("groupCallParticipantVideo", [("flags", _data.flags as Any), ("endpoint", _data.endpoint as Any), ("sourceGroups", _data.sourceGroups as Any), ("audioSource", _data.audioSource as Any)])
            }
        }

        public static func parse_groupCallParticipantVideo(_ reader: BufferReader) -> GroupCallParticipantVideo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.GroupCallParticipantVideoSourceGroup]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipantVideoSourceGroup.self)
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.GroupCallParticipantVideo.groupCallParticipantVideo(Cons_groupCallParticipantVideo(flags: _1!, endpoint: _2!, sourceGroups: _3!, audioSource: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideoSourceGroup {
            public var semantics: String
            public var sources: [Int32]
            public init(semantics: String, sources: [Int32]) {
                self.semantics = semantics
                self.sources = sources
            }
        }
        case groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipantVideoSourceGroup(let _data):
                if boxed {
                    buffer.appendInt32(-592373577)
                }
                serializeString(_data.semantics, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sources.count))
                for item in _data.sources {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallParticipantVideoSourceGroup(let _data):
                return ("groupCallParticipantVideoSourceGroup", [("semantics", _data.semantics as Any), ("sources", _data.sources as Any)])
            }
        }

        public static func parse_groupCallParticipantVideoSourceGroup(_ reader: BufferReader) -> GroupCallParticipantVideoSourceGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.GroupCallParticipantVideoSourceGroup.groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup(semantics: _1!, sources: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        public class Cons_groupCallStreamChannel {
            public var channel: Int32
            public var scale: Int32
            public var lastTimestampMs: Int64
            public init(channel: Int32, scale: Int32, lastTimestampMs: Int64) {
                self.channel = channel
                self.scale = scale
                self.lastTimestampMs = lastTimestampMs
            }
        }
        case groupCallStreamChannel(Cons_groupCallStreamChannel)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallStreamChannel(let _data):
                if boxed {
                    buffer.appendInt32(-2132064081)
                }
                serializeInt32(_data.channel, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                serializeInt64(_data.lastTimestampMs, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallStreamChannel(let _data):
                return ("groupCallStreamChannel", [("channel", _data.channel as Any), ("scale", _data.scale as Any), ("lastTimestampMs", _data.lastTimestampMs as Any)])
            }
        }

        public static func parse_groupCallStreamChannel(_ reader: BufferReader) -> GroupCallStreamChannel? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCallStreamChannel.groupCallStreamChannel(Cons_groupCallStreamChannel(channel: _1!, scale: _2!, lastTimestampMs: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        public class Cons_highScore {
            public var pos: Int32
            public var userId: Int64
            public var score: Int32
            public init(pos: Int32, userId: Int64, score: Int32) {
                self.pos = pos
                self.userId = userId
                self.score = score
            }
        }
        case highScore(Cons_highScore)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .highScore(let _data):
                if boxed {
                    buffer.appendInt32(1940093419)
                }
                serializeInt32(_data.pos, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.score, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .highScore(let _data):
                return ("highScore", [("pos", _data.pos as Any), ("userId", _data.userId as Any), ("score", _data.score as Any)])
            }
        }

        public static func parse_highScore(_ reader: BufferReader) -> HighScore? {
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
                return Api.HighScore.highScore(Cons_highScore(pos: _1!, userId: _2!, score: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        public class Cons_importedContact {
            public var userId: Int64
            public var clientId: Int64
            public init(userId: Int64, clientId: Int64) {
                self.userId = userId
                self.clientId = clientId
            }
        }
        case importedContact(Cons_importedContact)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .importedContact(let _data):
                if boxed {
                    buffer.appendInt32(-1052885936)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.clientId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .importedContact(let _data):
                return ("importedContact", [("userId", _data.userId as Any), ("clientId", _data.clientId as Any)])
            }
        }

        public static func parse_importedContact(_ reader: BufferReader) -> ImportedContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ImportedContact.importedContact(Cons_importedContact(userId: _1!, clientId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
        public class Cons_inlineBotSwitchPM {
            public var text: String
            public var startParam: String
            public init(text: String, startParam: String) {
                self.text = text
                self.startParam = startParam
            }
        }
        case inlineBotSwitchPM(Cons_inlineBotSwitchPM)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineBotSwitchPM(let _data):
                if boxed {
                    buffer.appendInt32(1008755359)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.startParam, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inlineBotSwitchPM(let _data):
                return ("inlineBotSwitchPM", [("text", _data.text as Any), ("startParam", _data.startParam as Any)])
            }
        }

        public static func parse_inlineBotSwitchPM(_ reader: BufferReader) -> InlineBotSwitchPM? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotSwitchPM.inlineBotSwitchPM(Cons_inlineBotSwitchPM(text: _1!, startParam: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription {
        public class Cons_inlineBotWebView {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        case inlineBotWebView(Cons_inlineBotWebView)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineBotWebView(let _data):
                if boxed {
                    buffer.appendInt32(-1250781739)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inlineBotWebView(let _data):
                return ("inlineBotWebView", [("text", _data.text as Any), ("url", _data.url as Any)])
            }
        }

        public static func parse_inlineBotWebView(_ reader: BufferReader) -> InlineBotWebView? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotWebView.inlineBotWebView(Cons_inlineBotWebView(text: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription {
        case inlineQueryPeerTypeBotPM
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineQueryPeerTypeBotPM:
                if boxed {
                    buffer.appendInt32(238759180)
                }
                break
            case .inlineQueryPeerTypeBroadcast:
                if boxed {
                    buffer.appendInt32(1664413338)
                }
                break
            case .inlineQueryPeerTypeChat:
                if boxed {
                    buffer.appendInt32(-681130742)
                }
                break
            case .inlineQueryPeerTypeMegagroup:
                if boxed {
                    buffer.appendInt32(1589952067)
                }
                break
            case .inlineQueryPeerTypePM:
                if boxed {
                    buffer.appendInt32(-2093215828)
                }
                break
            case .inlineQueryPeerTypeSameBotPM:
                if boxed {
                    buffer.appendInt32(813821341)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inlineQueryPeerTypeBotPM:
                return ("inlineQueryPeerTypeBotPM", [])
            case .inlineQueryPeerTypeBroadcast:
                return ("inlineQueryPeerTypeBroadcast", [])
            case .inlineQueryPeerTypeChat:
                return ("inlineQueryPeerTypeChat", [])
            case .inlineQueryPeerTypeMegagroup:
                return ("inlineQueryPeerTypeMegagroup", [])
            case .inlineQueryPeerTypePM:
                return ("inlineQueryPeerTypePM", [])
            case .inlineQueryPeerTypeSameBotPM:
                return ("inlineQueryPeerTypeSameBotPM", [])
            }
        }

        public static func parse_inlineQueryPeerTypeBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBotPM
        }
        public static func parse_inlineQueryPeerTypeBroadcast(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBroadcast
        }
        public static func parse_inlineQueryPeerTypeChat(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeChat
        }
        public static func parse_inlineQueryPeerTypeMegagroup(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeMegagroup
        }
        public static func parse_inlineQueryPeerTypePM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypePM
        }
        public static func parse_inlineQueryPeerTypeSameBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeSameBotPM
        }
    }
}
public extension Api {
    enum InputAppEvent: TypeConstructorDescription {
        public class Cons_inputAppEvent {
            public var time: Double
            public var type: String
            public var peer: Int64
            public var data: Api.JSONValue
            public init(time: Double, type: String, peer: Int64, data: Api.JSONValue) {
                self.time = time
                self.type = type
                self.peer = peer
                self.data = data
            }
        }
        case inputAppEvent(Cons_inputAppEvent)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputAppEvent(let _data):
                if boxed {
                    buffer.appendInt32(488313413)
                }
                serializeDouble(_data.time, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                serializeInt64(_data.peer, buffer: buffer, boxed: false)
                _data.data.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputAppEvent(let _data):
                return ("inputAppEvent", [("time", _data.time as Any), ("type", _data.type as Any), ("peer", _data.peer as Any), ("data", _data.data as Any)])
            }
        }

        public static func parse_inputAppEvent(_ reader: BufferReader) -> InputAppEvent? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.JSONValue?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputAppEvent.inputAppEvent(Cons_inputAppEvent(time: _1!, type: _2!, peer: _3!, data: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputBotApp: TypeConstructorDescription {
        public class Cons_inputBotAppID {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputBotAppShortName {
            public var botId: Api.InputUser
            public var shortName: String
            public init(botId: Api.InputUser, shortName: String) {
                self.botId = botId
                self.shortName = shortName
            }
        }
        case inputBotAppID(Cons_inputBotAppID)
        case inputBotAppShortName(Cons_inputBotAppShortName)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBotAppID(let _data):
                if boxed {
                    buffer.appendInt32(-1457472134)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputBotAppShortName(let _data):
                if boxed {
                    buffer.appendInt32(-1869872121)
                }
                _data.botId.serialize(buffer, true)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBotAppID(let _data):
                return ("inputBotAppID", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputBotAppShortName(let _data):
                return ("inputBotAppShortName", [("botId", _data.botId as Any), ("shortName", _data.shortName as Any)])
            }
        }

        public static func parse_inputBotAppID(_ reader: BufferReader) -> InputBotApp? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppID(Cons_inputBotAppID(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotAppShortName(_ reader: BufferReader) -> InputBotApp? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppShortName(Cons_inputBotAppShortName(botId: _1!, shortName: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBotInlineMessage: TypeConstructorDescription {
        public class Cons_inputBotInlineMessageGame {
            public var flags: Int32
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaAuto {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaContact {
            public var flags: Int32
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaGeo {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.InputWebDocument?
            public var invoice: Api.Invoice
            public var payload: Buffer
            public var provider: String
            public var providerData: Api.DataJSON
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.payload = payload
                self.provider = provider
                self.providerData = providerData
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaVenue {
            public var flags: Int32
            public var geoPoint: Api.InputGeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageMediaWebPage {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var url: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.url = url
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_inputBotInlineMessageText {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        case inputBotInlineMessageGame(Cons_inputBotInlineMessageGame)
        case inputBotInlineMessageMediaAuto(Cons_inputBotInlineMessageMediaAuto)
        case inputBotInlineMessageMediaContact(Cons_inputBotInlineMessageMediaContact)
        case inputBotInlineMessageMediaGeo(Cons_inputBotInlineMessageMediaGeo)
        case inputBotInlineMessageMediaInvoice(Cons_inputBotInlineMessageMediaInvoice)
        case inputBotInlineMessageMediaVenue(Cons_inputBotInlineMessageMediaVenue)
        case inputBotInlineMessageMediaWebPage(Cons_inputBotInlineMessageMediaWebPage)
        case inputBotInlineMessageText(Cons_inputBotInlineMessageText)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBotInlineMessageGame(let _data):
                if boxed {
                    buffer.appendInt32(1262639204)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaAuto(let _data):
                if boxed {
                    buffer.appendInt32(864077702)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaContact(let _data):
                if boxed {
                    buffer.appendInt32(-1494368259)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                serializeString(_data.vcard, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaGeo(let _data):
                if boxed {
                    buffer.appendInt32(-1768777083)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geoPoint.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.heading!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.period!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.proximityNotificationRadius!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaInvoice(let _data):
                if boxed {
                    buffer.appendInt32(-672693723)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                _data.invoice.serialize(buffer, true)
                serializeBytes(_data.payload, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                _data.providerData.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaVenue(let _data):
                if boxed {
                    buffer.appendInt32(1098628881)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geoPoint.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageMediaWebPage(let _data):
                if boxed {
                    buffer.appendInt32(-1109605104)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .inputBotInlineMessageText(let _data):
                if boxed {
                    buffer.appendInt32(1036876423)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBotInlineMessageGame(let _data):
                return ("inputBotInlineMessageGame", [("flags", _data.flags as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaAuto(let _data):
                return ("inputBotInlineMessageMediaAuto", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaContact(let _data):
                return ("inputBotInlineMessageMediaContact", [("flags", _data.flags as Any), ("phoneNumber", _data.phoneNumber as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("vcard", _data.vcard as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaGeo(let _data):
                return ("inputBotInlineMessageMediaGeo", [("flags", _data.flags as Any), ("geoPoint", _data.geoPoint as Any), ("heading", _data.heading as Any), ("period", _data.period as Any), ("proximityNotificationRadius", _data.proximityNotificationRadius as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaInvoice(let _data):
                return ("inputBotInlineMessageMediaInvoice", [("flags", _data.flags as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("invoice", _data.invoice as Any), ("payload", _data.payload as Any), ("provider", _data.provider as Any), ("providerData", _data.providerData as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaVenue(let _data):
                return ("inputBotInlineMessageMediaVenue", [("flags", _data.flags as Any), ("geoPoint", _data.geoPoint as Any), ("title", _data.title as Any), ("address", _data.address as Any), ("provider", _data.provider as Any), ("venueId", _data.venueId as Any), ("venueType", _data.venueType as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageMediaWebPage(let _data):
                return ("inputBotInlineMessageMediaWebPage", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("url", _data.url as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .inputBotInlineMessageText(let _data):
                return ("inputBotInlineMessageText", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("replyMarkup", _data.replyMarkup as Any)])
            }
        }

        public static func parse_inputBotInlineMessageGame(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.InputBotInlineMessage.inputBotInlineMessageGame(Cons_inputBotInlineMessageGame(flags: _1!, replyMarkup: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaAuto(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaAuto(Cons_inputBotInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaContact(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaContact(Cons_inputBotInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaGeo(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
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
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaGeo(Cons_inputBotInlineMessageMediaGeo(flags: _1!, geoPoint: _2!, heading: _3, period: _4, proximityNotificationRadius: _5, replyMarkup: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaInvoice(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
                }
            }
            var _5: Api.Invoice?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.DataJSON?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _9: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaInvoice(Cons_inputBotInlineMessageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7!, providerData: _8!, replyMarkup: _9))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaVenue(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaVenue(Cons_inputBotInlineMessageMediaVenue(flags: _1!, geoPoint: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaWebPage(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaWebPage(Cons_inputBotInlineMessageMediaWebPage(flags: _1!, message: _2!, entities: _3, url: _4!, replyMarkup: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageText(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageText(Cons_inputBotInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBotInlineMessageID: TypeConstructorDescription {
        public class Cons_inputBotInlineMessageID {
            public var dcId: Int32
            public var id: Int64
            public var accessHash: Int64
            public init(dcId: Int32, id: Int64, accessHash: Int64) {
                self.dcId = dcId
                self.id = id
                self.accessHash = accessHash
            }
        }
        public class Cons_inputBotInlineMessageID64 {
            public var dcId: Int32
            public var ownerId: Int64
            public var id: Int32
            public var accessHash: Int64
            public init(dcId: Int32, ownerId: Int64, id: Int32, accessHash: Int64) {
                self.dcId = dcId
                self.ownerId = ownerId
                self.id = id
                self.accessHash = accessHash
            }
        }
        case inputBotInlineMessageID(Cons_inputBotInlineMessageID)
        case inputBotInlineMessageID64(Cons_inputBotInlineMessageID64)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBotInlineMessageID(let _data):
                if boxed {
                    buffer.appendInt32(-1995686519)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputBotInlineMessageID64(let _data):
                if boxed {
                    buffer.appendInt32(-1227287081)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt64(_data.ownerId, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBotInlineMessageID(let _data):
                return ("inputBotInlineMessageID", [("dcId", _data.dcId as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            case .inputBotInlineMessageID64(let _data):
                return ("inputBotInlineMessageID64", [("dcId", _data.dcId as Any), ("ownerId", _data.ownerId as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any)])
            }
        }

        public static func parse_inputBotInlineMessageID(_ reader: BufferReader) -> InputBotInlineMessageID? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineMessageID.inputBotInlineMessageID(Cons_inputBotInlineMessageID(dcId: _1!, id: _2!, accessHash: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageID64(_ reader: BufferReader) -> InputBotInlineMessageID? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessageID.inputBotInlineMessageID64(Cons_inputBotInlineMessageID64(dcId: _1!, ownerId: _2!, id: _3!, accessHash: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBotInlineResult: TypeConstructorDescription {
        public class Cons_inputBotInlineResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var url: String?
            public var thumb: Api.InputWebDocument?
            public var content: Api.InputWebDocument?
            public var sendMessage: Api.InputBotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.InputWebDocument?, content: Api.InputWebDocument?, sendMessage: Api.InputBotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.title = title
                self.description = description
                self.url = url
                self.thumb = thumb
                self.content = content
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultDocument {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var document: Api.InputDocument
            public var sendMessage: Api.InputBotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, document: Api.InputDocument, sendMessage: Api.InputBotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.title = title
                self.description = description
                self.document = document
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultGame {
            public var id: String
            public var shortName: String
            public var sendMessage: Api.InputBotInlineMessage
            public init(id: String, shortName: String, sendMessage: Api.InputBotInlineMessage) {
                self.id = id
                self.shortName = shortName
                self.sendMessage = sendMessage
            }
        }
        public class Cons_inputBotInlineResultPhoto {
            public var id: String
            public var type: String
            public var photo: Api.InputPhoto
            public var sendMessage: Api.InputBotInlineMessage
            public init(id: String, type: String, photo: Api.InputPhoto, sendMessage: Api.InputBotInlineMessage) {
                self.id = id
                self.type = type
                self.photo = photo
                self.sendMessage = sendMessage
            }
        }
        case inputBotInlineResult(Cons_inputBotInlineResult)
        case inputBotInlineResultDocument(Cons_inputBotInlineResultDocument)
        case inputBotInlineResultGame(Cons_inputBotInlineResultGame)
        case inputBotInlineResultPhoto(Cons_inputBotInlineResultPhoto)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBotInlineResult(let _data):
                if boxed {
                    buffer.appendInt32(-2000710887)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.thumb!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.content!.serialize(buffer, true)
                }
                _data.sendMessage.serialize(buffer, true)
                break
            case .inputBotInlineResultDocument(let _data):
                if boxed {
                    buffer.appendInt32(-459324)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                _data.document.serialize(buffer, true)
                _data.sendMessage.serialize(buffer, true)
                break
            case .inputBotInlineResultGame(let _data):
                if boxed {
                    buffer.appendInt32(1336154098)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                _data.sendMessage.serialize(buffer, true)
                break
            case .inputBotInlineResultPhoto(let _data):
                if boxed {
                    buffer.appendInt32(-1462213465)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                _data.photo.serialize(buffer, true)
                _data.sendMessage.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBotInlineResult(let _data):
                return ("inputBotInlineResult", [("flags", _data.flags as Any), ("id", _data.id as Any), ("type", _data.type as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("url", _data.url as Any), ("thumb", _data.thumb as Any), ("content", _data.content as Any), ("sendMessage", _data.sendMessage as Any)])
            case .inputBotInlineResultDocument(let _data):
                return ("inputBotInlineResultDocument", [("flags", _data.flags as Any), ("id", _data.id as Any), ("type", _data.type as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("document", _data.document as Any), ("sendMessage", _data.sendMessage as Any)])
            case .inputBotInlineResultGame(let _data):
                return ("inputBotInlineResultGame", [("id", _data.id as Any), ("shortName", _data.shortName as Any), ("sendMessage", _data.sendMessage as Any)])
            case .inputBotInlineResultPhoto(let _data):
                return ("inputBotInlineResultPhoto", [("id", _data.id as Any), ("type", _data.type as Any), ("photo", _data.photo as Any), ("sendMessage", _data.sendMessage as Any)])
            }
        }

        public static func parse_inputBotInlineResult(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
                }
            }
            var _8: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
                }
            }
            var _9: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineResult.inputBotInlineResult(Cons_inputBotInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultDocument(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: Api.InputDocument?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _7: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputBotInlineResult.inputBotInlineResultDocument(Cons_inputBotInlineResultDocument(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, document: _6!, sendMessage: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultGame(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineResult.inputBotInlineResultGame(Cons_inputBotInlineResultGame(id: _1!, shortName: _2!, sendMessage: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultPhoto(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _4: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineResult.inputBotInlineResultPhoto(Cons_inputBotInlineResultPhoto(id: _1!, type: _2!, photo: _3!, sendMessage: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputBusinessAwayMessage: TypeConstructorDescription {
        public class Cons_inputBusinessAwayMessage {
            public var flags: Int32
            public var shortcutId: Int32
            public var schedule: Api.BusinessAwayMessageSchedule
            public var recipients: Api.InputBusinessRecipients
            public init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.InputBusinessRecipients) {
                self.flags = flags
                self.shortcutId = shortcutId
                self.schedule = schedule
                self.recipients = recipients
            }
        }
        case inputBusinessAwayMessage(Cons_inputBusinessAwayMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputBusinessAwayMessage(let _data):
                if boxed {
                    buffer.appendInt32(-2094959136)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                _data.schedule.serialize(buffer, true)
                _data.recipients.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputBusinessAwayMessage(let _data):
                return ("inputBusinessAwayMessage", [("flags", _data.flags as Any), ("shortcutId", _data.shortcutId as Any), ("schedule", _data.schedule as Any), ("recipients", _data.recipients as Any)])
            }
        }

        public static func parse_inputBusinessAwayMessage(_ reader: BufferReader) -> InputBusinessAwayMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.BusinessAwayMessageSchedule?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.BusinessAwayMessageSchedule
            }
            var _4: Api.InputBusinessRecipients?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBusinessRecipients
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBusinessAwayMessage.inputBusinessAwayMessage(Cons_inputBusinessAwayMessage(flags: _1!, shortcutId: _2!, schedule: _3!, recipients: _4!))
            }
            else {
                return nil
            }
        }
    }
}
