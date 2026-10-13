public extension Api {
    enum WalletTransactionPeer: TypeConstructorDescription {
        public class Cons_walletTransactionPeerAddress: TypeConstructorDescription {
            public var flags: Int32
            public var address: String
            public var domain: String?
            public init(flags: Int32, address: String, domain: String?) {
                self.flags = flags
                self.address = address
                self.domain = domain
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("walletTransactionPeerAddress", [("flags", ConstructorParameterDescription(self.flags)), ("address", ConstructorParameterDescription(self.address)), ("domain", ConstructorParameterDescription(self.domain))])
            }
        }
        public class Cons_walletTransactionPeerOnramp: TypeConstructorDescription {
            public var flags: Int32
            public var address: String
            public var domain: String?
            public var providerName: String
            public init(flags: Int32, address: String, domain: String?, providerName: String) {
                self.flags = flags
                self.address = address
                self.domain = domain
                self.providerName = providerName
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("walletTransactionPeerOnramp", [("flags", ConstructorParameterDescription(self.flags)), ("address", ConstructorParameterDescription(self.address)), ("domain", ConstructorParameterDescription(self.domain)), ("providerName", ConstructorParameterDescription(self.providerName))])
            }
        }
        public class Cons_walletTransactionPeerUser: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var address: String
            public var domain: String?
            public init(flags: Int32, userId: Int64, address: String, domain: String?) {
                self.flags = flags
                self.userId = userId
                self.address = address
                self.domain = domain
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("walletTransactionPeerUser", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("address", ConstructorParameterDescription(self.address)), ("domain", ConstructorParameterDescription(self.domain))])
            }
        }
        case walletTransactionPeerAddress(Cons_walletTransactionPeerAddress)
        case walletTransactionPeerOnramp(Cons_walletTransactionPeerOnramp)
        case walletTransactionPeerUnsupported
        case walletTransactionPeerUser(Cons_walletTransactionPeerUser)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .walletTransactionPeerAddress(let _data):
                if boxed {
                    buffer.appendInt32(103596476)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.domain!, buffer: buffer, boxed: false)
                }
                break
            case .walletTransactionPeerOnramp(let _data):
                if boxed {
                    buffer.appendInt32(-443213714)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.domain!, buffer: buffer, boxed: false)
                }
                serializeString(_data.providerName, buffer: buffer, boxed: false)
                break
            case .walletTransactionPeerUnsupported:
                if boxed {
                    buffer.appendInt32(1921772890)
                }
                break
            case .walletTransactionPeerUser(let _data):
                if boxed {
                    buffer.appendInt32(-722833299)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.domain!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .walletTransactionPeerAddress(let _data):
                return ("walletTransactionPeerAddress", [("flags", ConstructorParameterDescription(_data.flags)), ("address", ConstructorParameterDescription(_data.address)), ("domain", ConstructorParameterDescription(_data.domain))])
            case .walletTransactionPeerOnramp(let _data):
                return ("walletTransactionPeerOnramp", [("flags", ConstructorParameterDescription(_data.flags)), ("address", ConstructorParameterDescription(_data.address)), ("domain", ConstructorParameterDescription(_data.domain)), ("providerName", ConstructorParameterDescription(_data.providerName))])
            case .walletTransactionPeerUnsupported:
                return ("walletTransactionPeerUnsupported", [])
            case .walletTransactionPeerUser(let _data):
                return ("walletTransactionPeerUser", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("address", ConstructorParameterDescription(_data.address)), ("domain", ConstructorParameterDescription(_data.domain))])
            }
        }

        public static func parse_walletTransactionPeerAddress(_ reader: BufferReader) -> WalletTransactionPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WalletTransactionPeer.walletTransactionPeerAddress(Cons_walletTransactionPeerAddress(flags: _1!, address: _2!, domain: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_walletTransactionPeerOnramp(_ reader: BufferReader) -> WalletTransactionPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WalletTransactionPeer.walletTransactionPeerOnramp(Cons_walletTransactionPeerOnramp(flags: _1!, address: _2!, domain: _3, providerName: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_walletTransactionPeerUnsupported(_ reader: BufferReader) -> WalletTransactionPeer? {
            return Api.WalletTransactionPeer.walletTransactionPeerUnsupported
        }
        public static func parse_walletTransactionPeerUser(_ reader: BufferReader) -> WalletTransactionPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WalletTransactionPeer.walletTransactionPeerUser(Cons_walletTransactionPeerUser(flags: _1!, userId: _2!, address: _3!, domain: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WalletUserAddress: TypeConstructorDescription {
        public class Cons_walletUserAddress: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64?
            public var address: String
            public var publicKey: Buffer
            public init(flags: Int32, userId: Int64?, address: String, publicKey: Buffer) {
                self.flags = flags
                self.userId = userId
                self.address = address
                self.publicKey = publicKey
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("walletUserAddress", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("address", ConstructorParameterDescription(self.address)), ("publicKey", ConstructorParameterDescription(self.publicKey))])
            }
        }
        case walletUserAddress(Cons_walletUserAddress)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .walletUserAddress(let _data):
                if boxed {
                    buffer.appendInt32(-25628980)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.userId!, buffer: buffer, boxed: false)
                }
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeBytes(_data.publicKey, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .walletUserAddress(let _data):
                return ("walletUserAddress", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("address", ConstructorParameterDescription(_data.address)), ("publicKey", ConstructorParameterDescription(_data.publicKey))])
            }
        }

        public static func parse_walletUserAddress(_ reader: BufferReader) -> WalletUserAddress? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WalletUserAddress.walletUserAddress(Cons_walletUserAddress(flags: _1!, userId: _2, address: _3!, publicKey: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription {
        public class Cons_webAuthorization: TypeConstructorDescription {
            public var hash: Int64
            public var botId: Int64
            public var domain: String
            public var browser: String
            public var platform: String
            public var dateCreated: Int32
            public var dateActive: Int32
            public var ip: String
            public var region: String
            public init(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String) {
                self.hash = hash
                self.botId = botId
                self.domain = domain
                self.browser = browser
                self.platform = platform
                self.dateCreated = dateCreated
                self.dateActive = dateActive
                self.ip = ip
                self.region = region
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webAuthorization", [("hash", ConstructorParameterDescription(self.hash)), ("botId", ConstructorParameterDescription(self.botId)), ("domain", ConstructorParameterDescription(self.domain)), ("browser", ConstructorParameterDescription(self.browser)), ("platform", ConstructorParameterDescription(self.platform)), ("dateCreated", ConstructorParameterDescription(self.dateCreated)), ("dateActive", ConstructorParameterDescription(self.dateActive)), ("ip", ConstructorParameterDescription(self.ip)), ("region", ConstructorParameterDescription(self.region))])
            }
        }
        case webAuthorization(Cons_webAuthorization)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webAuthorization(let _data):
                if boxed {
                    buffer.appendInt32(-1493633966)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                serializeString(_data.browser, buffer: buffer, boxed: false)
                serializeString(_data.platform, buffer: buffer, boxed: false)
                serializeInt32(_data.dateCreated, buffer: buffer, boxed: false)
                serializeInt32(_data.dateActive, buffer: buffer, boxed: false)
                serializeString(_data.ip, buffer: buffer, boxed: false)
                serializeString(_data.region, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webAuthorization(let _data):
                return ("webAuthorization", [("hash", ConstructorParameterDescription(_data.hash)), ("botId", ConstructorParameterDescription(_data.botId)), ("domain", ConstructorParameterDescription(_data.domain)), ("browser", ConstructorParameterDescription(_data.browser)), ("platform", ConstructorParameterDescription(_data.platform)), ("dateCreated", ConstructorParameterDescription(_data.dateCreated)), ("dateActive", ConstructorParameterDescription(_data.dateActive)), ("ip", ConstructorParameterDescription(_data.ip)), ("region", ConstructorParameterDescription(_data.region))])
            }
        }

        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.WebAuthorization.webAuthorization(Cons_webAuthorization(hash: _1!, botId: _2!, domain: _3!, browser: _4!, platform: _5!, dateCreated: _6!, dateActive: _7!, ip: _8!, region: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription {
        public class Cons_webDocument: TypeConstructorDescription {
            public var url: String
            public var accessHash: Int64
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.accessHash = accessHash
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webDocument", [("url", ConstructorParameterDescription(self.url)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("size", ConstructorParameterDescription(self.size)), ("mimeType", ConstructorParameterDescription(self.mimeType)), ("attributes", ConstructorParameterDescription(self.attributes))])
            }
        }
        public class Cons_webDocumentNoProxy: TypeConstructorDescription {
            public var url: String
            public var size: Int32
            public var mimeType: String
            public var attributes: [Api.DocumentAttribute]
            public init(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
                self.url = url
                self.size = size
                self.mimeType = mimeType
                self.attributes = attributes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webDocumentNoProxy", [("url", ConstructorParameterDescription(self.url)), ("size", ConstructorParameterDescription(self.size)), ("mimeType", ConstructorParameterDescription(self.mimeType)), ("attributes", ConstructorParameterDescription(self.attributes))])
            }
        }
        case webDocument(Cons_webDocument)
        case webDocumentNoProxy(Cons_webDocumentNoProxy)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webDocument(let _data):
                if boxed {
                    buffer.appendInt32(475467473)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            case .webDocumentNoProxy(let _data):
                if boxed {
                    buffer.appendInt32(-104284986)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webDocument(let _data):
                return ("webDocument", [("url", ConstructorParameterDescription(_data.url)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("size", ConstructorParameterDescription(_data.size)), ("mimeType", ConstructorParameterDescription(_data.mimeType)), ("attributes", ConstructorParameterDescription(_data.attributes))])
            case .webDocumentNoProxy(let _data):
                return ("webDocumentNoProxy", [("url", ConstructorParameterDescription(_data.url)), ("size", ConstructorParameterDescription(_data.size)), ("mimeType", ConstructorParameterDescription(_data.mimeType)), ("attributes", ConstructorParameterDescription(_data.attributes))])
            }
        }

        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WebDocument.webDocument(Cons_webDocument(url: _1!, accessHash: _2!, size: _3!, mimeType: _4!, attributes: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebDocument.webDocumentNoProxy(Cons_webDocumentNoProxy(url: _1!, size: _2!, mimeType: _3!, attributes: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebDomainException: TypeConstructorDescription {
        public class Cons_webDomainException: TypeConstructorDescription {
            public var flags: Int32
            public var domain: String
            public var url: String
            public var title: String
            public var favicon: Int64?
            public init(flags: Int32, domain: String, url: String, title: String, favicon: Int64?) {
                self.flags = flags
                self.domain = domain
                self.url = url
                self.title = title
                self.favicon = favicon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webDomainException", [("flags", ConstructorParameterDescription(self.flags)), ("domain", ConstructorParameterDescription(self.domain)), ("url", ConstructorParameterDescription(self.url)), ("title", ConstructorParameterDescription(self.title)), ("favicon", ConstructorParameterDescription(self.favicon))])
            }
        }
        case webDomainException(Cons_webDomainException)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webDomainException(let _data):
                if boxed {
                    buffer.appendInt32(-1824741993)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.favicon!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webDomainException(let _data):
                return ("webDomainException", [("flags", ConstructorParameterDescription(_data.flags)), ("domain", ConstructorParameterDescription(_data.domain)), ("url", ConstructorParameterDescription(_data.url)), ("title", ConstructorParameterDescription(_data.title)), ("favicon", ConstructorParameterDescription(_data.favicon))])
            }
        }

        public static func parse_webDomainException(_ reader: BufferReader) -> WebDomainException? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WebDomainException.webDomainException(Cons_webDomainException(flags: _1!, domain: _2!, url: _3!, title: _4!, favicon: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription {
        public class Cons_webPage: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var url: String
            public var displayUrl: String
            public var hash: Int32
            public var type: String?
            public var siteName: String?
            public var title: String?
            public var description: String?
            public var photo: Api.Photo?
            public var embedUrl: String?
            public var embedType: String?
            public var embedWidth: Int32?
            public var embedHeight: Int32?
            public var duration: Int32?
            public var author: String?
            public var document: Api.Document?
            public var cachedPage: Api.Page?
            public var attributes: [Api.WebPageAttribute]?
            public init(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?) {
                self.flags = flags
                self.id = id
                self.url = url
                self.displayUrl = displayUrl
                self.hash = hash
                self.type = type
                self.siteName = siteName
                self.title = title
                self.description = description
                self.photo = photo
                self.embedUrl = embedUrl
                self.embedType = embedType
                self.embedWidth = embedWidth
                self.embedHeight = embedHeight
                self.duration = duration
                self.author = author
                self.document = document
                self.cachedPage = cachedPage
                self.attributes = attributes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPage", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("url", ConstructorParameterDescription(self.url)), ("displayUrl", ConstructorParameterDescription(self.displayUrl)), ("hash", ConstructorParameterDescription(self.hash)), ("type", ConstructorParameterDescription(self.type)), ("siteName", ConstructorParameterDescription(self.siteName)), ("title", ConstructorParameterDescription(self.title)), ("description", ConstructorParameterDescription(self.description)), ("photo", ConstructorParameterDescription(self.photo)), ("embedUrl", ConstructorParameterDescription(self.embedUrl)), ("embedType", ConstructorParameterDescription(self.embedType)), ("embedWidth", ConstructorParameterDescription(self.embedWidth)), ("embedHeight", ConstructorParameterDescription(self.embedHeight)), ("duration", ConstructorParameterDescription(self.duration)), ("author", ConstructorParameterDescription(self.author)), ("document", ConstructorParameterDescription(self.document)), ("cachedPage", ConstructorParameterDescription(self.cachedPage)), ("attributes", ConstructorParameterDescription(self.attributes))])
            }
        }
        public class Cons_webPageEmpty: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public init(flags: Int32, id: Int64, url: String?) {
                self.flags = flags
                self.id = id
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageEmpty", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_webPageNotModified: TypeConstructorDescription {
            public var flags: Int32
            public var cachedPageViews: Int32?
            public init(flags: Int32, cachedPageViews: Int32?) {
                self.flags = flags
                self.cachedPageViews = cachedPageViews
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageNotModified", [("flags", ConstructorParameterDescription(self.flags)), ("cachedPageViews", ConstructorParameterDescription(self.cachedPageViews))])
            }
        }
        public class Cons_webPagePending: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var url: String?
            public var date: Int32
            public init(flags: Int32, id: Int64, url: String?, date: Int32) {
                self.flags = flags
                self.id = id
                self.url = url
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPagePending", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("url", ConstructorParameterDescription(self.url)), ("date", ConstructorParameterDescription(self.date))])
            }
        }
        case webPage(Cons_webPage)
        case webPageEmpty(Cons_webPageEmpty)
        case webPageNotModified(Cons_webPageNotModified)
        case webPagePending(Cons_webPagePending)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPage(let _data):
                if boxed {
                    buffer.appendInt32(-392411726)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.displayUrl, buffer: buffer, boxed: false)
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.type!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.siteName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.embedUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.embedType!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.embedWidth!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.embedHeight!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.duration!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeString(_data.author!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.cachedPage!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.attributes!.count))
                    for item in _data.attributes! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .webPageEmpty(let _data):
                if boxed {
                    buffer.appendInt32(555358088)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                break
            case .webPageNotModified(let _data):
                if boxed {
                    buffer.appendInt32(1930545681)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.cachedPageViews!, buffer: buffer, boxed: false)
                }
                break
            case .webPagePending(let _data):
                if boxed {
                    buffer.appendInt32(-1328464313)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webPage(let _data):
                return ("webPage", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("url", ConstructorParameterDescription(_data.url)), ("displayUrl", ConstructorParameterDescription(_data.displayUrl)), ("hash", ConstructorParameterDescription(_data.hash)), ("type", ConstructorParameterDescription(_data.type)), ("siteName", ConstructorParameterDescription(_data.siteName)), ("title", ConstructorParameterDescription(_data.title)), ("description", ConstructorParameterDescription(_data.description)), ("photo", ConstructorParameterDescription(_data.photo)), ("embedUrl", ConstructorParameterDescription(_data.embedUrl)), ("embedType", ConstructorParameterDescription(_data.embedType)), ("embedWidth", ConstructorParameterDescription(_data.embedWidth)), ("embedHeight", ConstructorParameterDescription(_data.embedHeight)), ("duration", ConstructorParameterDescription(_data.duration)), ("author", ConstructorParameterDescription(_data.author)), ("document", ConstructorParameterDescription(_data.document)), ("cachedPage", ConstructorParameterDescription(_data.cachedPage)), ("attributes", ConstructorParameterDescription(_data.attributes))])
            case .webPageEmpty(let _data):
                return ("webPageEmpty", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("url", ConstructorParameterDescription(_data.url))])
            case .webPageNotModified(let _data):
                return ("webPageNotModified", [("flags", ConstructorParameterDescription(_data.flags)), ("cachedPageViews", ConstructorParameterDescription(_data.cachedPageViews))])
            case .webPagePending(let _data):
                return ("webPagePending", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("url", ConstructorParameterDescription(_data.url)), ("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _8 = parseString(reader)
            }
            var _9: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _9 = parseString(reader)
            }
            var _10: Api.Photo?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _11: String?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _11 = parseString(reader)
            }
            var _12: String?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int32?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                _13 = reader.readInt32()
            }
            var _14: Int32?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                _14 = reader.readInt32()
            }
            var _15: Int32?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _15 = reader.readInt32()
            }
            var _16: String?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _16 = parseString(reader)
            }
            var _17: Api.Document?
            if Int(_1 ?? 0) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _18: Api.Page?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _18 = Api.parse(reader, signature: signature) as? Api.Page
                }
            }
            var _19: [Api.WebPageAttribute]?
            if Int(_1 ?? 0) & Int(1 << 12) != 0 {
                if let _ = reader.readInt32() {
                    _19 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebPageAttribute.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _15 != nil
            let _c16 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1 ?? 0) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _18 != nil
            let _c19 = (Int(_1 ?? 0) & Int(1 << 12) == 0) || _19 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 {
                return Api.WebPage.webPage(Cons_webPage(flags: _1!, id: _2!, url: _3!, displayUrl: _4!, hash: _5!, type: _6, siteName: _7, title: _8, description: _9, photo: _10, embedUrl: _11, embedType: _12, embedWidth: _13, embedHeight: _14, duration: _15, author: _16, document: _17, cachedPage: _18, attributes: _19))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPage.webPageEmpty(Cons_webPageEmpty(flags: _1!, id: _2!, url: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebPage.webPageNotModified(Cons_webPageNotModified(flags: _1!, cachedPageViews: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebPage.webPagePending(Cons_webPagePending(flags: _1!, id: _2!, url: _3, date: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription {
        public class Cons_webPageAttributeAiComposeTone: TypeConstructorDescription {
            public var emojiId: Int64
            public init(emojiId: Int64) {
                self.emojiId = emojiId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPageAttributeAiComposeTone", [("emojiId", ConstructorParameterDescription(self.emojiId))])
            }
        }
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
        case webPageAttributeAiComposeTone(Cons_webPageAttributeAiComposeTone)
        case webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction)
        case webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection)
        case webPageAttributeStickerSet(Cons_webPageAttributeStickerSet)
        case webPageAttributeStory(Cons_webPageAttributeStory)
        case webPageAttributeTheme(Cons_webPageAttributeTheme)
        case webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPageAttributeAiComposeTone(let _data):
                if boxed {
                    buffer.appendInt32(2005007896)
                }
                serializeInt64(_data.emojiId, buffer: buffer, boxed: false)
                break
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
            case .webPageAttributeAiComposeTone(let _data):
                return ("webPageAttributeAiComposeTone", [("emojiId", ConstructorParameterDescription(_data.emojiId))])
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

        public static func parse_webPageAttributeAiComposeTone(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.WebPageAttribute.webPageAttributeAiComposeTone(Cons_webPageAttributeAiComposeTone(emojiId: _1!))
            }
            else {
                return nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.StoryItem
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
                }
            }
            var _3: Api.ThemeSettings?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
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
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
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
