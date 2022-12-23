public extension Api {
    enum DraftMessage: TypeConstructorDescription {
        case draftMessage(flags: Int32, replyToMsgId: Int32?, message: String, entities: [Api.MessageEntity]?, date: Int32)
        case draftMessageEmpty(flags: Int32, date: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .draftMessage(let flags, let replyToMsgId, let message, let entities, let date):
                    if boxed {
                        buffer.appendInt32(-40996577)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .draftMessageEmpty(let flags, let date):
                    if boxed {
                        buffer.appendInt32(453805082)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(date!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .draftMessage(let flags, let replyToMsgId, let message, let entities, let date):
                return ("draftMessage", [("flags", String(describing: flags)), ("replyToMsgId", String(describing: replyToMsgId)), ("message", String(describing: message)), ("entities", String(describing: entities)), ("date", String(describing: date))])
                case .draftMessageEmpty(let flags, let date):
                return ("draftMessageEmpty", [("flags", String(describing: flags)), ("date", String(describing: date))])
    }
    }
    
        public static func parse_draftMessage(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DraftMessage.draftMessage(flags: _1!, replyToMsgId: _2, message: _3!, entities: _4, date: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_draftMessageEmpty(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.DraftMessage.draftMessageEmpty(flags: _1!, date: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmailVerification: TypeConstructorDescription {
        case emailVerificationApple(token: String)
        case emailVerificationCode(code: String)
        case emailVerificationGoogle(token: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emailVerificationApple(let token):
                    if boxed {
                        buffer.appendInt32(-1764723459)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
                case .emailVerificationCode(let code):
                    if boxed {
                        buffer.appendInt32(-1842457175)
                    }
                    serializeString(code, buffer: buffer, boxed: false)
                    break
                case .emailVerificationGoogle(let token):
                    if boxed {
                        buffer.appendInt32(-611279166)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emailVerificationApple(let token):
                return ("emailVerificationApple", [("token", String(describing: token))])
                case .emailVerificationCode(let code):
                return ("emailVerificationCode", [("code", String(describing: code))])
                case .emailVerificationGoogle(let token):
                return ("emailVerificationGoogle", [("token", String(describing: token))])
    }
    }
    
        public static func parse_emailVerificationApple(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationApple(token: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationCode(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationCode(code: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationGoogle(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationGoogle(token: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum EmailVerifyPurpose: TypeConstructorDescription {
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(phoneNumber: String, phoneCodeHash: String)
        case emailVerifyPurposePassport
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emailVerifyPurposeLoginChange:
                    if boxed {
                        buffer.appendInt32(1383932651)
                    }
                    
                    break
                case .emailVerifyPurposeLoginSetup(let phoneNumber, let phoneCodeHash):
                    if boxed {
                        buffer.appendInt32(1128644211)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    break
                case .emailVerifyPurposePassport:
                    if boxed {
                        buffer.appendInt32(-1141565819)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emailVerifyPurposeLoginChange:
                return ("emailVerifyPurposeLoginChange", [])
                case .emailVerifyPurposeLoginSetup(let phoneNumber, let phoneCodeHash):
                return ("emailVerifyPurposeLoginSetup", [("phoneNumber", String(describing: phoneNumber)), ("phoneCodeHash", String(describing: phoneCodeHash))])
                case .emailVerifyPurposePassport:
                return ("emailVerifyPurposePassport", [])
    }
    }
    
        public static func parse_emailVerifyPurposeLoginChange(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposeLoginChange
        }
        public static func parse_emailVerifyPurposeLoginSetup(_ reader: BufferReader) -> EmailVerifyPurpose? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmailVerifyPurpose.emailVerifyPurposeLoginSetup(phoneNumber: _1!, phoneCodeHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerifyPurposePassport(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposePassport
        }
    
    }
}
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
    enum EmojiStatus: TypeConstructorDescription {
        case emojiStatus(documentId: Int64)
        case emojiStatusEmpty
        case emojiStatusUntil(documentId: Int64, until: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiStatus(let documentId):
                    if boxed {
                        buffer.appendInt32(-1835310691)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
                case .emojiStatusEmpty:
                    if boxed {
                        buffer.appendInt32(769727150)
                    }
                    
                    break
                case .emojiStatusUntil(let documentId, let until):
                    if boxed {
                        buffer.appendInt32(-97474361)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    serializeInt32(until, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiStatus(let documentId):
                return ("emojiStatus", [("documentId", String(describing: documentId))])
                case .emojiStatusEmpty:
                return ("emojiStatusEmpty", [])
                case .emojiStatusUntil(let documentId, let until):
                return ("emojiStatusUntil", [("documentId", String(describing: documentId)), ("until", String(describing: until))])
    }
    }
    
        public static func parse_emojiStatus(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiStatus.emojiStatus(documentId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusEmpty(_ reader: BufferReader) -> EmojiStatus? {
            return Api.EmojiStatus.emojiStatusEmpty
        }
        public static func parse_emojiStatusUntil(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiStatus.emojiStatusUntil(documentId: _1!, until: _2!)
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
        case encryptedFile(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, keyFingerprint: Int32)
        case encryptedFileEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .encryptedFile(let id, let accessHash, let size, let dcId, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(-1476358952)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
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
            var _3: Int64?
            _3 = reader.readInt64()
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
        case chatInvitePublicJoinRequests
    
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
                case .chatInvitePublicJoinRequests:
                    if boxed {
                        buffer.appendInt32(-317687113)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInviteExported(let flags, let link, let adminId, let date, let startDate, let expireDate, let usageLimit, let usage, let requested, let title):
                return ("chatInviteExported", [("flags", String(describing: flags)), ("link", String(describing: link)), ("adminId", String(describing: adminId)), ("date", String(describing: date)), ("startDate", String(describing: startDate)), ("expireDate", String(describing: expireDate)), ("usageLimit", String(describing: usageLimit)), ("usage", String(describing: usage)), ("requested", String(describing: requested)), ("title", String(describing: title))])
                case .chatInvitePublicJoinRequests:
                return ("chatInvitePublicJoinRequests", [])
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
        public static func parse_chatInvitePublicJoinRequests(_ reader: BufferReader) -> ExportedChatInvite? {
            return Api.ExportedChatInvite.chatInvitePublicJoinRequests
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
        case fileHash(offset: Int64, limit: Int32, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileHash(let offset, let limit, let hash):
                    if boxed {
                        buffer.appendInt32(-207944868)
                    }
                    serializeInt64(offset, buffer: buffer, boxed: false)
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
            var _1: Int64?
            _1 = reader.readInt64()
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
    enum ForumTopic: TypeConstructorDescription {
        case forumTopic(flags: Int32, id: Int32, date: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?)
        case forumTopicDeleted(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .forumTopic(let flags, let id, let date, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                    if boxed {
                        buffer.appendInt32(1903173033)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt32(iconColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    serializeInt32(topMessage, buffer: buffer, boxed: false)
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadMentionsCount, buffer: buffer, boxed: false)
                    serializeInt32(unreadReactionsCount, buffer: buffer, boxed: false)
                    fromId.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 4) != 0 {draft!.serialize(buffer, true)}
                    break
                case .forumTopicDeleted(let id):
                    if boxed {
                        buffer.appendInt32(37687451)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .forumTopic(let flags, let id, let date, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                return ("forumTopic", [("flags", String(describing: flags)), ("id", String(describing: id)), ("date", String(describing: date)), ("title", String(describing: title)), ("iconColor", String(describing: iconColor)), ("iconEmojiId", String(describing: iconEmojiId)), ("topMessage", String(describing: topMessage)), ("readInboxMaxId", String(describing: readInboxMaxId)), ("readOutboxMaxId", String(describing: readOutboxMaxId)), ("unreadCount", String(describing: unreadCount)), ("unreadMentionsCount", String(describing: unreadMentionsCount)), ("unreadReactionsCount", String(describing: unreadReactionsCount)), ("fromId", String(describing: fromId)), ("notifySettings", String(describing: notifySettings)), ("draft", String(describing: draft))])
                case .forumTopicDeleted(let id):
                return ("forumTopicDeleted", [("id", String(describing: id))])
    }
    }
    
        public static func parse_forumTopic(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt64() }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Api.Peer?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _14: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _15: Api.DraftMessage?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 4) == 0) || _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.ForumTopic.forumTopic(flags: _1!, id: _2!, date: _3!, title: _4!, iconColor: _5!, iconEmojiId: _6, topMessage: _7!, readInboxMaxId: _8!, readOutboxMaxId: _9!, unreadCount: _10!, unreadMentionsCount: _11!, unreadReactionsCount: _12!, fromId: _13!, notifySettings: _14!, draft: _15)
            }
            else {
                return nil
            }
        }
        public static func parse_forumTopicDeleted(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ForumTopic.forumTopicDeleted(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
