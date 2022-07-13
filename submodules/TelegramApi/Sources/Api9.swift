public extension Api {
    enum InputPrivacyRule: TypeConstructorDescription {
        case inputPrivacyValueAllowAll
        case inputPrivacyValueAllowChatParticipants(chats: [Int64])
        case inputPrivacyValueAllowContacts
        case inputPrivacyValueAllowUsers(users: [Api.InputUser])
        case inputPrivacyValueDisallowAll
        case inputPrivacyValueDisallowChatParticipants(chats: [Int64])
        case inputPrivacyValueDisallowContacts
        case inputPrivacyValueDisallowUsers(users: [Api.InputUser])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPrivacyValueAllowAll:
                    if boxed {
                        buffer.appendInt32(407582158)
                    }
                    
                    break
                case .inputPrivacyValueAllowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-2079962673)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .inputPrivacyValueAllowContacts:
                    if boxed {
                        buffer.appendInt32(218751099)
                    }
                    
                    break
                case .inputPrivacyValueAllowUsers(let users):
                    if boxed {
                        buffer.appendInt32(320652927)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .inputPrivacyValueDisallowAll:
                    if boxed {
                        buffer.appendInt32(-697604407)
                    }
                    
                    break
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                    if boxed {
                        buffer.appendInt32(-380694650)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .inputPrivacyValueDisallowContacts:
                    if boxed {
                        buffer.appendInt32(195371015)
                    }
                    
                    break
                case .inputPrivacyValueDisallowUsers(let users):
                    if boxed {
                        buffer.appendInt32(-1877932953)
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
                case .inputPrivacyValueAllowAll:
                return ("inputPrivacyValueAllowAll", [])
                case .inputPrivacyValueAllowChatParticipants(let chats):
                return ("inputPrivacyValueAllowChatParticipants", [("chats", String(describing: chats))])
                case .inputPrivacyValueAllowContacts:
                return ("inputPrivacyValueAllowContacts", [])
                case .inputPrivacyValueAllowUsers(let users):
                return ("inputPrivacyValueAllowUsers", [("users", String(describing: users))])
                case .inputPrivacyValueDisallowAll:
                return ("inputPrivacyValueDisallowAll", [])
                case .inputPrivacyValueDisallowChatParticipants(let chats):
                return ("inputPrivacyValueDisallowChatParticipants", [("chats", String(describing: chats))])
                case .inputPrivacyValueDisallowContacts:
                return ("inputPrivacyValueDisallowContacts", [])
                case .inputPrivacyValueDisallowUsers(let users):
                return ("inputPrivacyValueDisallowUsers", [("users", String(describing: users))])
    }
    }
    
        public static func parse_inputPrivacyValueAllowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowAll
        }
        public static func parse_inputPrivacyValueAllowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueAllowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueAllowContacts
        }
        public static func parse_inputPrivacyValueAllowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueAllowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowAll(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowAll
        }
        public static func parse_inputPrivacyValueDisallowChatParticipants(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowChatParticipants(chats: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputPrivacyValueDisallowContacts(_ reader: BufferReader) -> InputPrivacyRule? {
            return Api.InputPrivacyRule.inputPrivacyValueDisallowContacts
        }
        public static func parse_inputPrivacyValueDisallowUsers(_ reader: BufferReader) -> InputPrivacyRule? {
            var _1: [Api.InputUser]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputPrivacyRule.inputPrivacyValueDisallowUsers(users: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputSecureFile: TypeConstructorDescription {
        case inputSecureFile(id: Int64, accessHash: Int64)
        case inputSecureFileUploaded(id: Int64, parts: Int32, md5Checksum: String, fileHash: Buffer, secret: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureFile(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1399317950)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                    if boxed {
                        buffer.appendInt32(859091184)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(parts, buffer: buffer, boxed: false)
                    serializeString(md5Checksum, buffer: buffer, boxed: false)
                    serializeBytes(fileHash, buffer: buffer, boxed: false)
                    serializeBytes(secret, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureFile(let id, let accessHash):
                return ("inputSecureFile", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputSecureFileUploaded(let id, let parts, let md5Checksum, let fileHash, let secret):
                return ("inputSecureFileUploaded", [("id", String(describing: id)), ("parts", String(describing: parts)), ("md5Checksum", String(describing: md5Checksum)), ("fileHash", String(describing: fileHash)), ("secret", String(describing: secret))])
    }
    }
    
        public static func parse_inputSecureFile(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputSecureFile.inputSecureFile(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileUploaded(_ reader: BufferReader) -> InputSecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSecureFile.inputSecureFileUploaded(id: _1!, parts: _2!, md5Checksum: _3!, fileHash: _4!, secret: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputSecureValue: TypeConstructorDescription {
        case inputSecureValue(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.InputSecureFile?, reverseSide: Api.InputSecureFile?, selfie: Api.InputSecureFile?, translation: [Api.InputSecureFile]?, files: [Api.InputSecureFile]?, plainData: Api.SecurePlainData?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                    if boxed {
                        buffer.appendInt32(-618540889)
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
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSecureValue(let flags, let type, let data, let frontSide, let reverseSide, let selfie, let translation, let files, let plainData):
                return ("inputSecureValue", [("flags", String(describing: flags)), ("type", String(describing: type)), ("data", String(describing: data)), ("frontSide", String(describing: frontSide)), ("reverseSide", String(describing: reverseSide)), ("selfie", String(describing: selfie)), ("translation", String(describing: translation)), ("files", String(describing: files)), ("plainData", String(describing: plainData))])
    }
    }
    
        public static func parse_inputSecureValue(_ reader: BufferReader) -> InputSecureValue? {
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
            var _4: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _5: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _6: Api.InputSecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputSecureFile
            } }
            var _7: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _8: [Api.InputSecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputSecureFile.self)
            } }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputSecureValue.inputSecureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputSingleMedia: TypeConstructorDescription {
        case inputSingleMedia(flags: Int32, media: Api.InputMedia, randomId: Int64, message: String, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                    if boxed {
                        buffer.appendInt32(482797855)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputSingleMedia(let flags, let media, let randomId, let message, let entities):
                return ("inputSingleMedia", [("flags", String(describing: flags)), ("media", String(describing: media)), ("randomId", String(describing: randomId)), ("message", String(describing: message)), ("entities", String(describing: entities))])
    }
    }
    
        public static func parse_inputSingleMedia(_ reader: BufferReader) -> InputSingleMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputMedia?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputMedia
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputSingleMedia.inputSingleMedia(flags: _1!, media: _2!, randomId: _3!, message: _4!, entities: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStickerSet: TypeConstructorDescription {
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(emoticon: String)
        case inputStickerSetEmpty
        case inputStickerSetID(id: Int64, accessHash: Int64)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetAnimatedEmoji:
                    if boxed {
                        buffer.appendInt32(42402760)
                    }
                    
                    break
                case .inputStickerSetAnimatedEmojiAnimations:
                    if boxed {
                        buffer.appendInt32(215889721)
                    }
                    
                    break
                case .inputStickerSetDice(let emoticon):
                    if boxed {
                        buffer.appendInt32(-427863538)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetEmpty:
                    if boxed {
                        buffer.appendInt32(-4838507)
                    }
                    
                    break
                case .inputStickerSetID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1645763991)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetPremiumGifts:
                    if boxed {
                        buffer.appendInt32(-930399486)
                    }
                    
                    break
                case .inputStickerSetShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2044933984)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetAnimatedEmoji:
                return ("inputStickerSetAnimatedEmoji", [])
                case .inputStickerSetAnimatedEmojiAnimations:
                return ("inputStickerSetAnimatedEmojiAnimations", [])
                case .inputStickerSetDice(let emoticon):
                return ("inputStickerSetDice", [("emoticon", String(describing: emoticon))])
                case .inputStickerSetEmpty:
                return ("inputStickerSetEmpty", [])
                case .inputStickerSetID(let id, let accessHash):
                return ("inputStickerSetID", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputStickerSetPremiumGifts:
                return ("inputStickerSetPremiumGifts", [])
                case .inputStickerSetShortName(let shortName):
                return ("inputStickerSetShortName", [("shortName", String(describing: shortName))])
    }
    }
    
        public static func parse_inputStickerSetAnimatedEmoji(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetAnimatedEmoji
        }
        public static func parse_inputStickerSetAnimatedEmojiAnimations(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetAnimatedEmojiAnimations
        }
        public static func parse_inputStickerSetDice(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickerSet.inputStickerSetDice(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetEmpty
        }
        public static func parse_inputStickerSetID(_ reader: BufferReader) -> InputStickerSet? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputStickerSet.inputStickerSetID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetPremiumGifts(_ reader: BufferReader) -> InputStickerSet? {
            return Api.InputStickerSet.inputStickerSetPremiumGifts
        }
        public static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickerSet.inputStickerSetShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription {
        case inputStickerSetItem(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords):
                    if boxed {
                        buffer.appendInt32(-6249322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    serializeString(emoji, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickerSetItem(let flags, let document, let emoji, let maskCoords):
                return ("inputStickerSetItem", [("flags", String(describing: flags)), ("document", String(describing: document)), ("emoji", String(describing: emoji)), ("maskCoords", String(describing: maskCoords))])
    }
    }
    
        public static func parse_inputStickerSetItem(_ reader: BufferReader) -> InputStickerSetItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputDocument?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.MaskCoords?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputStickerSetItem.inputStickerSetItem(flags: _1!, document: _2!, emoji: _3!, maskCoords: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription {
        case inputStickeredMediaDocument(id: Api.InputDocument)
        case inputStickeredMediaPhoto(id: Api.InputPhoto)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickeredMediaDocument(let id):
                    if boxed {
                        buffer.appendInt32(70813275)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputStickeredMediaPhoto(let id):
                    if boxed {
                        buffer.appendInt32(1251549527)
                    }
                    id.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStickeredMediaDocument(let id):
                return ("inputStickeredMediaDocument", [("id", String(describing: id))])
                case .inputStickeredMediaPhoto(let id):
                return ("inputStickeredMediaPhoto", [("id", String(describing: id))])
    }
    }
    
        public static func parse_inputStickeredMediaDocument(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputDocument?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaDocument(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickeredMediaPhoto(_ reader: BufferReader) -> InputStickeredMedia? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStickeredMedia.inputStickeredMediaPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputStorePaymentPurpose: TypeConstructorDescription {
        case inputStorePaymentGiftPremium(userId: Api.InputUser, currency: String, amount: Int64)
        case inputStorePaymentPremiumSubscription(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStorePaymentGiftPremium(let userId, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(1634697192)
                    }
                    userId.serialize(buffer, true)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
                case .inputStorePaymentPremiumSubscription(let flags):
                    if boxed {
                        buffer.appendInt32(-1502273946)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputStorePaymentGiftPremium(let userId, let currency, let amount):
                return ("inputStorePaymentGiftPremium", [("userId", String(describing: userId)), ("currency", String(describing: currency)), ("amount", String(describing: amount))])
                case .inputStorePaymentPremiumSubscription(let flags):
                return ("inputStorePaymentPremiumSubscription", [("flags", String(describing: flags))])
    }
    }
    
        public static func parse_inputStorePaymentGiftPremium(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputStorePaymentPurpose.inputStorePaymentGiftPremium(userId: _1!, currency: _2!, amount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputStorePaymentPremiumSubscription(_ reader: BufferReader) -> InputStorePaymentPurpose? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputStorePaymentPurpose.inputStorePaymentPremiumSubscription(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputTheme: TypeConstructorDescription {
        case inputTheme(id: Int64, accessHash: Int64)
        case inputThemeSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputTheme(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(1012306921)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputThemeSlug(let slug):
                    if boxed {
                        buffer.appendInt32(-175567375)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputTheme(let id, let accessHash):
                return ("inputTheme", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputThemeSlug(let slug):
                return ("inputThemeSlug", [("slug", String(describing: slug))])
    }
    }
    
        public static func parse_inputTheme(_ reader: BufferReader) -> InputTheme? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputTheme.inputTheme(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputThemeSlug(_ reader: BufferReader) -> InputTheme? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputTheme.inputThemeSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputThemeSettings: TypeConstructorDescription {
        case inputThemeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper, let wallpaperSettings):
                    if boxed {
                        buffer.appendInt32(-1881255857)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(outboxAccentColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messageColors!.count))
                    for item in messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaperSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputThemeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper, let wallpaperSettings):
                return ("inputThemeSettings", [("flags", String(describing: flags)), ("baseTheme", String(describing: baseTheme)), ("accentColor", String(describing: accentColor)), ("outboxAccentColor", String(describing: outboxAccentColor)), ("messageColors", String(describing: messageColors)), ("wallpaper", String(describing: wallpaper)), ("wallpaperSettings", String(describing: wallpaperSettings))])
    }
    }
    
        public static func parse_inputThemeSettings(_ reader: BufferReader) -> InputThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            var _6: Api.InputWallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputWallPaper
            } }
            var _7: Api.WallPaperSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputThemeSettings.inputThemeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6, wallpaperSettings: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputUser: TypeConstructorDescription {
        case inputUser(userId: Int64, accessHash: Int64)
        case inputUserEmpty
        case inputUserFromMessage(peer: Api.InputPeer, msgId: Int32, userId: Int64)
        case inputUserSelf
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputUser(let userId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-233744186)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputUserEmpty:
                    if boxed {
                        buffer.appendInt32(-1182234929)
                    }
                    
                    break
                case .inputUserFromMessage(let peer, let msgId, let userId):
                    if boxed {
                        buffer.appendInt32(497305826)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .inputUserSelf:
                    if boxed {
                        buffer.appendInt32(-138301121)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputUser(let userId, let accessHash):
                return ("inputUser", [("userId", String(describing: userId)), ("accessHash", String(describing: accessHash))])
                case .inputUserEmpty:
                return ("inputUserEmpty", [])
                case .inputUserFromMessage(let peer, let msgId, let userId):
                return ("inputUserFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("userId", String(describing: userId))])
                case .inputUserSelf:
                return ("inputUserSelf", [])
    }
    }
    
        public static func parse_inputUser(_ reader: BufferReader) -> InputUser? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputUser.inputUser(userId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserEmpty(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserEmpty
        }
        public static func parse_inputUserFromMessage(_ reader: BufferReader) -> InputUser? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputUser.inputUserFromMessage(peer: _1!, msgId: _2!, userId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputUserSelf(_ reader: BufferReader) -> InputUser? {
            return Api.InputUser.inputUserSelf
        }
    
    }
}
public extension Api {
    enum InputWallPaper: TypeConstructorDescription {
        case inputWallPaper(id: Int64, accessHash: Int64)
        case inputWallPaperNoFile(id: Int64)
        case inputWallPaperSlug(slug: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputWallPaper(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-433014407)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperNoFile(let id):
                    if boxed {
                        buffer.appendInt32(-1770371538)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .inputWallPaperSlug(let slug):
                    if boxed {
                        buffer.appendInt32(1913199744)
                    }
                    serializeString(slug, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputWallPaper(let id, let accessHash):
                return ("inputWallPaper", [("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputWallPaperNoFile(let id):
                return ("inputWallPaperNoFile", [("id", String(describing: id))])
                case .inputWallPaperSlug(let slug):
                return ("inputWallPaperSlug", [("slug", String(describing: slug))])
    }
    }
    
        public static func parse_inputWallPaper(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputWallPaper.inputWallPaper(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperNoFile(_ reader: BufferReader) -> InputWallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperNoFile(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputWallPaperSlug(_ reader: BufferReader) -> InputWallPaper? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputWallPaper.inputWallPaperSlug(slug: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
