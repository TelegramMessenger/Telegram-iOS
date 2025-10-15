public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        case securePlainEmail(email: String)
        case securePlainPhone(phone: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .securePlainEmail(let email):
                    if boxed {
                        buffer.appendInt32(569137759)
                    }
                    serializeString(email, buffer: buffer, boxed: false)
                    break
                case .securePlainPhone(let phone):
                    if boxed {
                        buffer.appendInt32(2103482845)
                    }
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .securePlainEmail(let email):
                return ("securePlainEmail", [("email", email as Any)])
                case .securePlainPhone(let phone):
                return ("securePlainPhone", [("phone", phone as Any)])
    }
    }
    
        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainEmail(email: _1!)
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
                return Api.SecurePlainData.securePlainPhone(phone: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureRequiredType: TypeConstructorDescription {
        case secureRequiredType(flags: Int32, type: Api.SecureValueType)
        case secureRequiredTypeOneOf(types: [Api.SecureRequiredType])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureRequiredType(let flags, let type):
                    if boxed {
                        buffer.appendInt32(-2103600678)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    break
                case .secureRequiredTypeOneOf(let types):
                    if boxed {
                        buffer.appendInt32(41187252)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureRequiredType(let flags, let type):
                return ("secureRequiredType", [("flags", flags as Any), ("type", type as Any)])
                case .secureRequiredTypeOneOf(let types):
                return ("secureRequiredTypeOneOf", [("types", types as Any)])
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
                return Api.SecureRequiredType.secureRequiredType(flags: _1!, type: _2!)
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
                return Api.SecureRequiredType.secureRequiredTypeOneOf(types: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureSecretSettings: TypeConstructorDescription {
        case secureSecretSettings(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                    if boxed {
                        buffer.appendInt32(354925740)
                    }
                    secureAlgo.serialize(buffer, true)
                    serializeBytes(secureSecret, buffer: buffer, boxed: false)
                    serializeInt64(secureSecretId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureSecretSettings(let secureAlgo, let secureSecret, let secureSecretId):
                return ("secureSecretSettings", [("secureAlgo", secureAlgo as Any), ("secureSecret", secureSecret as Any), ("secureSecretId", secureSecretId as Any)])
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
                return Api.SecureSecretSettings.secureSecretSettings(secureAlgo: _1!, secureSecret: _2!, secureSecretId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValue: TypeConstructorDescription {
        case secureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                    if boxed {
                        buffer.appendInt32(411017418)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {data!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {frontSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {reverseSide!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {selfie!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(translation!.count))
                    for item in translation! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(files!.count))
                    for item in files! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 5) != 0 {plainData!.serialize(buffer, true)}
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData, let hash):
                return ("secureValue", [("flags", flags as Any), ("type", type as Any), ("data", data as Any), ("frontSide", frontSide as Any), ("reverseSide", reverseSide as Any), ("selfie", selfie as Any), ("translation", translation as Any), ("files", files as Any), ("plainData", plainData as Any), ("hash", hash as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureData
            } }
            var _4: Api.SecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _5: Api.SecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _6: Api.SecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureFile
            } }
            var _7: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _8: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
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
                return Api.SecureValue.secureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9, hash: _10!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription {
        case secureValueError(type: Api.SecureValueType, hash: Buffer, text: String)
        case secureValueErrorData(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String)
        case secureValueErrorFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
        case secureValueErrorFrontSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorReverseSide(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorSelfie(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFile(type: Api.SecureValueType, fileHash: Buffer, text: String)
        case secureValueErrorTranslationFiles(type: Api.SecureValueType, fileHash: [Buffer], text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueError(let type, let hash, let text):
                    if boxed {
                        buffer.appendInt32(-2036501105)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                    if boxed {
                        buffer.appendInt32(-391902247)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(dataHash, buffer: buffer, boxed: false)
                    serializeString(field, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(2054162547)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(1717706985)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(12467706)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-2037765467)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-449327402)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(-1592506512)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                    if boxed {
                        buffer.appendInt32(878931416)
                    }
                    type.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(fileHash.count))
                    for item in fileHash {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueError(let type, let hash, let text):
                return ("secureValueError", [("type", type as Any), ("hash", hash as Any), ("text", text as Any)])
                case .secureValueErrorData(let type, let dataHash, let field, let text):
                return ("secureValueErrorData", [("type", type as Any), ("dataHash", dataHash as Any), ("field", field as Any), ("text", text as Any)])
                case .secureValueErrorFile(let type, let fileHash, let text):
                return ("secureValueErrorFile", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorFiles(let type, let fileHash, let text):
                return ("secureValueErrorFiles", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorFrontSide(let type, let fileHash, let text):
                return ("secureValueErrorFrontSide", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorReverseSide(let type, let fileHash, let text):
                return ("secureValueErrorReverseSide", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorSelfie(let type, let fileHash, let text):
                return ("secureValueErrorSelfie", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorTranslationFile(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFile", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
                case .secureValueErrorTranslationFiles(let type, let fileHash, let text):
                return ("secureValueErrorTranslationFiles", [("type", type as Any), ("fileHash", fileHash as Any), ("text", text as Any)])
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
                return Api.SecureValueError.secureValueError(type: _1!, hash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorData(type: _1!, dataHash: _2!, field: _3!, text: _4!)
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
                return Api.SecureValueError.secureValueErrorFile(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorFiles(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorFrontSide(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorReverseSide(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorSelfie(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorTranslationFile(type: _1!, fileHash: _2!, text: _3!)
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
                return Api.SecureValueError.secureValueErrorTranslationFiles(type: _1!, fileHash: _2!, text: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription {
        case secureValueHash(type: Api.SecureValueType, hash: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .secureValueHash(let type, let hash):
                    if boxed {
                        buffer.appendInt32(-316748368)
                    }
                    type.serialize(buffer, true)
                    serializeBytes(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .secureValueHash(let type, let hash):
                return ("secureValueHash", [("type", type as Any), ("hash", hash as Any)])
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
                return Api.SecureValueHash.secureValueHash(type: _1!, hash: _2!)
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
        case sendAsPeer(flags: Int32, peer: Api.Peer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendAsPeer(let flags, let peer):
                    if boxed {
                        buffer.appendInt32(-1206095820)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sendAsPeer(let flags, let peer):
                return ("sendAsPeer", [("flags", flags as Any), ("peer", peer as Any)])
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
                return Api.SendAsPeer.sendAsPeer(flags: _1!, peer: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SendMessageAction: TypeConstructorDescription {
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageChooseStickerAction
        case sendMessageEmojiInteraction(emoticon: String, msgId: Int32, interaction: Api.DataJSON)
        case sendMessageEmojiInteractionSeen(emoticon: String)
        case sendMessageGamePlayAction
        case sendMessageGeoLocationAction
        case sendMessageHistoryImportAction(progress: Int32)
        case sendMessageRecordAudioAction
        case sendMessageRecordRoundAction
        case sendMessageRecordVideoAction
        case sendMessageTextDraftAction(randomId: Int64, text: Api.TextWithEntities)
        case sendMessageTypingAction
        case sendMessageUploadAudioAction(progress: Int32)
        case sendMessageUploadDocumentAction(progress: Int32)
        case sendMessageUploadPhotoAction(progress: Int32)
        case sendMessageUploadRoundAction(progress: Int32)
        case sendMessageUploadVideoAction(progress: Int32)
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
                case .sendMessageEmojiInteraction(let emoticon, let msgId, let interaction):
                    if boxed {
                        buffer.appendInt32(630664139)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    interaction.serialize(buffer, true)
                    break
                case .sendMessageEmojiInteractionSeen(let emoticon):
                    if boxed {
                        buffer.appendInt32(-1234857938)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
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
                case .sendMessageHistoryImportAction(let progress):
                    if boxed {
                        buffer.appendInt32(-606432698)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
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
                case .sendMessageTextDraftAction(let randomId, let text):
                    if boxed {
                        buffer.appendInt32(929929052)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    text.serialize(buffer, true)
                    break
                case .sendMessageTypingAction:
                    if boxed {
                        buffer.appendInt32(381645902)
                    }
                    
                    break
                case .sendMessageUploadAudioAction(let progress):
                    if boxed {
                        buffer.appendInt32(-212740181)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadDocumentAction(let progress):
                    if boxed {
                        buffer.appendInt32(-1441998364)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadPhotoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-774682074)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadRoundAction(let progress):
                    if boxed {
                        buffer.appendInt32(608050278)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
                    break
                case .sendMessageUploadVideoAction(let progress):
                    if boxed {
                        buffer.appendInt32(-378127636)
                    }
                    serializeInt32(progress, buffer: buffer, boxed: false)
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
                case .sendMessageEmojiInteraction(let emoticon, let msgId, let interaction):
                return ("sendMessageEmojiInteraction", [("emoticon", emoticon as Any), ("msgId", msgId as Any), ("interaction", interaction as Any)])
                case .sendMessageEmojiInteractionSeen(let emoticon):
                return ("sendMessageEmojiInteractionSeen", [("emoticon", emoticon as Any)])
                case .sendMessageGamePlayAction:
                return ("sendMessageGamePlayAction", [])
                case .sendMessageGeoLocationAction:
                return ("sendMessageGeoLocationAction", [])
                case .sendMessageHistoryImportAction(let progress):
                return ("sendMessageHistoryImportAction", [("progress", progress as Any)])
                case .sendMessageRecordAudioAction:
                return ("sendMessageRecordAudioAction", [])
                case .sendMessageRecordRoundAction:
                return ("sendMessageRecordRoundAction", [])
                case .sendMessageRecordVideoAction:
                return ("sendMessageRecordVideoAction", [])
                case .sendMessageTextDraftAction(let randomId, let text):
                return ("sendMessageTextDraftAction", [("randomId", randomId as Any), ("text", text as Any)])
                case .sendMessageTypingAction:
                return ("sendMessageTypingAction", [])
                case .sendMessageUploadAudioAction(let progress):
                return ("sendMessageUploadAudioAction", [("progress", progress as Any)])
                case .sendMessageUploadDocumentAction(let progress):
                return ("sendMessageUploadDocumentAction", [("progress", progress as Any)])
                case .sendMessageUploadPhotoAction(let progress):
                return ("sendMessageUploadPhotoAction", [("progress", progress as Any)])
                case .sendMessageUploadRoundAction(let progress):
                return ("sendMessageUploadRoundAction", [("progress", progress as Any)])
                case .sendMessageUploadVideoAction(let progress):
                return ("sendMessageUploadVideoAction", [("progress", progress as Any)])
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
                return Api.SendMessageAction.sendMessageEmojiInteraction(emoticon: _1!, msgId: _2!, interaction: _3!)
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
                return Api.SendMessageAction.sendMessageEmojiInteractionSeen(emoticon: _1!)
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
                return Api.SendMessageAction.sendMessageHistoryImportAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageTextDraftAction(randomId: _1!, text: _2!)
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
                return Api.SendMessageAction.sendMessageUploadAudioAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadDocumentAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadPhotoAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadRoundAction(progress: _1!)
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
                return Api.SendMessageAction.sendMessageUploadVideoAction(progress: _1!)
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
