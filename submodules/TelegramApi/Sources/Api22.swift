public extension Api {
    indirect enum PublicForward: TypeConstructorDescription {
        public class Cons_publicForwardMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("publicForwardMessage", [("message", self.message as Any)])
            }
        }
        public class Cons_publicForwardStory: TypeConstructorDescription {
            public var peer: Api.Peer
            public var story: Api.StoryItem
            public init(peer: Api.Peer, story: Api.StoryItem) {
                self.peer = peer
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("publicForwardStory", [("peer", self.peer as Any), ("story", self.story as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .publicForwardMessage(let _data):
                return ("publicForwardMessage", [("message", _data.message as Any)])
            case .publicForwardStory(let _data):
                return ("publicForwardStory", [("peer", _data.peer as Any), ("story", _data.story as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("quickReply", [("shortcutId", self.shortcutId as Any), ("shortcut", self.shortcut as Any), ("topMessage", self.topMessage as Any), ("count", self.count as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .quickReply(let _data):
                return ("quickReply", [("shortcutId", _data.shortcutId as Any), ("shortcut", _data.shortcut as Any), ("topMessage", _data.topMessage as Any), ("count", _data.count as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("reactionCustomEmoji", [("documentId", self.documentId as Any)])
            }
        }
        public class Cons_reactionEmoji: TypeConstructorDescription {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("reactionEmoji", [("emoticon", self.emoticon as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .reactionCustomEmoji(let _data):
                return ("reactionCustomEmoji", [("documentId", _data.documentId as Any)])
            case .reactionEmoji(let _data):
                return ("reactionEmoji", [("emoticon", _data.emoticon as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("reactionCount", [("flags", self.flags as Any), ("chosenOrder", self.chosenOrder as Any), ("reaction", self.reaction as Any), ("count", self.count as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .reactionCount(let _data):
                return ("reactionCount", [("flags", _data.flags as Any), ("chosenOrder", _data.chosenOrder as Any), ("reaction", _data.reaction as Any), ("count", _data.count as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("reactionsNotifySettings", [("flags", self.flags as Any), ("messagesNotifyFrom", self.messagesNotifyFrom as Any), ("storiesNotifyFrom", self.storiesNotifyFrom as Any), ("pollVotesNotifyFrom", self.pollVotesNotifyFrom as Any), ("sound", self.sound as Any), ("showPreviews", self.showPreviews as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .reactionsNotifySettings(let _data):
                return ("reactionsNotifySettings", [("flags", _data.flags as Any), ("messagesNotifyFrom", _data.messagesNotifyFrom as Any), ("storiesNotifyFrom", _data.storiesNotifyFrom as Any), ("pollVotesNotifyFrom", _data.pollVotesNotifyFrom as Any), ("sound", _data.sound as Any), ("showPreviews", _data.showPreviews as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("readParticipantDate", [("userId", self.userId as Any), ("date", self.date as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .readParticipantDate(let _data):
                return ("readParticipantDate", [("userId", _data.userId as Any), ("date", _data.date as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("receivedNotifyMessage", [("id", self.id as Any), ("flags", self.flags as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .receivedNotifyMessage(let _data):
                return ("receivedNotifyMessage", [("id", _data.id as Any), ("flags", _data.flags as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentMeUrlChat", [("url", self.url as Any), ("chatId", self.chatId as Any)])
            }
        }
        public class Cons_recentMeUrlChatInvite: TypeConstructorDescription {
            public var url: String
            public var chatInvite: Api.ChatInvite
            public init(url: String, chatInvite: Api.ChatInvite) {
                self.url = url
                self.chatInvite = chatInvite
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentMeUrlChatInvite", [("url", self.url as Any), ("chatInvite", self.chatInvite as Any)])
            }
        }
        public class Cons_recentMeUrlStickerSet: TypeConstructorDescription {
            public var url: String
            public var set: Api.StickerSetCovered
            public init(url: String, set: Api.StickerSetCovered) {
                self.url = url
                self.set = set
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentMeUrlStickerSet", [("url", self.url as Any), ("set", self.set as Any)])
            }
        }
        public class Cons_recentMeUrlUnknown: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentMeUrlUnknown", [("url", self.url as Any)])
            }
        }
        public class Cons_recentMeUrlUser: TypeConstructorDescription {
            public var url: String
            public var userId: Int64
            public init(url: String, userId: Int64) {
                self.url = url
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentMeUrlUser", [("url", self.url as Any), ("userId", self.userId as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .recentMeUrlChat(let _data):
                return ("recentMeUrlChat", [("url", _data.url as Any), ("chatId", _data.chatId as Any)])
            case .recentMeUrlChatInvite(let _data):
                return ("recentMeUrlChatInvite", [("url", _data.url as Any), ("chatInvite", _data.chatInvite as Any)])
            case .recentMeUrlStickerSet(let _data):
                return ("recentMeUrlStickerSet", [("url", _data.url as Any), ("set", _data.set as Any)])
            case .recentMeUrlUnknown(let _data):
                return ("recentMeUrlUnknown", [("url", _data.url as Any)])
            case .recentMeUrlUser(let _data):
                return ("recentMeUrlUser", [("url", _data.url as Any), ("userId", _data.userId as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("recentStory", [("flags", self.flags as Any), ("maxId", self.maxId as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .recentStory(let _data):
                return ("recentStory", [("flags", _data.flags as Any), ("maxId", _data.maxId as Any)])
            }
        }

        public static func parse_recentStory(_ reader: BufferReader) -> RecentStory? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
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
            public var rows: [Api.KeyboardButtonRow]
            public init(rows: [Api.KeyboardButtonRow]) {
                self.rows = rows
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("replyInlineMarkup", [("rows", self.rows as Any)])
            }
        }
        public class Cons_replyKeyboardForceReply: TypeConstructorDescription {
            public var flags: Int32
            public var placeholder: String?
            public init(flags: Int32, placeholder: String?) {
                self.flags = flags
                self.placeholder = placeholder
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("replyKeyboardForceReply", [("flags", self.flags as Any), ("placeholder", self.placeholder as Any)])
            }
        }
        public class Cons_replyKeyboardHide: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("replyKeyboardHide", [("flags", self.flags as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("replyKeyboardMarkup", [("flags", self.flags as Any), ("rows", self.rows as Any), ("placeholder", self.placeholder as Any)])
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
                    buffer.appendInt32(1218642516)
                }
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .replyInlineMarkup(let _data):
                return ("replyInlineMarkup", [("rows", _data.rows as Any)])
            case .replyKeyboardForceReply(let _data):
                return ("replyKeyboardForceReply", [("flags", _data.flags as Any), ("placeholder", _data.placeholder as Any)])
            case .replyKeyboardHide(let _data):
                return ("replyKeyboardHide", [("flags", _data.flags as Any)])
            case .replyKeyboardMarkup(let _data):
                return ("replyKeyboardMarkup", [("flags", _data.flags as Any), ("rows", _data.rows as Any), ("placeholder", _data.placeholder as Any)])
            }
        }

        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyInlineMarkup(Cons_replyInlineMarkup(rows: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
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
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
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

        public func descriptionFields() -> (String, [(String, Any)]) {
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
