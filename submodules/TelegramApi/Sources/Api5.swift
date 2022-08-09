public extension Api {
    enum EmojiKeyword: TypeConstructorDescription {
        case emojiKeyword(keyword: String, emoticons: [String])
        case emojiKeywordDeleted(keyword: String, emoticons: [String])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeyword(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(-709641735)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .emojiKeywordDeleted(let keyword, let emoticons):
                    if boxed {
                        buffer.appendInt32(594408994)
                    }
                    serializeString(keyword, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(emoticons.count))
                    for item in emoticons {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeyword(let keyword, let emoticons):
                return ("emojiKeyword", [("keyword", String(describing: keyword)), ("emoticons", String(describing: emoticons))])
                case .emojiKeywordDeleted(let keyword, let emoticons):
                return ("emojiKeywordDeleted", [("keyword", String(describing: keyword)), ("emoticons", String(describing: emoticons))])
    }
    }
    
        public static func parse_emojiKeyword(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeyword(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiKeywordDeleted(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeywordDeleted(keyword: _1!, emoticons: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiKeywordsDifference: TypeConstructorDescription {
        case emojiKeywordsDifference(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                    if boxed {
                        buffer.appendInt32(1556570557)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiKeywordsDifference(let langCode, let fromVersion, let version, let keywords):
                return ("emojiKeywordsDifference", [("langCode", String(describing: langCode)), ("fromVersion", String(describing: fromVersion)), ("version", String(describing: version)), ("keywords", String(describing: keywords))])
    }
    }
    
        public static func parse_emojiKeywordsDifference(_ reader: BufferReader) -> EmojiKeywordsDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.EmojiKeyword]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiKeyword.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EmojiKeywordsDifference.emojiKeywordsDifference(langCode: _1!, fromVersion: _2!, version: _3!, keywords: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiLanguage: TypeConstructorDescription {
        case emojiLanguage(langCode: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiLanguage(let langCode):
                    if boxed {
                        buffer.appendInt32(-1275374751)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiLanguage(let langCode):
                return ("emojiLanguage", [("langCode", String(describing: langCode))])
    }
    }
    
        public static func parse_emojiLanguage(_ reader: BufferReader) -> EmojiLanguage? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiLanguage.emojiLanguage(langCode: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmojiURL: TypeConstructorDescription {
        case emojiURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiURL(let url):
                    if boxed {
                        buffer.appendInt32(-1519029347)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiURL(let url):
                return ("emojiURL", [("url", String(describing: url))])
    }
    }
    
        public static func parse_emojiURL(_ reader: BufferReader) -> EmojiURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiURL.emojiURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EncryptedChat: TypeConstructorDescription {
        case encryptedChat(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gAOrB: Buffer, keyFingerprint: Int64)
        case encryptedChatDiscarded(flags: Int32, id: Int32)
        case encryptedChatEmpty(id: Int32)
        case encryptedChatRequested(flags: Int32, folderId: Int32?, id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64, gA: Buffer)
        case encryptedChatWaiting(id: Int32, accessHash: Int64, date: Int32, adminId: Int64, participantId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1643173063)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gAOrB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .encryptedChatDiscarded(let flags, let id):
                    if boxed {
                        buffer.appendInt32(505183301)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .encryptedChatEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-1417756512)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .encryptedChatRequested(let flags, let folderId, let id, let accessHash, let date, let adminId, let participantId, let gA):
                    if boxed {
                        buffer.appendInt32(1223809356)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    break
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                    if boxed {
                        buffer.appendInt32(1722964307)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt64(participantId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                return ("encryptedChat", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("date", String(describing: date)), ("adminId", String(describing: adminId)), ("participantId", String(describing: participantId)), ("gAOrB", String(describing: gAOrB)), ("keyFingerprint", String(describing: keyFingerprint))])
                case .encryptedChatDiscarded(let flags, let id):
                return ("encryptedChatDiscarded", [("flags", String(describing: flags)), ("id", String(describing: id))])
                case .encryptedChatEmpty(let id):
                return ("encryptedChatEmpty", [("id", String(describing: id))])
                case .encryptedChatRequested(let flags, let folderId, let id, let accessHash, let date, let adminId, let participantId, let gA):
                return ("encryptedChatRequested", [("flags", String(describing: flags)), ("folderId", String(describing: folderId)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("date", String(describing: date)), ("adminId", String(describing: adminId)), ("participantId", String(describing: participantId)), ("gA", String(describing: gA))])
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                return ("encryptedChatWaiting", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("date", String(describing: date)), ("adminId", String(describing: adminId)), ("participantId", String(describing: participantId))])
    }
    }
    
        public static func parse_encryptedChat(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.EncryptedChat.encryptedChat(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gAOrB: _6!, keyFingerprint: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatDiscarded(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EncryptedChat.encryptedChatDiscarded(flags: _1!, id: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatEmpty(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.EncryptedChat.encryptedChatEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatRequested(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Buffer?
            _8 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.EncryptedChat.encryptedChatRequested(flags: _1!, folderId: _2, id: _3!, accessHash: _4!, date: _5!, adminId: _6!, participantId: _7!, gA: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedChatWaiting(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedChat.encryptedChatWaiting(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EncryptedFile: TypeConstructorDescription {
        case encryptedFile(id: Int64, accessHash: Int64, size: Int32, dcId: Int32, keyFingerprint: Int32)
        case encryptedFileEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedFile(let id, let accessHash, let size, let dcId, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1248893260)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt32(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .encryptedFileEmpty:
                    if boxed {
                        buffer.appendInt32(-1038136962)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedFile(let id, let accessHash, let size, let dcId, let keyFingerprint):
                return ("encryptedFile", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("size", String(describing: size)), ("dcId", String(describing: dcId)), ("keyFingerprint", String(describing: keyFingerprint))])
                case .encryptedFileEmpty:
                return ("encryptedFileEmpty", [])
    }
    }
    
        public static func parse_encryptedFile(_ reader: BufferReader) -> EncryptedFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedFile.encryptedFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, keyFingerprint: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedFileEmpty(_ reader: BufferReader) -> EncryptedFile? {
            return Api.EncryptedFile.encryptedFileEmpty
        }
    
    }
}
public extension Api {
    enum EncryptedMessage: TypeConstructorDescription {
        case encryptedMessage(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile)
        case encryptedMessageService(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedMessage(let randomId, let chatId, let date, let bytes, let file):
                    if boxed {
                        buffer.appendInt32(-317144808)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    file.serialize(buffer, true)
                    break
                case .encryptedMessageService(let randomId, let chatId, let date, let bytes):
                    if boxed {
                        buffer.appendInt32(594758406)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .encryptedMessage(let randomId, let chatId, let date, let bytes, let file):
                return ("encryptedMessage", [("randomId", String(describing: randomId)), ("chatId", String(describing: chatId)), ("date", String(describing: date)), ("bytes", String(describing: bytes)), ("file", String(describing: file))])
                case .encryptedMessageService(let randomId, let chatId, let date, let bytes):
                return ("encryptedMessageService", [("randomId", String(describing: randomId)), ("chatId", String(describing: chatId)), ("date", String(describing: date)), ("bytes", String(describing: bytes))])
    }
    }
    
        public static func parse_encryptedMessage(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.EncryptedFile?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.EncryptedFile
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.EncryptedMessage.encryptedMessage(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!, file: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_encryptedMessageService(_ reader: BufferReader) -> EncryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EncryptedMessage.encryptedMessageService(randomId: _1!, chatId: _2!, date: _3!, bytes: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ExportedChatInvite: TypeConstructorDescription {
        case chatInviteExported(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, title: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInviteExported(let flags, let link, let adminId, let date, let startDate, let expireDate, let usageLimit, let usage, let requested, let title):
                    if boxed {
                        buffer.appendInt32(179611673)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(link, buffer: buffer, boxed: false)
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(startDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(expireDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(usageLimit!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(usage!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(requested!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInviteExported(let flags, let link, let adminId, let date, let startDate, let expireDate, let usageLimit, let usage, let requested, let title):
                return ("chatInviteExported", [("flags", String(describing: flags)), ("link", String(describing: link)), ("adminId", String(describing: adminId)), ("date", String(describing: date)), ("startDate", String(describing: startDate)), ("expireDate", String(describing: expireDate)), ("usageLimit", String(describing: usageLimit)), ("usage", String(describing: usage)), ("requested", String(describing: requested)), ("title", String(describing: title))])
    }
    }
    
        public static func parse_chatInviteExported(_ reader: BufferReader) -> ExportedChatInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_9 = reader.readInt32() }
            var _10: String?
            if Int(_1!) & Int(1 << 8) != 0 {_10 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 8) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.ExportedChatInvite.chatInviteExported(flags: _1!, link: _2!, adminId: _3!, date: _4!, startDate: _5, expireDate: _6, usageLimit: _7, usage: _8, requested: _9, title: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ExportedMessageLink: TypeConstructorDescription {
        case exportedMessageLink(link: String, html: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedMessageLink(let link, let html):
                    if boxed {
                        buffer.appendInt32(1571494644)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    serializeString(html, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedMessageLink(let link, let html):
                return ("exportedMessageLink", [("link", String(describing: link)), ("html", String(describing: html))])
    }
    }
    
        public static func parse_exportedMessageLink(_ reader: BufferReader) -> ExportedMessageLink? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ExportedMessageLink.exportedMessageLink(link: _1!, html: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum FileHash: TypeConstructorDescription {
        case fileHash(offset: Int32, limit: Int32, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileHash(let offset, let limit, let hash):
                    if boxed {
                        buffer.appendInt32(1648543603)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(limit, buffer: buffer, boxed: false)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .fileHash(let offset, let limit, let hash):
                return ("fileHash", [("offset", String(describing: offset)), ("limit", String(describing: limit)), ("hash", String(describing: hash))])
    }
    }
    
        public static func parse_fileHash(_ reader: BufferReader) -> FileHash? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.FileHash.fileHash(offset: _1!, limit: _2!, hash: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Folder: TypeConstructorDescription {
        case folder(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .folder(let flags, let id, let title, let photo):
                    if boxed {
                        buffer.appendInt32(-11252123)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {photo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .folder(let flags, let id, let title, let photo):
                return ("folder", [("flags", String(describing: flags)), ("id", String(describing: id)), ("title", String(describing: title)), ("photo", String(describing: photo))])
    }
    }
    
        public static func parse_folder(_ reader: BufferReader) -> Folder? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatPhoto?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Folder.folder(flags: _1!, id: _2!, title: _3!, photo: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum FolderPeer: TypeConstructorDescription {
        case folderPeer(peer: Api.Peer, folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .folderPeer(let peer, let folderId):
                    if boxed {
                        buffer.appendInt32(-373643672)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .folderPeer(let peer, let folderId):
                return ("folderPeer", [("peer", String(describing: peer)), ("folderId", String(describing: folderId))])
    }
    }
    
        public static func parse_folderPeer(_ reader: BufferReader) -> FolderPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.FolderPeer.folderPeer(peer: _1!, folderId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Game: TypeConstructorDescription {
        case game(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .game(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document):
                    if boxed {
                        buffer.appendInt32(-1107729093)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {document!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .game(let flags, let id, let accessHash, let shortName, let title, let description, let photo, let document):
                return ("game", [("flags", String(describing: flags)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("shortName", String(describing: shortName)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("document", String(describing: document))])
    }
    }
    
        public static func parse_game(_ reader: BufferReader) -> Game? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.Photo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Game.game(flags: _1!, id: _2!, accessHash: _3!, shortName: _4!, title: _5!, description: _6!, photo: _7!, document: _8)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GeoPoint: TypeConstructorDescription {
        case geoPoint(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?)
        case geoPointEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .geoPoint(let flags, let long, let lat, let accessHash, let accuracyRadius):
                    if boxed {
                        buffer.appendInt32(-1297942941)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(accuracyRadius!, buffer: buffer, boxed: false)}
                    break
                case .geoPointEmpty:
                    if boxed {
                        buffer.appendInt32(286776671)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .geoPoint(let flags, let long, let lat, let accessHash, let accuracyRadius):
                return ("geoPoint", [("flags", String(describing: flags)), ("long", String(describing: long)), ("lat", String(describing: lat)), ("accessHash", String(describing: accessHash)), ("accuracyRadius", String(describing: accuracyRadius))])
                case .geoPointEmpty:
                return ("geoPointEmpty", [])
    }
    }
    
        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPoint.geoPoint(flags: _1!, long: _2!, lat: _3!, accessHash: _4!, accuracyRadius: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return Api.GeoPoint.geoPointEmpty
        }
    
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        case globalPrivacySettings(flags: Int32, archiveAndMuteNewNoncontactPeers: Api.Bool?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .globalPrivacySettings(let flags, let archiveAndMuteNewNoncontactPeers):
                    if boxed {
                        buffer.appendInt32(-1096616924)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {archiveAndMuteNewNoncontactPeers!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .globalPrivacySettings(let flags, let archiveAndMuteNewNoncontactPeers):
                return ("globalPrivacySettings", [("flags", String(describing: flags)), ("archiveAndMuteNewNoncontactPeers", String(describing: archiveAndMuteNewNoncontactPeers))])
    }
    }
    
        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.GlobalPrivacySettings.globalPrivacySettings(flags: _1!, archiveAndMuteNewNoncontactPeers: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32)
        case groupCallDiscarded(id: Int64, accessHash: Int64, duration: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version):
                    if boxed {
                        buffer.appendInt32(-711498484)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(streamDcId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(recordStartDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(unmutedVideoCount!, buffer: buffer, boxed: false)}
                    serializeInt32(unmutedVideoLimit, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .groupCallDiscarded(let id, let accessHash, let duration):
                    if boxed {
                        buffer.appendInt32(2004925620)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version):
                return ("groupCall", [("flags", String(describing: flags)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("participantsCount", String(describing: participantsCount)), ("title", String(describing: title)), ("streamDcId", String(describing: streamDcId)), ("recordStartDate", String(describing: recordStartDate)), ("scheduleDate", String(describing: scheduleDate)), ("unmutedVideoCount", String(describing: unmutedVideoCount)), ("unmutedVideoLimit", String(describing: unmutedVideoLimit)), ("version", String(describing: version))])
                case .groupCallDiscarded(let id, let accessHash, let duration):
                return ("groupCallDiscarded", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("duration", String(describing: duration))])
    }
    }
    
        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.GroupCall.groupCall(flags: _1!, id: _2!, accessHash: _3!, participantsCount: _4!, title: _5, streamDcId: _6, recordStartDate: _7, scheduleDate: _8, unmutedVideoCount: _9, unmutedVideoLimit: _10!, version: _11!)
            }
            else {
                return nil
            }
        }
        public static func parse_groupCallDiscarded(_ reader: BufferReader) -> GroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCall.groupCallDiscarded(id: _1!, accessHash: _2!, duration: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription {
        case groupCallParticipant(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipant(let flags, let peer, let date, let activeDate, let source, let volume, let about, let raiseHandRating, let video, let presentation):
                    if boxed {
                        buffer.appendInt32(-341428482)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(activeDate!, buffer: buffer, boxed: false)}
                    serializeInt32(source, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(volume!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt64(raiseHandRating!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {presentation!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipant(let flags, let peer, let date, let activeDate, let source, let volume, let about, let raiseHandRating, let video, let presentation):
                return ("groupCallParticipant", [("flags", String(describing: flags)), ("peer", String(describing: peer)), ("date", String(describing: date)), ("activeDate", String(describing: activeDate)), ("source", String(describing: source)), ("volume", String(describing: volume)), ("about", String(describing: about)), ("raiseHandRating", String(describing: raiseHandRating)), ("video", String(describing: video)), ("presentation", String(describing: presentation))])
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
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 11) != 0 {_7 = parseString(reader) }
            var _8: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {_8 = reader.readInt64() }
            var _9: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
            } }
            var _10: Api.GroupCallParticipantVideo?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
            } }
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.GroupCallParticipant.groupCallParticipant(flags: _1!, peer: _2!, date: _3!, activeDate: _4, source: _5!, volume: _6, about: _7, raiseHandRating: _8, video: _9, presentation: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription {
        case groupCallParticipantVideo(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipantVideo(let flags, let endpoint, let sourceGroups, let audioSource):
                    if boxed {
                        buffer.appendInt32(1735736008)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(endpoint, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sourceGroups.count))
                    for item in sourceGroups {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(audioSource!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipantVideo(let flags, let endpoint, let sourceGroups, let audioSource):
                return ("groupCallParticipantVideo", [("flags", String(describing: flags)), ("endpoint", String(describing: endpoint)), ("sourceGroups", String(describing: sourceGroups)), ("audioSource", String(describing: audioSource))])
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
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.GroupCallParticipantVideo.groupCallParticipantVideo(flags: _1!, endpoint: _2!, sourceGroups: _3!, audioSource: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        case groupCallParticipantVideoSourceGroup(semantics: String, sources: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                    if boxed {
                        buffer.appendInt32(-592373577)
                    }
                    serializeString(semantics, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sources.count))
                    for item in sources {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                return ("groupCallParticipantVideoSourceGroup", [("semantics", String(describing: semantics)), ("sources", String(describing: sources))])
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
                return Api.GroupCallParticipantVideoSourceGroup.groupCallParticipantVideoSourceGroup(semantics: _1!, sources: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        case groupCallStreamChannel(channel: Int32, scale: Int32, lastTimestampMs: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                    if boxed {
                        buffer.appendInt32(-2132064081)
                    }
                    serializeInt32(channel, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    serializeInt64(lastTimestampMs, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                return ("groupCallStreamChannel", [("channel", String(describing: channel)), ("scale", String(describing: scale)), ("lastTimestampMs", String(describing: lastTimestampMs))])
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
                return Api.GroupCallStreamChannel.groupCallStreamChannel(channel: _1!, scale: _2!, lastTimestampMs: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        case highScore(pos: Int32, userId: Int64, score: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScore(let pos, let userId, let score):
                    if boxed {
                        buffer.appendInt32(1940093419)
                    }
                    serializeInt32(pos, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .highScore(let pos, let userId, let score):
                return ("highScore", [("pos", String(describing: pos)), ("userId", String(describing: userId)), ("score", String(describing: score))])
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
                return Api.HighScore.highScore(pos: _1!, userId: _2!, score: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        case importedContact(userId: Int64, clientId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .importedContact(let userId, let clientId):
                    if boxed {
                        buffer.appendInt32(-1052885936)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .importedContact(let userId, let clientId):
                return ("importedContact", [("userId", String(describing: userId)), ("clientId", String(describing: clientId))])
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
                return Api.ImportedContact.importedContact(userId: _1!, clientId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
        case inlineBotSwitchPM(text: String, startParam: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                    if boxed {
                        buffer.appendInt32(1008755359)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                return ("inlineBotSwitchPM", [("text", String(describing: text)), ("startParam", String(describing: startParam))])
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
                return Api.InlineBotSwitchPM.inlineBotSwitchPM(text: _1!, startParam: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
