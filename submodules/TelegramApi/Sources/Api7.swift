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
                return ("emojiURL", [("url", url as Any)])
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
                return ("encryptedChat", [("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gAOrB", gAOrB as Any), ("keyFingerprint", keyFingerprint as Any)])
                case .encryptedChatDiscarded(let flags, let id):
                return ("encryptedChatDiscarded", [("flags", flags as Any), ("id", id as Any)])
                case .encryptedChatEmpty(let id):
                return ("encryptedChatEmpty", [("id", id as Any)])
                case .encryptedChatRequested(let flags, let folderId, let id, let accessHash, let date, let adminId, let participantId, let gA):
                return ("encryptedChatRequested", [("flags", flags as Any), ("folderId", folderId as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any), ("gA", gA as Any)])
                case .encryptedChatWaiting(let id, let accessHash, let date, let adminId, let participantId):
                return ("encryptedChatWaiting", [("id", id as Any), ("accessHash", accessHash as Any), ("date", date as Any), ("adminId", adminId as Any), ("participantId", participantId as Any)])
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
                return ("encryptedFile", [("id", id as Any), ("accessHash", accessHash as Any), ("size", size as Any), ("dcId", dcId as Any), ("keyFingerprint", keyFingerprint as Any)])
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
                return ("encryptedMessage", [("randomId", randomId as Any), ("chatId", chatId as Any), ("date", date as Any), ("bytes", bytes as Any), ("file", file as Any)])
                case .encryptedMessageService(let randomId, let chatId, let date, let bytes):
                return ("encryptedMessageService", [("randomId", randomId as Any), ("chatId", chatId as Any), ("date", date as Any), ("bytes", bytes as Any)])
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
        case chatInviteExported(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, subscriptionExpired: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?)
        case chatInvitePublicJoinRequests
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInviteExported(let flags, let link, let adminId, let date, let startDate, let expireDate, let usageLimit, let usage, let requested, let subscriptionExpired, let title, let subscriptionPricing):
                    if boxed {
                        buffer.appendInt32(-1574126186)
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
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(subscriptionExpired!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {subscriptionPricing!.serialize(buffer, true)}
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
                case .chatInviteExported(let flags, let link, let adminId, let date, let startDate, let expireDate, let usageLimit, let usage, let requested, let subscriptionExpired, let title, let subscriptionPricing):
                return ("chatInviteExported", [("flags", flags as Any), ("link", link as Any), ("adminId", adminId as Any), ("date", date as Any), ("startDate", startDate as Any), ("expireDate", expireDate as Any), ("usageLimit", usageLimit as Any), ("usage", usage as Any), ("requested", requested as Any), ("subscriptionExpired", subscriptionExpired as Any), ("title", title as Any), ("subscriptionPricing", subscriptionPricing as Any)])
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
            var _10: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_10 = reader.readInt32() }
            var _11: String?
            if Int(_1!) & Int(1 << 8) != 0 {_11 = parseString(reader) }
            var _12: Api.StarsSubscriptionPricing?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 7) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 10) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 9) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.ExportedChatInvite.chatInviteExported(flags: _1!, link: _2!, adminId: _3!, date: _4!, startDate: _5, expireDate: _6, usageLimit: _7, usage: _8, requested: _9, subscriptionExpired: _10, title: _11, subscriptionPricing: _12)
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
    enum ExportedChatlistInvite: TypeConstructorDescription {
        case exportedChatlistInvite(flags: Int32, title: String, url: String, peers: [Api.Peer])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedChatlistInvite(let flags, let title, let url, let peers):
                    if boxed {
                        buffer.appendInt32(206668204)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedChatlistInvite(let flags, let title, let url, let peers):
                return ("exportedChatlistInvite", [("flags", flags as Any), ("title", title as Any), ("url", url as Any), ("peers", peers as Any)])
    }
    }
    
        public static func parse_exportedChatlistInvite(_ reader: BufferReader) -> ExportedChatlistInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Peer]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ExportedChatlistInvite.exportedChatlistInvite(flags: _1!, title: _2!, url: _3!, peers: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ExportedContactToken: TypeConstructorDescription {
        case exportedContactToken(url: String, expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedContactToken(let url, let expires):
                    if boxed {
                        buffer.appendInt32(1103040667)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedContactToken(let url, let expires):
                return ("exportedContactToken", [("url", url as Any), ("expires", expires as Any)])
    }
    }
    
        public static func parse_exportedContactToken(_ reader: BufferReader) -> ExportedContactToken? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ExportedContactToken.exportedContactToken(url: _1!, expires: _2!)
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
                return ("exportedMessageLink", [("link", link as Any), ("html", html as Any)])
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
    enum ExportedStoryLink: TypeConstructorDescription {
        case exportedStoryLink(link: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedStoryLink(let link):
                    if boxed {
                        buffer.appendInt32(1070138683)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedStoryLink(let link):
                return ("exportedStoryLink", [("link", link as Any)])
    }
    }
    
        public static func parse_exportedStoryLink(_ reader: BufferReader) -> ExportedStoryLink? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ExportedStoryLink.exportedStoryLink(link: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum FactCheck: TypeConstructorDescription {
        case factCheck(flags: Int32, country: String?, text: Api.TextWithEntities?, hash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .factCheck(let flags, let country, let text, let hash):
                    if boxed {
                        buffer.appendInt32(-1197736753)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(country!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {text!.serialize(buffer, true)}
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .factCheck(let flags, let country, let text, let hash):
                return ("factCheck", [("flags", flags as Any), ("country", country as Any), ("text", text as Any), ("hash", hash as Any)])
    }
    }
    
        public static func parse_factCheck(_ reader: BufferReader) -> FactCheck? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = parseString(reader) }
            var _3: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            } }
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.FactCheck.factCheck(flags: _1!, country: _2, text: _3, hash: _4!)
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
                return ("fileHash", [("offset", offset as Any), ("limit", limit as Any), ("hash", hash as Any)])
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
                return ("folder", [("flags", flags as Any), ("id", id as Any), ("title", title as Any), ("photo", photo as Any)])
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
                return ("folderPeer", [("peer", peer as Any), ("folderId", folderId as Any)])
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
    indirect enum ForumTopic: TypeConstructorDescription {
        case forumTopic(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?)
        case forumTopicDeleted(id: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .forumTopic(let flags, let id, let date, let peer, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                    if boxed {
                        buffer.appendInt32(-838922550)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
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
                case .forumTopic(let flags, let id, let date, let peer, let title, let iconColor, let iconEmojiId, let topMessage, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let unreadMentionsCount, let unreadReactionsCount, let fromId, let notifySettings, let draft):
                return ("forumTopic", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("peer", peer as Any), ("title", title as Any), ("iconColor", iconColor as Any), ("iconEmojiId", iconEmojiId as Any), ("topMessage", topMessage as Any), ("readInboxMaxId", readInboxMaxId as Any), ("readOutboxMaxId", readOutboxMaxId as Any), ("unreadCount", unreadCount as Any), ("unreadMentionsCount", unreadMentionsCount as Any), ("unreadReactionsCount", unreadReactionsCount as Any), ("fromId", fromId as Any), ("notifySettings", notifySettings as Any), ("draft", draft as Any)])
                case .forumTopicDeleted(let id):
                return ("forumTopicDeleted", [("id", id as Any)])
    }
    }
    
        public static func parse_forumTopic(_ reader: BufferReader) -> ForumTopic? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = reader.readInt64() }
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
            var _13: Int32?
            _13 = reader.readInt32()
            var _14: Api.Peer?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _15: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _16: Api.DraftMessage?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 4) == 0) || _16 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 {
                return Api.ForumTopic.forumTopic(flags: _1!, id: _2!, date: _3!, peer: _4!, title: _5!, iconColor: _6!, iconEmojiId: _7, topMessage: _8!, readInboxMaxId: _9!, readOutboxMaxId: _10!, unreadCount: _11!, unreadMentionsCount: _12!, unreadReactionsCount: _13!, fromId: _14!, notifySettings: _15!, draft: _16)
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
public extension Api {
    indirect enum FoundStory: TypeConstructorDescription {
        case foundStory(peer: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .foundStory(let peer, let story):
                    if boxed {
                        buffer.appendInt32(-394605632)
                    }
                    peer.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .foundStory(let peer, let story):
                return ("foundStory", [("peer", peer as Any), ("story", story as Any)])
    }
    }
    
        public static func parse_foundStory(_ reader: BufferReader) -> FoundStory? {
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
                return Api.FoundStory.foundStory(peer: _1!, story: _2!)
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
                return ("game", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("shortName", shortName as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("document", document as Any)])
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
                return ("geoPoint", [("flags", flags as Any), ("long", long as Any), ("lat", lat as Any), ("accessHash", accessHash as Any), ("accuracyRadius", accuracyRadius as Any)])
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
    enum GeoPointAddress: TypeConstructorDescription {
        case geoPointAddress(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .geoPointAddress(let flags, let countryIso2, let state, let city, let street):
                    if boxed {
                        buffer.appendInt32(-565420653)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(countryIso2, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(state!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(city!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(street!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .geoPointAddress(let flags, let countryIso2, let state, let city, let street):
                return ("geoPointAddress", [("flags", flags as Any), ("countryIso2", countryIso2 as Any), ("state", state as Any), ("city", city as Any), ("street", street as Any)])
    }
    }
    
        public static func parse_geoPointAddress(_ reader: BufferReader) -> GeoPointAddress? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPointAddress.geoPointAddress(flags: _1!, countryIso2: _2!, state: _3, city: _4, street: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        case globalPrivacySettings(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .globalPrivacySettings(let flags, let noncontactPeersPaidStars, let disallowedGifts):
                    if boxed {
                        buffer.appendInt32(-29248689)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt64(noncontactPeersPaidStars!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {disallowedGifts!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .globalPrivacySettings(let flags, let noncontactPeersPaidStars, let disallowedGifts):
                return ("globalPrivacySettings", [("flags", flags as Any), ("noncontactPeersPaidStars", noncontactPeersPaidStars as Any), ("disallowedGifts", disallowedGifts as Any)])
    }
    }
    
        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 5) != 0 {_2 = reader.readInt64() }
            var _3: Api.DisallowedGiftsSettings?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DisallowedGiftsSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 5) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GlobalPrivacySettings.globalPrivacySettings(flags: _1!, noncontactPeersPaidStars: _2, disallowedGifts: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?)
        case groupCallDiscarded(id: Int64, accessHash: Int64, duration: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version, let inviteLink):
                    if boxed {
                        buffer.appendInt32(1429932961)
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
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(inviteLink!, buffer: buffer, boxed: false)}
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
                case .groupCall(let flags, let id, let accessHash, let participantsCount, let title, let streamDcId, let recordStartDate, let scheduleDate, let unmutedVideoCount, let unmutedVideoLimit, let version, let inviteLink):
                return ("groupCall", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("participantsCount", participantsCount as Any), ("title", title as Any), ("streamDcId", streamDcId as Any), ("recordStartDate", recordStartDate as Any), ("scheduleDate", scheduleDate as Any), ("unmutedVideoCount", unmutedVideoCount as Any), ("unmutedVideoLimit", unmutedVideoLimit as Any), ("version", version as Any), ("inviteLink", inviteLink as Any)])
                case .groupCallDiscarded(let id, let accessHash, let duration):
                return ("groupCallDiscarded", [("id", id as Any), ("accessHash", accessHash as Any), ("duration", duration as Any)])
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
            var _12: String?
            if Int(_1!) & Int(1 << 16) != 0 {_12 = parseString(reader) }
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
            let _c12 = (Int(_1!) & Int(1 << 16) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.GroupCall.groupCall(flags: _1!, id: _2!, accessHash: _3!, participantsCount: _4!, title: _5, streamDcId: _6, recordStartDate: _7, scheduleDate: _8, unmutedVideoCount: _9, unmutedVideoLimit: _10!, version: _11!, inviteLink: _12)
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
                return ("groupCallParticipant", [("flags", flags as Any), ("peer", peer as Any), ("date", date as Any), ("activeDate", activeDate as Any), ("source", source as Any), ("volume", volume as Any), ("about", about as Any), ("raiseHandRating", raiseHandRating as Any), ("video", video as Any), ("presentation", presentation as Any)])
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
                return ("groupCallParticipantVideo", [("flags", flags as Any), ("endpoint", endpoint as Any), ("sourceGroups", sourceGroups as Any), ("audioSource", audioSource as Any)])
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
