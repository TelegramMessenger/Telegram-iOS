public extension Api.wallet {
    enum ExistingBalance: TypeConstructorDescription {
        public class Cons_existingBalance: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public init(flags: Int32, url: String) {
                self.flags = flags
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("existingBalance", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        case existingBalance(Cons_existingBalance)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .existingBalance(let _data):
                if boxed {
                    buffer.appendInt32(-1108800883)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .existingBalance(let _data):
                return ("existingBalance", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url))])
            }
        }

        public static func parse_existingBalance(_ reader: BufferReader) -> ExistingBalance? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.ExistingBalance.existingBalance(Cons_existingBalance(flags: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum HolderDc: TypeConstructorDescription {
        public class Cons_holderDc: TypeConstructorDescription {
            public var dc: Int32
            public var publicKey: Buffer
            public init(dc: Int32, publicKey: Buffer) {
                self.dc = dc
                self.publicKey = publicKey
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("holderDc", [("dc", ConstructorParameterDescription(self.dc)), ("publicKey", ConstructorParameterDescription(self.publicKey))])
            }
        }
        case holderDc(Cons_holderDc)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .holderDc(let _data):
                if boxed {
                    buffer.appendInt32(-103410961)
                }
                serializeInt32(_data.dc, buffer: buffer, boxed: false)
                serializeBytes(_data.publicKey, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .holderDc(let _data):
                return ("holderDc", [("dc", ConstructorParameterDescription(_data.dc)), ("publicKey", ConstructorParameterDescription(_data.publicKey))])
            }
        }

        public static func parse_holderDc(_ reader: BufferReader) -> HolderDc? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.HolderDc.holderDc(Cons_holderDc(dc: _1!, publicKey: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum NftAttribute: TypeConstructorDescription {
        public class Cons_nftAttribute: TypeConstructorDescription {
            public var traitType: String
            public var value: String
            public init(traitType: String, value: String) {
                self.traitType = traitType
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("nftAttribute", [("traitType", ConstructorParameterDescription(self.traitType)), ("value", ConstructorParameterDescription(self.value))])
            }
        }
        case nftAttribute(Cons_nftAttribute)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nftAttribute(let _data):
                if boxed {
                    buffer.appendInt32(1277096206)
                }
                serializeString(_data.traitType, buffer: buffer, boxed: false)
                serializeString(_data.value, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .nftAttribute(let _data):
                return ("nftAttribute", [("traitType", ConstructorParameterDescription(_data.traitType)), ("value", ConstructorParameterDescription(_data.value))])
            }
        }

        public static func parse_nftAttribute(_ reader: BufferReader) -> NftAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.NftAttribute.nftAttribute(Cons_nftAttribute(traitType: _1!, value: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum NftItem: TypeConstructorDescription {
        public class Cons_nftItem: TypeConstructorDescription {
            public var flags: Int32
            public var collectionAddress: String?
            public var address: String
            public var ownerAddress: String
            public var index: String
            public var name: String?
            public var description: String?
            public var image: Api.WebDocument?
            public var imageSmall: Api.WebDocument?
            public var contentUrl: Api.WebDocument?
            public var lottie: Api.WebDocument?
            public var attributes: [Api.wallet.NftAttribute]?
            public var extra: Api.DataJSON?
            public init(flags: Int32, collectionAddress: String?, address: String, ownerAddress: String, index: String, name: String?, description: String?, image: Api.WebDocument?, imageSmall: Api.WebDocument?, contentUrl: Api.WebDocument?, lottie: Api.WebDocument?, attributes: [Api.wallet.NftAttribute]?, extra: Api.DataJSON?) {
                self.flags = flags
                self.collectionAddress = collectionAddress
                self.address = address
                self.ownerAddress = ownerAddress
                self.index = index
                self.name = name
                self.description = description
                self.image = image
                self.imageSmall = imageSmall
                self.contentUrl = contentUrl
                self.lottie = lottie
                self.attributes = attributes
                self.extra = extra
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("nftItem", [("flags", ConstructorParameterDescription(self.flags)), ("collectionAddress", ConstructorParameterDescription(self.collectionAddress)), ("address", ConstructorParameterDescription(self.address)), ("ownerAddress", ConstructorParameterDescription(self.ownerAddress)), ("index", ConstructorParameterDescription(self.index)), ("name", ConstructorParameterDescription(self.name)), ("description", ConstructorParameterDescription(self.description)), ("image", ConstructorParameterDescription(self.image)), ("imageSmall", ConstructorParameterDescription(self.imageSmall)), ("contentUrl", ConstructorParameterDescription(self.contentUrl)), ("lottie", ConstructorParameterDescription(self.lottie)), ("attributes", ConstructorParameterDescription(self.attributes)), ("extra", ConstructorParameterDescription(self.extra))])
            }
        }
        case nftItem(Cons_nftItem)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nftItem(let _data):
                if boxed {
                    buffer.appendInt32(876739868)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.collectionAddress!, buffer: buffer, boxed: false)
                }
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.ownerAddress, buffer: buffer, boxed: false)
                serializeString(_data.index, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.name!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.image!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.imageSmall!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.contentUrl!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.lottie!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.attributes!.count))
                    for item in _data.attributes! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.extra!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .nftItem(let _data):
                return ("nftItem", [("flags", ConstructorParameterDescription(_data.flags)), ("collectionAddress", ConstructorParameterDescription(_data.collectionAddress)), ("address", ConstructorParameterDescription(_data.address)), ("ownerAddress", ConstructorParameterDescription(_data.ownerAddress)), ("index", ConstructorParameterDescription(_data.index)), ("name", ConstructorParameterDescription(_data.name)), ("description", ConstructorParameterDescription(_data.description)), ("image", ConstructorParameterDescription(_data.image)), ("imageSmall", ConstructorParameterDescription(_data.imageSmall)), ("contentUrl", ConstructorParameterDescription(_data.contentUrl)), ("lottie", ConstructorParameterDescription(_data.lottie)), ("attributes", ConstructorParameterDescription(_data.attributes)), ("extra", ConstructorParameterDescription(_data.extra))])
            }
        }

        public static func parse_nftItem(_ reader: BufferReader) -> NftItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _7 = parseString(reader)
            }
            var _8: Api.WebDocument?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _9: Api.WebDocument?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _10: Api.WebDocument?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _11: Api.WebDocument?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _12: [Api.wallet.NftAttribute]?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.wallet.NftAttribute.self)
                }
            }
            var _13: Api.DataJSON?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _13 = Api.parse(reader, signature: signature) as? Api.DataJSON
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.wallet.NftItem.nftItem(Cons_nftItem(flags: _1!, collectionAddress: _2, address: _3!, ownerAddress: _4!, index: _5!, name: _6, description: _7, image: _8, imageSmall: _9, contentUrl: _10, lottie: _11, attributes: _12, extra: _13))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum NftItems: TypeConstructorDescription {
        public class Cons_nftItems: TypeConstructorDescription {
            public var flags: Int32
            public var items: [Api.wallet.NftItem]
            public var nextOffset: String?
            public init(flags: Int32, items: [Api.wallet.NftItem], nextOffset: String?) {
                self.flags = flags
                self.items = items
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("nftItems", [("flags", ConstructorParameterDescription(self.flags)), ("items", ConstructorParameterDescription(self.items)), ("nextOffset", ConstructorParameterDescription(self.nextOffset))])
            }
        }
        case nftItems(Cons_nftItems)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nftItems(let _data):
                if boxed {
                    buffer.appendInt32(2035107951)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .nftItems(let _data):
                return ("nftItems", [("flags", ConstructorParameterDescription(_data.flags)), ("items", ConstructorParameterDescription(_data.items)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset))])
            }
        }

        public static func parse_nftItems(_ reader: BufferReader) -> NftItems? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.wallet.NftItem]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.wallet.NftItem.self)
            }
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.wallet.NftItems.nftItems(Cons_nftItems(flags: _1!, items: _2!, nextOffset: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum ProofChallenge: TypeConstructorDescription {
        public class Cons_proofChallenge: TypeConstructorDescription {
            public var payload: String
            public var expires: Int32
            public var domain: String
            public init(payload: String, expires: Int32, domain: String) {
                self.payload = payload
                self.expires = expires
                self.domain = domain
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("proofChallenge", [("payload", ConstructorParameterDescription(self.payload)), ("expires", ConstructorParameterDescription(self.expires)), ("domain", ConstructorParameterDescription(self.domain))])
            }
        }
        case proofChallenge(Cons_proofChallenge)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .proofChallenge(let _data):
                if boxed {
                    buffer.appendInt32(-1713105145)
                }
                serializeString(_data.payload, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                serializeString(_data.domain, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .proofChallenge(let _data):
                return ("proofChallenge", [("payload", ConstructorParameterDescription(_data.payload)), ("expires", ConstructorParameterDescription(_data.expires)), ("domain", ConstructorParameterDescription(_data.domain))])
            }
        }

        public static func parse_proofChallenge(_ reader: BufferReader) -> ProofChallenge? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.wallet.ProofChallenge.proofChallenge(Cons_proofChallenge(payload: _1!, expires: _2!, domain: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum SecretPhraseParts: TypeConstructorDescription {
        public class Cons_secretPhraseParts: TypeConstructorDescription {
            public var token: String
            public var dcs: [Int32]
            public init(token: String, dcs: [Int32]) {
                self.token = token
                self.dcs = dcs
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("secretPhraseParts", [("token", ConstructorParameterDescription(self.token)), ("dcs", ConstructorParameterDescription(self.dcs))])
            }
        }
        case secretPhraseParts(Cons_secretPhraseParts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secretPhraseParts(let _data):
                if boxed {
                    buffer.appendInt32(-422514943)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dcs.count))
                for item in _data.dcs {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .secretPhraseParts(let _data):
                return ("secretPhraseParts", [("token", ConstructorParameterDescription(_data.token)), ("dcs", ConstructorParameterDescription(_data.dcs))])
            }
        }

        public static func parse_secretPhraseParts(_ reader: BufferReader) -> SecretPhraseParts? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.SecretPhraseParts.secretPhraseParts(Cons_secretPhraseParts(token: _1!, dcs: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectChallenge: TypeConstructorDescription {
        public class Cons_tonConnectChallenge: TypeConstructorDescription {
            public var challenge: Buffer
            public var eventId: Int64
            public init(challenge: Buffer, eventId: Int64) {
                self.challenge = challenge
                self.eventId = eventId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectChallenge", [("challenge", ConstructorParameterDescription(self.challenge)), ("eventId", ConstructorParameterDescription(self.eventId))])
            }
        }
        case tonConnectChallenge(Cons_tonConnectChallenge)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectChallenge(let _data):
                if boxed {
                    buffer.appendInt32(1271436947)
                }
                serializeBytes(_data.challenge, buffer: buffer, boxed: false)
                serializeInt64(_data.eventId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectChallenge(let _data):
                return ("tonConnectChallenge", [("challenge", ConstructorParameterDescription(_data.challenge)), ("eventId", ConstructorParameterDescription(_data.eventId))])
            }
        }

        public static func parse_tonConnectChallenge(_ reader: BufferReader) -> TonConnectChallenge? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.TonConnectChallenge.tonConnectChallenge(Cons_tonConnectChallenge(challenge: _1!, eventId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectPending: TypeConstructorDescription {
        public class Cons_tonConnectPending: TypeConstructorDescription {
            public var session: Api.TonConnectSession
            public var requests: [Api.TonConnectRequest]
            public init(session: Api.TonConnectSession, requests: [Api.TonConnectRequest]) {
                self.session = session
                self.requests = requests
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectPending", [("session", ConstructorParameterDescription(self.session)), ("requests", ConstructorParameterDescription(self.requests))])
            }
        }
        case tonConnectPending(Cons_tonConnectPending)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectPending(let _data):
                if boxed {
                    buffer.appendInt32(-2050952924)
                }
                _data.session.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.requests.count))
                for item in _data.requests {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectPending(let _data):
                return ("tonConnectPending", [("session", ConstructorParameterDescription(_data.session)), ("requests", ConstructorParameterDescription(_data.requests))])
            }
        }

        public static func parse_tonConnectPending(_ reader: BufferReader) -> TonConnectPending? {
            var _1: Api.TonConnectSession?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TonConnectSession
            }
            var _2: [Api.TonConnectRequest]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TonConnectRequest.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.TonConnectPending.tonConnectPending(Cons_tonConnectPending(session: _1!, requests: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum TonConnectSessions: TypeConstructorDescription {
        public class Cons_tonConnectSessions: TypeConstructorDescription {
            public var sessions: [Api.TonConnectSession]
            public init(sessions: [Api.TonConnectSession]) {
                self.sessions = sessions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tonConnectSessions", [("sessions", ConstructorParameterDescription(self.sessions))])
            }
        }
        case tonConnectSessions(Cons_tonConnectSessions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tonConnectSessions(let _data):
                if boxed {
                    buffer.appendInt32(236939414)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sessions.count))
                for item in _data.sessions {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tonConnectSessions(let _data):
                return ("tonConnectSessions", [("sessions", ConstructorParameterDescription(_data.sessions))])
            }
        }

        public static func parse_tonConnectSessions(_ reader: BufferReader) -> TonConnectSessions? {
            var _1: [Api.TonConnectSession]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TonConnectSession.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.wallet.TonConnectSessions.tonConnectSessions(Cons_tonConnectSessions(sessions: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum Transactions: TypeConstructorDescription {
        public class Cons_transactions: TypeConstructorDescription {
            public var flags: Int32
            public var balance: Int64
            public var transactions: [Api.WalletTransaction]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, balance: Int64, transactions: [Api.WalletTransaction], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.balance = balance
                self.transactions = transactions
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("transactions", [("flags", ConstructorParameterDescription(self.flags)), ("balance", ConstructorParameterDescription(self.balance)), ("transactions", ConstructorParameterDescription(self.transactions)), ("nextOffset", ConstructorParameterDescription(self.nextOffset)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case transactions(Cons_transactions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .transactions(let _data):
                if boxed {
                    buffer.appendInt32(1126356389)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.balance, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.transactions.count))
                for item in _data.transactions {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
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
            case .transactions(let _data):
                return ("transactions", [("flags", ConstructorParameterDescription(_data.flags)), ("balance", ConstructorParameterDescription(_data.balance)), ("transactions", ConstructorParameterDescription(_data.transactions)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_transactions(_ reader: BufferReader) -> Transactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.WalletTransaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WalletTransaction.self)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
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
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.wallet.Transactions.transactions(Cons_transactions(flags: _1!, balance: _2!, transactions: _3!, nextOffset: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.wallet {
    enum UserAddresses: TypeConstructorDescription {
        public class Cons_userAddresses: TypeConstructorDescription {
            public var addresses: [Api.WalletUserAddress]
            public var users: [Api.User]
            public init(addresses: [Api.WalletUserAddress], users: [Api.User]) {
                self.addresses = addresses
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("userAddresses", [("addresses", ConstructorParameterDescription(self.addresses)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case userAddresses(Cons_userAddresses)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userAddresses(let _data):
                if boxed {
                    buffer.appendInt32(-1836156075)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.addresses.count))
                for item in _data.addresses {
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
            case .userAddresses(let _data):
                return ("userAddresses", [("addresses", ConstructorParameterDescription(_data.addresses)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_userAddresses(_ reader: BufferReader) -> UserAddresses? {
            var _1: [Api.WalletUserAddress]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WalletUserAddress.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.wallet.UserAddresses.userAddresses(Cons_userAddresses(addresses: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
