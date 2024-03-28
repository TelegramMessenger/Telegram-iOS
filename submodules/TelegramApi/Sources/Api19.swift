public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        case privacyValueAllowAll
        case privacyValueAllowChatParticipants(chats: [Int64])
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(users: [Int64])
        case privacyValueDisallowAll
        case privacyValueDisallowChatParticipants(chats: [Int64])
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(users: [Int64])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(1698855810)
                    }
                    
                    break
                case .privacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(1796427406)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
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
                case .privacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-1198497870)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-1955338397)
                    }
                    
                    break
                case .privacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(1103656293)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .privacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(-125240806)
                    }
                    
                    break
                case .privacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-463335103)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .privacyValueAllowAll:
                return ("privacyValueAllowAll", [])
                case .privacyValueAllowChatParticipants(let chats):
                return ("privacyValueAllowChatParticipants", [("chats", chats as Any)])
                case .privacyValueAllowCloseFriends:
                return ("privacyValueAllowCloseFriends", [])
                case .privacyValueAllowContacts:
                return ("privacyValueAllowContacts", [])
                case .privacyValueAllowPremium:
                return ("privacyValueAllowPremium", [])
                case .privacyValueAllowUsers(let users):
                return ("privacyValueAllowUsers", [("users", users as Any)])
                case .privacyValueDisallowAll:
                return ("privacyValueDisallowAll", [])
                case .privacyValueDisallowChatParticipants(let chats):
                return ("privacyValueDisallowChatParticipants", [("chats", chats as Any)])
                case .privacyValueDisallowContacts:
                return ("privacyValueDisallowContacts", [])
                case .privacyValueDisallowUsers(let users):
                return ("privacyValueDisallowUsers", [("users", users as Any)])
    }
    }
    
        public static func parse_privacyValueAllowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueAllowAll
        }
        public static func parse_privacyValueAllowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueAllowChatParticipants(chats: _1!)
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
                return Api.PrivacyRule.privacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_privacyValueDisallowAll(_ reader: BufferReader) -> PrivacyRule? {
            return Api.PrivacyRule.privacyValueDisallowAll
        }
        public static func parse_privacyValueDisallowChatParticipants(_ reader: BufferReader) -> PrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PrivacyRule.privacyValueDisallowChatParticipants(chats: _1!)
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
                return Api.PrivacyRule.privacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum PublicForward: TypeConstructorDescription {
        case publicForwardMessage(message: Api.Message)
        case publicForwardStory(peer: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .publicForwardMessage(let message):
                    if boxed {
                        buffer.appendInt32(32685898)
                    }
                    message.serialize(buffer, true)
                    break
                case .publicForwardStory(let peer, let story):
                    if boxed {
                        buffer.appendInt32(-302797360)
                    }
                    peer.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .publicForwardMessage(let message):
                return ("publicForwardMessage", [("message", message as Any)])
                case .publicForwardStory(let peer, let story):
                return ("publicForwardStory", [("peer", peer as Any), ("story", story as Any)])
    }
    }
    
        public static func parse_publicForwardMessage(_ reader: BufferReader) -> PublicForward? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PublicForward.publicForwardMessage(message: _1!)
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
                return Api.PublicForward.publicForwardStory(peer: _1!, story: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum QuickReply: TypeConstructorDescription {
        case quickReply(shortcutId: Int32, shortcut: String, topMessage: Int32, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .quickReply(let shortcutId, let shortcut, let topMessage, let count):
                    if boxed {
                        buffer.appendInt32(110563371)
                    }
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    serializeString(shortcut, buffer: buffer, boxed: false)
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .quickReply(let shortcutId, let shortcut, let topMessage, let count):
                return ("quickReply", [("shortcutId", shortcutId as Any), ("shortcut", shortcut as Any), ("topMessage", topMessage as Any), ("count", count as Any)])
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
                return Api.QuickReply.quickReply(shortcutId: _1!, shortcut: _2!, topMessage: _3!, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Reaction: TypeConstructorDescription {
        case reactionCustomEmoji(documentId: Int64)
        case reactionEmoji(emoticon: String)
        case reactionEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .reactionCustomEmoji(let documentId):
                    if boxed {
                        buffer.appendInt32(-1992950669)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
                case .reactionEmoji(let emoticon):
                    if boxed {
                        buffer.appendInt32(455247544)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .reactionEmpty:
                    if boxed {
                        buffer.appendInt32(2046153753)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .reactionCustomEmoji(let documentId):
                return ("reactionCustomEmoji", [("documentId", documentId as Any)])
                case .reactionEmoji(let emoticon):
                return ("reactionEmoji", [("emoticon", emoticon as Any)])
                case .reactionEmpty:
                return ("reactionEmpty", [])
    }
    }
    
        public static func parse_reactionCustomEmoji(_ reader: BufferReader) -> Reaction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Reaction.reactionCustomEmoji(documentId: _1!)
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
                return Api.Reaction.reactionEmoji(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_reactionEmpty(_ reader: BufferReader) -> Reaction? {
            return Api.Reaction.reactionEmpty
        }
    
    }
}
public extension Api {
    enum ReactionCount: TypeConstructorDescription {
        case reactionCount(flags: Int32, chosenOrder: Int32?, reaction: Api.Reaction, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .reactionCount(let flags, let chosenOrder, let reaction, let count):
                    if boxed {
                        buffer.appendInt32(-1546531968)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(chosenOrder!, buffer: buffer, boxed: false)}
                    reaction.serialize(buffer, true)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .reactionCount(let flags, let chosenOrder, let reaction, let count):
                return ("reactionCount", [("flags", flags as Any), ("chosenOrder", chosenOrder as Any), ("reaction", reaction as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_reactionCount(_ reader: BufferReader) -> ReactionCount? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
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
                return Api.ReactionCount.reactionCount(flags: _1!, chosenOrder: _2, reaction: _3!, count: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ReadParticipantDate: TypeConstructorDescription {
        case readParticipantDate(userId: Int64, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .readParticipantDate(let userId, let date):
                    if boxed {
                        buffer.appendInt32(1246753138)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .readParticipantDate(let userId, let date):
                return ("readParticipantDate", [("userId", userId as Any), ("date", date as Any)])
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
                return Api.ReadParticipantDate.readParticipantDate(userId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription {
        case receivedNotifyMessage(id: Int32, flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .receivedNotifyMessage(let id, let flags):
                    if boxed {
                        buffer.appendInt32(-1551583367)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .receivedNotifyMessage(let id, let flags):
                return ("receivedNotifyMessage", [("id", id as Any), ("flags", flags as Any)])
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
                return Api.ReceivedNotifyMessage.receivedNotifyMessage(id: _1!, flags: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription {
        case recentMeUrlChat(url: String, chatId: Int64)
        case recentMeUrlChatInvite(url: String, chatInvite: Api.ChatInvite)
        case recentMeUrlStickerSet(url: String, set: Api.StickerSetCovered)
        case recentMeUrlUnknown(url: String)
        case recentMeUrlUser(url: String, userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentMeUrlChat(let url, let chatId):
                    if boxed {
                        buffer.appendInt32(-1294306862)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlChatInvite(let url, let chatInvite):
                    if boxed {
                        buffer.appendInt32(-347535331)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    chatInvite.serialize(buffer, true)
                    break
                case .recentMeUrlStickerSet(let url, let set):
                    if boxed {
                        buffer.appendInt32(-1140172836)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    set.serialize(buffer, true)
                    break
                case .recentMeUrlUnknown(let url):
                    if boxed {
                        buffer.appendInt32(1189204285)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .recentMeUrlUser(let url, let userId):
                    if boxed {
                        buffer.appendInt32(-1188296222)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentMeUrlChat(let url, let chatId):
                return ("recentMeUrlChat", [("url", url as Any), ("chatId", chatId as Any)])
                case .recentMeUrlChatInvite(let url, let chatInvite):
                return ("recentMeUrlChatInvite", [("url", url as Any), ("chatInvite", chatInvite as Any)])
                case .recentMeUrlStickerSet(let url, let set):
                return ("recentMeUrlStickerSet", [("url", url as Any), ("set", set as Any)])
                case .recentMeUrlUnknown(let url):
                return ("recentMeUrlUnknown", [("url", url as Any)])
                case .recentMeUrlUser(let url, let userId):
                return ("recentMeUrlUser", [("url", url as Any), ("userId", userId as Any)])
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
                return Api.RecentMeUrl.recentMeUrlChat(url: _1!, chatId: _2!)
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
                return Api.RecentMeUrl.recentMeUrlChatInvite(url: _1!, chatInvite: _2!)
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
                return Api.RecentMeUrl.recentMeUrlStickerSet(url: _1!, set: _2!)
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
                return Api.RecentMeUrl.recentMeUrlUnknown(url: _1!)
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
                return Api.RecentMeUrl.recentMeUrlUser(url: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription {
        case replyInlineMarkup(rows: [Api.KeyboardButtonRow])
        case replyKeyboardForceReply(flags: Int32, placeholder: String?)
        case replyKeyboardHide(flags: Int32)
        case replyKeyboardMarkup(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .replyInlineMarkup(let rows):
                    if boxed {
                        buffer.appendInt32(1218642516)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    break
                case .replyKeyboardForceReply(let flags, let placeholder):
                    if boxed {
                        buffer.appendInt32(-2035021048)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(placeholder!, buffer: buffer, boxed: false)}
                    break
                case .replyKeyboardHide(let flags):
                    if boxed {
                        buffer.appendInt32(-1606526075)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .replyKeyboardMarkup(let flags, let rows, let placeholder):
                    if boxed {
                        buffer.appendInt32(-2049074735)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rows.count))
                    for item in rows {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(placeholder!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .replyInlineMarkup(let rows):
                return ("replyInlineMarkup", [("rows", rows as Any)])
                case .replyKeyboardForceReply(let flags, let placeholder):
                return ("replyKeyboardForceReply", [("flags", flags as Any), ("placeholder", placeholder as Any)])
                case .replyKeyboardHide(let flags):
                return ("replyKeyboardHide", [("flags", flags as Any)])
                case .replyKeyboardMarkup(let flags, let rows, let placeholder):
                return ("replyKeyboardMarkup", [("flags", flags as Any), ("rows", rows as Any), ("placeholder", placeholder as Any)])
    }
    }
    
        public static func parse_replyInlineMarkup(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: [Api.KeyboardButtonRow]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButtonRow.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ReplyMarkup.replyInlineMarkup(rows: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_replyKeyboardForceReply(_ reader: BufferReader) -> ReplyMarkup? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 3) != 0 {_2 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.ReplyMarkup.replyKeyboardForceReply(flags: _1!, placeholder: _2)
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
                return Api.ReplyMarkup.replyKeyboardHide(flags: _1!)
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
            if Int(_1!) & Int(1 << 3) != 0 {_3 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ReplyMarkup.replyKeyboardMarkup(flags: _1!, rows: _2!, placeholder: _3)
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
