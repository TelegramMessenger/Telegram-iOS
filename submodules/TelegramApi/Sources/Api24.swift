public extension Api.messages {
    enum DhConfig: TypeConstructorDescription {
        case dhConfig(g: Int32, p: Buffer, version: Int32, random: Buffer)
        case dhConfigNotModified(random: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dhConfig(let g, let p, let version, let random):
                    if boxed {
                        buffer.appendInt32(740433629)
                    }
                    serializeInt32(g, buffer: buffer, boxed: false)
                    serializeBytes(p, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    serializeBytes(random, buffer: buffer, boxed: false)
                    break
                case .dhConfigNotModified(let random):
                    if boxed {
                        buffer.appendInt32(-1058912715)
                    }
                    serializeBytes(random, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .dhConfig(let g, let p, let version, let random):
                return ("dhConfig", [("g", String(describing: g)), ("p", String(describing: p)), ("version", String(describing: version)), ("random", String(describing: random))])
                case .dhConfigNotModified(let random):
                return ("dhConfigNotModified", [("random", String(describing: random))])
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
                return Api.messages.DhConfig.dhConfig(g: _1!, p: _2!, version: _3!, random: _4!)
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
                return Api.messages.DhConfig.dhConfigNotModified(random: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum Dialogs: TypeConstructorDescription {
        case dialogs(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case dialogsNotModified(count: Int32)
        case dialogsSlice(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .dialogs(let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(364538944)
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
                case .dialogsNotModified(let count):
                    if boxed {
                        buffer.appendInt32(-253500010)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
                case .dialogsSlice(let count, let dialogs, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1910543603)
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
                case .dialogs(let dialogs, let messages, let chats, let users):
                return ("dialogs", [("dialogs", String(describing: dialogs)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
                case .dialogsNotModified(let count):
                return ("dialogsNotModified", [("count", String(describing: count))])
                case .dialogsSlice(let count, let dialogs, let messages, let chats, let users):
                return ("dialogsSlice", [("count", String(describing: count)), ("dialogs", String(describing: dialogs)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
                return Api.messages.Dialogs.dialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!)
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
                return Api.messages.Dialogs.dialogsNotModified(count: _1!)
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
                return Api.messages.Dialogs.dialogsSlice(count: _1!, dialogs: _2!, messages: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum DiscussionMessage: TypeConstructorDescription {
        case discussionMessage(flags: Int32, messages: [Api.Message], maxId: Int32?, readInboxMaxId: Int32?, readOutboxMaxId: Int32?, unreadCount: Int32, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .discussionMessage(let flags, let messages, let maxId, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1506535550)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(maxId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(readInboxMaxId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(readOutboxMaxId!, buffer: buffer, boxed: false)}
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
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
                case .discussionMessage(let flags, let messages, let maxId, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chats, let users):
                return ("discussionMessage", [("flags", String(describing: flags)), ("messages", String(describing: messages)), ("maxId", String(describing: maxId)), ("readInboxMaxId", String(describing: readInboxMaxId)), ("readOutboxMaxId", String(describing: readOutboxMaxId)), ("unreadCount", String(describing: unreadCount)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
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
                return Api.messages.DiscussionMessage.discussionMessage(flags: _1!, messages: _2!, maxId: _3, readInboxMaxId: _4, readOutboxMaxId: _5, unreadCount: _6!, chats: _7!, users: _8!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum ExportedChatInvite: TypeConstructorDescription {
        case exportedChatInvite(invite: Api.ExportedChatInvite, users: [Api.User])
        case exportedChatInviteReplaced(invite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedChatInvite(let invite, let users):
                    if boxed {
                        buffer.appendInt32(410107472)
                    }
                    invite.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .exportedChatInviteReplaced(let invite, let newInvite, let users):
                    if boxed {
                        buffer.appendInt32(572915951)
                    }
                    invite.serialize(buffer, true)
                    newInvite.serialize(buffer, true)
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
                case .exportedChatInvite(let invite, let users):
                return ("exportedChatInvite", [("invite", String(describing: invite)), ("users", String(describing: users))])
                case .exportedChatInviteReplaced(let invite, let newInvite, let users):
                return ("exportedChatInviteReplaced", [("invite", String(describing: invite)), ("newInvite", String(describing: newInvite)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_exportedChatInvite(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.ExportedChatInvite.exportedChatInvite(invite: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_exportedChatInviteReplaced(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ExportedChatInvite.exportedChatInviteReplaced(invite: _1!, newInvite: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum ExportedChatInvites: TypeConstructorDescription {
        case exportedChatInvites(count: Int32, invites: [Api.ExportedChatInvite], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedChatInvites(let count, let invites, let users):
                    if boxed {
                        buffer.appendInt32(-1111085620)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(invites.count))
                    for item in invites {
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
                case .exportedChatInvites(let count, let invites, let users):
                return ("exportedChatInvites", [("count", String(describing: count)), ("invites", String(describing: invites)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_exportedChatInvites(_ reader: BufferReader) -> ExportedChatInvites? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ExportedChatInvite]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ExportedChatInvite.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.ExportedChatInvites.exportedChatInvites(count: _1!, invites: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum FavedStickers: TypeConstructorDescription {
        case favedStickers(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document])
        case favedStickersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .favedStickers(let hash, let packs, let stickers):
                    if boxed {
                        buffer.appendInt32(750063767)
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
                    break
                case .favedStickersNotModified:
                    if boxed {
                        buffer.appendInt32(-1634752813)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .favedStickers(let hash, let packs, let stickers):
                return ("favedStickers", [("hash", String(describing: hash)), ("packs", String(describing: packs)), ("stickers", String(describing: stickers))])
                case .favedStickersNotModified:
                return ("favedStickersNotModified", [])
    }
    }
    
        public static func parse_favedStickers(_ reader: BufferReader) -> FavedStickers? {
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.FavedStickers.favedStickers(hash: _1!, packs: _2!, stickers: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_favedStickersNotModified(_ reader: BufferReader) -> FavedStickers? {
            return Api.messages.FavedStickers.favedStickersNotModified
        }
    
    }
}
public extension Api.messages {
    enum FeaturedStickers: TypeConstructorDescription {
        case featuredStickers(hash: Int64, count: Int32, sets: [Api.StickerSetCovered], unread: [Int64])
        case featuredStickersNotModified(count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .featuredStickers(let hash, let count, let sets, let unread):
                    if boxed {
                        buffer.appendInt32(-2067782896)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(unread.count))
                    for item in unread {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .featuredStickersNotModified(let count):
                    if boxed {
                        buffer.appendInt32(-958657434)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .featuredStickers(let hash, let count, let sets, let unread):
                return ("featuredStickers", [("hash", String(describing: hash)), ("count", String(describing: count)), ("sets", String(describing: sets)), ("unread", String(describing: unread))])
                case .featuredStickersNotModified(let count):
                return ("featuredStickersNotModified", [("count", String(describing: count))])
    }
    }
    
        public static func parse_featuredStickers(_ reader: BufferReader) -> FeaturedStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            var _4: [Int64]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.FeaturedStickers.featuredStickers(hash: _1!, count: _2!, sets: _3!, unread: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_featuredStickersNotModified(_ reader: BufferReader) -> FeaturedStickers? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.FeaturedStickers.featuredStickersNotModified(count: _1!)
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
                return ("foundStickerSets", [("hash", String(describing: hash)), ("sets", String(describing: sets))])
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
                return ("highScores", [("scores", String(describing: scores)), ("users", String(describing: users))])
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
                return ("historyImport", [("id", String(describing: id))])
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
                return ("historyImportParsed", [("flags", String(describing: flags)), ("title", String(describing: title))])
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
                return ("inactiveChats", [("dates", String(describing: dates)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
                return ("messageEditData", [("flags", String(describing: flags))])
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
                return ("messageReactionsList", [("flags", String(describing: flags)), ("count", String(describing: count)), ("reactions", String(describing: reactions)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("nextOffset", String(describing: nextOffset))])
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
                return ("messageViews", [("views", String(describing: views)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
        case channelMessages(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case messages(messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
        case messagesNotModified(count: Int32)
        case messagesSlice(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelMessages(let flags, let pts, let count, let offsetIdOffset, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1682413576)
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
                case .channelMessages(let flags, let pts, let count, let offsetIdOffset, let messages, let chats, let users):
                return ("channelMessages", [("flags", String(describing: flags)), ("pts", String(describing: pts)), ("count", String(describing: count)), ("offsetIdOffset", String(describing: offsetIdOffset)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
                case .messages(let messages, let chats, let users):
                return ("messages", [("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
                case .messagesNotModified(let count):
                return ("messagesNotModified", [("count", String(describing: count))])
                case .messagesSlice(let flags, let count, let nextRate, let offsetIdOffset, let messages, let chats, let users):
                return ("messagesSlice", [("flags", String(describing: flags)), ("count", String(describing: count)), ("nextRate", String(describing: nextRate)), ("offsetIdOffset", String(describing: offsetIdOffset)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.Messages.channelMessages(flags: _1!, pts: _2!, count: _3!, offsetIdOffset: _4, messages: _5!, chats: _6!, users: _7!)
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
                return ("peerDialogs", [("dialogs", String(describing: dialogs)), ("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("state", String(describing: state))])
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
                return ("peerSettings", [("settings", String(describing: settings)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
                return ("recentStickers", [("hash", String(describing: hash)), ("packs", String(describing: packs)), ("stickers", String(describing: stickers)), ("dates", String(describing: dates))])
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
                return ("savedGifs", [("hash", String(describing: hash)), ("gifs", String(describing: gifs))])
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
