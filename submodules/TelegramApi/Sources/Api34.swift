public extension Api.messages {
    enum ForumTopics: TypeConstructorDescription {
        case forumTopics(flags: Int32, count: Int32, topics: [Api.ForumTopic], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], pts: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .forumTopics(let flags, let count, let topics, let messages, let chats, let users, let pts):
                    if boxed {
                        buffer.appendInt32(913709011)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topics.count))
                    for item in topics {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .forumTopics(let flags, let count, let topics, let messages, let chats, let users, let pts):
                return ("forumTopics", [("flags", flags as Any), ("count", count as Any), ("topics", topics as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any), ("pts", pts as Any)])
    }
    }
    
        public static func parse_forumTopics(_ reader: BufferReader) -> ForumTopics? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.ForumTopics.forumTopics(flags: _1!, count: _2!, topics: _3!, messages: _4!, chats: _5!, users: _6!, pts: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum FoundStickerSets: TypeConstructorDescription {
        case foundStickerSets(hash: Int64, sets: [Api.StickerSetCovered])
        case foundStickerSetsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundStickerSets(let hash, let sets):
                    if boxed {
                        buffer.appendInt32(-1963942446)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    break
                case .foundStickerSetsNotModified:
                    if boxed {
                        buffer.appendInt32(223655517)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundStickerSets(let hash, let sets):
                return ("foundStickerSets", [("hash", hash as Any), ("sets", sets as Any)])
                case .foundStickerSetsNotModified:
                return ("foundStickerSetsNotModified", [])
    }
    }
    
        public static func parse_foundStickerSets(_ reader: BufferReader) -> FoundStickerSets? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundStickerSets.foundStickerSets(hash: _1!, sets: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_foundStickerSetsNotModified(_ reader: BufferReader) -> FoundStickerSets? {
            return Api.messages.FoundStickerSets.foundStickerSetsNotModified
        }
    
    }
}
public extension Api.messages {
    enum FoundStickers: TypeConstructorDescription {
        case foundStickers(flags: Int32, nextOffset: Int32?, hash: Int64, stickers: [Api.Document])
        case foundStickersNotModified(flags: Int32, nextOffset: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundStickers(let flags, let nextOffset, let hash, let stickers):
                    if boxed {
                        buffer.appendInt32(-2100698480)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextOffset!, buffer: buffer, boxed: false)}
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
                case .foundStickersNotModified(let flags, let nextOffset):
                    if boxed {
                        buffer.appendInt32(1611711796)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundStickers(let flags, let nextOffset, let hash, let stickers):
                return ("foundStickers", [("flags", flags as Any), ("nextOffset", nextOffset as Any), ("hash", hash as Any), ("stickers", stickers as Any)])
                case .foundStickersNotModified(let flags, let nextOffset):
                return ("foundStickersNotModified", [("flags", flags as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_foundStickers(_ reader: BufferReader) -> FoundStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.FoundStickers.foundStickers(flags: _1!, nextOffset: _2, hash: _3!, stickers: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_foundStickersNotModified(_ reader: BufferReader) -> FoundStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.messages.FoundStickers.foundStickersNotModified(flags: _1!, nextOffset: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum HighScores: TypeConstructorDescription {
        case highScores(scores: [Api.HighScore], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScores(let scores, let users):
                    if boxed {
                        buffer.appendInt32(-1707344487)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(scores.count))
                    for item in scores {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .highScores(let scores, let users):
                return ("highScores", [("scores", scores as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_highScores(_ reader: BufferReader) -> HighScores? {
            var _1: [Api.HighScore]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.HighScore.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.HighScores.highScores(scores: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum HistoryImport: TypeConstructorDescription {
        case historyImport(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .historyImport(let id):
                    if boxed {
                        buffer.appendInt32(375566091)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .historyImport(let id):
                return ("historyImport", [("id", id as Any)])
    }
    }
    
        public static func parse_historyImport(_ reader: BufferReader) -> HistoryImport? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.HistoryImport.historyImport(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum HistoryImportParsed: TypeConstructorDescription {
        case historyImportParsed(flags: Int32, title: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .historyImportParsed(let flags, let title):
                    if boxed {
                        buffer.appendInt32(1578088377)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .historyImportParsed(let flags, let title):
                return ("historyImportParsed", [("flags", flags as Any), ("title", title as Any)])
    }
    }
    
        public static func parse_historyImportParsed(_ reader: BufferReader) -> HistoryImportParsed? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 2) != 0 {_2 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.messages.HistoryImportParsed.historyImportParsed(flags: _1!, title: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum InactiveChats: TypeConstructorDescription {
        case inactiveChats(dates: [Int32], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inactiveChats(let dates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1456996667)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dates.count))
                    for item in dates {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inactiveChats(let dates, let chats, let users):
                return ("inactiveChats", [("dates", dates as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_inactiveChats(_ reader: BufferReader) -> InactiveChats? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
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
                return Api.messages.InactiveChats.inactiveChats(dates: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    indirect enum InvitedUsers: TypeConstructorDescription {
        case invitedUsers(updates: Api.Updates, missingInvitees: [Api.MissingInvitee])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .invitedUsers(let updates, let missingInvitees):
                    if boxed {
                        buffer.appendInt32(2136862630)
                    }
                    updates.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(missingInvitees.count))
                    for item in missingInvitees {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .invitedUsers(let updates, let missingInvitees):
                return ("invitedUsers", [("updates", updates as Any), ("missingInvitees", missingInvitees as Any)])
    }
    }
    
        public static func parse_invitedUsers(_ reader: BufferReader) -> InvitedUsers? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            var _2: [Api.MissingInvitee]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MissingInvitee.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.InvitedUsers.invitedUsers(updates: _1!, missingInvitees: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum MessageEditData: TypeConstructorDescription {
        case messageEditData(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageEditData(let flags):
                    if boxed {
                        buffer.appendInt32(649453030)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageEditData(let flags):
                return ("messageEditData", [("flags", flags as Any)])
    }
    }
    
        public static func parse_messageEditData(_ reader: BufferReader) -> MessageEditData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.MessageEditData.messageEditData(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum MessageReactionsList: TypeConstructorDescription {
        case messageReactionsList(flags: Int32, count: Int32, reactions: [Api.MessagePeerReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(834488621)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReactionsList(let flags, let count, let reactions, let chats, let users, let nextOffset):
                return ("messageReactionsList", [("flags", flags as Any), ("count", count as Any), ("reactions", reactions as Any), ("chats", chats as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_messageReactionsList(_ reader: BufferReader) -> MessageReactionsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessagePeerReaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerReaction.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.MessageReactionsList.messageReactionsList(flags: _1!, count: _2!, reactions: _3!, chats: _4!, users: _5!, nextOffset: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum MessageViews: TypeConstructorDescription {
        case messageViews(views: [Api.MessageViews], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageViews(let views, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1228606141)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(views.count))
                    for item in views {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageViews(let views, let chats, let users):
                return ("messageViews", [("views", views as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_messageViews(_ reader: BufferReader) -> MessageViews? {
            var _1: [Api.MessageViews]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageViews.self)
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
                return Api.messages.MessageViews.messageViews(views: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum Messages: TypeConstructorDescription {
        case channelMessages(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User])
        case messages(messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case messagesNotModified(count: Int32)
        case messagesSlice(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelMessages(let flags, let pts, let count, let offsetIdOffset, let messages, let topics, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-948520370)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(offsetIdOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topics.count))
                    for item in topics {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .messages(let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1938715001)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .messagesNotModified(let count):
                    if boxed {
                        buffer.appendInt32(1951620897)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
                case .messagesSlice(let flags, let count, let nextRate, let offsetIdOffset, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(978610270)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextRate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(offsetIdOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelMessages(let flags, let pts, let count, let offsetIdOffset, let messages, let topics, let chats, let users):
                return ("channelMessages", [("flags", flags as Any), ("pts", pts as Any), ("count", count as Any), ("offsetIdOffset", offsetIdOffset as Any), ("messages", messages as Any), ("topics", topics as Any), ("chats", chats as Any), ("users", users as Any)])
                case .messages(let messages, let chats, let users):
                return ("messages", [("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
                case .messagesNotModified(let count):
                return ("messagesNotModified", [("count", count as Any)])
                case .messagesSlice(let flags, let count, let nextRate, let offsetIdOffset, let messages, let chats, let users):
                return ("messagesSlice", [("flags", flags as Any), ("count", count as Any), ("nextRate", nextRate as Any), ("offsetIdOffset", offsetIdOffset as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_channelMessages(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: [Api.Message]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _6: [Api.ForumTopic]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ForumTopic.self)
            }
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
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.messages.Messages.channelMessages(flags: _1!, pts: _2!, count: _3!, offsetIdOffset: _4, messages: _5!, topics: _6!, chats: _7!, users: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_messages(_ reader: BufferReader) -> Messages? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
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
                return Api.messages.Messages.messages(messages: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messagesNotModified(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.Messages.messagesNotModified(count: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messagesSlice(_ reader: BufferReader) -> Messages? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            var _5: [Api.Message]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.Messages.messagesSlice(flags: _1!, count: _2!, nextRate: _3, offsetIdOffset: _4, messages: _5!, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum MyStickers: TypeConstructorDescription {
        case myStickers(count: Int32, sets: [Api.StickerSetCovered])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .myStickers(let count, let sets):
                    if boxed {
                        buffer.appendInt32(-83926371)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .myStickers(let count, let sets):
                return ("myStickers", [("count", count as Any), ("sets", sets as Any)])
    }
    }
    
        public static func parse_myStickers(_ reader: BufferReader) -> MyStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.MyStickers.myStickers(count: _1!, sets: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum PeerDialogs: TypeConstructorDescription {
        case peerDialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerDialogs(let dialogs, let messages, let chats, let users, let state):
                    if boxed {
                        buffer.appendInt32(863093588)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    state.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerDialogs(let dialogs, let messages, let chats, let users, let state):
                return ("peerDialogs", [("dialogs", dialogs as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any), ("state", state as Any)])
    }
    }
    
        public static func parse_peerDialogs(_ reader: BufferReader) -> PeerDialogs? {
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
            var _5: Api.updates.State?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.PeerDialogs.peerDialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!, state: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum PeerSettings: TypeConstructorDescription {
        case peerSettings(settings: Api.PeerSettings, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .peerSettings(let settings, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1753266509)
                    }
                    settings.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .peerSettings(let settings, let chats, let users):
                return ("peerSettings", [("settings", settings as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_peerSettings(_ reader: BufferReader) -> PeerSettings? {
            var _1: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerSettings
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
                return Api.messages.PeerSettings.peerSettings(settings: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum PreparedInlineMessage: TypeConstructorDescription {
        case preparedInlineMessage(queryId: Int64, result: Api.BotInlineResult, peerTypes: [Api.InlineQueryPeerType], cacheTime: Int32, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .preparedInlineMessage(let queryId, let result, let peerTypes, let cacheTime, let users):
                    if boxed {
                        buffer.appendInt32(-11046771)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    result.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerTypes.count))
                    for item in peerTypes {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(cacheTime, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .preparedInlineMessage(let queryId, let result, let peerTypes, let cacheTime, let users):
                return ("preparedInlineMessage", [("queryId", queryId as Any), ("result", result as Any), ("peerTypes", peerTypes as Any), ("cacheTime", cacheTime as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_preparedInlineMessage(_ reader: BufferReader) -> PreparedInlineMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.BotInlineResult?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotInlineResult
            }
            var _3: [Api.InlineQueryPeerType]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InlineQueryPeerType.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
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
                return Api.messages.PreparedInlineMessage.preparedInlineMessage(queryId: _1!, result: _2!, peerTypes: _3!, cacheTime: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum QuickReplies: TypeConstructorDescription {
        case quickReplies(quickReplies: [Api.QuickReply], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case quickRepliesNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .quickReplies(let quickReplies, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-963811691)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(quickReplies.count))
                    for item in quickReplies {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .quickRepliesNotModified:
                    if boxed {
                        buffer.appendInt32(1603398491)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .quickReplies(let quickReplies, let messages, let chats, let users):
                return ("quickReplies", [("quickReplies", quickReplies as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
                case .quickRepliesNotModified:
                return ("quickRepliesNotModified", [])
    }
    }
    
        public static func parse_quickReplies(_ reader: BufferReader) -> QuickReplies? {
            var _1: [Api.QuickReply]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.QuickReply.self)
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
                return Api.messages.QuickReplies.quickReplies(quickReplies: _1!, messages: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_quickRepliesNotModified(_ reader: BufferReader) -> QuickReplies? {
            return Api.messages.QuickReplies.quickRepliesNotModified
        }
    
    }
}
public extension Api.messages {
    enum Reactions: TypeConstructorDescription {
        case reactions(hash: Int64, reactions: [Api.Reaction])
        case reactionsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .reactions(let hash, let reactions):
                    if boxed {
                        buffer.appendInt32(-352454890)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    break
                case .reactionsNotModified:
                    if boxed {
                        buffer.appendInt32(-1334846497)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .reactions(let hash, let reactions):
                return ("reactions", [("hash", hash as Any), ("reactions", reactions as Any)])
                case .reactionsNotModified:
                return ("reactionsNotModified", [])
    }
    }
    
        public static func parse_reactions(_ reader: BufferReader) -> Reactions? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Reactions.reactions(hash: _1!, reactions: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_reactionsNotModified(_ reader: BufferReader) -> Reactions? {
            return Api.messages.Reactions.reactionsNotModified
        }
    
    }
}
public extension Api.messages {
    enum RecentStickers: TypeConstructorDescription {
        case recentStickers(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32])
        case recentStickersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentStickers(let hash, let packs, let stickers, let dates):
                    if boxed {
                        buffer.appendInt32(-1999405994)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dates.count))
                    for item in dates {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .recentStickersNotModified:
                    if boxed {
                        buffer.appendInt32(186120336)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .recentStickers(let hash, let packs, let stickers, let dates):
                return ("recentStickers", [("hash", hash as Any), ("packs", packs as Any), ("stickers", stickers as Any), ("dates", dates as Any)])
                case .recentStickersNotModified:
                return ("recentStickersNotModified", [])
    }
    }
    
        public static func parse_recentStickers(_ reader: BufferReader) -> RecentStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            var _4: [Int32]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.RecentStickers.recentStickers(hash: _1!, packs: _2!, stickers: _3!, dates: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_recentStickersNotModified(_ reader: BufferReader) -> RecentStickers? {
            return Api.messages.RecentStickers.recentStickersNotModified
        }
    
    }
}
public extension Api.messages {
    enum SavedDialogs: TypeConstructorDescription {
        case savedDialogs(dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case savedDialogsNotModified(count: Int32)
        case savedDialogsSlice(count: Int32, dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedDialogs(let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-130358751)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .savedDialogsNotModified(let count):
                    if boxed {
                        buffer.appendInt32(-1071681560)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
                case .savedDialogsSlice(let count, let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1153080793)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dialogs.count))
                    for item in dialogs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedDialogs(let dialogs, let messages, let chats, let users):
                return ("savedDialogs", [("dialogs", dialogs as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
                case .savedDialogsNotModified(let count):
                return ("savedDialogsNotModified", [("count", count as Any)])
                case .savedDialogsSlice(let count, let dialogs, let messages, let chats, let users):
                return ("savedDialogsSlice", [("count", count as Any), ("dialogs", dialogs as Any), ("messages", messages as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_savedDialogs(_ reader: BufferReader) -> SavedDialogs? {
            var _1: [Api.SavedDialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedDialog.self)
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
                return Api.messages.SavedDialogs.savedDialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_savedDialogsNotModified(_ reader: BufferReader) -> SavedDialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.SavedDialogs.savedDialogsNotModified(count: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_savedDialogsSlice(_ reader: BufferReader) -> SavedDialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SavedDialog]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedDialog.self)
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
                return Api.messages.SavedDialogs.savedDialogsSlice(count: _1!, dialogs: _2!, messages: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum SavedGifs: TypeConstructorDescription {
        case savedGifs(hash: Int64, gifs: [Api.Document])
        case savedGifsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedGifs(let hash, let gifs):
                    if boxed {
                        buffer.appendInt32(-2069878259)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifs.count))
                    for item in gifs {
                        item.serialize(buffer, true)
                    }
                    break
                case .savedGifsNotModified:
                    if boxed {
                        buffer.appendInt32(-402498398)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedGifs(let hash, let gifs):
                return ("savedGifs", [("hash", hash as Any), ("gifs", gifs as Any)])
                case .savedGifsNotModified:
                return ("savedGifsNotModified", [])
    }
    }
    
        public static func parse_savedGifs(_ reader: BufferReader) -> SavedGifs? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SavedGifs.savedGifs(hash: _1!, gifs: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_savedGifsNotModified(_ reader: BufferReader) -> SavedGifs? {
            return Api.messages.SavedGifs.savedGifsNotModified
        }
    
    }
}
