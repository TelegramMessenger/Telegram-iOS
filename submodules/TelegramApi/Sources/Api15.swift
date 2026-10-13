public extension Api {
    enum InputWalletReplacement: TypeConstructorDescription {
        public class Cons_inputWalletImported: TypeConstructorDescription {
            public var flags: Int32
            public var publicKey: Buffer
            public var anchorPublicKey: Buffer?
            public var proof: Api.WalletOwnershipProof
            public init(flags: Int32, publicKey: Buffer, anchorPublicKey: Buffer?, proof: Api.WalletOwnershipProof) {
                self.flags = flags
                self.publicKey = publicKey
                self.anchorPublicKey = anchorPublicKey
                self.proof = proof
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWalletImported", [("flags", ConstructorParameterDescription(self.flags)), ("publicKey", ConstructorParameterDescription(self.publicKey)), ("anchorPublicKey", ConstructorParameterDescription(self.anchorPublicKey)), ("proof", ConstructorParameterDescription(self.proof))])
            }
        }
        case inputWalletImported(Cons_inputWalletImported)
        case inputWalletNew

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputWalletImported(let _data):
                if boxed {
                    buffer.appendInt32(1722182203)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.publicKey, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.anchorPublicKey!, buffer: buffer, boxed: false)
                }
                _data.proof.serialize(buffer, true)
                break
            case .inputWalletNew:
                if boxed {
                    buffer.appendInt32(1671708892)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputWalletImported(let _data):
                return ("inputWalletImported", [("flags", ConstructorParameterDescription(_data.flags)), ("publicKey", ConstructorParameterDescription(_data.publicKey)), ("anchorPublicKey", ConstructorParameterDescription(_data.anchorPublicKey)), ("proof", ConstructorParameterDescription(_data.proof))])
            case .inputWalletNew:
                return ("inputWalletNew", [])
            }
        }

        public static func parse_inputWalletImported(_ reader: BufferReader) -> InputWalletReplacement? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: Api.WalletOwnershipProof?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.WalletOwnershipProof
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWalletReplacement.inputWalletImported(Cons_inputWalletImported(flags: _1!, publicKey: _2!, anchorPublicKey: _3, proof: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWalletNew(_ reader: BufferReader) -> InputWalletReplacement? {
            return Api.InputWalletReplacement.inputWalletNew
        }
    }
}
public extension Api {
    enum InputWebDocument: TypeConstructorDescription {
        public class Cons_inputWebDocument: TypeConstructorDescription {
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
                return ("inputWebDocument", [("url", ConstructorParameterDescription(self.url)), ("size", ConstructorParameterDescription(self.size)), ("mimeType", ConstructorParameterDescription(self.mimeType)), ("attributes", ConstructorParameterDescription(self.attributes))])
            }
        }
        case inputWebDocument(Cons_inputWebDocument)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputWebDocument(let _data):
                if boxed {
                    buffer.appendInt32(-1678949555)
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
            case .inputWebDocument(let _data):
                return ("inputWebDocument", [("url", ConstructorParameterDescription(_data.url)), ("size", ConstructorParameterDescription(_data.size)), ("mimeType", ConstructorParameterDescription(_data.mimeType)), ("attributes", ConstructorParameterDescription(_data.attributes))])
            }
        }

        public static func parse_inputWebDocument(_ reader: BufferReader) -> InputWebDocument? {
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
                return Api.InputWebDocument.inputWebDocument(Cons_inputWebDocument(url: _1!, size: _2!, mimeType: _3!, attributes: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputWebFileLocation: TypeConstructorDescription {
        public class Cons_inputWebFileAudioAlbumThumbLocation: TypeConstructorDescription {
            public var flags: Int32
            public var document: Api.InputDocument?
            public var title: String?
            public var performer: String?
            public init(flags: Int32, document: Api.InputDocument?, title: String?, performer: String?) {
                self.flags = flags
                self.document = document
                self.title = title
                self.performer = performer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWebFileAudioAlbumThumbLocation", [("flags", ConstructorParameterDescription(self.flags)), ("document", ConstructorParameterDescription(self.document)), ("title", ConstructorParameterDescription(self.title)), ("performer", ConstructorParameterDescription(self.performer))])
            }
        }
        public class Cons_inputWebFileGeoPointLocation: TypeConstructorDescription {
            public var geoPoint: Api.InputGeoPoint
            public var accessHash: Int64
            public var w: Int32
            public var h: Int32
            public var zoom: Int32
            public var scale: Int32
            public init(geoPoint: Api.InputGeoPoint, accessHash: Int64, w: Int32, h: Int32, zoom: Int32, scale: Int32) {
                self.geoPoint = geoPoint
                self.accessHash = accessHash
                self.w = w
                self.h = h
                self.zoom = zoom
                self.scale = scale
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWebFileGeoPointLocation", [("geoPoint", ConstructorParameterDescription(self.geoPoint)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("zoom", ConstructorParameterDescription(self.zoom)), ("scale", ConstructorParameterDescription(self.scale))])
            }
        }
        public class Cons_inputWebFileLocation: TypeConstructorDescription {
            public var url: String
            public var accessHash: Int64
            public init(url: String, accessHash: Int64) {
                self.url = url
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputWebFileLocation", [("url", ConstructorParameterDescription(self.url)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        case inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation)
        case inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation)
        case inputWebFileLocation(Cons_inputWebFileLocation)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputWebFileAudioAlbumThumbLocation(let _data):
                if boxed {
                    buffer.appendInt32(-193992412)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.performer!, buffer: buffer, boxed: false)
                }
                break
            case .inputWebFileGeoPointLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1625153079)
                }
                _data.geoPoint.serialize(buffer, true)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                serializeInt32(_data.zoom, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                break
            case .inputWebFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1036396922)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputWebFileAudioAlbumThumbLocation(let _data):
                return ("inputWebFileAudioAlbumThumbLocation", [("flags", ConstructorParameterDescription(_data.flags)), ("document", ConstructorParameterDescription(_data.document)), ("title", ConstructorParameterDescription(_data.title)), ("performer", ConstructorParameterDescription(_data.performer))])
            case .inputWebFileGeoPointLocation(let _data):
                return ("inputWebFileGeoPointLocation", [("geoPoint", ConstructorParameterDescription(_data.geoPoint)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("zoom", ConstructorParameterDescription(_data.zoom)), ("scale", ConstructorParameterDescription(_data.scale))])
            case .inputWebFileLocation(let _data):
                return ("inputWebFileLocation", [("url", ConstructorParameterDescription(_data.url)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            }
        }

        public static func parse_inputWebFileAudioAlbumThumbLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
                }
            }
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputWebFileLocation.inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation(flags: _1!, document: _2, title: _3, performer: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileGeoPointLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputWebFileLocation.inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation(geoPoint: _1!, accessHash: _2!, w: _3!, h: _4!, zoom: _5!, scale: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputWebFileLocation(_ reader: BufferReader) -> InputWebFileLocation? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWebFileLocation.inputWebFileLocation(Cons_inputWebFileLocation(url: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Invoice: TypeConstructorDescription {
        public class Cons_invoice: TypeConstructorDescription {
            public var flags: Int32
            public var currency: String
            public var prices: [Api.LabeledPrice]
            public var maxTipAmount: Int64?
            public var suggestedTipAmounts: [Int64]?
            public var termsUrl: String?
            public var subscriptionPeriod: Int32?
            public init(flags: Int32, currency: String, prices: [Api.LabeledPrice], maxTipAmount: Int64?, suggestedTipAmounts: [Int64]?, termsUrl: String?, subscriptionPeriod: Int32?) {
                self.flags = flags
                self.currency = currency
                self.prices = prices
                self.maxTipAmount = maxTipAmount
                self.suggestedTipAmounts = suggestedTipAmounts
                self.termsUrl = termsUrl
                self.subscriptionPeriod = subscriptionPeriod
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("invoice", [("flags", ConstructorParameterDescription(self.flags)), ("currency", ConstructorParameterDescription(self.currency)), ("prices", ConstructorParameterDescription(self.prices)), ("maxTipAmount", ConstructorParameterDescription(self.maxTipAmount)), ("suggestedTipAmounts", ConstructorParameterDescription(self.suggestedTipAmounts)), ("termsUrl", ConstructorParameterDescription(self.termsUrl)), ("subscriptionPeriod", ConstructorParameterDescription(self.subscriptionPeriod))])
            }
        }
        case invoice(Cons_invoice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .invoice(let _data):
                if boxed {
                    buffer.appendInt32(77522308)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prices.count))
                for item in _data.prices {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.maxTipAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.suggestedTipAmounts!.count))
                    for item in _data.suggestedTipAmounts! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeString(_data.termsUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.subscriptionPeriod!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .invoice(let _data):
                return ("invoice", [("flags", ConstructorParameterDescription(_data.flags)), ("currency", ConstructorParameterDescription(_data.currency)), ("prices", ConstructorParameterDescription(_data.prices)), ("maxTipAmount", ConstructorParameterDescription(_data.maxTipAmount)), ("suggestedTipAmounts", ConstructorParameterDescription(_data.suggestedTipAmounts)), ("termsUrl", ConstructorParameterDescription(_data.termsUrl)), ("subscriptionPeriod", ConstructorParameterDescription(_data.subscriptionPeriod))])
            }
        }

        public static func parse_invoice(_ reader: BufferReader) -> Invoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.LabeledPrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LabeledPrice.self)
            }
            var _4: Int64?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                _4 = reader.readInt64()
            }
            var _5: [Int64]?
            if Int(_1 ?? 0) & Int(1 << 8) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                _6 = parseString(reader)
            }
            var _7: Int32?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _7 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Invoice.invoice(Cons_invoice(flags: _1!, currency: _2!, prices: _3!, maxTipAmount: _4, suggestedTipAmounts: _5, termsUrl: _6, subscriptionPeriod: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum JSONObjectValue: TypeConstructorDescription {
        public class Cons_jsonObjectValue: TypeConstructorDescription {
            public var key: String
            public var value: Api.JSONValue
            public init(key: String, value: Api.JSONValue) {
                self.key = key
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonObjectValue", [("key", ConstructorParameterDescription(self.key)), ("value", ConstructorParameterDescription(self.value))])
            }
        }
        case jsonObjectValue(Cons_jsonObjectValue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .jsonObjectValue(let _data):
                if boxed {
                    buffer.appendInt32(-1059185703)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                _data.value.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .jsonObjectValue(let _data):
                return ("jsonObjectValue", [("key", ConstructorParameterDescription(_data.key)), ("value", ConstructorParameterDescription(_data.value))])
            }
        }

        public static func parse_jsonObjectValue(_ reader: BufferReader) -> JSONObjectValue? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.JSONValue?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.JSONObjectValue.jsonObjectValue(Cons_jsonObjectValue(key: _1!, value: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum JSONValue: TypeConstructorDescription {
        public class Cons_jsonArray: TypeConstructorDescription {
            public var value: [Api.JSONValue]
            public init(value: [Api.JSONValue]) {
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonArray", [("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_jsonBool: TypeConstructorDescription {
            public var value: Api.Bool
            public init(value: Api.Bool) {
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonBool", [("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_jsonNumber: TypeConstructorDescription {
            public var value: Double
            public init(value: Double) {
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonNumber", [("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_jsonObject: TypeConstructorDescription {
            public var value: [Api.JSONObjectValue]
            public init(value: [Api.JSONObjectValue]) {
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonObject", [("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_jsonString: TypeConstructorDescription {
            public var value: String
            public init(value: String) {
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("jsonString", [("value", ConstructorParameterDescription(self.value))])
            }
        }
        case jsonArray(Cons_jsonArray)
        case jsonBool(Cons_jsonBool)
        case jsonNull
        case jsonNumber(Cons_jsonNumber)
        case jsonObject(Cons_jsonObject)
        case jsonString(Cons_jsonString)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .jsonArray(let _data):
                if boxed {
                    buffer.appendInt32(-146520221)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.value.count))
                for item in _data.value {
                    item.serialize(buffer, true)
                }
                break
            case .jsonBool(let _data):
                if boxed {
                    buffer.appendInt32(-952869270)
                }
                _data.value.serialize(buffer, true)
                break
            case .jsonNull:
                if boxed {
                    buffer.appendInt32(1064139624)
                }
                break
            case .jsonNumber(let _data):
                if boxed {
                    buffer.appendInt32(736157604)
                }
                serializeDouble(_data.value, buffer: buffer, boxed: false)
                break
            case .jsonObject(let _data):
                if boxed {
                    buffer.appendInt32(-1715350371)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.value.count))
                for item in _data.value {
                    item.serialize(buffer, true)
                }
                break
            case .jsonString(let _data):
                if boxed {
                    buffer.appendInt32(-1222740358)
                }
                serializeString(_data.value, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .jsonArray(let _data):
                return ("jsonArray", [("value", ConstructorParameterDescription(_data.value))])
            case .jsonBool(let _data):
                return ("jsonBool", [("value", ConstructorParameterDescription(_data.value))])
            case .jsonNull:
                return ("jsonNull", [])
            case .jsonNumber(let _data):
                return ("jsonNumber", [("value", ConstructorParameterDescription(_data.value))])
            case .jsonObject(let _data):
                return ("jsonObject", [("value", ConstructorParameterDescription(_data.value))])
            case .jsonString(let _data):
                return ("jsonString", [("value", ConstructorParameterDescription(_data.value))])
            }
        }

        public static func parse_jsonArray(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonArray(Cons_jsonArray(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonBool(_ reader: BufferReader) -> JSONValue? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonBool(Cons_jsonBool(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonNull(_ reader: BufferReader) -> JSONValue? {
            return Api.JSONValue.jsonNull
        }
        public static func parse_jsonNumber(_ reader: BufferReader) -> JSONValue? {
            var _1: Double?
            _1 = reader.readDouble()
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonNumber(Cons_jsonNumber(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonObject(_ reader: BufferReader) -> JSONValue? {
            var _1: [Api.JSONObjectValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.JSONObjectValue.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonObject(Cons_jsonObject(value: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_jsonString(_ reader: BufferReader) -> JSONValue? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.JSONValue.jsonString(Cons_jsonString(value: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum JoinChatBotResult: TypeConstructorDescription {
        public class Cons_joinChatBotResultWebView: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("joinChatBotResultWebView", [("url", ConstructorParameterDescription(self.url))])
            }
        }
        case joinChatBotResultApproved
        case joinChatBotResultDeclined
        case joinChatBotResultQueued
        case joinChatBotResultWebView(Cons_joinChatBotResultWebView)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .joinChatBotResultApproved:
                if boxed {
                    buffer.appendInt32(-1374344599)
                }
                break
            case .joinChatBotResultDeclined:
                if boxed {
                    buffer.appendInt32(251265428)
                }
                break
            case .joinChatBotResultQueued:
                if boxed {
                    buffer.appendInt32(-1734105024)
                }
                break
            case .joinChatBotResultWebView(let _data):
                if boxed {
                    buffer.appendInt32(-689719277)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .joinChatBotResultApproved:
                return ("joinChatBotResultApproved", [])
            case .joinChatBotResultDeclined:
                return ("joinChatBotResultDeclined", [])
            case .joinChatBotResultQueued:
                return ("joinChatBotResultQueued", [])
            case .joinChatBotResultWebView(let _data):
                return ("joinChatBotResultWebView", [("url", ConstructorParameterDescription(_data.url))])
            }
        }

        public static func parse_joinChatBotResultApproved(_ reader: BufferReader) -> JoinChatBotResult? {
            return Api.JoinChatBotResult.joinChatBotResultApproved
        }
        public static func parse_joinChatBotResultDeclined(_ reader: BufferReader) -> JoinChatBotResult? {
            return Api.JoinChatBotResult.joinChatBotResultDeclined
        }
        public static func parse_joinChatBotResultQueued(_ reader: BufferReader) -> JoinChatBotResult? {
            return Api.JoinChatBotResult.joinChatBotResultQueued
        }
        public static func parse_joinChatBotResultWebView(_ reader: BufferReader) -> JoinChatBotResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.JoinChatBotResult.joinChatBotResultWebView(Cons_joinChatBotResultWebView(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum KeyboardButton: TypeConstructorDescription {
        public class Cons_keyboardButton: TypeConstructorDescription {
            public var flags: Int32
            public var style: Api.KeyboardButtonStyle?
            public var text: String
            public var type: Api.ButtonType
            public init(flags: Int32, style: Api.KeyboardButtonStyle?, text: String, type: Api.ButtonType) {
                self.flags = flags
                self.style = style
                self.text = text
                self.type = type
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardButton", [("flags", ConstructorParameterDescription(self.flags)), ("style", ConstructorParameterDescription(self.style)), ("text", ConstructorParameterDescription(self.text)), ("type", ConstructorParameterDescription(self.type))])
            }
        }
        case keyboardButton(Cons_keyboardButton)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardButton(let _data):
                if boxed {
                    buffer.appendInt32(795322159)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.style!.serialize(buffer, true)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardButton(let _data):
                return ("keyboardButton", [("flags", ConstructorParameterDescription(_data.flags)), ("style", ConstructorParameterDescription(_data.style)), ("text", ConstructorParameterDescription(_data.text)), ("type", ConstructorParameterDescription(_data.type))])
            }
        }

        public static func parse_keyboardButton(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.KeyboardButtonStyle?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.KeyboardButtonStyle
                }
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ButtonType?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ButtonType
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardButton.keyboardButton(Cons_keyboardButton(flags: _1!, style: _2, text: _3!, type: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription {
        public class Cons_keyboardButtonRow: TypeConstructorDescription {
            public var buttons: [Api.KeyboardButton]
            public init(buttons: [Api.KeyboardButton]) {
                self.buttons = buttons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardButtonRow", [("buttons", ConstructorParameterDescription(self.buttons))])
            }
        }
        case keyboardButtonRow(Cons_keyboardButtonRow)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardButtonRow(let _data):
                if boxed {
                    buffer.appendInt32(2002815875)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.buttons.count))
                for item in _data.buttons {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardButtonRow(let _data):
                return ("keyboardButtonRow", [("buttons", ConstructorParameterDescription(_data.buttons))])
            }
        }

        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            var _1: [Api.KeyboardButton]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButton.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButtonRow.keyboardButtonRow(Cons_keyboardButtonRow(buttons: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum KeyboardButtonStyle: TypeConstructorDescription {
        public class Cons_keyboardButtonStyle: TypeConstructorDescription {
            public var flags: Int32
            public var icon: Int64?
            public init(flags: Int32, icon: Int64?) {
                self.flags = flags
                self.icon = icon
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardButtonStyle", [("flags", ConstructorParameterDescription(self.flags)), ("icon", ConstructorParameterDescription(self.icon))])
            }
        }
        case keyboardButtonStyle(Cons_keyboardButtonStyle)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardButtonStyle(let _data):
                if boxed {
                    buffer.appendInt32(1339896880)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.icon!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardButtonStyle(let _data):
                return ("keyboardButtonStyle", [("flags", ConstructorParameterDescription(_data.flags)), ("icon", ConstructorParameterDescription(_data.icon))])
            }
        }

        public static func parse_keyboardButtonStyle(_ reader: BufferReader) -> KeyboardButtonStyle? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _2 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButtonStyle.keyboardButtonStyle(Cons_keyboardButtonStyle(flags: _1!, icon: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum KeyboardInlineButton: TypeConstructorDescription {
        public class Cons_keyboardInlineButton: TypeConstructorDescription {
            public var flags: Int32
            public var style: Api.KeyboardButtonStyle?
            public var text: String
            public var type: Api.InlineButtonType
            public init(flags: Int32, style: Api.KeyboardButtonStyle?, text: String, type: Api.InlineButtonType) {
                self.flags = flags
                self.style = style
                self.text = text
                self.type = type
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardInlineButton", [("flags", ConstructorParameterDescription(self.flags)), ("style", ConstructorParameterDescription(self.style)), ("text", ConstructorParameterDescription(self.text)), ("type", ConstructorParameterDescription(self.type))])
            }
        }
        case keyboardInlineButton(Cons_keyboardInlineButton)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardInlineButton(let _data):
                if boxed {
                    buffer.appendInt32(297902882)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.style!.serialize(buffer, true)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardInlineButton(let _data):
                return ("keyboardInlineButton", [("flags", ConstructorParameterDescription(_data.flags)), ("style", ConstructorParameterDescription(_data.style)), ("text", ConstructorParameterDescription(_data.text)), ("type", ConstructorParameterDescription(_data.type))])
            }
        }

        public static func parse_keyboardInlineButton(_ reader: BufferReader) -> KeyboardInlineButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.KeyboardButtonStyle?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.KeyboardButtonStyle
                }
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InlineButtonType?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InlineButtonType
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardInlineButton.keyboardInlineButton(Cons_keyboardInlineButton(flags: _1!, style: _2, text: _3!, type: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum KeyboardInlineButtonRow: TypeConstructorDescription {
        public class Cons_keyboardInlineButtonRow: TypeConstructorDescription {
            public var buttons: [Api.KeyboardInlineButton]
            public init(buttons: [Api.KeyboardInlineButton]) {
                self.buttons = buttons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("keyboardInlineButtonRow", [("buttons", ConstructorParameterDescription(self.buttons))])
            }
        }
        case keyboardInlineButtonRow(Cons_keyboardInlineButtonRow)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .keyboardInlineButtonRow(let _data):
                if boxed {
                    buffer.appendInt32(423758582)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.buttons.count))
                for item in _data.buttons {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .keyboardInlineButtonRow(let _data):
                return ("keyboardInlineButtonRow", [("buttons", ConstructorParameterDescription(_data.buttons))])
            }
        }

        public static func parse_keyboardInlineButtonRow(_ reader: BufferReader) -> KeyboardInlineButtonRow? {
            var _1: [Api.KeyboardInlineButton]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardInlineButton.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardInlineButtonRow.keyboardInlineButtonRow(Cons_keyboardInlineButtonRow(buttons: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription {
        public class Cons_labeledPrice: TypeConstructorDescription {
            public var label: String
            public var amount: Int64
            public init(label: String, amount: Int64) {
                self.label = label
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("labeledPrice", [("label", ConstructorParameterDescription(self.label)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        case labeledPrice(Cons_labeledPrice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .labeledPrice(let _data):
                if boxed {
                    buffer.appendInt32(-886477832)
                }
                serializeString(_data.label, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .labeledPrice(let _data):
                return ("labeledPrice", [("label", ConstructorParameterDescription(_data.label)), ("amount", ConstructorParameterDescription(_data.amount))])
            }
        }

        public static func parse_labeledPrice(_ reader: BufferReader) -> LabeledPrice? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LabeledPrice.labeledPrice(Cons_labeledPrice(label: _1!, amount: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription {
        public class Cons_langPackDifference: TypeConstructorDescription {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var strings: [Api.LangPackString]
            public init(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.strings = strings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackDifference", [("langCode", ConstructorParameterDescription(self.langCode)), ("fromVersion", ConstructorParameterDescription(self.fromVersion)), ("version", ConstructorParameterDescription(self.version)), ("strings", ConstructorParameterDescription(self.strings))])
            }
        }
        case langPackDifference(Cons_langPackDifference)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackDifference(let _data):
                if boxed {
                    buffer.appendInt32(-209337866)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                serializeInt32(_data.fromVersion, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.strings.count))
                for item in _data.strings {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackDifference(let _data):
                return ("langPackDifference", [("langCode", ConstructorParameterDescription(_data.langCode)), ("fromVersion", ConstructorParameterDescription(_data.fromVersion)), ("version", ConstructorParameterDescription(_data.version)), ("strings", ConstructorParameterDescription(_data.strings))])
            }
        }

        public static func parse_langPackDifference(_ reader: BufferReader) -> LangPackDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.LangPackString]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.LangPackDifference.langPackDifference(Cons_langPackDifference(langCode: _1!, fromVersion: _2!, version: _3!, strings: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription {
        public class Cons_langPackLanguage: TypeConstructorDescription {
            public var flags: Int32
            public var name: String
            public var nativeName: String
            public var langCode: String
            public var baseLangCode: String?
            public var pluralCode: String
            public var stringsCount: Int32
            public var translatedCount: Int32
            public var translationsUrl: String
            public init(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String) {
                self.flags = flags
                self.name = name
                self.nativeName = nativeName
                self.langCode = langCode
                self.baseLangCode = baseLangCode
                self.pluralCode = pluralCode
                self.stringsCount = stringsCount
                self.translatedCount = translatedCount
                self.translationsUrl = translationsUrl
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackLanguage", [("flags", ConstructorParameterDescription(self.flags)), ("name", ConstructorParameterDescription(self.name)), ("nativeName", ConstructorParameterDescription(self.nativeName)), ("langCode", ConstructorParameterDescription(self.langCode)), ("baseLangCode", ConstructorParameterDescription(self.baseLangCode)), ("pluralCode", ConstructorParameterDescription(self.pluralCode)), ("stringsCount", ConstructorParameterDescription(self.stringsCount)), ("translatedCount", ConstructorParameterDescription(self.translatedCount)), ("translationsUrl", ConstructorParameterDescription(self.translationsUrl))])
            }
        }
        case langPackLanguage(Cons_langPackLanguage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackLanguage(let _data):
                if boxed {
                    buffer.appendInt32(-288727837)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeString(_data.nativeName, buffer: buffer, boxed: false)
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.baseLangCode!, buffer: buffer, boxed: false)
                }
                serializeString(_data.pluralCode, buffer: buffer, boxed: false)
                serializeInt32(_data.stringsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.translatedCount, buffer: buffer, boxed: false)
                serializeString(_data.translationsUrl, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackLanguage(let _data):
                return ("langPackLanguage", [("flags", ConstructorParameterDescription(_data.flags)), ("name", ConstructorParameterDescription(_data.name)), ("nativeName", ConstructorParameterDescription(_data.nativeName)), ("langCode", ConstructorParameterDescription(_data.langCode)), ("baseLangCode", ConstructorParameterDescription(_data.baseLangCode)), ("pluralCode", ConstructorParameterDescription(_data.pluralCode)), ("stringsCount", ConstructorParameterDescription(_data.stringsCount)), ("translatedCount", ConstructorParameterDescription(_data.translatedCount)), ("translationsUrl", ConstructorParameterDescription(_data.translationsUrl))])
            }
        }

        public static func parse_langPackLanguage(_ reader: BufferReader) -> LangPackLanguage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.LangPackLanguage.langPackLanguage(Cons_langPackLanguage(flags: _1!, name: _2!, nativeName: _3!, langCode: _4!, baseLangCode: _5, pluralCode: _6!, stringsCount: _7!, translatedCount: _8!, translationsUrl: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription {
        public class Cons_langPackString: TypeConstructorDescription {
            public var key: String
            public var value: String
            public init(key: String, value: String) {
                self.key = key
                self.value = value
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackString", [("key", ConstructorParameterDescription(self.key)), ("value", ConstructorParameterDescription(self.value))])
            }
        }
        public class Cons_langPackStringDeleted: TypeConstructorDescription {
            public var key: String
            public init(key: String) {
                self.key = key
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackStringDeleted", [("key", ConstructorParameterDescription(self.key))])
            }
        }
        public class Cons_langPackStringPluralized: TypeConstructorDescription {
            public var flags: Int32
            public var key: String
            public var zeroValue: String?
            public var oneValue: String?
            public var twoValue: String?
            public var fewValue: String?
            public var manyValue: String?
            public var otherValue: String
            public init(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String) {
                self.flags = flags
                self.key = key
                self.zeroValue = zeroValue
                self.oneValue = oneValue
                self.twoValue = twoValue
                self.fewValue = fewValue
                self.manyValue = manyValue
                self.otherValue = otherValue
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("langPackStringPluralized", [("flags", ConstructorParameterDescription(self.flags)), ("key", ConstructorParameterDescription(self.key)), ("zeroValue", ConstructorParameterDescription(self.zeroValue)), ("oneValue", ConstructorParameterDescription(self.oneValue)), ("twoValue", ConstructorParameterDescription(self.twoValue)), ("fewValue", ConstructorParameterDescription(self.fewValue)), ("manyValue", ConstructorParameterDescription(self.manyValue)), ("otherValue", ConstructorParameterDescription(self.otherValue))])
            }
        }
        case langPackString(Cons_langPackString)
        case langPackStringDeleted(Cons_langPackStringDeleted)
        case langPackStringPluralized(Cons_langPackStringPluralized)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .langPackString(let _data):
                if boxed {
                    buffer.appendInt32(-892239370)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                serializeString(_data.value, buffer: buffer, boxed: false)
                break
            case .langPackStringDeleted(let _data):
                if boxed {
                    buffer.appendInt32(695856818)
                }
                serializeString(_data.key, buffer: buffer, boxed: false)
                break
            case .langPackStringPluralized(let _data):
                if boxed {
                    buffer.appendInt32(1816636575)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.key, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.zeroValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.oneValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.twoValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.fewValue!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.manyValue!, buffer: buffer, boxed: false)
                }
                serializeString(_data.otherValue, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .langPackString(let _data):
                return ("langPackString", [("key", ConstructorParameterDescription(_data.key)), ("value", ConstructorParameterDescription(_data.value))])
            case .langPackStringDeleted(let _data):
                return ("langPackStringDeleted", [("key", ConstructorParameterDescription(_data.key))])
            case .langPackStringPluralized(let _data):
                return ("langPackStringPluralized", [("flags", ConstructorParameterDescription(_data.flags)), ("key", ConstructorParameterDescription(_data.key)), ("zeroValue", ConstructorParameterDescription(_data.zeroValue)), ("oneValue", ConstructorParameterDescription(_data.oneValue)), ("twoValue", ConstructorParameterDescription(_data.twoValue)), ("fewValue", ConstructorParameterDescription(_data.fewValue)), ("manyValue", ConstructorParameterDescription(_data.manyValue)), ("otherValue", ConstructorParameterDescription(_data.otherValue))])
            }
        }

        public static func parse_langPackString(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LangPackString.langPackString(Cons_langPackString(key: _1!, value: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringDeleted(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.LangPackString.langPackStringDeleted(Cons_langPackStringDeleted(key: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringPluralized(_ reader: BufferReader) -> LangPackString? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.LangPackString.langPackStringPluralized(Cons_langPackStringPluralized(flags: _1!, key: _2!, zeroValue: _3, oneValue: _4, twoValue: _5, fewValue: _6, manyValue: _7, otherValue: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription {
        public class Cons_maskCoords: TypeConstructorDescription {
            public var n: Int32
            public var x: Double
            public var y: Double
            public var zoom: Double
            public init(n: Int32, x: Double, y: Double, zoom: Double) {
                self.n = n
                self.x = x
                self.y = y
                self.zoom = zoom
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("maskCoords", [("n", ConstructorParameterDescription(self.n)), ("x", ConstructorParameterDescription(self.x)), ("y", ConstructorParameterDescription(self.y)), ("zoom", ConstructorParameterDescription(self.zoom))])
            }
        }
        case maskCoords(Cons_maskCoords)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .maskCoords(let _data):
                if boxed {
                    buffer.appendInt32(-1361650766)
                }
                serializeInt32(_data.n, buffer: buffer, boxed: false)
                serializeDouble(_data.x, buffer: buffer, boxed: false)
                serializeDouble(_data.y, buffer: buffer, boxed: false)
                serializeDouble(_data.zoom, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .maskCoords(let _data):
                return ("maskCoords", [("n", ConstructorParameterDescription(_data.n)), ("x", ConstructorParameterDescription(_data.x)), ("y", ConstructorParameterDescription(_data.y)), ("zoom", ConstructorParameterDescription(_data.zoom))])
            }
        }

        public static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Double?
            _4 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MaskCoords.maskCoords(Cons_maskCoords(n: _1!, x: _2!, y: _3!, zoom: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription {
        public class Cons_inputMediaAreaChannelPost: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var channel: Api.InputChannel
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32) {
                self.coordinates = coordinates
                self.channel = channel
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("channel", ConstructorParameterDescription(self.channel)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_inputMediaAreaVenue: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var queryId: Int64
            public var resultId: String
            public init(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String) {
                self.coordinates = coordinates
                self.queryId = queryId
                self.resultId = resultId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputMediaAreaVenue", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("queryId", ConstructorParameterDescription(self.queryId)), ("resultId", ConstructorParameterDescription(self.resultId))])
            }
        }
        public class Cons_mediaAreaChannelPost: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var channelId: Int64
            public var msgId: Int32
            public init(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32) {
                self.coordinates = coordinates
                self.channelId = channelId
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("channelId", ConstructorParameterDescription(self.channelId)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_mediaAreaGeoPoint: TypeConstructorDescription {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var address: Api.GeoPointAddress?
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?) {
                self.flags = flags
                self.coordinates = coordinates
                self.geo = geo
                self.address = address
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaGeoPoint", [("flags", ConstructorParameterDescription(self.flags)), ("coordinates", ConstructorParameterDescription(self.coordinates)), ("geo", ConstructorParameterDescription(self.geo)), ("address", ConstructorParameterDescription(self.address))])
            }
        }
        public class Cons_mediaAreaStarGift: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var slug: String
            public init(coordinates: Api.MediaAreaCoordinates, slug: String) {
                self.coordinates = coordinates
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaStarGift", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        public class Cons_mediaAreaSuggestedReaction: TypeConstructorDescription {
            public var flags: Int32
            public var coordinates: Api.MediaAreaCoordinates
            public var reaction: Api.Reaction
            public init(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction) {
                self.flags = flags
                self.coordinates = coordinates
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaSuggestedReaction", [("flags", ConstructorParameterDescription(self.flags)), ("coordinates", ConstructorParameterDescription(self.coordinates)), ("reaction", ConstructorParameterDescription(self.reaction))])
            }
        }
        public class Cons_mediaAreaUrl: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var url: String
            public init(coordinates: Api.MediaAreaCoordinates, url: String) {
                self.coordinates = coordinates
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaUrl", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_mediaAreaVenue: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public init(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
                self.coordinates = coordinates
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaVenue", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("geo", ConstructorParameterDescription(self.geo)), ("title", ConstructorParameterDescription(self.title)), ("address", ConstructorParameterDescription(self.address)), ("provider", ConstructorParameterDescription(self.provider)), ("venueId", ConstructorParameterDescription(self.venueId)), ("venueType", ConstructorParameterDescription(self.venueType))])
            }
        }
        public class Cons_mediaAreaWeather: TypeConstructorDescription {
            public var coordinates: Api.MediaAreaCoordinates
            public var emoji: String
            public var temperatureC: Double
            public var color: Int32
            public init(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32) {
                self.coordinates = coordinates
                self.emoji = emoji
                self.temperatureC = temperatureC
                self.color = color
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("mediaAreaWeather", [("coordinates", ConstructorParameterDescription(self.coordinates)), ("emoji", ConstructorParameterDescription(self.emoji)), ("temperatureC", ConstructorParameterDescription(self.temperatureC)), ("color", ConstructorParameterDescription(self.color))])
            }
        }
        case inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost)
        case inputMediaAreaVenue(Cons_inputMediaAreaVenue)
        case mediaAreaChannelPost(Cons_mediaAreaChannelPost)
        case mediaAreaGeoPoint(Cons_mediaAreaGeoPoint)
        case mediaAreaStarGift(Cons_mediaAreaStarGift)
        case mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction)
        case mediaAreaUrl(Cons_mediaAreaUrl)
        case mediaAreaVenue(Cons_mediaAreaVenue)
        case mediaAreaWeather(Cons_mediaAreaWeather)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMediaAreaChannelPost(let _data):
                if boxed {
                    buffer.appendInt32(577893055)
                }
                _data.coordinates.serialize(buffer, true)
                _data.channel.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .inputMediaAreaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1300094593)
                }
                _data.coordinates.serialize(buffer, true)
                serializeInt64(_data.queryId, buffer: buffer, boxed: false)
                serializeString(_data.resultId, buffer: buffer, boxed: false)
                break
            case .mediaAreaChannelPost(let _data):
                if boxed {
                    buffer.appendInt32(1996756655)
                }
                _data.coordinates.serialize(buffer, true)
                serializeInt64(_data.channelId, buffer: buffer, boxed: false)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .mediaAreaGeoPoint(let _data):
                if boxed {
                    buffer.appendInt32(-891992787)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.coordinates.serialize(buffer, true)
                _data.geo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.address!.serialize(buffer, true)
                }
                break
            case .mediaAreaStarGift(let _data):
                if boxed {
                    buffer.appendInt32(1468491885)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            case .mediaAreaSuggestedReaction(let _data):
                if boxed {
                    buffer.appendInt32(340088945)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.coordinates.serialize(buffer, true)
                _data.reaction.serialize(buffer, true)
                break
            case .mediaAreaUrl(let _data):
                if boxed {
                    buffer.appendInt32(926421125)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .mediaAreaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1098720356)
                }
                _data.coordinates.serialize(buffer, true)
                _data.geo.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                break
            case .mediaAreaWeather(let _data):
                if boxed {
                    buffer.appendInt32(1235637404)
                }
                _data.coordinates.serialize(buffer, true)
                serializeString(_data.emoji, buffer: buffer, boxed: false)
                serializeDouble(_data.temperatureC, buffer: buffer, boxed: false)
                serializeInt32(_data.color, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputMediaAreaChannelPost(let _data):
                return ("inputMediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("channel", ConstructorParameterDescription(_data.channel)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            case .inputMediaAreaVenue(let _data):
                return ("inputMediaAreaVenue", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("queryId", ConstructorParameterDescription(_data.queryId)), ("resultId", ConstructorParameterDescription(_data.resultId))])
            case .mediaAreaChannelPost(let _data):
                return ("mediaAreaChannelPost", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("channelId", ConstructorParameterDescription(_data.channelId)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            case .mediaAreaGeoPoint(let _data):
                return ("mediaAreaGeoPoint", [("flags", ConstructorParameterDescription(_data.flags)), ("coordinates", ConstructorParameterDescription(_data.coordinates)), ("geo", ConstructorParameterDescription(_data.geo)), ("address", ConstructorParameterDescription(_data.address))])
            case .mediaAreaStarGift(let _data):
                return ("mediaAreaStarGift", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("slug", ConstructorParameterDescription(_data.slug))])
            case .mediaAreaSuggestedReaction(let _data):
                return ("mediaAreaSuggestedReaction", [("flags", ConstructorParameterDescription(_data.flags)), ("coordinates", ConstructorParameterDescription(_data.coordinates)), ("reaction", ConstructorParameterDescription(_data.reaction))])
            case .mediaAreaUrl(let _data):
                return ("mediaAreaUrl", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("url", ConstructorParameterDescription(_data.url))])
            case .mediaAreaVenue(let _data):
                return ("mediaAreaVenue", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("geo", ConstructorParameterDescription(_data.geo)), ("title", ConstructorParameterDescription(_data.title)), ("address", ConstructorParameterDescription(_data.address)), ("provider", ConstructorParameterDescription(_data.provider)), ("venueId", ConstructorParameterDescription(_data.venueId)), ("venueType", ConstructorParameterDescription(_data.venueType))])
            case .mediaAreaWeather(let _data):
                return ("mediaAreaWeather", [("coordinates", ConstructorParameterDescription(_data.coordinates)), ("emoji", ConstructorParameterDescription(_data.emoji)), ("temperatureC", ConstructorParameterDescription(_data.temperatureC)), ("color", ConstructorParameterDescription(_data.color))])
            }
        }

        public static func parse_inputMediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.InputChannel?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputChannel
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaChannelPost(Cons_inputMediaAreaChannelPost(coordinates: _1!, channel: _2!, msgId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaVenue(Cons_inputMediaAreaVenue(coordinates: _1!, queryId: _2!, resultId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaChannelPost(Cons_mediaAreaChannelPost(coordinates: _1!, channelId: _2!, msgId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaGeoPoint(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _4: Api.GeoPointAddress?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.GeoPointAddress
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaGeoPoint(Cons_mediaAreaGeoPoint(flags: _1!, coordinates: _2!, geo: _3!, address: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaStarGift(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MediaArea.mediaAreaStarGift(Cons_mediaAreaStarGift(coordinates: _1!, slug: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaSuggestedReaction(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaSuggestedReaction(Cons_mediaAreaSuggestedReaction(flags: _1!, coordinates: _2!, reaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaUrl(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MediaArea.mediaAreaUrl(Cons_mediaAreaUrl(coordinates: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            _7 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MediaArea.mediaAreaVenue(Cons_mediaAreaVenue(coordinates: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaWeather(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaWeather(Cons_mediaAreaWeather(coordinates: _1!, emoji: _2!, temperatureC: _3!, color: _4!))
            }
            else {
                return nil
            }
        }
    }
}
