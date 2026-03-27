public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription {
        public class Cons_webPageAttributeStarGiftAuction: TypeConstructorDescription {
            public var gift: Api.StarGift
            public var endDate: Int32
            public init(gift: Api.StarGift, endDate: Int32) {
                self.gift = gift
                self.endDate = endDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeStarGiftAuction", [("gift", ConstructorParameterDescription(self.gift)), ("endDate", ConstructorParameterDescription(self.endDate))])
            }
        }
        public class Cons_webPageAttributeStarGiftCollection: TypeConstructorDescription {
            public var icons: [Api.Document]
            public init(icons: [Api.Document]) {
                self.icons = icons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeStarGiftCollection", [("icons", ConstructorParameterDescription(self.icons))])
            }
        }
        public class Cons_webPageAttributeStickerSet: TypeConstructorDescription {
            public var flags: Int32
            public var stickers: [Api.Document]
            public init(flags: Int32, stickers: [Api.Document]) {
                self.flags = flags
                self.stickers = stickers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeStickerSet", [("flags", ConstructorParameterDescription(self.flags)), ("stickers", ConstructorParameterDescription(self.stickers))])
            }
        }
        public class Cons_webPageAttributeStory: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var id: Int32
            public var story: Api.StoryItem?
            public init(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?) {
                self.flags = flags
                self.peer = peer
                self.id = id
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeStory", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("id", ConstructorParameterDescription(self.id)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        public class Cons_webPageAttributeTheme: TypeConstructorDescription {
            public var flags: Int32
            public var documents: [Api.Document]?
            public var settings: Api.ThemeSettings?
            public init(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?) {
                self.flags = flags
                self.documents = documents
                self.settings = settings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeTheme", [("flags", ConstructorParameterDescription(self.flags)), ("documents", ConstructorParameterDescription(self.documents)), ("settings", ConstructorParameterDescription(self.settings))])
            }
        }
        public class Cons_webPageAttributeUniqueStarGift: TypeConstructorDescription {
            public var gift: Api.StarGift
            public init(gift: Api.StarGift) {
                self.gift = gift
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeUniqueStarGift", [("gift", ConstructorParameterDescription(self.gift))])
            }
        }
        case webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction)
        case webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection)
        case webPageAttributeStickerSet(Cons_webPageAttributeStickerSet)
        case webPageAttributeStory(Cons_webPageAttributeStory)
        case webPageAttributeTheme(Cons_webPageAttributeTheme)
        case webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPageAttributeStarGiftAuction(let _data):
                if boxed {
                    buffer.appendInt32(29770178)
                }
                _data.gift.serialize(buffer, true)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
                break
            case .webPageAttributeStarGiftCollection(let _data):
                if boxed {
                    buffer.appendInt32(835375875)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.icons.count))
                for item in _data.icons {
                    item.serialize(buffer, true)
                }
                break
            case .webPageAttributeStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(1355547603)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stickers.count))
                for item in _data.stickers {
                    item.serialize(buffer, true)
                }
                break
            case .webPageAttributeStory(let _data):
                if boxed {
                    buffer.appendInt32(781501415)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.story!.serialize(buffer, true)
                }
                break
            case .webPageAttributeTheme(let _data):
                if boxed {
                    buffer.appendInt32(1421174295)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.documents!.count))
                    for item in _data.documents! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.settings!.serialize(buffer, true)
                }
                break
            case .webPageAttributeUniqueStarGift(let _data):
                if boxed {
                    buffer.appendInt32(-814781000)
                }
                _data.gift.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webPageAttributeStarGiftAuction(let _data):
                return ("webPageAttributeStarGiftAuction", [("gift", ConstructorParameterDescription(_data.gift)), ("endDate", ConstructorParameterDescription(_data.endDate))])
            case .webPageAttributeStarGiftCollection(let _data):
                return ("webPageAttributeStarGiftCollection", [("icons", ConstructorParameterDescription(_data.icons))])
            case .webPageAttributeStickerSet(let _data):
                return ("webPageAttributeStickerSet", [("flags", ConstructorParameterDescription(_data.flags)), ("stickers", ConstructorParameterDescription(_data.stickers))])
            case .webPageAttributeStory(let _data):
                return ("webPageAttributeStory", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("id", ConstructorParameterDescription(_data.id)), ("story", ConstructorParameterDescription(_data.story))])
            case .webPageAttributeTheme(let _data):
                return ("webPageAttributeTheme", [("flags", ConstructorParameterDescription(_data.flags)), ("documents", ConstructorParameterDescription(_data.documents)), ("settings", ConstructorParameterDescription(_data.settings))])
            case .webPageAttributeUniqueStarGift(let _data):
                return ("webPageAttributeUniqueStarGift", [("gift", ConstructorParameterDescription(_data.gift))])
            }
        }

        public static func parse_webPageAttributeStarGiftAuction(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.WebPageAttribute.webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction(gift: _1!, endDate: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageAttributeStarGiftCollection(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: [Api.Document]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.WebPageAttribute.webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection(icons: _1!))
            }
            else {
                return nil
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
                return Api.WebPageAttribute.webPageAttributeStickerSet(Cons_webPageAttributeStickerSet(flags: _1!, stickers: _2!))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.StoryItem
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebPageAttribute.webPageAttributeStory(Cons_webPageAttributeStory(flags: _1!, peer: _2!, id: _3!, story: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageAttributeTheme(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
                }
            }
            var _3: Api.ThemeSettings?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPageAttribute.webPageAttributeTheme(Cons_webPageAttributeTheme(flags: _1!, documents: _2, settings: _3))
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
                return Api.WebPageAttribute.webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift(gift: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebViewMessageSent: TypeConstructorDescription {
        public class Cons_webViewMessageSent: TypeConstructorDescription {
            public var flags: Int32
            public var msgId: Api.InputBotInlineMessageID?
            public init(flags: Int32, msgId: Api.InputBotInlineMessageID?) {
                self.flags = flags
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webViewMessageSent", [("flags", ConstructorParameterDescription(self.flags)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        case webViewMessageSent(Cons_webViewMessageSent)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webViewMessageSent(let _data):
                if boxed {
                    buffer.appendInt32(211046684)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.msgId!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webViewMessageSent(let _data):
                return ("webViewMessageSent", [("flags", ConstructorParameterDescription(_data.flags)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            }
        }

        public static func parse_webViewMessageSent(_ reader: BufferReader) -> WebViewMessageSent? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebViewMessageSent.webViewMessageSent(Cons_webViewMessageSent(flags: _1!, msgId: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebViewResult: TypeConstructorDescription {
        public class Cons_webViewResultUrl: TypeConstructorDescription {
            public var flags: Int32
            public var queryId: Int64?
            public var url: String
            public init(flags: Int32, queryId: Int64?, url: String) {
                self.flags = flags
                self.queryId = queryId
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webViewResultUrl", [("flags", ConstructorParameterDescription(self.flags)), ("queryId", ConstructorParameterDescription(self.queryId)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        case webViewResultUrl(Cons_webViewResultUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webViewResultUrl(let _data):
                if boxed {
                    buffer.appendInt32(1294139288)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.queryId!, buffer: buffer, boxed: false)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webViewResultUrl(let _data):
                return ("webViewResultUrl", [("flags", ConstructorParameterDescription(_data.flags)), ("queryId", ConstructorParameterDescription(_data.queryId)), ("url", ConstructorParameterDescription(_data.url))])
            }
        }

        public static func parse_webViewResultUrl(_ reader: BufferReader) -> WebViewResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebViewResult.webViewResultUrl(Cons_webViewResultUrl(flags: _1!, queryId: _2, url: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum AuthorizationForm: TypeConstructorDescription {
        public class Cons_authorizationForm: TypeConstructorDescription {
            public var flags: Int32
            public var requiredTypes: [Api.SecureRequiredType]
            public var values: [Api.SecureValue]
            public var errors: [Api.SecureValueError]
            public var users: [Api.User]
            public var privacyPolicyUrl: String?
            public init(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?) {
                self.flags = flags
                self.requiredTypes = requiredTypes
                self.values = values
                self.errors = errors
                self.users = users
                self.privacyPolicyUrl = privacyPolicyUrl
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("authorizationForm", [("flags", ConstructorParameterDescription(self.flags)), ("requiredTypes", ConstructorParameterDescription(self.requiredTypes)), ("values", ConstructorParameterDescription(self.values)), ("errors", ConstructorParameterDescription(self.errors)), ("users", ConstructorParameterDescription(self.users)), ("privacyPolicyUrl", ConstructorParameterDescription(self.privacyPolicyUrl))])
            }
        }
        case authorizationForm(Cons_authorizationForm)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .authorizationForm(let _data):
                if boxed {
                    buffer.appendInt32(-1389486888)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.requiredTypes.count))
                for item in _data.requiredTypes {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.values.count))
                for item in _data.values {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.errors.count))
                for item in _data.errors {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.privacyPolicyUrl!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .authorizationForm(let _data):
                return ("authorizationForm", [("flags", ConstructorParameterDescription(_data.flags)), ("requiredTypes", ConstructorParameterDescription(_data.requiredTypes)), ("values", ConstructorParameterDescription(_data.values)), ("errors", ConstructorParameterDescription(_data.errors)), ("users", ConstructorParameterDescription(_data.users)), ("privacyPolicyUrl", ConstructorParameterDescription(_data.privacyPolicyUrl))])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.AuthorizationForm.authorizationForm(Cons_authorizationForm(flags: _1!, requiredTypes: _2!, values: _3!, errors: _4!, users: _5!, privacyPolicyUrl: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Authorizations: TypeConstructorDescription {
        public class Cons_authorizations: TypeConstructorDescription {
            public var authorizationTtlDays: Int32
            public var authorizations: [Api.Authorization]
            public init(authorizationTtlDays: Int32, authorizations: [Api.Authorization]) {
                self.authorizationTtlDays = authorizationTtlDays
                self.authorizations = authorizations
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("authorizations", [("authorizationTtlDays", ConstructorParameterDescription(self.authorizationTtlDays)), ("authorizations", ConstructorParameterDescription(self.authorizations))])
            }
        }
        case authorizations(Cons_authorizations)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .authorizations(let _data):
                if boxed {
                    buffer.appendInt32(1275039392)
                }
                serializeInt32(_data.authorizationTtlDays, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.authorizations.count))
                for item in _data.authorizations {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .authorizations(let _data):
                return ("authorizations", [("authorizationTtlDays", ConstructorParameterDescription(_data.authorizationTtlDays)), ("authorizations", ConstructorParameterDescription(_data.authorizations))])
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
                return Api.account.Authorizations.authorizations(Cons_authorizations(authorizationTtlDays: _1!, authorizations: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum AutoDownloadSettings: TypeConstructorDescription {
        public class Cons_autoDownloadSettings: TypeConstructorDescription {
            public var low: Api.AutoDownloadSettings
            public var medium: Api.AutoDownloadSettings
            public var high: Api.AutoDownloadSettings
            public init(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings) {
                self.low = low
                self.medium = medium
                self.high = high
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("autoDownloadSettings", [("low", ConstructorParameterDescription(self.low)), ("medium", ConstructorParameterDescription(self.medium)), ("high", ConstructorParameterDescription(self.high))])
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .autoDownloadSettings(let _data):
                if boxed {
                    buffer.appendInt32(1674235686)
                }
                _data.low.serialize(buffer, true)
                _data.medium.serialize(buffer, true)
                _data.high.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .autoDownloadSettings(let _data):
                return ("autoDownloadSettings", [("low", ConstructorParameterDescription(_data.low)), ("medium", ConstructorParameterDescription(_data.medium)), ("high", ConstructorParameterDescription(_data.high))])
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
                return Api.account.AutoDownloadSettings.autoDownloadSettings(Cons_autoDownloadSettings(low: _1!, medium: _2!, high: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum AutoSaveSettings: TypeConstructorDescription {
        public class Cons_autoSaveSettings: TypeConstructorDescription {
            public var usersSettings: Api.AutoSaveSettings
            public var chatsSettings: Api.AutoSaveSettings
            public var broadcastsSettings: Api.AutoSaveSettings
            public var exceptions: [Api.AutoSaveException]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(usersSettings: Api.AutoSaveSettings, chatsSettings: Api.AutoSaveSettings, broadcastsSettings: Api.AutoSaveSettings, exceptions: [Api.AutoSaveException], chats: [Api.Chat], users: [Api.User]) {
                self.usersSettings = usersSettings
                self.chatsSettings = chatsSettings
                self.broadcastsSettings = broadcastsSettings
                self.exceptions = exceptions
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("autoSaveSettings", [("usersSettings", ConstructorParameterDescription(self.usersSettings)), ("chatsSettings", ConstructorParameterDescription(self.chatsSettings)), ("broadcastsSettings", ConstructorParameterDescription(self.broadcastsSettings)), ("exceptions", ConstructorParameterDescription(self.exceptions)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .autoSaveSettings(let _data):
                if boxed {
                    buffer.appendInt32(1279133341)
                }
                _data.usersSettings.serialize(buffer, true)
                _data.chatsSettings.serialize(buffer, true)
                _data.broadcastsSettings.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.exceptions.count))
                for item in _data.exceptions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .autoSaveSettings(let _data):
                return ("autoSaveSettings", [("usersSettings", ConstructorParameterDescription(_data.usersSettings)), ("chatsSettings", ConstructorParameterDescription(_data.chatsSettings)), ("broadcastsSettings", ConstructorParameterDescription(_data.broadcastsSettings)), ("exceptions", ConstructorParameterDescription(_data.exceptions)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.AutoSaveSettings.autoSaveSettings(Cons_autoSaveSettings(usersSettings: _1!, chatsSettings: _2!, broadcastsSettings: _3!, exceptions: _4!, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum BusinessChatLinks: TypeConstructorDescription {
        public class Cons_businessChatLinks: TypeConstructorDescription {
            public var links: [Api.BusinessChatLink]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(links: [Api.BusinessChatLink], chats: [Api.Chat], users: [Api.User]) {
                self.links = links
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("businessChatLinks", [("links", ConstructorParameterDescription(self.links)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case businessChatLinks(Cons_businessChatLinks)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessChatLinks(let _data):
                if boxed {
                    buffer.appendInt32(-331111727)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.links.count))
                for item in _data.links {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .businessChatLinks(let _data):
                return ("businessChatLinks", [("links", ConstructorParameterDescription(_data.links)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.BusinessChatLinks.businessChatLinks(Cons_businessChatLinks(links: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ChatThemes: TypeConstructorDescription {
        public class Cons_chatThemes: TypeConstructorDescription {
            public var flags: Int32
            public var hash: Int64
            public var themes: [Api.ChatTheme]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, hash: Int64, themes: [Api.ChatTheme], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.hash = hash
                self.themes = themes
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatThemes", [("flags", ConstructorParameterDescription(self.flags)), ("hash", ConstructorParameterDescription(self.hash)), ("themes", ConstructorParameterDescription(self.themes)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users)), ("nextOffset", ConstructorParameterDescription(self.nextOffset))])
            }
        }
        case chatThemes(Cons_chatThemes)
        case chatThemesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatThemes(let _data):
                if boxed {
                    buffer.appendInt32(-1106673293)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.themes.count))
                for item in _data.themes {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            case .chatThemesNotModified:
                if boxed {
                    buffer.appendInt32(-535699004)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatThemes(let _data):
                return ("chatThemes", [("flags", ConstructorParameterDescription(_data.flags)), ("hash", ConstructorParameterDescription(_data.hash)), ("themes", ConstructorParameterDescription(_data.themes)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset))])
            case .chatThemesNotModified:
                return ("chatThemesNotModified", [])
            }
        }

        public static func parse_chatThemes(_ reader: BufferReader) -> ChatThemes? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.ChatTheme]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChatTheme.self)
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.ChatThemes.chatThemes(Cons_chatThemes(flags: _1!, hash: _2!, themes: _3!, chats: _4!, users: _5!, nextOffset: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_chatThemesNotModified(_ reader: BufferReader) -> ChatThemes? {
            return Api.account.ChatThemes.chatThemesNotModified
        }
    }
}
public extension Api.account {
    enum ConnectedBots: TypeConstructorDescription {
        public class Cons_connectedBots: TypeConstructorDescription {
            public var connectedBots: [Api.ConnectedBot]
            public var users: [Api.User]
            public init(connectedBots: [Api.ConnectedBot], users: [Api.User]) {
                self.connectedBots = connectedBots
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("connectedBots", [("connectedBots", ConstructorParameterDescription(self.connectedBots)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case connectedBots(Cons_connectedBots)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .connectedBots(let _data):
                if boxed {
                    buffer.appendInt32(400029819)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.connectedBots.count))
                for item in _data.connectedBots {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .connectedBots(let _data):
                return ("connectedBots", [("connectedBots", ConstructorParameterDescription(_data.connectedBots)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.ConnectedBots.connectedBots(Cons_connectedBots(connectedBots: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ContentSettings: TypeConstructorDescription {
        public class Cons_contentSettings: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("contentSettings", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        case contentSettings(Cons_contentSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .contentSettings(let _data):
                if boxed {
                    buffer.appendInt32(1474462241)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .contentSettings(let _data):
                return ("contentSettings", [("flags", ConstructorParameterDescription(_data.flags))])
            }
        }

        public static func parse_contentSettings(_ reader: BufferReader) -> ContentSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ContentSettings.contentSettings(Cons_contentSettings(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum EmailVerified: TypeConstructorDescription {
        public class Cons_emailVerified: TypeConstructorDescription {
            public var email: String
            public init(email: String) {
                self.email = email
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerified", [("email", ConstructorParameterDescription(self.email))])
            }
        }
        public class Cons_emailVerifiedLogin: TypeConstructorDescription {
            public var email: String
            public var sentCode: Api.auth.SentCode
            public init(email: String, sentCode: Api.auth.SentCode) {
                self.email = email
                self.sentCode = sentCode
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerifiedLogin", [("email", ConstructorParameterDescription(self.email)), ("sentCode", ConstructorParameterDescription(self.sentCode))])
            }
        }
        case emailVerified(Cons_emailVerified)
        case emailVerifiedLogin(Cons_emailVerifiedLogin)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emailVerified(let _data):
                if boxed {
                    buffer.appendInt32(731303195)
                }
                serializeString(_data.email, buffer: buffer, boxed: false)
                break
            case .emailVerifiedLogin(let _data):
                if boxed {
                    buffer.appendInt32(-507835039)
                }
                serializeString(_data.email, buffer: buffer, boxed: false)
                _data.sentCode.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emailVerified(let _data):
                return ("emailVerified", [("email", ConstructorParameterDescription(_data.email))])
            case .emailVerifiedLogin(let _data):
                return ("emailVerifiedLogin", [("email", ConstructorParameterDescription(_data.email)), ("sentCode", ConstructorParameterDescription(_data.sentCode))])
            }
        }

        public static func parse_emailVerified(_ reader: BufferReader) -> EmailVerified? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.EmailVerified.emailVerified(Cons_emailVerified(email: _1!))
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
                return Api.account.EmailVerified.emailVerifiedLogin(Cons_emailVerifiedLogin(email: _1!, sentCode: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum EmojiStatuses: TypeConstructorDescription {
        public class Cons_emojiStatuses: TypeConstructorDescription {
            public var hash: Int64
            public var statuses: [Api.EmojiStatus]
            public init(hash: Int64, statuses: [Api.EmojiStatus]) {
                self.hash = hash
                self.statuses = statuses
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatuses", [("hash", ConstructorParameterDescription(self.hash)), ("statuses", ConstructorParameterDescription(self.statuses))])
            }
        }
        case emojiStatuses(Cons_emojiStatuses)
        case emojiStatusesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiStatuses(let _data):
                if boxed {
                    buffer.appendInt32(-1866176559)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.statuses.count))
                for item in _data.statuses {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiStatuses(let _data):
                return ("emojiStatuses", [("hash", ConstructorParameterDescription(_data.hash)), ("statuses", ConstructorParameterDescription(_data.statuses))])
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
                return Api.account.EmojiStatuses.emojiStatuses(Cons_emojiStatuses(hash: _1!, statuses: _2!))
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
        public class Cons_paidMessagesRevenue: TypeConstructorDescription {
            public var starsAmount: Int64
            public init(starsAmount: Int64) {
                self.starsAmount = starsAmount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("paidMessagesRevenue", [("starsAmount", ConstructorParameterDescription(self.starsAmount))])
            }
        }
        case paidMessagesRevenue(Cons_paidMessagesRevenue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paidMessagesRevenue(let _data):
                if boxed {
                    buffer.appendInt32(504403720)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .paidMessagesRevenue(let _data):
                return ("paidMessagesRevenue", [("starsAmount", ConstructorParameterDescription(_data.starsAmount))])
            }
        }

        public static func parse_paidMessagesRevenue(_ reader: BufferReader) -> PaidMessagesRevenue? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.PaidMessagesRevenue.paidMessagesRevenue(Cons_paidMessagesRevenue(starsAmount: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasskeyRegistrationOptions: TypeConstructorDescription {
        public class Cons_passkeyRegistrationOptions: TypeConstructorDescription {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passkeyRegistrationOptions", [("options", ConstructorParameterDescription(self.options))])
            }
        }
        case passkeyRegistrationOptions(Cons_passkeyRegistrationOptions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkeyRegistrationOptions(let _data):
                if boxed {
                    buffer.appendInt32(-513057567)
                }
                _data.options.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passkeyRegistrationOptions(let _data):
                return ("passkeyRegistrationOptions", [("options", ConstructorParameterDescription(_data.options))])
            }
        }

        public static func parse_passkeyRegistrationOptions(_ reader: BufferReader) -> PasskeyRegistrationOptions? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.PasskeyRegistrationOptions.passkeyRegistrationOptions(Cons_passkeyRegistrationOptions(options: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Passkeys: TypeConstructorDescription {
        public class Cons_passkeys: TypeConstructorDescription {
            public var passkeys: [Api.Passkey]
            public init(passkeys: [Api.Passkey]) {
                self.passkeys = passkeys
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passkeys", [("passkeys", ConstructorParameterDescription(self.passkeys))])
            }
        }
        case passkeys(Cons_passkeys)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkeys(let _data):
                if boxed {
                    buffer.appendInt32(-119494116)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.passkeys.count))
                for item in _data.passkeys {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passkeys(let _data):
                return ("passkeys", [("passkeys", ConstructorParameterDescription(_data.passkeys))])
            }
        }

        public static func parse_passkeys(_ reader: BufferReader) -> Passkeys? {
            var _1: [Api.Passkey]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Passkey.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Passkeys.passkeys(Cons_passkeys(passkeys: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription {
        public class Cons_password: TypeConstructorDescription {
            public var flags: Int32
            public var currentAlgo: Api.PasswordKdfAlgo?
            public var srpB: Buffer?
            public var srpId: Int64?
            public var hint: String?
            public var emailUnconfirmedPattern: String?
            public var newAlgo: Api.PasswordKdfAlgo
            public var newSecureAlgo: Api.SecurePasswordKdfAlgo
            public var secureRandom: Buffer
            public var pendingResetDate: Int32?
            public var loginEmailPattern: String?
            public init(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?) {
                self.flags = flags
                self.currentAlgo = currentAlgo
                self.srpB = srpB
                self.srpId = srpId
                self.hint = hint
                self.emailUnconfirmedPattern = emailUnconfirmedPattern
                self.newAlgo = newAlgo
                self.newSecureAlgo = newSecureAlgo
                self.secureRandom = secureRandom
                self.pendingResetDate = pendingResetDate
                self.loginEmailPattern = loginEmailPattern
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("password", [("flags", ConstructorParameterDescription(self.flags)), ("currentAlgo", ConstructorParameterDescription(self.currentAlgo)), ("srpB", ConstructorParameterDescription(self.srpB)), ("srpId", ConstructorParameterDescription(self.srpId)), ("hint", ConstructorParameterDescription(self.hint)), ("emailUnconfirmedPattern", ConstructorParameterDescription(self.emailUnconfirmedPattern)), ("newAlgo", ConstructorParameterDescription(self.newAlgo)), ("newSecureAlgo", ConstructorParameterDescription(self.newSecureAlgo)), ("secureRandom", ConstructorParameterDescription(self.secureRandom)), ("pendingResetDate", ConstructorParameterDescription(self.pendingResetDate)), ("loginEmailPattern", ConstructorParameterDescription(self.loginEmailPattern))])
            }
        }
        case password(Cons_password)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .password(let _data):
                if boxed {
                    buffer.appendInt32(-1787080453)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.currentAlgo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeBytes(_data.srpB!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.srpId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.hint!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.emailUnconfirmedPattern!, buffer: buffer, boxed: false)
                }
                _data.newAlgo.serialize(buffer, true)
                _data.newSecureAlgo.serialize(buffer, true)
                serializeBytes(_data.secureRandom, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.pendingResetDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.loginEmailPattern!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .password(let _data):
                return ("password", [("flags", ConstructorParameterDescription(_data.flags)), ("currentAlgo", ConstructorParameterDescription(_data.currentAlgo)), ("srpB", ConstructorParameterDescription(_data.srpB)), ("srpId", ConstructorParameterDescription(_data.srpId)), ("hint", ConstructorParameterDescription(_data.hint)), ("emailUnconfirmedPattern", ConstructorParameterDescription(_data.emailUnconfirmedPattern)), ("newAlgo", ConstructorParameterDescription(_data.newAlgo)), ("newSecureAlgo", ConstructorParameterDescription(_data.newSecureAlgo)), ("secureRandom", ConstructorParameterDescription(_data.secureRandom)), ("pendingResetDate", ConstructorParameterDescription(_data.pendingResetDate)), ("loginEmailPattern", ConstructorParameterDescription(_data.loginEmailPattern))])
            }
        }

        public static func parse_password(_ reader: BufferReader) -> Password? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
                }
            }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt64()
            }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = parseString(reader)
            }
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
            if Int(_1!) & Int(1 << 5) != 0 {
                _10 = reader.readInt32()
            }
            var _11: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _11 = parseString(reader)
            }
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
                return Api.account.Password.password(Cons_password(flags: _1!, currentAlgo: _2, srpB: _3, srpId: _4, hint: _5, emailUnconfirmedPattern: _6, newAlgo: _7!, newSecureAlgo: _8!, secureRandom: _9!, pendingResetDate: _10, loginEmailPattern: _11))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription {
        public class Cons_passwordInputSettings: TypeConstructorDescription {
            public var flags: Int32
            public var newAlgo: Api.PasswordKdfAlgo?
            public var newPasswordHash: Buffer?
            public var hint: String?
            public var email: String?
            public var newSecureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.newAlgo = newAlgo
                self.newPasswordHash = newPasswordHash
                self.hint = hint
                self.email = email
                self.newSecureSettings = newSecureSettings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passwordInputSettings", [("flags", ConstructorParameterDescription(self.flags)), ("newAlgo", ConstructorParameterDescription(self.newAlgo)), ("newPasswordHash", ConstructorParameterDescription(self.newPasswordHash)), ("hint", ConstructorParameterDescription(self.hint)), ("email", ConstructorParameterDescription(self.email)), ("newSecureSettings", ConstructorParameterDescription(self.newSecureSettings))])
            }
        }
        case passwordInputSettings(Cons_passwordInputSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordInputSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1036572727)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.newAlgo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.newPasswordHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.hint!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.email!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.newSecureSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passwordInputSettings(let _data):
                return ("passwordInputSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("newAlgo", ConstructorParameterDescription(_data.newAlgo)), ("newPasswordHash", ConstructorParameterDescription(_data.newPasswordHash)), ("hint", ConstructorParameterDescription(_data.hint)), ("email", ConstructorParameterDescription(_data.email)), ("newSecureSettings", ConstructorParameterDescription(_data.newSecureSettings))])
            }
        }

        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
                }
            }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.PasswordInputSettings.passwordInputSettings(Cons_passwordInputSettings(flags: _1!, newAlgo: _2, newPasswordHash: _3, hint: _4, email: _5, newSecureSettings: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription {
        public class Cons_passwordSettings: TypeConstructorDescription {
            public var flags: Int32
            public var email: String?
            public var secureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.email = email
                self.secureSettings = secureSettings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passwordSettings", [("flags", ConstructorParameterDescription(self.flags)), ("email", ConstructorParameterDescription(self.email)), ("secureSettings", ConstructorParameterDescription(self.secureSettings))])
            }
        }
        case passwordSettings(Cons_passwordSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1705233435)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.email!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.secureSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passwordSettings(let _data):
                return ("passwordSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("email", ConstructorParameterDescription(_data.email)), ("secureSettings", ConstructorParameterDescription(_data.secureSettings))])
            }
        }

        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.PasswordSettings.passwordSettings(Cons_passwordSettings(flags: _1!, email: _2, secureSettings: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription {
        public class Cons_privacyRules: TypeConstructorDescription {
            public var rules: [Api.PrivacyRule]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User]) {
                self.rules = rules
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyRules", [("rules", ConstructorParameterDescription(self.rules)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case privacyRules(Cons_privacyRules)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .privacyRules(let _data):
                if boxed {
                    buffer.appendInt32(1352683077)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rules.count))
                for item in _data.rules {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .privacyRules(let _data):
                return ("privacyRules", [("rules", ConstructorParameterDescription(_data.rules)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.PrivacyRules.privacyRules(Cons_privacyRules(rules: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription {
        public class Cons_resetPasswordFailedWait: TypeConstructorDescription {
            public var retryDate: Int32
            public init(retryDate: Int32) {
                self.retryDate = retryDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resetPasswordFailedWait", [("retryDate", ConstructorParameterDescription(self.retryDate))])
            }
        }
        public class Cons_resetPasswordRequestedWait: TypeConstructorDescription {
            public var untilDate: Int32
            public init(untilDate: Int32) {
                self.untilDate = untilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resetPasswordRequestedWait", [("untilDate", ConstructorParameterDescription(self.untilDate))])
            }
        }
        case resetPasswordFailedWait(Cons_resetPasswordFailedWait)
        case resetPasswordOk
        case resetPasswordRequestedWait(Cons_resetPasswordRequestedWait)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resetPasswordFailedWait(let _data):
                if boxed {
                    buffer.appendInt32(-478701471)
                }
                serializeInt32(_data.retryDate, buffer: buffer, boxed: false)
                break
            case .resetPasswordOk:
                if boxed {
                    buffer.appendInt32(-383330754)
                }
                break
            case .resetPasswordRequestedWait(let _data):
                if boxed {
                    buffer.appendInt32(-370148227)
                }
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .resetPasswordFailedWait(let _data):
                return ("resetPasswordFailedWait", [("retryDate", ConstructorParameterDescription(_data.retryDate))])
            case .resetPasswordOk:
                return ("resetPasswordOk", [])
            case .resetPasswordRequestedWait(let _data):
                return ("resetPasswordRequestedWait", [("untilDate", ConstructorParameterDescription(_data.untilDate))])
            }
        }

        public static func parse_resetPasswordFailedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordFailedWait(Cons_resetPasswordFailedWait(retryDate: _1!))
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
                return Api.account.ResetPasswordResult.resetPasswordRequestedWait(Cons_resetPasswordRequestedWait(untilDate: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ResolvedBusinessChatLinks: TypeConstructorDescription {
        public class Cons_resolvedBusinessChatLinks: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.peer = peer
                self.message = message
                self.entities = entities
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resolvedBusinessChatLinks", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resolvedBusinessChatLinks(let _data):
                if boxed {
                    buffer.appendInt32(-1708937439)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .resolvedBusinessChatLinks(let _data):
                return ("resolvedBusinessChatLinks", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
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
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.ResolvedBusinessChatLinks.resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks(flags: _1!, peer: _2!, message: _3!, entities: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
