
fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[-1255641564] = { return parseString($0) }
    dict[528568095] = { return SecretApi8.DecryptedMessage.parse_decryptedMessage($0) }
    dict[-1438109059] = { return SecretApi8.DecryptedMessage.parse_decryptedMessageService($0) }
    dict[144661578] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaEmpty($0) }
    dict[846826124] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaPhoto($0) }
    dict[1290694387] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaVideo($0) }
    dict[893913689] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaGeoPoint($0) }
    dict[1485441687] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaContact($0) }
    dict[-1332395189] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaDocument($0) }
    dict[1619031439] = { return SecretApi8.DecryptedMessageMedia.parse_decryptedMessageMediaAudio($0) }
    dict[-1586283796] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionSetMessageTTL($0) }
    dict[206520510] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionReadMessages($0) }
    dict[1700872964] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionDeleteMessages($0) }
    dict[-1967000459] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionScreenshotMessages($0) }
    dict[1729750108] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionFlushHistory($0) }
    dict[-217806717] = { return SecretApi8.DecryptedMessageAction.parse_decryptedMessageActionNotifyLayer($0) }
    return dict
}()

public struct SecretApi8 {
    public static func parse(_ buffer: Buffer) -> Any? {
        let reader = BufferReader(buffer)
        if let signature = reader.readInt32() {
            return parse(reader, signature: signature)
        }
        return nil
    }
    
        fileprivate static func parse(_ reader: BufferReader, signature: Int32) -> Any? {
            if let parser = parsers[signature] {
                return parser(reader)
            }
            else {
                telegramApiLog("Type constructor \(String(signature, radix: 16, uppercase: false)) not found")
                return nil
            }
        }
        
        fileprivate static func parseVector<T>(_ reader: BufferReader, elementSignature: Int32, elementType: T.Type) -> [T]? {
        if let count = reader.readInt32() {
            var array = [T]()
            var i: Int32 = 0
            while i < count {
                var signature = elementSignature
                if elementSignature == 0 {
                    if let unboxedSignature = reader.readInt32() {
                        signature = unboxedSignature
                    }
                    else {
                        return nil
                    }
                }
                if let item = SecretApi8.parse(reader, signature: signature) as? T {
                    array.append(item)
                }
                else {
                    return nil
                }
                i += 1
            }
            return array
        }
        return nil
    }
    
    public static func serializeObject(_ object: Any, buffer: Buffer, boxed: Swift.Bool) {
        switch object {
            case let _1 as SecretApi8.DecryptedMessage:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi8.DecryptedMessageMedia:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi8.DecryptedMessageAction:
                _1.serialize(buffer, boxed)
            default:
                break
        }
    }

    public enum DecryptedMessage {
        case decryptedMessage(randomId: Int64, randomBytes: Buffer, message: String, media: SecretApi8.DecryptedMessageMedia)
        case decryptedMessageService(randomId: Int64, randomBytes: Buffer, action: SecretApi8.DecryptedMessageAction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessage(let randomId, let randomBytes, let message, let media):
                    if boxed {
                        buffer.appendInt32(528568095)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(randomBytes, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    break
                case .decryptedMessageService(let randomId, let randomBytes, let action):
                    if boxed {
                        buffer.appendInt32(-1438109059)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeBytes(randomBytes, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
    }
    }
    
        fileprivate static func parse_decryptedMessage(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: SecretApi8.DecryptedMessageMedia?
            if let signature = reader.readInt32() {
                _4 = SecretApi8.parse(reader, signature: signature) as? SecretApi8.DecryptedMessageMedia
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi8.DecryptedMessage.decryptedMessage(randomId: _1!, randomBytes: _2!, message: _3!, media: _4!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageService(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: SecretApi8.DecryptedMessageAction?
            if let signature = reader.readInt32() {
                _3 = SecretApi8.parse(reader, signature: signature) as? SecretApi8.DecryptedMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return SecretApi8.DecryptedMessage.decryptedMessageService(randomId: _1!, randomBytes: _2!, action: _3!)
            }
            else {
                return nil
            }
        }
    
    }

    public enum DecryptedMessageMedia {
        case decryptedMessageMediaEmpty
        case decryptedMessageMediaPhoto(thumb: Buffer, thumbW: Int32, thumbH: Int32, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaVideo(thumb: Buffer, thumbW: Int32, thumbH: Int32, duration: Int32, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaGeoPoint(lat: Double, long: Double)
        case decryptedMessageMediaContact(phoneNumber: String, firstName: String, lastName: String, userId: Int32)
        case decryptedMessageMediaDocument(thumb: Buffer, thumbW: Int32, thumbH: Int32, fileName: String, mimeType: String, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaAudio(duration: Int32, size: Int32, key: Buffer, iv: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessageMediaEmpty:
                    if boxed {
                        buffer.appendInt32(144661578)
                    }
                    
                    break
                case .decryptedMessageMediaPhoto(let thumb, let thumbW, let thumbH, let w, let h, let size, let key, let iv):
                    if boxed {
                        buffer.appendInt32(846826124)
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaVideo(let thumb, let thumbW, let thumbH, let duration, let w, let h, let size, let key, let iv):
                    if boxed {
                        buffer.appendInt32(1290694387)
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaGeoPoint(let lat, let long):
                    if boxed {
                        buffer.appendInt32(893913689)
                    }
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaContact(let phoneNumber, let firstName, let lastName, let userId):
                    if boxed {
                        buffer.appendInt32(1485441687)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeInt32(userId, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaDocument(let thumb, let thumbW, let thumbH, let fileName, let mimeType, let size, let key, let iv):
                    if boxed {
                        buffer.appendInt32(-1332395189)
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeString(fileName, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaAudio(let duration, let size, let key, let iv):
                    if boxed {
                        buffer.appendInt32(1619031439)
                    }
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    break
    }
    }
    
        fileprivate static func parse_decryptedMessageMediaEmpty(_ reader: BufferReader) -> DecryptedMessageMedia? {
            return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaEmpty
        }
        fileprivate static func parse_decryptedMessageMediaPhoto(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: Buffer?
            _8 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: _1!, thumbW: _2!, thumbH: _3!, w: _4!, h: _5!, size: _6!, key: _7!, iv: _8!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaVideo(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Buffer?
            _8 = parseBytes(reader)
            var _9: Buffer?
            _9 = parseBytes(reader)
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
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaVideo(thumb: _1!, thumbW: _2!, thumbH: _3!, duration: _4!, w: _5!, h: _6!, size: _7!, key: _8!, iv: _9!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaGeoPoint(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaGeoPoint(lat: _1!, long: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaContact(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, userId: _4!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaDocument(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: Buffer?
            _8 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: _1!, thumbW: _2!, thumbH: _3!, fileName: _4!, mimeType: _5!, size: _6!, key: _7!, iv: _8!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaAudio(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi8.DecryptedMessageMedia.decryptedMessageMediaAudio(duration: _1!, size: _2!, key: _3!, iv: _4!)
            }
            else {
                return nil
            }
        }
    
    }

    public enum DecryptedMessageAction {
        case decryptedMessageActionSetMessageTTL(ttlSeconds: Int32)
        case decryptedMessageActionReadMessages(randomIds: [Int64])
        case decryptedMessageActionDeleteMessages(randomIds: [Int64])
        case decryptedMessageActionScreenshotMessages(randomIds: [Int64])
        case decryptedMessageActionFlushHistory
        case decryptedMessageActionNotifyLayer(layer: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessageActionSetMessageTTL(let ttlSeconds):
                    if boxed {
                        buffer.appendInt32(-1586283796)
                    }
                    serializeInt32(ttlSeconds, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionReadMessages(let randomIds):
                    if boxed {
                        buffer.appendInt32(206520510)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(randomIds.count))
                    for item in randomIds {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .decryptedMessageActionDeleteMessages(let randomIds):
                    if boxed {
                        buffer.appendInt32(1700872964)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(randomIds.count))
                    for item in randomIds {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .decryptedMessageActionScreenshotMessages(let randomIds):
                    if boxed {
                        buffer.appendInt32(-1967000459)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(randomIds.count))
                    for item in randomIds {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .decryptedMessageActionFlushHistory:
                    if boxed {
                        buffer.appendInt32(1729750108)
                    }
                    
                    break
                case .decryptedMessageActionNotifyLayer(let layer):
                    if boxed {
                        buffer.appendInt32(-217806717)
                    }
                    serializeInt32(layer, buffer: buffer, boxed: false)
                    break
    }
    }
    
        fileprivate static func parse_decryptedMessageActionSetMessageTTL(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi8.DecryptedMessageAction.decryptedMessageActionSetMessageTTL(ttlSeconds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionReadMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi8.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi8.DecryptedMessageAction.decryptedMessageActionReadMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionDeleteMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi8.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi8.DecryptedMessageAction.decryptedMessageActionDeleteMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionScreenshotMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi8.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi8.DecryptedMessageAction.decryptedMessageActionScreenshotMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionFlushHistory(_ reader: BufferReader) -> DecryptedMessageAction? {
            return SecretApi8.DecryptedMessageAction.decryptedMessageActionFlushHistory
        }
        fileprivate static func parse_decryptedMessageActionNotifyLayer(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi8.DecryptedMessageAction.decryptedMessageActionNotifyLayer(layer: _1!)
            }
            else {
                return nil
            }
        }
    
    }

    public struct functions {
        
    }

}
