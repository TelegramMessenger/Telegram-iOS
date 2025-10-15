public extension Api {
    enum PrivacyRule: TypeConstructorDescription {
        case privacyValueAllowAll
        case privacyValueAllowBots
        case privacyValueAllowChatParticipants(chats: [Int64])
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(users: [Int64])
        case privacyValueDisallowAll
        case privacyValueDisallowBots
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
                case .privacyValueAllowBots:
                    if boxed {
                        buffer.appendInt32(558242653)
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
                case .privacyValueDisallowBots:
                    if boxed {
                        buffer.appendInt32(-156895185)
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
                case .privacyValueAllowBots:
                return ("privacyValueAllowBots", [])
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
                case .privacyValueDisallowBots:
                return ("privacyValueDisallowBots", [])
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
    
    public func descriptionFields() -> (String, [(String, Any)]) {
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
        case reactionPaid
    
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
                case .reactionPaid:
                    if boxed {
                        buffer.appendInt32(1379771627)
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
                case .reactionPaid:
                return ("reactionPaid", [])
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
        public static func parse_reactionPaid(_ reader: BufferReader) -> Reaction? {
            return Api.Reaction.reactionPaid
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
        case reactionsNotifySettings(flags: Int32, messagesNotifyFrom: Api.ReactionNotificationsFrom?, storiesNotifyFrom: Api.ReactionNotificationsFrom?, sound: Api.NotificationSound, showPreviews: Api.Bool)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .reactionsNotifySettings(let flags, let messagesNotifyFrom, let storiesNotifyFrom, let sound, let showPreviews):
                    if boxed {
                        buffer.appendInt32(1457736048)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {messagesNotifyFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {storiesNotifyFrom!.serialize(buffer, true)}
                    sound.serialize(buffer, true)
                    showPreviews.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .reactionsNotifySettings(let flags, let messagesNotifyFrom, let storiesNotifyFrom, let sound, let showPreviews):
                return ("reactionsNotifySettings", [("flags", flags as Any), ("messagesNotifyFrom", messagesNotifyFrom as Any), ("storiesNotifyFrom", storiesNotifyFrom as Any), ("sound", sound as Any), ("showPreviews", showPreviews as Any)])
    }
    }
    
        public static func parse_reactionsNotifySettings(_ reader: BufferReader) -> ReactionsNotifySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ReactionNotificationsFrom?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
            } }
            var _3: Api.ReactionNotificationsFrom?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ReactionNotificationsFrom
            } }
            var _4: Api.NotificationSound?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.NotificationSound
            }
            var _5: Api.Bool?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ReactionsNotifySettings.reactionsNotifySettings(flags: _1!, messagesNotifyFrom: _2, storiesNotifyFrom: _3, sound: _4!, showPreviews: _5!)
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
