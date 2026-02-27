public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        public class Cons_securePlainEmail {
            public var email: String
            public init(email: String) {
                self.email = email
            }
        }
        public class Cons_securePlainPhone {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
        }
        case securePlainEmail(Cons_securePlainEmail)
        case securePlainPhone(Cons_securePlainPhone)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .securePlainEmail(let _data):
                if boxed {
                    buffer.appendInt32(569137759)
                }
                serializeString(_data.email, buffer: buffer, boxed: false)
                break
            case .securePlainPhone(let _data):
                if boxed {
                    buffer.appendInt32(2103482845)
                }
                serializeString(_data.phone, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .securePlainEmail(let _data):
                return ("securePlainEmail", [("email", _data.email as Any)])
            case .securePlainPhone(let _data):
                return ("securePlainPhone", [("phone", _data.phone as Any)])
            }
        }

        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainEmail(Cons_securePlainEmail(email: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePlainPhone(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainPhone(Cons_securePlainPhone(phone: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureRequiredType: TypeConstructorDescription {
        public class Cons_secureRequiredType {
            public var flags: Int32
            public var type: Api.SecureValueType
            public init(flags: Int32, type: Api.SecureValueType) {
                self.flags = flags
                self.type = type
            }
        }
        public class Cons_secureRequiredTypeOneOf {
            public var types: [Api.SecureRequiredType]
            public init(types: [Api.SecureRequiredType]) {
                self.types = types
            }
        }
        case secureRequiredType(Cons_secureRequiredType)
        case secureRequiredTypeOneOf(Cons_secureRequiredTypeOneOf)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureRequiredType(let _data):
                if boxed {
                    buffer.appendInt32(-2103600678)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                break
            case .secureRequiredTypeOneOf(let _data):
                if boxed {
                    buffer.appendInt32(41187252)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.types.count))
                for item in _data.types {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureRequiredType(let _data):
                return ("secureRequiredType", [("flags", _data.flags as Any), ("type", _data.type as Any)])
            case .secureRequiredTypeOneOf(let _data):
                return ("secureRequiredTypeOneOf", [("types", _data.types as Any)])
            }
        }

        public static func parse_secureRequiredType(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureRequiredType.secureRequiredType(Cons_secureRequiredType(flags: _1!, type: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureRequiredTypeOneOf(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecureRequiredType.secureRequiredTypeOneOf(Cons_secureRequiredTypeOneOf(types: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureSecretSettings: TypeConstructorDescription {
        public class Cons_secureSecretSettings {
            public var secureAlgo: Api.SecurePasswordKdfAlgo
            public var secureSecret: Buffer
            public var secureSecretId: Int64
            public init(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64) {
                self.secureAlgo = secureAlgo
                self.secureSecret = secureSecret
                self.secureSecretId = secureSecretId
            }
        }
        case secureSecretSettings(Cons_secureSecretSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureSecretSettings(let _data):
                if boxed {
                    buffer.appendInt32(354925740)
                }
                _data.secureAlgo.serialize(buffer, true)
                serializeBytes(_data.secureSecret, buffer: buffer, boxed: false)
                serializeInt64(_data.secureSecretId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureSecretSettings(let _data):
                return ("secureSecretSettings", [("secureAlgo", _data.secureAlgo as Any), ("secureSecret", _data.secureSecret as Any), ("secureSecretId", _data.secureSecretId as Any)])
            }
        }

        public static func parse_secureSecretSettings(_ reader: BufferReader) -> SecureSecretSettings? {
            var _1: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureSecretSettings.secureSecretSettings(Cons_secureSecretSettings(secureAlgo: _1!, secureSecret: _2!, secureSecretId: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValue: TypeConstructorDescription {
        public class Cons_secureValue {
            public var flags: Int32
            public var type: Api.SecureValueType
            public var data: Api.SecureData?
            public var frontSide: Api.SecureFile?
            public var reverseSide: Api.SecureFile?
            public var selfie: Api.SecureFile?
            public var translation: [Api.SecureFile]?
            public var files: [Api.SecureFile]?
            public var plainData: Api.SecurePlainData?
            public var hash: Buffer
            public init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer) {
                self.flags = flags
                self.type = type
                self.data = data
                self.frontSide = frontSide
                self.reverseSide = reverseSide
                self.selfie = selfie
                self.translation = translation
                self.files = files
                self.plainData = plainData
                self.hash = hash
            }
        }
        case secureValue(Cons_secureValue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValue(let _data):
                if boxed {
                    buffer.appendInt32(411017418)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.data!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.frontSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.reverseSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.selfie!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.translation!.count))
                    for item in _data.translation! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.files!.count))
                    for item in _data.files! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.plainData!.serialize(buffer, true)
                }
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValue(let _data):
                return ("secureValue", [("flags", _data.flags as Any), ("type", _data.type as Any), ("data", _data.data as Any), ("frontSide", _data.frontSide as Any), ("reverseSide", _data.reverseSide as Any), ("selfie", _data.selfie as Any), ("translation", _data.translation as Any), ("files", _data.files as Any), ("plainData", _data.plainData as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_secureValue(_ reader: BufferReader) -> SecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureData
                }
            }
            var _4: Api.SecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _5: Api.SecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _6: Api.SecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _7: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
                }
            }
            var _8: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
                }
            }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
                }
            }
            var _10: Buffer?
            _10 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.SecureValue.secureValue(Cons_secureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9, hash: _10!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription {
        public class Cons_secureValueError {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, hash: Buffer, text: String) {
                self.type = type
                self.hash = hash
                self.text = text
            }
        }
        public class Cons_secureValueErrorData {
            public var type: Api.SecureValueType
            public var dataHash: Buffer
            public var field: String
            public var text: String
            public init(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String) {
                self.type = type
                self.dataHash = dataHash
                self.field = field
                self.text = text
            }
        }
        public class Cons_secureValueErrorFile {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorFiles {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorFrontSide {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorReverseSide {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorSelfie {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorTranslationFile {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        public class Cons_secureValueErrorTranslationFiles {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
        }
        case secureValueError(Cons_secureValueError)
        case secureValueErrorData(Cons_secureValueErrorData)
        case secureValueErrorFile(Cons_secureValueErrorFile)
        case secureValueErrorFiles(Cons_secureValueErrorFiles)
        case secureValueErrorFrontSide(Cons_secureValueErrorFrontSide)
        case secureValueErrorReverseSide(Cons_secureValueErrorReverseSide)
        case secureValueErrorSelfie(Cons_secureValueErrorSelfie)
        case secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile)
        case secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueError(let _data):
                if boxed {
                    buffer.appendInt32(-2036501105)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorData(let _data):
                if boxed {
                    buffer.appendInt32(-391902247)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.dataHash, buffer: buffer, boxed: false)
                serializeString(_data.field, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFile(let _data):
                if boxed {
                    buffer.appendInt32(2054162547)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFiles(let _data):
                if boxed {
                    buffer.appendInt32(1717706985)
                }
                _data.type.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.fileHash.count))
                for item in _data.fileHash {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFrontSide(let _data):
                if boxed {
                    buffer.appendInt32(12467706)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorReverseSide(let _data):
                if boxed {
                    buffer.appendInt32(-2037765467)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorSelfie(let _data):
                if boxed {
                    buffer.appendInt32(-449327402)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorTranslationFile(let _data):
                if boxed {
                    buffer.appendInt32(-1592506512)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorTranslationFiles(let _data):
                if boxed {
                    buffer.appendInt32(878931416)
                }
                _data.type.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.fileHash.count))
                for item in _data.fileHash {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueError(let _data):
                return ("secureValueError", [("type", _data.type as Any), ("hash", _data.hash as Any), ("text", _data.text as Any)])
            case .secureValueErrorData(let _data):
                return ("secureValueErrorData", [("type", _data.type as Any), ("dataHash", _data.dataHash as Any), ("field", _data.field as Any), ("text", _data.text as Any)])
            case .secureValueErrorFile(let _data):
                return ("secureValueErrorFile", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorFiles(let _data):
                return ("secureValueErrorFiles", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorFrontSide(let _data):
                return ("secureValueErrorFrontSide", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorReverseSide(let _data):
                return ("secureValueErrorReverseSide", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorSelfie(let _data):
                return ("secureValueErrorSelfie", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorTranslationFile(let _data):
                return ("secureValueErrorTranslationFile", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorTranslationFiles(let _data):
                return ("secureValueErrorTranslationFiles", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            }
        }

        public static func parse_secureValueError(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueError(Cons_secureValueError(type: _1!, hash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorData(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SecureValueError.secureValueErrorData(Cons_secureValueErrorData(type: _1!, dataHash: _2!, field: _3!, text: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFile(Cons_secureValueErrorFile(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFiles(Cons_secureValueErrorFiles(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFrontSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFrontSide(Cons_secureValueErrorFrontSide(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorReverseSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorReverseSide(Cons_secureValueErrorReverseSide(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorSelfie(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorSelfie(Cons_secureValueErrorSelfie(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription {
        public class Cons_secureValueHash {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public init(type: Api.SecureValueType, hash: Buffer) {
                self.type = type
                self.hash = hash
            }
        }
        case secureValueHash(Cons_secureValueHash)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueHash(let _data):
                if boxed {
                    buffer.appendInt32(-316748368)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueHash(let _data):
                return ("secureValueHash", [("type", _data.type as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_secureValueHash(_ reader: BufferReader) -> SecureValueHash? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureValueHash.secureValueHash(Cons_secureValueHash(type: _1!, hash: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueType: TypeConstructorDescription {
        case secureValueTypeAddress
        case secureValueTypeBankStatement
        case secureValueTypeDriverLicense
        case secureValueTypeEmail
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypePassport
        case secureValueTypePassportRegistration
        case secureValueTypePersonalDetails
        case secureValueTypePhone
        case secureValueTypeRentalAgreement
        case secureValueTypeTemporaryRegistration
        case secureValueTypeUtilityBill

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueTypeAddress:
                if boxed {
                    buffer.appendInt32(-874308058)
                }
                break
            case .secureValueTypeBankStatement:
                if boxed {
                    buffer.appendInt32(-1995211763)
                }
                break
            case .secureValueTypeDriverLicense:
                if boxed {
                    buffer.appendInt32(115615172)
                }
                break
            case .secureValueTypeEmail:
                if boxed {
                    buffer.appendInt32(-1908627474)
                }
                break
            case .secureValueTypeIdentityCard:
                if boxed {
                    buffer.appendInt32(-1596951477)
                }
                break
            case .secureValueTypeInternalPassport:
                if boxed {
                    buffer.appendInt32(-1717268701)
                }
                break
            case .secureValueTypePassport:
                if boxed {
                    buffer.appendInt32(1034709504)
                }
                break
            case .secureValueTypePassportRegistration:
                if boxed {
                    buffer.appendInt32(-1713143702)
                }
                break
            case .secureValueTypePersonalDetails:
                if boxed {
                    buffer.appendInt32(-1658158621)
                }
                break
            case .secureValueTypePhone:
                if boxed {
                    buffer.appendInt32(-1289704741)
                }
                break
            case .secureValueTypeRentalAgreement:
                if boxed {
                    buffer.appendInt32(-1954007928)
                }
                break
            case .secureValueTypeTemporaryRegistration:
                if boxed {
                    buffer.appendInt32(-368907213)
                }
                break
            case .secureValueTypeUtilityBill:
                if boxed {
                    buffer.appendInt32(-63531698)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueTypeAddress:
                return ("secureValueTypeAddress", [])
            case .secureValueTypeBankStatement:
                return ("secureValueTypeBankStatement", [])
            case .secureValueTypeDriverLicense:
                return ("secureValueTypeDriverLicense", [])
            case .secureValueTypeEmail:
                return ("secureValueTypeEmail", [])
            case .secureValueTypeIdentityCard:
                return ("secureValueTypeIdentityCard", [])
            case .secureValueTypeInternalPassport:
                return ("secureValueTypeInternalPassport", [])
            case .secureValueTypePassport:
                return ("secureValueTypePassport", [])
            case .secureValueTypePassportRegistration:
                return ("secureValueTypePassportRegistration", [])
            case .secureValueTypePersonalDetails:
                return ("secureValueTypePersonalDetails", [])
            case .secureValueTypePhone:
                return ("secureValueTypePhone", [])
            case .secureValueTypeRentalAgreement:
                return ("secureValueTypeRentalAgreement", [])
            case .secureValueTypeTemporaryRegistration:
                return ("secureValueTypeTemporaryRegistration", [])
            case .secureValueTypeUtilityBill:
                return ("secureValueTypeUtilityBill", [])
            }
        }

        public static func parse_secureValueTypeAddress(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeAddress
        }
        public static func parse_secureValueTypeBankStatement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeBankStatement
        }
        public static func parse_secureValueTypeDriverLicense(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeDriverLicense
        }
        public static func parse_secureValueTypeEmail(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeEmail
        }
        public static func parse_secureValueTypeIdentityCard(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeIdentityCard
        }
        public static func parse_secureValueTypeInternalPassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeInternalPassport
        }
        public static func parse_secureValueTypePassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassport
        }
        public static func parse_secureValueTypePassportRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassportRegistration
        }
        public static func parse_secureValueTypePersonalDetails(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePersonalDetails
        }
        public static func parse_secureValueTypePhone(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePhone
        }
        public static func parse_secureValueTypeRentalAgreement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeRentalAgreement
        }
        public static func parse_secureValueTypeTemporaryRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeTemporaryRegistration
        }
        public static func parse_secureValueTypeUtilityBill(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeUtilityBill
        }
    }
}
public extension Api {
    enum SendAsPeer: TypeConstructorDescription {
        public class Cons_sendAsPeer {
            public var flags: Int32
            public var peer: Api.Peer
            public init(flags: Int32, peer: Api.Peer) {
                self.flags = flags
                self.peer = peer
            }
        }
        case sendAsPeer(Cons_sendAsPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sendAsPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1206095820)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sendAsPeer(let _data):
                return ("sendAsPeer", [("flags", _data.flags as Any), ("peer", _data.peer as Any)])
            }
        }

        public static func parse_sendAsPeer(_ reader: BufferReader) -> SendAsPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SendAsPeer.sendAsPeer(Cons_sendAsPeer(flags: _1!, peer: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription {
        public class Cons_sendMessageEmojiInteraction {
            public var emoticon: String
            public var msgId: Int32
            public var interaction: Api.DataJSON
            public init(emoticon: String, msgId: Int32, interaction: Api.DataJSON) {
                self.emoticon = emoticon
                self.msgId = msgId
                self.interaction = interaction
            }
        }
        public class Cons_sendMessageEmojiInteractionSeen {
            public var emoticon: String
            public init(emoticon: String) {
                self.emoticon = emoticon
            }
        }
        public class Cons_sendMessageHistoryImportAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageTextDraftAction {
            public var randomId: Int64
            public var text: Api.TextWithEntities
            public init(randomId: Int64, text: Api.TextWithEntities) {
                self.randomId = randomId
                self.text = text
            }
        }
        public class Cons_sendMessageUploadAudioAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadDocumentAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadPhotoAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadRoundAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        public class Cons_sendMessageUploadVideoAction {
            public var progress: Int32
            public init(progress: Int32) {
                self.progress = progress
            }
        }
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction)
        case sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageTextDraftAction(Cons_sendMessageTextDraftAction)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction)
        case sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction)
        case sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction)
        case sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction)
        case sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction)
        case speakingInGroupCallAction

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sendMessageCancelAction:
                if boxed {
                    buffer.appendInt32(-44119819)
                }
                break
            case .sendMessageChooseContactAction:
                if boxed {
                    buffer.appendInt32(1653390447)
                }
                break
            case .sendMessageChooseStickerAction:
                if boxed {
                    buffer.appendInt32(-1336228175)
                }
                break
            case .sendMessageEmojiInteraction(let _data):
                if boxed {
                    buffer.appendInt32(630664139)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                _data.interaction.serialize(buffer, true)
                break
            case .sendMessageEmojiInteractionSeen(let _data):
                if boxed {
                    buffer.appendInt32(-1234857938)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                break
            case .sendMessageGamePlayAction:
                if boxed {
                    buffer.appendInt32(-580219064)
                }
                break
            case .sendMessageGeoLocationAction:
                if boxed {
                    buffer.appendInt32(393186209)
                }
                break
            case .sendMessageHistoryImportAction(let _data):
                if boxed {
                    buffer.appendInt32(-606432698)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageRecordAudioAction:
                if boxed {
                    buffer.appendInt32(-718310409)
                }
                break
            case .sendMessageRecordRoundAction:
                if boxed {
                    buffer.appendInt32(-1997373508)
                }
                break
            case .sendMessageRecordVideoAction:
                if boxed {
                    buffer.appendInt32(-1584933265)
                }
                break
            case .sendMessageTextDraftAction(let _data):
                if boxed {
                    buffer.appendInt32(929929052)
                }
                serializeInt64(_data.randomId, buffer: buffer, boxed: false)
                _data.text.serialize(buffer, true)
                break
            case .sendMessageTypingAction:
                if boxed {
                    buffer.appendInt32(381645902)
                }
                break
            case .sendMessageUploadAudioAction(let _data):
                if boxed {
                    buffer.appendInt32(-212740181)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadDocumentAction(let _data):
                if boxed {
                    buffer.appendInt32(-1441998364)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadPhotoAction(let _data):
                if boxed {
                    buffer.appendInt32(-774682074)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadRoundAction(let _data):
                if boxed {
                    buffer.appendInt32(608050278)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .sendMessageUploadVideoAction(let _data):
                if boxed {
                    buffer.appendInt32(-378127636)
                }
                serializeInt32(_data.progress, buffer: buffer, boxed: false)
                break
            case .speakingInGroupCallAction:
                if boxed {
                    buffer.appendInt32(-651419003)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sendMessageCancelAction:
                return ("sendMessageCancelAction", [])
            case .sendMessageChooseContactAction:
                return ("sendMessageChooseContactAction", [])
            case .sendMessageChooseStickerAction:
                return ("sendMessageChooseStickerAction", [])
            case .sendMessageEmojiInteraction(let _data):
                return ("sendMessageEmojiInteraction", [("emoticon", _data.emoticon as Any), ("msgId", _data.msgId as Any), ("interaction", _data.interaction as Any)])
            case .sendMessageEmojiInteractionSeen(let _data):
                return ("sendMessageEmojiInteractionSeen", [("emoticon", _data.emoticon as Any)])
            case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
            case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
            case .sendMessageHistoryImportAction(let _data):
                return ("sendMessageHistoryImportAction", [("progress", _data.progress as Any)])
            case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
            case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
            case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
            case .sendMessageTextDraftAction(let _data):
                return ("sendMessageTextDraftAction", [("randomId", _data.randomId as Any), ("text", _data.text as Any)])
            case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
            case .sendMessageUploadAudioAction(let _data):
                return ("sendMessageUploadAudioAction", [("progress", _data.progress as Any)])
            case .sendMessageUploadDocumentAction(let _data):
                return ("sendMessageUploadDocumentAction", [("progress", _data.progress as Any)])
            case .sendMessageUploadPhotoAction(let _data):
                return ("sendMessageUploadPhotoAction", [("progress", _data.progress as Any)])
            case .sendMessageUploadRoundAction(let _data):
                return ("sendMessageUploadRoundAction", [("progress", _data.progress as Any)])
            case .sendMessageUploadVideoAction(let _data):
                return ("sendMessageUploadVideoAction", [("progress", _data.progress as Any)])
            case .speakingInGroupCallAction:
                return ("speakingInGroupCallAction", [])
            }
        }

        public static func parse_sendMessageCancelAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageCancelAction
        }
        public static func parse_sendMessageChooseContactAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageChooseContactAction
        }
        public static func parse_sendMessageChooseStickerAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageChooseStickerAction
        }
        public static func parse_sendMessageEmojiInteraction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.DataJSON?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SendMessageAction.sendMessageEmojiInteraction(Cons_sendMessageEmojiInteraction(emoticon: _1!, msgId: _2!, interaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageEmojiInteractionSeen(_ reader: BufferReader) -> SendMessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageEmojiInteractionSeen(Cons_sendMessageEmojiInteractionSeen(emoticon: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageGamePlayAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGamePlayAction
        }
        public static func parse_sendMessageGeoLocationAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageGeoLocationAction
        }
        public static func parse_sendMessageHistoryImportAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageHistoryImportAction(Cons_sendMessageHistoryImportAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageRecordAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordAudioAction
        }
        public static func parse_sendMessageRecordRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordRoundAction
        }
        public static func parse_sendMessageRecordVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageRecordVideoAction
        }
        public static func parse_sendMessageTextDraftAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SendMessageAction.sendMessageTextDraftAction(Cons_sendMessageTextDraftAction(randomId: _1!, text: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.sendMessageTypingAction
        }
        public static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadAudioAction(Cons_sendMessageUploadAudioAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadDocumentAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadDocumentAction(Cons_sendMessageUploadDocumentAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadPhotoAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadPhotoAction(Cons_sendMessageUploadPhotoAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadRoundAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadRoundAction(Cons_sendMessageUploadRoundAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sendMessageUploadVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.SendMessageAction.sendMessageUploadVideoAction(Cons_sendMessageUploadVideoAction(progress: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_speakingInGroupCallAction(_ reader: BufferReader) -> SendMessageAction? {
            return Api.SendMessageAction.speakingInGroupCallAction
        }
    }
}
