public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        public class Cons_privacyValueAllowChatParticipants: TypeConstructorDescription {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyValueAllowChatParticipants", [("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        public class Cons_privacyValueAllowUsers: TypeConstructorDescription {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyValueAllowUsers", [("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_privacyValueDisallowChatParticipants: TypeConstructorDescription {
            public var chats: [Int64]
            public init(chats: [Int64]) {
                self.chats = chats
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyValueDisallowChatParticipants", [("chats", ConstructorParameterDescription(self.chats))])
            }
        }
        public class Cons_privacyValueDisallowUsers: TypeConstructorDescription {
            public var users: [Int64]
            public init(users: [Int64]) {
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyValueDisallowUsers", [("users", ConstructorParameterDescription(self.users))])
            }
        }
        case privacyValueAllowAll
        case privacyValueAllowBots
        case privacyValueAllowChatParticipants(Cons_privacyValueAllowChatParticipants)
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(Cons_privacyValueAllowUsers)
        case privacyValueDisallowAll
        case privacyValueDisallowBots
        case privacyValueDisallowChatParticipants(Cons_privacyValueDisallowChatParticipants)
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(Cons_privacyValueDisallowUsers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .privacyValueAllowAll:
                if boxed {
                    buffer.appendInt32(1698855810)
                }
                break
            case .privacyValueAllowBots:
                if boxed {
                    buffer.appendInt32(558242653)
                }
                break
            case .privacyValueAllowChatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(1796427406)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .privacyValueAllowCloseFriends:
                if boxed {
                    buffer.appendInt32(-135735141)
                }
                break
            case .privacyValueAllowContacts:
                if boxed {
                    buffer.appendInt32(-123988)
                }
                break
            case .privacyValueAllowPremium:
                if boxed {
                    buffer.appendInt32(-320241333)
                }
                break
            case .privacyValueAllowUsers(let _data):
                if boxed {
                    buffer.appendInt32(-1198497870)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .privacyValueDisallowAll:
                if boxed {
                    buffer.appendInt32(-1955338397)
                }
                break
            case .privacyValueDisallowBots:
                if boxed {
                    buffer.appendInt32(-156895185)
                }
                break
            case .privacyValueDisallowChatParticipants(let _data):
                if boxed {
                    buffer.appendInt32(1103656293)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .privacyValueDisallowContacts:
                if boxed {
                    buffer.appendInt32(-125240806)
                }
                break
            case .privacyValueDisallowUsers(let _data):
                if boxed {
                    buffer.appendInt32(-463335103)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .privacyValueAllowAll:
                return ("privacyValueAllowAll", [])
            case .privacyValueAllowBots:
                return ("privacyValueAllowBots", [])
            case .privacyValueAllowChatParticipants(let _data):
                return ("privacyValueAllowChatParticipants", [("chats", ConstructorParameterDescription(_data.chats))])
            case .privacyValueAllowCloseFriends:
                return ("privacyValueAllowCloseFriends", [])
            case .privacyValueAllowContacts:
                return ("privacyValueAllowContacts", [])
            case .privacyValueAllowPremium:
                return ("privacyValueAllowPremium", [])
            case .privacyValueAllowUsers(let _data):
                return ("privacyValueAllowUsers", [("users", ConstructorParameterDescription(_data.users))])
            case .privacyValueDisallowAll:
                return ("privacyValueDisallowAll", [])
            case .privacyValueDisallowBots:
                return ("privacyValueDisallowBots", [])
            case .privacyValueDisallowChatParticipants(let _data):
                return ("privacyValueDisallowChatParticipants", [("chats", ConstructorParameterDescription(_data.chats))])
            case .privacyValueDisallowContacts:
                return ("privacyValueDisallowContacts", [])
            case .privacyValueDisallowUsers(let _data):
                return ("privacyValueDisallowUsers", [("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_privacyValueAllowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowAll
        }
        public static func parse_privacyValueAllowBots(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowBots
        }
        public static func parse_privacyValueAllowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowChatParticipants(Cons_privacyValueAllowChatParticipants(chats: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueAllowCloseFriends(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowCloseFriends
        }
        public static func parse_privacyValueAllowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowContacts
        }
        public static func parse_privacyValueAllowPremium(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowPremium
        }
        public static func parse_privacyValueAllowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowUsers(Cons_privacyValueAllowUsers(users: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowAll
        }
        public static func parse_privacyValueDisallowBots(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowBots
        }
        public static func parse_privacyValueDisallowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowChatParticipants(Cons_privacyValueDisallowChatParticipants(chats: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowContacts(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowContacts
        }
        public static func parse_privacyValueDisallowUsers(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowUsers(Cons_privacyValueDisallowUsers(users: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ProfileTab: TypeConstructorDescription {
        case profileTabFiles
        case profileTabGifs
        case profileTabGifts
        case profileTabLinks
        case profileTabMedia
        case profileTabMusic
        case profileTabPosts
        case profileTabVoice

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .profileTabFiles:
                if boxed {
                    buffer.appendInt32(-1422681088)
                }
                break
            case .profileTabGifs:
                if boxed {
                    buffer.appendInt32(-1564412267)
                }
                break
            case .profileTabGifts:
                if boxed {
                    buffer.appendInt32(1296815210)
                }
                break
            case .profileTabLinks:
                if boxed {
                    buffer.appendInt32(-748329831)
                }
                break
            case .profileTabMedia:
                if boxed {
                    buffer.appendInt32(1925597525)
                }
                break
            case .profileTabMusic:
                if boxed {
                    buffer.appendInt32(-1624780178)
                }
                break
            case .profileTabPosts:
                if boxed {
                    buffer.appendInt32(-1181952362)
                }
                break
            case .profileTabVoice:
                if boxed {
                    buffer.appendInt32(-461960914)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .profileTabFiles:
                return ("profileTabFiles", [])
            case .profileTabGifs:
                return ("profileTabGifs", [])
            case .profileTabGifts:
                return ("profileTabGifts", [])
            case .profileTabLinks:
                return ("profileTabLinks", [])
            case .profileTabMedia:
                return ("profileTabMedia", [])
            case .profileTabMusic:
                return ("profileTabMusic", [])
            case .profileTabPosts:
                return ("profileTabPosts", [])
            case .profileTabVoice:
                return ("profileTabVoice", [])
            }
        }

        public static func parse_profileTabFiles(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabFiles
        }
        public static func parse_profileTabGifs(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabGifs
        }
        public static func parse_profileTabGifts(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabGifts
        }
        public static func parse_profileTabLinks(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabLinks
        }
        public static func parse_profileTabMedia(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabMedia
        }
        public static func parse_profileTabMusic(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabMusic
        }
        public static func parse_profileTabPosts(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabPosts
        }
        public static func parse_profileTabVoice(_ reader: BufferReader) -> ProfileTab? {
            return Api.ProfileTab.profileTabVoice
        }
    }
}
public extension Api {
    indirect enum PublicForward: TypeConstructorDescription {
        public class Cons_publicForwardMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("publicForwardMessage", [("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_publicForwardStory: TypeConstructorDescription {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("publicForwardStory", [("peer", ConstructorParameterDescription(self.peer)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        case publicForwardMessage(Cons_publicForwardMessage)
        case publicForwardStory(Cons_publicForwardStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .publicForwardMessage(let _data):
                if boxed {
                    buffer.appendInt32(32685898)
                }
                _data.message.serialize(buffer, true)
                break
            case .publicForwardStory(let _data):
                if boxed {
                    buffer.appendInt32(-302797360)
                }
                _data.peer.serialize(buffer, true)
                _data.story.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .publicForwardMessage(let _data):
                return ("publicForwardMessage", [("message", ConstructorParameterDescription(_data.message))])
            case .publicForwardStory(let _data):
                return ("publicForwardStory", [("peer", ConstructorParameterDescription(_data.peer)), ("story", ConstructorParameterDescription(_data.story))])
            }
        }

        public static func parse_publicForwardMessage(_ reader: BufferReader) -> PublicForward? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PublicForward.publicForwardMessage(Cons_publicForwardMessage(message: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_publicForwardStory(_ reader: BufferReader) -> PublicForward? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PublicForward.publicForwardStory(Cons_publicForwardStory(peer: _1!, story: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum QuickReply: TypeConstructorDescription {
        public class Cons_quickReply: TypeConstructorDescription {
            public var shortcutId: Int32
            public var shortcut: String
            public var topMessage: Int32
            public var count: Int32
            public init(shortcutId: Int32, shortcut: String, topMessage: Int32, count: Int32) {
                self.shortcutId = shortcutId
                self.shortcut = shortcut
                self.topMessage = topMessage
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("quickReply", [("shortcutId", ConstructorParameterDescription(self.shortcutId)), ("shortcut", ConstructorParameterDescription(self.shortcut)), ("topMessage", ConstructorParameterDescription(self.topMessage)), ("count", ConstructorParameterDescription(self.count))])
            }
        }
        case quickReply(Cons_quickReply)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .quickReply(let _data):
                if boxed {
                    buffer.appendInt32(110563371)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                serializeString(_data.shortcut, buffer: buffer, boxed: false)
                serializeInt32(_data.topMessage, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .quickReply(let _data):
                return ("quickReply", [("shortcutId", ConstructorParameterDescription(_data.shortcutId)), ("shortcut", ConstructorParameterDescription(_data.shortcut)), ("topMessage", ConstructorParameterDescription(_data.topMessage)), ("count", ConstructorParameterDescription(_data.count))])
            }
        }

        public static func parse_quickReply(_ reader: BufferReader) -> QuickReply? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.QuickReply.quickReply(Cons_quickReply(shortcutId: _1!, shortcut: _2!, topMessage: _3!, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Reaction: TypeConstructorDescription {
        public class Cons_reactionCustomEmoji: TypeConstructorDescription {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("reactionCustomEmoji", [("documentId", ConstructorParameterDescription(self.documentId))])
            }
        }
        public class Cons_reactionEmoji: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("reactionEmoji", [("emoticon", ConstructorParameterDescription(self.emoticon))])
            }
        }
        case reactionCustomEmoji(Cons_reactionCustomEmoji)
        case reactionEmoji(Cons_reactionEmoji)
        case reactionEmpty
        case reactionPaid

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reactionCustomEmoji(let _data):
                if boxed {
                    buffer.appendInt32(-1992950669)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            case .reactionEmoji(let _data):
                if boxed {
                    buffer.appendInt32(455247544)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .reactionEmpty:
                if boxed {
                    buffer.appendInt32(2046153753)
                }
                break
            case .reactionPaid:
                if boxed {
                    buffer.appendInt32(1379771627)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .reactionCustomEmoji(let _data):
                return ("reactionCustomEmoji", [("documentId", ConstructorParameterDescription(_data.documentId))])
            case .reactionEmoji(let _data):
                return ("reactionEmoji", [("emoticon", ConstructorParameterDescription(_data.emoticon))])
            case .reactionEmpty:
                return ("reactionEmpty", [])
            case .reactionPaid:
                return ("reactionPaid", [])
            }
        }

        public static func parse_reactionCustomEmoji(_ reader: BufferReader) -> Reaction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Reaction.reactionCustomEmoji(Cons_reactionCustomEmoji(documentId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_reactionEmoji(_ reader: BufferReader) -> Reaction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Reaction.reactionEmoji(Cons_reactionEmoji(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_reactionEmpty(_ reader: BufferReader) -> Reaction? {
            return Api.Reaction.reactionEmpty
        }
        public static func parse_reactionPaid(_ reader: BufferReader) -> Reaction? {
            return Api.Reaction.reactionPaid
        }
    }
}
public extension Api {
    enum ReactionCount: TypeConstructorDescription {
        public class Cons_reactionCount: TypeConstructorDescription {
            public var flags: Int32
            public var chosenOrder: Int32?
            public var reaction: Api.Reaction
            public var count: Int32
            public init(flags: Int32, chosenOrder: Int32?, reaction: Api.Reaction, count: Int32) {
                self.flags = flags
                self.chosenOrder = chosenOrder
                self.reaction = reaction
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("reactionCount", [("flags", ConstructorParameterDescription(self.flags)), ("chosenOrder", ConstructorParameterDescription(self.chosenOrder)), ("reaction", ConstructorParameterDescription(self.reaction)), ("count", ConstructorParameterDescription(self.count))])
            }
        }
        case reactionCount(Cons_reactionCount)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reactionCount(let _data):
                if boxed {
                    buffer.appendInt32(-1546531968)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.chosenOrder!, buffer: buffer, boxed: false)
                }
                _data.reaction.serialize(buffer, true)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .reactionCount(let _data):
                return ("reactionCount", [("flags", ConstructorParameterDescription(_data.flags)), ("chosenOrder", ConstructorParameterDescription(_data.chosenOrder)), ("reaction", ConstructorParameterDescription(_data.reaction)), ("count", ConstructorParameterDescription(_data.count))])
            }
        }

        public static func parse_reactionCount(_ reader: BufferReader) -> ReactionCount? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ReactionCount.reactionCount(Cons_reactionCount(flags: _1!, chosenOrder: _2, reaction: _3!, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ReactionNotificationsFrom: TypeConstructorDescription {
        case reactionNotificationsFromAll
        case reactionNotificationsFromContacts

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reactionNotificationsFromAll:
                if boxed {
                    buffer.appendInt32(1268654752)
                }
                break
            case .reactionNotificationsFromContacts:
                if boxed {
                    buffer.appendInt32(-1161583078)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .reactionNotificationsFromAll:
                return ("reactionNotificationsFromAll", [])
            case .reactionNotificationsFromContacts:
                return ("reactionNotificationsFromContacts", [])
            }
        }

        public static func parse_reactionNotificationsFromAll(_ reader: BufferReader) -> ReactionNotificationsFrom? {
            return Api.ReactionNotificationsFrom.reactionNotificationsFromAll
        }
        public static func parse_reactionNotificationsFromContacts(_ reader: BufferReader) -> ReactionNotificationsFrom? {
            return Api.ReactionNotificationsFrom.reactionNotificationsFromContacts
        }
    }
}
public extension Api {
    enum ReactionsNotifySettings: TypeConstructorDescription {
        public class Cons_reactionsNotifySettings: TypeConstructorDescription {
            public var flags: Int32
            public var messagesNotifyFrom: Api.ReactionNotificationsFrom?
            public var storiesNotifyFrom: Api.ReactionNotificationsFrom?
            public var pollVotesNotifyFrom: Api.ReactionNotificationsFrom?
            public var sound: Api.NotificationSound
            public var showPreviews: Api.Bool
            public init(flags: Int32, messagesNotifyFrom: Api.ReactionNotificationsFrom?, storiesNotifyFrom: Api.ReactionNotificationsFrom?, pollVotesNotifyFrom: Api.ReactionNotificationsFrom?, sound: Api.NotificationSound, showPreviews: Api.Bool) {
                self.flags = flags
                self.messagesNotifyFrom = messagesNotifyFrom
                self.storiesNotifyFrom = storiesNotifyFrom
                self.pollVotesNotifyFrom = pollVotesNotifyFrom
                self.sound = sound
                self.showPreviews = showPreviews
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("reactionsNotifySettings", [("flags", ConstructorParameterDescription(self.flags)), ("messagesNotifyFrom", ConstructorParameterDescription(self.messagesNotifyFrom)), ("storiesNotifyFrom", ConstructorParameterDescription(self.storiesNotifyFrom)), ("pollVotesNotifyFrom", ConstructorParameterDescription(self.pollVotesNotifyFrom)), ("sound", ConstructorParameterDescription(self.sound)), ("showPreviews", ConstructorParameterDescription(self.showPreviews))])
            }
        }
        case reactionsNotifySettings(Cons_reactionsNotifySettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .reactionsNotifySettings(let _data):
                if boxed {
                    buffer.appendInt32(1910827608)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.messagesNotifyFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.storiesNotifyFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.pollVotesNotifyFrom!.serialize(buffer, true)
                }
                _data.sound.serialize(buffer, true)
                _data.showPreviews.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .reactionsNotifySettings(let _data):
                return ("reactionsNotifySettings", [("flags", ConstructorParameterDescription(_data.flags)), ("messagesNotifyFrom", ConstructorParameterDescription(_data.messagesNotifyFrom)), ("storiesNotifyFrom", ConstructorParameterDescription(_data.storiesNotifyFrom)), ("pollVotesNotifyFrom", ConstructorParameterDescription(_data.pollVotesNotifyFrom)), ("sound", ConstructorParameterDescription(_data.sound)), ("showPreviews", ConstructorParameterDescription(_data.showPreviews))])
            }
        }

        public static func parse_reactionsNotifySettings(_ reader: BufferReader) -> ReactionsNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ReactionNotificationsFrom?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
                }
            }
            var _3: Api.ReactionNotificationsFrom?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
                }
            }
            var _4: Api.ReactionNotificationsFrom?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
                }
            }
            var _5: Api.NotificationSound?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            }
            var _6: Api.Bool?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ReactionsNotifySettings.reactionsNotifySettings(Cons_reactionsNotifySettings(flags: _1!, messagesNotifyFrom: _2, storiesNotifyFrom: _3, pollVotesNotifyFrom: _4, sound: _5!, showPreviews: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ReadParticipantDate: TypeConstructorDescription {
        public class Cons_readParticipantDate: TypeConstructorDescription {
            public var userId: Int64
            public var date: Int32
            public init(userId: Int64, date: Int32) {
                self.userId = userId
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("readParticipantDate", [("userId", ConstructorParameterDescription(self.userId)), ("date", ConstructorParameterDescription(self.date))])
            }
        }
        case readParticipantDate(Cons_readParticipantDate)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .readParticipantDate(let _data):
                if boxed {
                    buffer.appendInt32(1246753138)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .readParticipantDate(let _data):
                return ("readParticipantDate", [("userId", ConstructorParameterDescription(_data.userId)), ("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_readParticipantDate(_ reader: BufferReader) -> ReadParticipantDate? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReadParticipantDate.readParticipantDate(Cons_readParticipantDate(userId: _1!, date: _2!))
            }
            else {
                return nil
            }
        }
    }
}
