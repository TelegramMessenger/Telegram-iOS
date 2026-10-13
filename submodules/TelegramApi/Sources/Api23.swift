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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
                }
            }
            var _3: Api.ReactionNotificationsFrom?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
                }
            }
            var _4: Api.ReactionNotificationsFrom?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
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
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
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
public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        public class Cons_receivedNotifyMessage: TypeConstructorDescription {
            public var id: Int32
            public var flags: Int32
            public init(id: Int32, flags: Int32) {
                self.id = id
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("receivedNotifyMessage", [("id", ConstructorParameterDescription(self.id)), ("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        case receivedNotifyMessage(Cons_receivedNotifyMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .receivedNotifyMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1551583367)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .receivedNotifyMessage(let _data):
                return ("receivedNotifyMessage", [("id", ConstructorParameterDescription(_data.id)), ("flags", ConstructorParameterDescription(_data.flags))])
            }
        }

        public static func parse_receivedNotifyMessage(_ reader: BufferReader) -> ReceivedNotifyMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReceivedNotifyMessage.receivedNotifyMessage(Cons_receivedNotifyMessage(id: _1!, flags: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription {
        public class Cons_recentMeUrlChat: TypeConstructorDescription {
            public var url: String
            public var chatId: Int64
            public init(url: String, chatId: Int64) {
                self.url = url
                self.chatId = chatId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentMeUrlChat", [("url", ConstructorParameterDescription(self.url)), ("chatId", ConstructorParameterDescription(self.chatId))])
            }
        }
        public class Cons_recentMeUrlChatInvite: TypeConstructorDescription {
            public var url: String
            public var chatInvite: Api.ChatInvite
            public init(url: String, chatInvite: Api.ChatInvite) {
                self.url = url
                self.chatInvite = chatInvite
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentMeUrlChatInvite", [("url", ConstructorParameterDescription(self.url)), ("chatInvite", ConstructorParameterDescription(self.chatInvite))])
            }
        }
        public class Cons_recentMeUrlStickerSet: TypeConstructorDescription {
            public var url: String
            public var set: Api.StickerSetCovered
            public init(url: String, set: Api.StickerSetCovered) {
                self.url = url
                self.set = set
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentMeUrlStickerSet", [("url", ConstructorParameterDescription(self.url)), ("set", ConstructorParameterDescription(self.set))])
            }
        }
        public class Cons_recentMeUrlUnknown: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentMeUrlUnknown", [("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_recentMeUrlUser: TypeConstructorDescription {
            public var url: String
            public var userId: Int64
            public init(url: String, userId: Int64) {
                self.url = url
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentMeUrlUser", [("url", ConstructorParameterDescription(self.url)), ("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        case recentMeUrlChat(Cons_recentMeUrlChat)
        case recentMeUrlChatInvite(Cons_recentMeUrlChatInvite)
        case recentMeUrlStickerSet(Cons_recentMeUrlStickerSet)
        case recentMeUrlUnknown(Cons_recentMeUrlUnknown)
        case recentMeUrlUser(Cons_recentMeUrlUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentMeUrlChat(let _data):
                if boxed {
                    buffer.appendInt32(-1294306862)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.chatId, buffer: buffer, boxed: false)
                break
            case .recentMeUrlChatInvite(let _data):
                if boxed {
                    buffer.appendInt32(-347535331)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                _data.chatInvite.serialize(buffer, true)
                break
            case .recentMeUrlStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(-1140172836)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                _data.set.serialize(buffer, true)
                break
            case .recentMeUrlUnknown(let _data):
                if boxed {
                    buffer.appendInt32(1189204285)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .recentMeUrlUser(let _data):
                if boxed {
                    buffer.appendInt32(-1188296222)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .recentMeUrlChat(let _data):
                return ("recentMeUrlChat", [("url", ConstructorParameterDescription(_data.url)), ("chatId", ConstructorParameterDescription(_data.chatId))])
            case .recentMeUrlChatInvite(let _data):
                return ("recentMeUrlChatInvite", [("url", ConstructorParameterDescription(_data.url)), ("chatInvite", ConstructorParameterDescription(_data.chatInvite))])
            case .recentMeUrlStickerSet(let _data):
                return ("recentMeUrlStickerSet", [("url", ConstructorParameterDescription(_data.url)), ("set", ConstructorParameterDescription(_data.set))])
            case .recentMeUrlUnknown(let _data):
                return ("recentMeUrlUnknown", [("url", ConstructorParameterDescription(_data.url))])
            case .recentMeUrlUser(let _data):
                return ("recentMeUrlUser", [("url", ConstructorParameterDescription(_data.url)), ("userId", ConstructorParameterDescription(_data.userId))])
            }
        }

        public static func parse_recentMeUrlChat(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChat(Cons_recentMeUrlChat(url: _1!, chatId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlChatInvite(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.ChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlChatInvite(Cons_recentMeUrlChatInvite(url: _1!, chatInvite: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlStickerSet(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.StickerSetCovered?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StickerSetCovered
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlStickerSet(Cons_recentMeUrlStickerSet(url: _1!, set: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlUnknown(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.RecentMeUrl.recentMeUrlUnknown(Cons_recentMeUrlUnknown(url: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_recentMeUrlUser(_ reader: BufferReader) -> RecentMeUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.RecentMeUrl.recentMeUrlUser(Cons_recentMeUrlUser(url: _1!, userId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum RecentStory: TypeConstructorDescription {
        public class Cons_recentStory: TypeConstructorDescription {
            public var flags: Int32
            public var maxId: Int32?
            public init(flags: Int32, maxId: Int32?) {
                self.flags = flags
                self.maxId = maxId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentStory", [("flags", ConstructorParameterDescription(self.flags)), ("maxId", ConstructorParameterDescription(self.maxId))])
            }
        }
        case recentStory(Cons_recentStory)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentStory(let _data):
                if boxed {
                    buffer.appendInt32(1897752877)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.maxId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .recentStory(let _data):
                return ("recentStory", [("flags", ConstructorParameterDescription(_data.flags)), ("maxId", ConstructorParameterDescription(_data.maxId))])
            }
        }

        public static func parse_recentStory(_ reader: BufferReader) -> RecentStory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.RecentStory.recentStory(Cons_recentStory(flags: _1!, maxId: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription {
        public class Cons_replyInlineMarkup: TypeConstructorDescription {
            public var flags: Int32
            public var rows: [Api.KeyboardInlineButtonRow]
            public init(flags: Int32, rows: [Api.KeyboardInlineButtonRow]) {
                self.flags = flags
                self.rows = rows
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("replyInlineMarkup", [("flags", ConstructorParameterDescription(self.flags)), ("rows", ConstructorParameterDescription(self.rows))])
            }
        }
        public class Cons_replyKeyboardForceReply: TypeConstructorDescription {
            public var flags: Int32
            public var placeholder: String?
            public init(flags: Int32, placeholder: String?) {
                self.flags = flags
                self.placeholder = placeholder
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("replyKeyboardForceReply", [("flags", ConstructorParameterDescription(self.flags)), ("placeholder", ConstructorParameterDescription(self.placeholder))])
            }
        }
        public class Cons_replyKeyboardHide: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("replyKeyboardHide", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        public class Cons_replyKeyboardMarkup: TypeConstructorDescription {
            public var flags: Int32
            public var rows: [Api.KeyboardButtonRow]
            public var placeholder: String?
            public init(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?) {
                self.flags = flags
                self.rows = rows
                self.placeholder = placeholder
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("replyKeyboardMarkup", [("flags", ConstructorParameterDescription(self.flags)), ("rows", ConstructorParameterDescription(self.rows)), ("placeholder", ConstructorParameterDescription(self.placeholder))])
            }
        }
        case replyInlineMarkup(Cons_replyInlineMarkup)
        case replyKeyboardForceReply(Cons_replyKeyboardForceReply)
        case replyKeyboardHide(Cons_replyKeyboardHide)
        case replyKeyboardMarkup(Cons_replyKeyboardMarkup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .replyInlineMarkup(let _data):
                if boxed {
                    buffer.appendInt32(-1297000592)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                break
            case .replyKeyboardForceReply(let _data):
                if boxed {
                    buffer.appendInt32(-2035021048)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.placeholder!, buffer: buffer, boxed: false)
                }
                break
            case .replyKeyboardHide(let _data):
                if boxed {
                    buffer.appendInt32(-1606526075)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .replyKeyboardMarkup(let _data):
                if boxed {
                    buffer.appendInt32(-2049074735)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.placeholder!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .replyInlineMarkup(let _data):
                return ("replyInlineMarkup", [("flags", ConstructorParameterDescription(_data.flags)), ("rows", ConstructorParameterDescription(_data.rows))])
            case .replyKeyboardForceReply(let _data):
                return ("replyKeyboardForceReply", [("flags", ConstructorParameterDescription(_data.flags)), ("placeholder", ConstructorParameterDescription(_data.placeholder))])
            case .replyKeyboardHide(let _data):
                return ("replyKeyboardHide", [("flags", ConstructorParameterDescription(_data.flags))])
            case .replyKeyboardMarkup(let _data):
                return ("replyKeyboardMarkup", [("flags", ConstructorParameterDescription(_data.flags)), ("rows", ConstructorParameterDescription(_data.rows)), ("placeholder", ConstructorParameterDescription(_data.placeholder))])
            }
        }

        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.KeyboardInlineButtonRow]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardInlineButtonRow.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyInlineMarkup(Cons_replyInlineMarkup(flags: _1!, rows: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyKeyboardForceReply(Cons_replyKeyboardForceReply(flags: _1!, placeholder: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardHide(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyKeyboardHide(Cons_replyKeyboardHide(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ReplyMarkup.replyKeyboardMarkup(Cons_replyKeyboardMarkup(flags: _1!, rows: _2!, placeholder: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ReportReason: TypeConstructorDescription {
        case inputReportReasonChildAbuse
        case inputReportReasonCopyright
        case inputReportReasonFake
        case inputReportReasonGeoIrrelevant
        case inputReportReasonIllegalDrugs
        case inputReportReasonOther
        case inputReportReasonPersonalDetails
        case inputReportReasonPornography
        case inputReportReasonSpam
        case inputReportReasonViolence

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputReportReasonChildAbuse:
                if boxed {
                    buffer.appendInt32(-1376497949)
                }
                break
            case .inputReportReasonCopyright:
                if boxed {
                    buffer.appendInt32(-1685456582)
                }
                break
            case .inputReportReasonFake:
                if boxed {
                    buffer.appendInt32(-170010905)
                }
                break
            case .inputReportReasonGeoIrrelevant:
                if boxed {
                    buffer.appendInt32(-606798099)
                }
                break
            case .inputReportReasonIllegalDrugs:
                if boxed {
                    buffer.appendInt32(177124030)
                }
                break
            case .inputReportReasonOther:
                if boxed {
                    buffer.appendInt32(-1041980751)
                }
                break
            case .inputReportReasonPersonalDetails:
                if boxed {
                    buffer.appendInt32(-1631091139)
                }
                break
            case .inputReportReasonPornography:
                if boxed {
                    buffer.appendInt32(777640226)
                }
                break
            case .inputReportReasonSpam:
                if boxed {
                    buffer.appendInt32(1490799288)
                }
                break
            case .inputReportReasonViolence:
                if boxed {
                    buffer.appendInt32(505595789)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputReportReasonChildAbuse:
                return ("inputReportReasonChildAbuse", [])
            case .inputReportReasonCopyright:
                return ("inputReportReasonCopyright", [])
            case .inputReportReasonFake:
                return ("inputReportReasonFake", [])
            case .inputReportReasonGeoIrrelevant:
                return ("inputReportReasonGeoIrrelevant", [])
            case .inputReportReasonIllegalDrugs:
                return ("inputReportReasonIllegalDrugs", [])
            case .inputReportReasonOther:
                return ("inputReportReasonOther", [])
            case .inputReportReasonPersonalDetails:
                return ("inputReportReasonPersonalDetails", [])
            case .inputReportReasonPornography:
                return ("inputReportReasonPornography", [])
            case .inputReportReasonSpam:
                return ("inputReportReasonSpam", [])
            case .inputReportReasonViolence:
                return ("inputReportReasonViolence", [])
            }
        }

        public static func parse_inputReportReasonChildAbuse(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonChildAbuse
        }
        public static func parse_inputReportReasonCopyright(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonCopyright
        }
        public static func parse_inputReportReasonFake(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonFake
        }
        public static func parse_inputReportReasonGeoIrrelevant(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonGeoIrrelevant
        }
        public static func parse_inputReportReasonIllegalDrugs(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonIllegalDrugs
        }
        public static func parse_inputReportReasonOther(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonOther
        }
        public static func parse_inputReportReasonPersonalDetails(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonPersonalDetails
        }
        public static func parse_inputReportReasonPornography(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonPornography
        }
        public static func parse_inputReportReasonSpam(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonSpam
        }
        public static func parse_inputReportReasonViolence(_ reader: BufferReader) -> ReportReason? {
            return Api.ReportReason.inputReportReasonViolence
        }
    }
}
