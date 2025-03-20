public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription {
        case webPageAttributeStickerSet(flags: Int32, stickers: [Api.Document])
        case webPageAttributeStory(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?)
        case webPageAttributeTheme(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?)
        case webPageAttributeUniqueStarGift(gift: Api.StarGift)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPageAttributeStickerSet(let flags, let stickers):
                    if boxed {
                        buffer.appendInt32(1355547603)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
                case .webPageAttributeStory(let flags, let peer, let id, let story):
                    if boxed {
                        buffer.appendInt32(781501415)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {story!.serialize(buffer, true)}
                    break
                case .webPageAttributeTheme(let flags, let documents, let settings):
                    if boxed {
                        buffer.appendInt32(1421174295)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents!.count))
                    for item in documents! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {settings!.serialize(buffer, true)}
                    break
                case .webPageAttributeUniqueStarGift(let gift):
                    if boxed {
                        buffer.appendInt32(-814781000)
                    }
                    gift.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webPageAttributeStickerSet(let flags, let stickers):
                return ("webPageAttributeStickerSet", [("flags", flags as Any), ("stickers", stickers as Any)])
                case .webPageAttributeStory(let flags, let peer, let id, let story):
                return ("webPageAttributeStory", [("flags", flags as Any), ("peer", peer as Any), ("id", id as Any), ("story", story as Any)])
                case .webPageAttributeTheme(let flags, let documents, let settings):
                return ("webPageAttributeTheme", [("flags", flags as Any), ("documents", documents as Any), ("settings", settings as Any)])
                case .webPageAttributeUniqueStarGift(let gift):
                return ("webPageAttributeUniqueStarGift", [("gift", gift as Any)])
    }
    }
    
        public static func parse_webPageAttributeStickerSet(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.WebPageAttribute.webPageAttributeStickerSet(flags: _1!, stickers: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageAttributeStory(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.StoryItem?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StoryItem
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebPageAttribute.webPageAttributeStory(flags: _1!, peer: _2!, id: _3!, story: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageAttributeTheme(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            } }
            var _3: Api.ThemeSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPageAttribute.webPageAttributeTheme(flags: _1!, documents: _2, settings: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageAttributeUniqueStarGift(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.WebPageAttribute.webPageAttributeUniqueStarGift(gift: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebViewMessageSent: TypeConstructorDescription {
        case webViewMessageSent(flags: Int32, msgId: Api.InputBotInlineMessageID?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webViewMessageSent(let flags, let msgId):
                    if boxed {
                        buffer.appendInt32(211046684)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {msgId!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webViewMessageSent(let flags, let msgId):
                return ("webViewMessageSent", [("flags", flags as Any), ("msgId", msgId as Any)])
    }
    }
    
        public static func parse_webViewMessageSent(_ reader: BufferReader) -> WebViewMessageSent? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebViewMessageSent.webViewMessageSent(flags: _1!, msgId: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebViewResult: TypeConstructorDescription {
        case webViewResultUrl(flags: Int32, queryId: Int64?, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webViewResultUrl(let flags, let queryId, let url):
                    if boxed {
                        buffer.appendInt32(1294139288)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(queryId!, buffer: buffer, boxed: false)}
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webViewResultUrl(let flags, let queryId, let url):
                return ("webViewResultUrl", [("flags", flags as Any), ("queryId", queryId as Any), ("url", url as Any)])
    }
    }
    
        public static func parse_webViewResultUrl(_ reader: BufferReader) -> WebViewResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebViewResult.webViewResultUrl(flags: _1!, queryId: _2, url: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum AuthorizationForm: TypeConstructorDescription {
        case authorizationForm(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                    if boxed {
                        buffer.appendInt32(-1389486888)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(requiredTypes.count))
                    for item in requiredTypes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(privacyPolicyUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                return ("authorizationForm", [("flags", flags as Any), ("requiredTypes", requiredTypes as Any), ("values", values as Any), ("errors", errors as Any), ("users", users as Any), ("privacyPolicyUrl", privacyPolicyUrl as Any)])
    }
    }
    
        public static func parse_authorizationForm(_ reader: BufferReader) -> AuthorizationForm? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            var _3: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _4: [Api.SecureValueError]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueError.self)
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
                return Api.account.AuthorizationForm.authorizationForm(flags: _1!, requiredTypes: _2!, values: _3!, errors: _4!, users: _5!, privacyPolicyUrl: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Authorizations: TypeConstructorDescription {
        case authorizations(authorizationTtlDays: Int32, authorizations: [Api.Authorization])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizations(let authorizationTtlDays, let authorizations):
                    if boxed {
                        buffer.appendInt32(1275039392)
                    }
                    serializeInt32(authorizationTtlDays, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(authorizations.count))
                    for item in authorizations {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizations(let authorizationTtlDays, let authorizations):
                return ("authorizations", [("authorizationTtlDays", authorizationTtlDays as Any), ("authorizations", authorizations as Any)])
    }
    }
    
        public static func parse_authorizations(_ reader: BufferReader) -> Authorizations? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Authorization]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Authorization.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.Authorizations.authorizations(authorizationTtlDays: _1!, authorizations: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                    if boxed {
                        buffer.appendInt32(1674235686)
                    }
                    low.serialize(buffer, true)
                    medium.serialize(buffer, true)
                    high.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                return ("autoDownloadSettings", [("low", low as Any), ("medium", medium as Any), ("high", high as Any)])
    }
    }
    
        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _2: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _3: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.AutoDownloadSettings.autoDownloadSettings(low: _1!, medium: _2!, high: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum AutoSaveSettings: TypeConstructorDescription {
        case autoSaveSettings(usersSettings: Api.AutoSaveSettings, chatsSettings: Api.AutoSaveSettings, broadcastsSettings: Api.AutoSaveSettings, exceptions: [Api.AutoSaveException], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoSaveSettings(let usersSettings, let chatsSettings, let broadcastsSettings, let exceptions, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1279133341)
                    }
                    usersSettings.serialize(buffer, true)
                    chatsSettings.serialize(buffer, true)
                    broadcastsSettings.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(exceptions.count))
                    for item in exceptions {
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
                case .autoSaveSettings(let usersSettings, let chatsSettings, let broadcastsSettings, let exceptions, let chats, let users):
                return ("autoSaveSettings", [("usersSettings", usersSettings as Any), ("chatsSettings", chatsSettings as Any), ("broadcastsSettings", broadcastsSettings as Any), ("exceptions", exceptions as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_autoSaveSettings(_ reader: BufferReader) -> AutoSaveSettings? {
            var _1: Api.AutoSaveSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AutoSaveSettings
            }
            var _2: Api.AutoSaveSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoSaveSettings
            }
            var _3: Api.AutoSaveSettings?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.AutoSaveSettings
            }
            var _4: [Api.AutoSaveException]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AutoSaveException.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.AutoSaveSettings.autoSaveSettings(usersSettings: _1!, chatsSettings: _2!, broadcastsSettings: _3!, exceptions: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum BusinessChatLinks: TypeConstructorDescription {
        case businessChatLinks(links: [Api.BusinessChatLink], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessChatLinks(let links, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-331111727)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(links.count))
                    for item in links {
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
                case .businessChatLinks(let links, let chats, let users):
                return ("businessChatLinks", [("links", links as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_businessChatLinks(_ reader: BufferReader) -> BusinessChatLinks? {
            var _1: [Api.BusinessChatLink]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BusinessChatLink.self)
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
                return Api.account.BusinessChatLinks.businessChatLinks(links: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ConnectedBots: TypeConstructorDescription {
        case connectedBots(connectedBots: [Api.ConnectedBot], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .connectedBots(let connectedBots, let users):
                    if boxed {
                        buffer.appendInt32(400029819)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(connectedBots.count))
                    for item in connectedBots {
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
                case .connectedBots(let connectedBots, let users):
                return ("connectedBots", [("connectedBots", connectedBots as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_connectedBots(_ reader: BufferReader) -> ConnectedBots? {
            var _1: [Api.ConnectedBot]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ConnectedBot.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.ConnectedBots.connectedBots(connectedBots: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ContentSettings: TypeConstructorDescription {
        case contentSettings(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contentSettings(let flags):
                    if boxed {
                        buffer.appendInt32(1474462241)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contentSettings(let flags):
                return ("contentSettings", [("flags", flags as Any)])
    }
    }
    
        public static func parse_contentSettings(_ reader: BufferReader) -> ContentSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ContentSettings.contentSettings(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum EmailVerified: TypeConstructorDescription {
        case emailVerified(email: String)
        case emailVerifiedLogin(email: String, sentCode: Api.auth.SentCode)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emailVerified(let email):
                    if boxed {
                        buffer.appendInt32(731303195)
                    }
                    serializeString(email, buffer: buffer, boxed: false)
                    break
                case .emailVerifiedLogin(let email, let sentCode):
                    if boxed {
                        buffer.appendInt32(-507835039)
                    }
                    serializeString(email, buffer: buffer, boxed: false)
                    sentCode.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emailVerified(let email):
                return ("emailVerified", [("email", email as Any)])
                case .emailVerifiedLogin(let email, let sentCode):
                return ("emailVerifiedLogin", [("email", email as Any), ("sentCode", sentCode as Any)])
    }
    }
    
        public static func parse_emailVerified(_ reader: BufferReader) -> EmailVerified? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.EmailVerified.emailVerified(email: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerifiedLogin(_ reader: BufferReader) -> EmailVerified? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.auth.SentCode?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.auth.SentCode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.EmailVerified.emailVerifiedLogin(email: _1!, sentCode: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum EmojiStatuses: TypeConstructorDescription {
        case emojiStatuses(hash: Int64, statuses: [Api.EmojiStatus])
        case emojiStatusesNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .emojiStatuses(let hash, let statuses):
                    if boxed {
                        buffer.appendInt32(-1866176559)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(statuses.count))
                    for item in statuses {
                        item.serialize(buffer, true)
                    }
                    break
                case .emojiStatusesNotModified:
                    if boxed {
                        buffer.appendInt32(-796072379)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .emojiStatuses(let hash, let statuses):
                return ("emojiStatuses", [("hash", hash as Any), ("statuses", statuses as Any)])
                case .emojiStatusesNotModified:
                return ("emojiStatusesNotModified", [])
    }
    }
    
        public static func parse_emojiStatuses(_ reader: BufferReader) -> EmojiStatuses? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.EmojiStatus]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiStatus.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.EmojiStatuses.emojiStatuses(hash: _1!, statuses: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusesNotModified(_ reader: BufferReader) -> EmojiStatuses? {
            return Api.account.EmojiStatuses.emojiStatusesNotModified
        }
    
    }
}
public extension Api.account {
    enum PaidMessagesRevenue: TypeConstructorDescription {
        case paidMessagesRevenue(starsAmount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paidMessagesRevenue(let starsAmount):
                    if boxed {
                        buffer.appendInt32(504403720)
                    }
                    serializeInt64(starsAmount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paidMessagesRevenue(let starsAmount):
                return ("paidMessagesRevenue", [("starsAmount", starsAmount as Any)])
    }
    }
    
        public static func parse_paidMessagesRevenue(_ reader: BufferReader) -> PaidMessagesRevenue? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.PaidMessagesRevenue.paidMessagesRevenue(starsAmount: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription {
        case password(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom, let pendingResetDate, let loginEmailPattern):
                    if boxed {
                        buffer.appendInt32(-1787080453)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {currentAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(srpB!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(srpId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(emailUnconfirmedPattern!, buffer: buffer, boxed: false)}
                    newAlgo.serialize(buffer, true)
                    newSecureAlgo.serialize(buffer, true)
                    serializeBytes(secureRandom, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(pendingResetDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(loginEmailPattern!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom, let pendingResetDate, let loginEmailPattern):
                return ("password", [("flags", flags as Any), ("currentAlgo", currentAlgo as Any), ("srpB", srpB as Any), ("srpId", srpId as Any), ("hint", hint as Any), ("emailUnconfirmedPattern", emailUnconfirmedPattern as Any), ("newAlgo", newAlgo as Any), ("newSecureAlgo", newSecureAlgo as Any), ("secureRandom", secureRandom as Any), ("pendingResetDate", pendingResetDate as Any), ("loginEmailPattern", loginEmailPattern as Any)])
    }
    }
    
        public static func parse_password(_ reader: BufferReader) -> Password? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = parseBytes(reader) }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt64() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
            var _7: Api.PasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            }
            var _8: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _9: Buffer?
            _9 = parseBytes(reader)
            var _10: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_10 = reader.readInt32() }
            var _11: String?
            if Int(_1!) & Int(1 << 6) != 0 {_11 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 5) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.account.Password.password(flags: _1!, currentAlgo: _2, srpB: _3, srpId: _4, hint: _5, emailUnconfirmedPattern: _6, newAlgo: _7!, newSecureAlgo: _8!, secureRandom: _9!, pendingResetDate: _10, loginEmailPattern: _11)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription {
        case passwordInputSettings(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                    if boxed {
                        buffer.appendInt32(-1036572727)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {newAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(newPasswordHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {newSecureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                return ("passwordInputSettings", [("flags", flags as Any), ("newAlgo", newAlgo as Any), ("newPasswordHash", newPasswordHash as Any), ("hint", hint as Any), ("email", email as Any), ("newSecureSettings", newSecureSettings as Any)])
    }
    }
    
        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseBytes(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.PasswordInputSettings.passwordInputSettings(flags: _1!, newAlgo: _2, newPasswordHash: _3, hint: _4, email: _5, newSecureSettings: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription {
        case passwordSettings(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                    if boxed {
                        buffer.appendInt32(-1705233435)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {secureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                return ("passwordSettings", [("flags", flags as Any), ("email", email as Any), ("secureSettings", secureSettings as Any)])
    }
    }
    
        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.PasswordSettings.passwordSettings(flags: _1!, email: _2, secureSettings: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription {
        case privacyRules(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyRules(let rules, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1352683077)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
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
                case .privacyRules(let rules, let chats, let users):
                return ("privacyRules", [("rules", rules as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_privacyRules(_ reader: BufferReader) -> PrivacyRules? {
            var _1: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
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
                return Api.account.PrivacyRules.privacyRules(rules: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription {
        case resetPasswordFailedWait(retryDate: Int32)
        case resetPasswordOk
        case resetPasswordRequestedWait(untilDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resetPasswordFailedWait(let retryDate):
                    if boxed {
                        buffer.appendInt32(-478701471)
                    }
                    serializeInt32(retryDate, buffer: buffer, boxed: false)
                    break
                case .resetPasswordOk:
                    if boxed {
                        buffer.appendInt32(-383330754)
                    }
                    
                    break
                case .resetPasswordRequestedWait(let untilDate):
                    if boxed {
                        buffer.appendInt32(-370148227)
                    }
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .resetPasswordFailedWait(let retryDate):
                return ("resetPasswordFailedWait", [("retryDate", retryDate as Any)])
                case .resetPasswordOk:
                return ("resetPasswordOk", [])
                case .resetPasswordRequestedWait(let untilDate):
                return ("resetPasswordRequestedWait", [("untilDate", untilDate as Any)])
    }
    }
    
        public static func parse_resetPasswordFailedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordFailedWait(retryDate: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_resetPasswordOk(_ reader: BufferReader) -> ResetPasswordResult? {
            return Api.account.ResetPasswordResult.resetPasswordOk
        }
        public static func parse_resetPasswordRequestedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordRequestedWait(untilDate: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ResolvedBusinessChatLinks: TypeConstructorDescription {
        case resolvedBusinessChatLinks(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resolvedBusinessChatLinks(let flags, let peer, let message, let entities, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1708937439)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
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
                case .resolvedBusinessChatLinks(let flags, let peer, let message, let entities, let chats, let users):
                return ("resolvedBusinessChatLinks", [("flags", flags as Any), ("peer", peer as Any), ("message", message as Any), ("entities", entities as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_resolvedBusinessChatLinks(_ reader: BufferReader) -> ResolvedBusinessChatLinks? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.ResolvedBusinessChatLinks.resolvedBusinessChatLinks(flags: _1!, peer: _2!, message: _3!, entities: _4, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum SavedRingtone: TypeConstructorDescription {
        case savedRingtone
        case savedRingtoneConverted(document: Api.Document)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedRingtone:
                    if boxed {
                        buffer.appendInt32(-1222230163)
                    }
                    
                    break
                case .savedRingtoneConverted(let document):
                    if boxed {
                        buffer.appendInt32(523271863)
                    }
                    document.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedRingtone:
                return ("savedRingtone", [])
                case .savedRingtoneConverted(let document):
                return ("savedRingtoneConverted", [("document", document as Any)])
    }
    }
    
        public static func parse_savedRingtone(_ reader: BufferReader) -> SavedRingtone? {
            return Api.account.SavedRingtone.savedRingtone
        }
        public static func parse_savedRingtoneConverted(_ reader: BufferReader) -> SavedRingtone? {
            var _1: Api.Document?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.SavedRingtone.savedRingtoneConverted(document: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum SavedRingtones: TypeConstructorDescription {
        case savedRingtones(hash: Int64, ringtones: [Api.Document])
        case savedRingtonesNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedRingtones(let hash, let ringtones):
                    if boxed {
                        buffer.appendInt32(-1041683259)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ringtones.count))
                    for item in ringtones {
                        item.serialize(buffer, true)
                    }
                    break
                case .savedRingtonesNotModified:
                    if boxed {
                        buffer.appendInt32(-67704655)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedRingtones(let hash, let ringtones):
                return ("savedRingtones", [("hash", hash as Any), ("ringtones", ringtones as Any)])
                case .savedRingtonesNotModified:
                return ("savedRingtonesNotModified", [])
    }
    }
    
        public static func parse_savedRingtones(_ reader: BufferReader) -> SavedRingtones? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.SavedRingtones.savedRingtones(hash: _1!, ringtones: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_savedRingtonesNotModified(_ reader: BufferReader) -> SavedRingtones? {
            return Api.account.SavedRingtones.savedRingtonesNotModified
        }
    
    }
}
public extension Api.account {
    enum SentEmailCode: TypeConstructorDescription {
        case sentEmailCode(emailPattern: String, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentEmailCode(let emailPattern, let length):
                    if boxed {
                        buffer.appendInt32(-2128640689)
                    }
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentEmailCode(let emailPattern, let length):
                return ("sentEmailCode", [("emailPattern", emailPattern as Any), ("length", length as Any)])
    }
    }
    
        public static func parse_sentEmailCode(_ reader: BufferReader) -> SentEmailCode? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.SentEmailCode.sentEmailCode(emailPattern: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Takeout: TypeConstructorDescription {
        case takeout(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .takeout(let id):
                    if boxed {
                        buffer.appendInt32(1304052993)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .takeout(let id):
                return ("takeout", [("id", id as Any)])
    }
    }
    
        public static func parse_takeout(_ reader: BufferReader) -> Takeout? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Takeout.takeout(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
