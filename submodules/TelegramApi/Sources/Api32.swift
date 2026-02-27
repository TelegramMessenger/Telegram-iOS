public extension Api.bots {
    enum BotInfo: TypeConstructorDescription {
        public class Cons_botInfo {
            public var name: String
            public var about: String
            public var description: String
            public init(name: String, about: String, description: String) {
                self.name = name
                self.about = about
                self.description = description
            }
        }
        case botInfo(Cons_botInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botInfo(let _data):
                if boxed {
                    buffer.appendInt32(-391678544)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeString(_data.about, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botInfo(let _data):
                return ("botInfo", [("name", _data.name as Any), ("about", _data.about as Any), ("description", _data.description as Any)])
            }
        }

        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.bots.BotInfo.botInfo(Cons_botInfo(name: _1!, about: _2!, description: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum PopularAppBots: TypeConstructorDescription {
        public class Cons_popularAppBots {
            public var flags: Int32
            public var nextOffset: String?
            public var users: [Api.User]
            public init(flags: Int32, nextOffset: String?, users: [Api.User]) {
                self.flags = flags
                self.nextOffset = nextOffset
                self.users = users
            }
        }
        case popularAppBots(Cons_popularAppBots)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .popularAppBots(let _data):
                if boxed {
                    buffer.appendInt32(428978491)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
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
            case .popularAppBots(let _data):
                return ("popularAppBots", [("flags", _data.flags as Any), ("nextOffset", _data.nextOffset as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_popularAppBots(_ reader: BufferReader) -> PopularAppBots? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.bots.PopularAppBots.popularAppBots(Cons_popularAppBots(flags: _1!, nextOffset: _2, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum PreviewInfo: TypeConstructorDescription {
        public class Cons_previewInfo {
            public var media: [Api.BotPreviewMedia]
            public var langCodes: [String]
            public init(media: [Api.BotPreviewMedia], langCodes: [String]) {
                self.media = media
                self.langCodes = langCodes
            }
        }
        case previewInfo(Cons_previewInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .previewInfo(let _data):
                if boxed {
                    buffer.appendInt32(212278628)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.media.count))
                for item in _data.media {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.langCodes.count))
                for item in _data.langCodes {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .previewInfo(let _data):
                return ("previewInfo", [("media", _data.media as Any), ("langCodes", _data.langCodes as Any)])
            }
        }

        public static func parse_previewInfo(_ reader: BufferReader) -> PreviewInfo? {
            var _1: [Api.BotPreviewMedia]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotPreviewMedia.self)
            }
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.bots.PreviewInfo.previewInfo(Cons_previewInfo(media: _1!, langCodes: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.channels {
    enum AdminLogResults: TypeConstructorDescription {
        public class Cons_adminLogResults {
            public var events: [Api.ChannelAdminLogEvent]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User]) {
                self.events = events
                self.chats = chats
                self.users = users
            }
        }
        case adminLogResults(Cons_adminLogResults)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .adminLogResults(let _data):
                if boxed {
                    buffer.appendInt32(-309659827)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.events.count))
                for item in _data.events {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .adminLogResults(let _data):
                return ("adminLogResults", [("events", _data.events as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_adminLogResults(_ reader: BufferReader) -> AdminLogResults? {
            var _1: [Api.ChannelAdminLogEvent]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelAdminLogEvent.self)
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
                return Api.channels.AdminLogResults.adminLogResults(Cons_adminLogResults(events: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.channels {
    enum ChannelParticipant: TypeConstructorDescription {
        public class Cons_channelParticipant {
            public var participant: Api.ChannelParticipant
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User]) {
                self.participant = participant
                self.chats = chats
                self.users = users
            }
        }
        case channelParticipant(Cons_channelParticipant)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelParticipant(let _data):
                if boxed {
                    buffer.appendInt32(-541588713)
                }
                _data.participant.serialize(buffer, true)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelParticipant(let _data):
                return ("channelParticipant", [("participant", _data.participant as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
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
                return Api.channels.ChannelParticipant.channelParticipant(Cons_channelParticipant(participant: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.channels {
    enum ChannelParticipants: TypeConstructorDescription {
        public class Cons_channelParticipants {
            public var count: Int32
            public var participants: [Api.ChannelParticipant]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.participants = participants
                self.chats = chats
                self.users = users
            }
        }
        case channelParticipants(Cons_channelParticipants)
        case channelParticipantsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelParticipants(let _data):
                if boxed {
                    buffer.appendInt32(-1699676497)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.participants.count))
                for item in _data.participants {
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
            case .channelParticipantsNotModified:
                if boxed {
                    buffer.appendInt32(-266911767)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelParticipants(let _data):
                return ("channelParticipants", [("count", _data.count as Any), ("participants", _data.participants as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .channelParticipantsNotModified:
                return ("channelParticipantsNotModified", [])
            }
        }

        public static func parse_channelParticipants(_ reader: BufferReader) -> ChannelParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ChannelParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelParticipant.self)
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
                return Api.channels.ChannelParticipants.channelParticipants(Cons_channelParticipants(count: _1!, participants: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsNotModified(_ reader: BufferReader) -> ChannelParticipants? {
            return Api.channels.ChannelParticipants.channelParticipantsNotModified
        }
    }
}
public extension Api.channels {
    enum SendAsPeers: TypeConstructorDescription {
        public class Cons_sendAsPeers {
            public var peers: [Api.SendAsPeer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.SendAsPeer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case sendAsPeers(Cons_sendAsPeers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sendAsPeers(let _data):
                if boxed {
                    buffer.appendInt32(-191450938)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sendAsPeers(let _data):
                return ("sendAsPeers", [("peers", _data.peers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_sendAsPeers(_ reader: BufferReader) -> SendAsPeers? {
            var _1: [Api.SendAsPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SendAsPeer.self)
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
                return Api.channels.SendAsPeers.sendAsPeers(Cons_sendAsPeers(peers: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.channels {
    enum SponsoredMessageReportResult: TypeConstructorDescription {
        public class Cons_sponsoredMessageReportResultChooseOption {
            public var title: String
            public var options: [Api.SponsoredMessageReportOption]
            public init(title: String, options: [Api.SponsoredMessageReportOption]) {
                self.title = title
                self.options = options
            }
        }
        case sponsoredMessageReportResultAdsHidden
        case sponsoredMessageReportResultChooseOption(Cons_sponsoredMessageReportResultChooseOption)
        case sponsoredMessageReportResultReported

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessageReportResultAdsHidden:
                if boxed {
                    buffer.appendInt32(1044107055)
                }
                break
            case .sponsoredMessageReportResultChooseOption(let _data):
                if boxed {
                    buffer.appendInt32(-2073059774)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.options.count))
                for item in _data.options {
                    item.serialize(buffer, true)
                }
                break
            case .sponsoredMessageReportResultReported:
                if boxed {
                    buffer.appendInt32(-1384544183)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sponsoredMessageReportResultAdsHidden:
                return ("sponsoredMessageReportResultAdsHidden", [])
            case .sponsoredMessageReportResultChooseOption(let _data):
                return ("sponsoredMessageReportResultChooseOption", [("title", _data.title as Any), ("options", _data.options as Any)])
            case .sponsoredMessageReportResultReported:
                return ("sponsoredMessageReportResultReported", [])
            }
        }

        public static func parse_sponsoredMessageReportResultAdsHidden(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            return Api.channels.SponsoredMessageReportResult.sponsoredMessageReportResultAdsHidden
        }
        public static func parse_sponsoredMessageReportResultChooseOption(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.SponsoredMessageReportOption]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SponsoredMessageReportOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.channels.SponsoredMessageReportResult.sponsoredMessageReportResultChooseOption(Cons_sponsoredMessageReportResultChooseOption(title: _1!, options: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_sponsoredMessageReportResultReported(_ reader: BufferReader) -> SponsoredMessageReportResult? {
            return Api.channels.SponsoredMessageReportResult.sponsoredMessageReportResultReported
        }
    }
}
public extension Api.chatlists {
    enum ChatlistInvite: TypeConstructorDescription {
        public class Cons_chatlistInvite {
            public var flags: Int32
            public var title: Api.TextWithEntities
            public var emoticon: String?
            public var peers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, title: Api.TextWithEntities, emoticon: String?, peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.title = title
                self.emoticon = emoticon
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_chatlistInviteAlready {
            public var filterId: Int32
            public var missingPeers: [Api.Peer]
            public var alreadyPeers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(filterId: Int32, missingPeers: [Api.Peer], alreadyPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.filterId = filterId
                self.missingPeers = missingPeers
                self.alreadyPeers = alreadyPeers
                self.chats = chats
                self.users = users
            }
        }
        case chatlistInvite(Cons_chatlistInvite)
        case chatlistInviteAlready(Cons_chatlistInviteAlready)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatlistInvite(let _data):
                if boxed {
                    buffer.appendInt32(-250687953)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.emoticon!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
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
            case .chatlistInviteAlready(let _data):
                if boxed {
                    buffer.appendInt32(-91752871)
                }
                serializeInt32(_data.filterId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.missingPeers.count))
                for item in _data.missingPeers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.alreadyPeers.count))
                for item in _data.alreadyPeers {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatlistInvite(let _data):
                return ("chatlistInvite", [("flags", _data.flags as Any), ("title", _data.title as Any), ("emoticon", _data.emoticon as Any), ("peers", _data.peers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .chatlistInviteAlready(let _data):
                return ("chatlistInviteAlready", [("filterId", _data.filterId as Any), ("missingPeers", _data.missingPeers as Any), ("alreadyPeers", _data.alreadyPeers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_chatlistInvite(_ reader: BufferReader) -> ChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: [Api.Peer]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.chatlists.ChatlistInvite.chatlistInvite(Cons_chatlistInvite(flags: _1!, title: _2!, emoticon: _3, peers: _4!, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatlistInviteAlready(_ reader: BufferReader) -> ChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Peer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _3: [Api.Peer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.chatlists.ChatlistInvite.chatlistInviteAlready(Cons_chatlistInviteAlready(filterId: _1!, missingPeers: _2!, alreadyPeers: _3!, chats: _4!, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.chatlists {
    enum ChatlistUpdates: TypeConstructorDescription {
        public class Cons_chatlistUpdates {
            public var missingPeers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(missingPeers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.missingPeers = missingPeers
                self.chats = chats
                self.users = users
            }
        }
        case chatlistUpdates(Cons_chatlistUpdates)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatlistUpdates(let _data):
                if boxed {
                    buffer.appendInt32(-1816295539)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.missingPeers.count))
                for item in _data.missingPeers {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatlistUpdates(let _data):
                return ("chatlistUpdates", [("missingPeers", _data.missingPeers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_chatlistUpdates(_ reader: BufferReader) -> ChatlistUpdates? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.chatlists.ChatlistUpdates.chatlistUpdates(Cons_chatlistUpdates(missingPeers: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.chatlists {
    enum ExportedChatlistInvite: TypeConstructorDescription {
        public class Cons_exportedChatlistInvite {
            public var filter: Api.DialogFilter
            public var invite: Api.ExportedChatlistInvite
            public init(filter: Api.DialogFilter, invite: Api.ExportedChatlistInvite) {
                self.filter = filter
                self.invite = invite
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedChatlistInvite(let _data):
                if boxed {
                    buffer.appendInt32(283567014)
                }
                _data.filter.serialize(buffer, true)
                _data.invite.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedChatlistInvite(let _data):
                return ("exportedChatlistInvite", [("filter", _data.filter as Any), ("invite", _data.invite as Any)])
            }
        }

        public static func parse_exportedChatlistInvite(_ reader: BufferReader) -> ExportedChatlistInvite? {
            var _1: Api.DialogFilter?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DialogFilter
            }
            var _2: Api.ExportedChatlistInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatlistInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.chatlists.ExportedChatlistInvite.exportedChatlistInvite(Cons_exportedChatlistInvite(filter: _1!, invite: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.chatlists {
    enum ExportedInvites: TypeConstructorDescription {
        public class Cons_exportedInvites {
            public var invites: [Api.ExportedChatlistInvite]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(invites: [Api.ExportedChatlistInvite], chats: [Api.Chat], users: [Api.User]) {
                self.invites = invites
                self.chats = chats
                self.users = users
            }
        }
        case exportedInvites(Cons_exportedInvites)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedInvites(let _data):
                if boxed {
                    buffer.appendInt32(279670215)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.invites.count))
                for item in _data.invites {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedInvites(let _data):
                return ("exportedInvites", [("invites", _data.invites as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_exportedInvites(_ reader: BufferReader) -> ExportedInvites? {
            var _1: [Api.ExportedChatlistInvite]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ExportedChatlistInvite.self)
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
                return Api.chatlists.ExportedInvites.exportedInvites(Cons_exportedInvites(invites: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum Blocked: TypeConstructorDescription {
        public class Cons_blocked {
            public var blocked: [Api.PeerBlocked]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
                self.blocked = blocked
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_blockedSlice {
            public var count: Int32
            public var blocked: [Api.PeerBlocked]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.blocked = blocked
                self.chats = chats
                self.users = users
            }
        }
        case blocked(Cons_blocked)
        case blockedSlice(Cons_blockedSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .blocked(let _data):
                if boxed {
                    buffer.appendInt32(182326673)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocked.count))
                for item in _data.blocked {
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
            case .blockedSlice(let _data):
                if boxed {
                    buffer.appendInt32(-513392236)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocked.count))
                for item in _data.blocked {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .blocked(let _data):
                return ("blocked", [("blocked", _data.blocked as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .blockedSlice(let _data):
                return ("blockedSlice", [("count", _data.count as Any), ("blocked", _data.blocked as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_blocked(_ reader: BufferReader) -> Blocked? {
            var _1: [Api.PeerBlocked]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerBlocked.self)
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
                return Api.contacts.Blocked.blocked(Cons_blocked(blocked: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_blockedSlice(_ reader: BufferReader) -> Blocked? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PeerBlocked]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerBlocked.self)
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
                return Api.contacts.Blocked.blockedSlice(Cons_blockedSlice(count: _1!, blocked: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum ContactBirthdays: TypeConstructorDescription {
        public class Cons_contactBirthdays {
            public var contacts: [Api.ContactBirthday]
            public var users: [Api.User]
            public init(contacts: [Api.ContactBirthday], users: [Api.User]) {
                self.contacts = contacts
                self.users = users
            }
        }
        case contactBirthdays(Cons_contactBirthdays)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contactBirthdays(let _data):
                if boxed {
                    buffer.appendInt32(290452237)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.contacts.count))
                for item in _data.contacts {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .contactBirthdays(let _data):
                return ("contactBirthdays", [("contacts", _data.contacts as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_contactBirthdays(_ reader: BufferReader) -> ContactBirthdays? {
            var _1: [Api.ContactBirthday]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ContactBirthday.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.contacts.ContactBirthdays.contactBirthdays(Cons_contactBirthdays(contacts: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum Contacts: TypeConstructorDescription {
        public class Cons_contacts {
            public var contacts: [Api.Contact]
            public var savedCount: Int32
            public var users: [Api.User]
            public init(contacts: [Api.Contact], savedCount: Int32, users: [Api.User]) {
                self.contacts = contacts
                self.savedCount = savedCount
                self.users = users
            }
        }
        case contacts(Cons_contacts)
        case contactsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contacts(let _data):
                if boxed {
                    buffer.appendInt32(-353862078)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.contacts.count))
                for item in _data.contacts {
                    item.serialize(buffer, true)
                }
                serializeInt32(_data.savedCount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .contactsNotModified:
                if boxed {
                    buffer.appendInt32(-1219778094)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .contacts(let _data):
                return ("contacts", [("contacts", _data.contacts as Any), ("savedCount", _data.savedCount as Any), ("users", _data.users as Any)])
            case .contactsNotModified:
                return ("contactsNotModified", [])
            }
        }

        public static func parse_contacts(_ reader: BufferReader) -> Contacts? {
            var _1: [Api.Contact]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Contact.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.contacts.Contacts.contacts(Cons_contacts(contacts: _1!, savedCount: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_contactsNotModified(_ reader: BufferReader) -> Contacts? {
            return Api.contacts.Contacts.contactsNotModified
        }
    }
}
public extension Api.contacts {
    enum Found: TypeConstructorDescription {
        public class Cons_found {
            public var myResults: [Api.Peer]
            public var results: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(myResults: [Api.Peer], results: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.myResults = myResults
                self.results = results
                self.chats = chats
                self.users = users
            }
        }
        case found(Cons_found)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .found(let _data):
                if boxed {
                    buffer.appendInt32(-1290580579)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.myResults.count))
                for item in _data.myResults {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.results.count))
                for item in _data.results {
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .found(let _data):
                return ("found", [("myResults", _data.myResults as Any), ("results", _data.results as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_found(_ reader: BufferReader) -> Found? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _2: [Api.Peer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.contacts.Found.found(Cons_found(myResults: _1!, results: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum ImportedContacts: TypeConstructorDescription {
        public class Cons_importedContacts {
            public var imported: [Api.ImportedContact]
            public var popularInvites: [Api.PopularContact]
            public var retryContacts: [Int64]
            public var users: [Api.User]
            public init(imported: [Api.ImportedContact], popularInvites: [Api.PopularContact], retryContacts: [Int64], users: [Api.User]) {
                self.imported = imported
                self.popularInvites = popularInvites
                self.retryContacts = retryContacts
                self.users = users
            }
        }
        case importedContacts(Cons_importedContacts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .importedContacts(let _data):
                if boxed {
                    buffer.appendInt32(2010127419)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.imported.count))
                for item in _data.imported {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.popularInvites.count))
                for item in _data.popularInvites {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.retryContacts.count))
                for item in _data.retryContacts {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
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
            case .importedContacts(let _data):
                return ("importedContacts", [("imported", _data.imported as Any), ("popularInvites", _data.popularInvites as Any), ("retryContacts", _data.retryContacts as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_importedContacts(_ reader: BufferReader) -> ImportedContacts? {
            var _1: [Api.ImportedContact]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ImportedContact.self)
            }
            var _2: [Api.PopularContact]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PopularContact.self)
            }
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
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
                return Api.contacts.ImportedContacts.importedContacts(Cons_importedContacts(imported: _1!, popularInvites: _2!, retryContacts: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum ResolvedPeer: TypeConstructorDescription {
        public class Cons_resolvedPeer {
            public var peer: Api.Peer
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peer: Api.Peer, chats: [Api.Chat], users: [Api.User]) {
                self.peer = peer
                self.chats = chats
                self.users = users
            }
        }
        case resolvedPeer(Cons_resolvedPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resolvedPeer(let _data):
                if boxed {
                    buffer.appendInt32(2131196633)
                }
                _data.peer.serialize(buffer, true)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .resolvedPeer(let _data):
                return ("resolvedPeer", [("peer", _data.peer as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_resolvedPeer(_ reader: BufferReader) -> ResolvedPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
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
                return Api.contacts.ResolvedPeer.resolvedPeer(Cons_resolvedPeer(peer: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.contacts {
    enum SponsoredPeers: TypeConstructorDescription {
        public class Cons_sponsoredPeers {
            public var peers: [Api.SponsoredPeer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.SponsoredPeer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case sponsoredPeers(Cons_sponsoredPeers)
        case sponsoredPeersEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredPeers(let _data):
                if boxed {
                    buffer.appendInt32(-352114556)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
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
            case .sponsoredPeersEmpty:
                if boxed {
                    buffer.appendInt32(-365775695)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sponsoredPeers(let _data):
                return ("sponsoredPeers", [("peers", _data.peers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .sponsoredPeersEmpty:
                return ("sponsoredPeersEmpty", [])
            }
        }

        public static func parse_sponsoredPeers(_ reader: BufferReader) -> SponsoredPeers? {
            var _1: [Api.SponsoredPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SponsoredPeer.self)
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
                return Api.contacts.SponsoredPeers.sponsoredPeers(Cons_sponsoredPeers(peers: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_sponsoredPeersEmpty(_ reader: BufferReader) -> SponsoredPeers? {
            return Api.contacts.SponsoredPeers.sponsoredPeersEmpty
        }
    }
}
public extension Api.contacts {
    enum TopPeers: TypeConstructorDescription {
        public class Cons_topPeers {
            public var categories: [Api.TopPeerCategoryPeers]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(categories: [Api.TopPeerCategoryPeers], chats: [Api.Chat], users: [Api.User]) {
                self.categories = categories
                self.chats = chats
                self.users = users
            }
        }
        case topPeers(Cons_topPeers)
        case topPeersDisabled
        case topPeersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .topPeers(let _data):
                if boxed {
                    buffer.appendInt32(1891070632)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.categories.count))
                for item in _data.categories {
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
            case .topPeersDisabled:
                if boxed {
                    buffer.appendInt32(-1255369827)
                }
                break
            case .topPeersNotModified:
                if boxed {
                    buffer.appendInt32(-567906571)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .topPeers(let _data):
                return ("topPeers", [("categories", _data.categories as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .topPeersDisabled:
                return ("topPeersDisabled", [])
            case .topPeersNotModified:
                return ("topPeersNotModified", [])
            }
        }

        public static func parse_topPeers(_ reader: BufferReader) -> TopPeers? {
            var _1: [Api.TopPeerCategoryPeers]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TopPeerCategoryPeers.self)
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
                return Api.contacts.TopPeers.topPeers(Cons_topPeers(categories: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_topPeersDisabled(_ reader: BufferReader) -> TopPeers? {
            return Api.contacts.TopPeers.topPeersDisabled
        }
        public static func parse_topPeersNotModified(_ reader: BufferReader) -> TopPeers? {
            return Api.contacts.TopPeers.topPeersNotModified
        }
    }
}
public extension Api.fragment {
    enum CollectibleInfo: TypeConstructorDescription {
        public class Cons_collectibleInfo {
            public var purchaseDate: Int32
            public var currency: String
            public var amount: Int64
            public var cryptoCurrency: String
            public var cryptoAmount: Int64
            public var url: String
            public init(purchaseDate: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, url: String) {
                self.purchaseDate = purchaseDate
                self.currency = currency
                self.amount = amount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.url = url
            }
        }
        case collectibleInfo(Cons_collectibleInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .collectibleInfo(let _data):
                if boxed {
                    buffer.appendInt32(1857945489)
                }
                serializeInt32(_data.purchaseDate, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoCurrency, buffer: buffer, boxed: false)
                serializeInt64(_data.cryptoAmount, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .collectibleInfo(let _data):
                return ("collectibleInfo", [("purchaseDate", _data.purchaseDate as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any), ("cryptoCurrency", _data.cryptoCurrency as Any), ("cryptoAmount", _data.cryptoAmount as Any), ("url", _data.url as Any)])
            }
        }

        public static func parse_collectibleInfo(_ reader: BufferReader) -> CollectibleInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.fragment.CollectibleInfo.collectibleInfo(Cons_collectibleInfo(purchaseDate: _1!, currency: _2!, amount: _3!, cryptoCurrency: _4!, cryptoAmount: _5!, url: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.help {
    enum AppConfig: TypeConstructorDescription {
        public class Cons_appConfig {
            public var hash: Int32
            public var config: Api.JSONValue
            public init(hash: Int32, config: Api.JSONValue) {
                self.hash = hash
                self.config = config
            }
        }
        case appConfig(Cons_appConfig)
        case appConfigNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .appConfig(let _data):
                if boxed {
                    buffer.appendInt32(-585598930)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                _data.config.serialize(buffer, true)
                break
            case .appConfigNotModified:
                if boxed {
                    buffer.appendInt32(2094949405)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .appConfig(let _data):
                return ("appConfig", [("hash", _data.hash as Any), ("config", _data.config as Any)])
            case .appConfigNotModified:
                return ("appConfigNotModified", [])
            }
        }

        public static func parse_appConfig(_ reader: BufferReader) -> AppConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.JSONValue?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.AppConfig.appConfig(Cons_appConfig(hash: _1!, config: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_appConfigNotModified(_ reader: BufferReader) -> AppConfig? {
            return Api.help.AppConfig.appConfigNotModified
        }
    }
}
