
fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[-1255641564] = { return parseString($0) }
    dict[-1586283796] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionSetMessageTTL($0) }
    dict[206520510] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionReadMessages($0) }
    dict[1700872964] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionDeleteMessages($0) }
    dict[-1967000459] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionScreenshotMessages($0) }
    dict[1729750108] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionFlushHistory($0) }
    dict[-217806717] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionNotifyLayer($0) }
    dict[1360072880] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionResend($0) }
    dict[-204906213] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionRequestKey($0) }
    dict[1877046107] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionAcceptKey($0) }
    dict[-586814357] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionAbortKey($0) }
    dict[-332526693] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionCommitKey($0) }
    dict[-1473258141] = { return SecretApi144.DecryptedMessageAction.parse_decryptedMessageActionNoop($0) }
    dict[236446268] = { return SecretApi144.PhotoSize.parse_photoSizeEmpty($0) }
    dict[2009052699] = { return SecretApi144.PhotoSize.parse_photoSize($0) }
    dict[-374917894] = { return SecretApi144.PhotoSize.parse_photoCachedSize($0) }
    dict[2086234950] = { return SecretApi144.FileLocation.parse_fileLocationUnavailable($0) }
    dict[1406570614] = { return SecretApi144.FileLocation.parse_fileLocation($0) }
    dict[467867529] = { return SecretApi144.DecryptedMessageLayer.parse_decryptedMessageLayer($0) }
    dict[1930838368] = { return SecretApi144.DecryptedMessage.parse_decryptedMessageService($0) }
    dict[-1848883596] = { return SecretApi144.DecryptedMessage.parse_decryptedMessage($0) }
    dict[1815593308] = { return SecretApi144.DocumentAttribute.parse_documentAttributeImageSize($0) }
    dict[297109817] = { return SecretApi144.DocumentAttribute.parse_documentAttributeAnimated($0) }
    dict[358154344] = { return SecretApi144.DocumentAttribute.parse_documentAttributeFilename($0) }
    dict[978674434] = { return SecretApi144.DocumentAttribute.parse_documentAttributeSticker($0) }
    dict[-1739392570] = { return SecretApi144.DocumentAttribute.parse_documentAttributeAudio($0) }
    dict[250621158] = { return SecretApi144.DocumentAttribute.parse_documentAttributeVideo($0) }
    dict[-2044933984] = { return SecretApi144.InputStickerSet.parse_inputStickerSetShortName($0) }
    dict[-4838507] = { return SecretApi144.InputStickerSet.parse_inputStickerSetEmpty($0) }
    dict[-1148011883] = { return SecretApi144.MessageEntity.parse_messageEntityUnknown($0) }
    dict[-100378723] = { return SecretApi144.MessageEntity.parse_messageEntityMention($0) }
    dict[1868782349] = { return SecretApi144.MessageEntity.parse_messageEntityHashtag($0) }
    dict[1827637959] = { return SecretApi144.MessageEntity.parse_messageEntityBotCommand($0) }
    dict[1859134776] = { return SecretApi144.MessageEntity.parse_messageEntityUrl($0) }
    dict[1692693954] = { return SecretApi144.MessageEntity.parse_messageEntityEmail($0) }
    dict[-1117713463] = { return SecretApi144.MessageEntity.parse_messageEntityBold($0) }
    dict[-2106619040] = { return SecretApi144.MessageEntity.parse_messageEntityItalic($0) }
    dict[681706865] = { return SecretApi144.MessageEntity.parse_messageEntityCode($0) }
    dict[1938967520] = { return SecretApi144.MessageEntity.parse_messageEntityPre($0) }
    dict[1990644519] = { return SecretApi144.MessageEntity.parse_messageEntityTextUrl($0) }
    dict[-1672577397] = { return SecretApi144.MessageEntity.parse_messageEntityUnderline($0) }
    dict[-1090087980] = { return SecretApi144.MessageEntity.parse_messageEntityStrike($0) }
    dict[34469328] = { return SecretApi144.MessageEntity.parse_messageEntityBlockquote($0) }
    dict[Int32(bitPattern: 0xc8cf05f8 as UInt32)] = { return SecretApi144.MessageEntity.parse_messageEntityCustomEmoji($0) }
    dict[Int32(bitPattern: 0x32ca960f as UInt32)] = { return SecretApi144.MessageEntity.parse_messageEntitySpoiler($0) }
    dict[144661578] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaEmpty($0) }
    dict[893913689] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaGeoPoint($0) }
    dict[1485441687] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaContact($0) }
    dict[1474341323] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaAudio($0) }
    dict[-90853155] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaExternalDocument($0) }
    dict[-235238024] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaPhoto($0) }
    dict[Int32(bitPattern: 0x6abd9782 as UInt32)] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaDocument($0) }
    dict[-1760785394] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaVideo($0) }
    dict[-1978796689] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaVenue($0) }
    dict[-452652584] = { return SecretApi144.DecryptedMessageMedia.parse_decryptedMessageMediaWebPage($0) }
    return dict
}()

public struct SecretApi144 {
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
                if let item = SecretApi144.parse(reader, signature: signature) as? T {
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
            case let _1 as SecretApi144.DecryptedMessageAction:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.PhotoSize:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.FileLocation:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.DecryptedMessageLayer:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.DecryptedMessage:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.DocumentAttribute:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.InputStickerSet:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.MessageEntity:
                _1.serialize(buffer, boxed)
            case let _1 as SecretApi144.DecryptedMessageMedia:
                _1.serialize(buffer, boxed)
            default:
                break
        }
    }

    public enum DecryptedMessageAction {
        case decryptedMessageActionSetMessageTTL(ttlSeconds: Int32)
        case decryptedMessageActionReadMessages(randomIds: [Int64])
        case decryptedMessageActionDeleteMessages(randomIds: [Int64])
        case decryptedMessageActionScreenshotMessages(randomIds: [Int64])
        case decryptedMessageActionFlushHistory
        case decryptedMessageActionNotifyLayer(layer: Int32)
        case decryptedMessageActionResend(startSeqNo: Int32, endSeqNo: Int32)
        case decryptedMessageActionRequestKey(exchangeId: Int64, gA: Buffer)
        case decryptedMessageActionAcceptKey(exchangeId: Int64, gB: Buffer, keyFingerprint: Int64)
        case decryptedMessageActionAbortKey(exchangeId: Int64)
        case decryptedMessageActionCommitKey(exchangeId: Int64, keyFingerprint: Int64)
        case decryptedMessageActionNoop
    
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
                case .decryptedMessageActionResend(let startSeqNo, let endSeqNo):
                    if boxed {
                        buffer.appendInt32(1360072880)
                    }
                    serializeInt32(startSeqNo, buffer: buffer, boxed: false)
                    serializeInt32(endSeqNo, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionRequestKey(let exchangeId, let gA):
                    if boxed {
                        buffer.appendInt32(-204906213)
                    }
                    serializeInt64(exchangeId, buffer: buffer, boxed: false)
                    serializeBytes(gA, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionAcceptKey(let exchangeId, let gB, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(1877046107)
                    }
                    serializeInt64(exchangeId, buffer: buffer, boxed: false)
                    serializeBytes(gB, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionAbortKey(let exchangeId):
                    if boxed {
                        buffer.appendInt32(-586814357)
                    }
                    serializeInt64(exchangeId, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionCommitKey(let exchangeId, let keyFingerprint):
                    if boxed {
                        buffer.appendInt32(-332526693)
                    }
                    serializeInt64(exchangeId, buffer: buffer, boxed: false)
                    serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageActionNoop:
                    if boxed {
                        buffer.appendInt32(-1473258141)
                    }
                    
                    break
    }
    }
        fileprivate static func parse_decryptedMessageActionSetMessageTTL(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionSetMessageTTL(ttlSeconds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionReadMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi144.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionReadMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionDeleteMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi144.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionDeleteMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionScreenshotMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi144.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionScreenshotMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionFlushHistory(_ reader: BufferReader) -> DecryptedMessageAction? {
            return SecretApi144.DecryptedMessageAction.decryptedMessageActionFlushHistory
        }
        fileprivate static func parse_decryptedMessageActionNotifyLayer(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionNotifyLayer(layer: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionResend(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionResend(startSeqNo: _1!, endSeqNo: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionRequestKey(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionRequestKey(exchangeId: _1!, gA: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionAcceptKey(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionAcceptKey(exchangeId: _1!, gB: _2!, keyFingerprint: _3!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionAbortKey(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionAbortKey(exchangeId: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionCommitKey(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DecryptedMessageAction.decryptedMessageActionCommitKey(exchangeId: _1!, keyFingerprint: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionNoop(_ reader: BufferReader) -> DecryptedMessageAction? {
            return SecretApi144.DecryptedMessageAction.decryptedMessageActionNoop
        }
    
    
    }

    public enum PhotoSize {
        case photoSizeEmpty(type: String)
        case photoSize(type: String, location: SecretApi144.FileLocation, w: Int32, h: Int32, size: Int32)
        case photoCachedSize(type: String, location: SecretApi144.FileLocation, w: Int32, h: Int32, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photoSizeEmpty(let type):
                    if boxed {
                        buffer.appendInt32(236446268)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    break
                case .photoSize(let type, let location, let w, let h, let size):
                    if boxed {
                        buffer.appendInt32(2009052699)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    break
                case .photoCachedSize(let type, let location, let w, let h, let bytes):
                    if boxed {
                        buffer.appendInt32(-374917894)
                    }
                    serializeString(type, buffer: buffer, boxed: false)
                    location.serialize(buffer, true)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
        fileprivate static func parse_photoSizeEmpty(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.PhotoSize.photoSizeEmpty(type: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_photoSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: SecretApi144.FileLocation?
            if let signature = reader.readInt32() {
                _2 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.FileLocation
            }
            var _3: Int32?
            _3 = reader.readInt32()
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
                return SecretApi144.PhotoSize.photoSize(type: _1!, location: _2!, w: _3!, h: _4!, size: _5!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_photoCachedSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: SecretApi144.FileLocation?
            if let signature = reader.readInt32() {
                _2 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.FileLocation
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return SecretApi144.PhotoSize.photoCachedSize(type: _1!, location: _2!, w: _3!, h: _4!, bytes: _5!)
            }
            else {
                return nil
            }
        }
    
    
    }

    public enum FileLocation {
        case fileLocationUnavailable(volumeId: Int64, localId: Int32, secret: Int64)
        case fileLocation(dcId: Int32, volumeId: Int64, localId: Int32, secret: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .fileLocationUnavailable(let volumeId, let localId, let secret):
                    if boxed {
                        buffer.appendInt32(2086234950)
                    }
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    break
                case .fileLocation(let dcId, let volumeId, let localId, let secret):
                    if boxed {
                        buffer.appendInt32(1406570614)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt64(volumeId, buffer: buffer, boxed: false)
                    serializeInt32(localId, buffer: buffer, boxed: false)
                    serializeInt64(secret, buffer: buffer, boxed: false)
                    break
    }
    }
        fileprivate static func parse_fileLocationUnavailable(_ reader: BufferReader) -> FileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return SecretApi144.FileLocation.fileLocationUnavailable(volumeId: _1!, localId: _2!, secret: _3!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_fileLocation(_ reader: BufferReader) -> FileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi144.FileLocation.fileLocation(dcId: _1!, volumeId: _2!, localId: _3!, secret: _4!)
            }
            else {
                return nil
            }
        }
    
    
    }

    public enum DecryptedMessageLayer {
        case decryptedMessageLayer(randomBytes: Buffer, layer: Int32, inSeqNo: Int32, outSeqNo: Int32, message: SecretApi144.DecryptedMessage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessageLayer(let randomBytes, let layer, let inSeqNo, let outSeqNo, let message):
                    if boxed {
                        buffer.appendInt32(467867529)
                    }
                    serializeBytes(randomBytes, buffer: buffer, boxed: false)
                    serializeInt32(layer, buffer: buffer, boxed: false)
                    serializeInt32(inSeqNo, buffer: buffer, boxed: false)
                    serializeInt32(outSeqNo, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    break
    }
    }
        fileprivate static func parse_decryptedMessageLayer(_ reader: BufferReader) -> DecryptedMessageLayer? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: SecretApi144.DecryptedMessage?
            if let signature = reader.readInt32() {
                _5 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.DecryptedMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return SecretApi144.DecryptedMessageLayer.decryptedMessageLayer(randomBytes: _1!, layer: _2!, inSeqNo: _3!, outSeqNo: _4!, message: _5!)
            }
            else {
                return nil
            }
        }
    
    
    }

    public enum DecryptedMessage {
        case decryptedMessageService(randomId: Int64, action: SecretApi144.DecryptedMessageAction)
        case decryptedMessage(flags: Int32, randomId: Int64, ttl: Int32, message: String, media: SecretApi144.DecryptedMessageMedia?, entities: [SecretApi144.MessageEntity]?, viaBotName: String?, replyToRandomId: Int64?, groupedId: Int64?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessageService(let randomId, let action):
                    if boxed {
                        buffer.appendInt32(1930838368)
                    }
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .decryptedMessage(let flags, let randomId, let ttl, let message, let media, let entities, let viaBotName, let replyToRandomId, let groupedId):
                    if boxed {
                        buffer.appendInt32(-1848883596)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    serializeInt32(ttl, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(viaBotName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(replyToRandomId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt64(groupedId!, buffer: buffer, boxed: false)}
                    break
    }
    }
        fileprivate static func parse_decryptedMessageService(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: SecretApi144.DecryptedMessageAction?
            if let signature = reader.readInt32() {
                _2 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.DecryptedMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DecryptedMessage.decryptedMessageService(randomId: _1!, action: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessage(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: SecretApi144.DecryptedMessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _5 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.DecryptedMessageMedia
            } }
            var _6: [SecretApi144.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _6 = SecretApi144.parseVector(reader, elementSignature: 0, elementType: SecretApi144.MessageEntity.self)
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 11) != 0 {_7 = parseString(reader) }
            var _8: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_8 = reader.readInt64() }
            var _9: Int64?
            if Int(_1!) & Int(1 << 17) != 0 {_9 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 9) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 7) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 17) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return SecretApi144.DecryptedMessage.decryptedMessage(flags: _1!, randomId: _2!, ttl: _3!, message: _4!, media: _5, entities: _6, viaBotName: _7, replyToRandomId: _8, groupedId: _9)
            }
            else {
                return nil
            }
        }
    
    
    }

    public enum DocumentAttribute {
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeAnimated
        case documentAttributeFilename(fileName: String)
        case documentAttributeSticker(alt: String, stickerset: SecretApi144.InputStickerSet)
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeVideo(flags: Int32, duration: Int32, w: Int32, h: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .documentAttributeImageSize(let w, let h):
                    if boxed {
                        buffer.appendInt32(1815593308)
                    }
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
                case .documentAttributeAnimated:
                    if boxed {
                        buffer.appendInt32(297109817)
                    }
                    
                    break
                case .documentAttributeFilename(let fileName):
                    if boxed {
                        buffer.appendInt32(358154344)
                    }
                    serializeString(fileName, buffer: buffer, boxed: false)
                    break
                case .documentAttributeSticker(let alt, let stickerset):
                    if boxed {
                        buffer.appendInt32(978674434)
                    }
                    serializeString(alt, buffer: buffer, boxed: false)
                    stickerset.serialize(buffer, true)
                    break
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                    if boxed {
                        buffer.appendInt32(-1739392570)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(performer!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(waveform!, buffer: buffer, boxed: false)}
                    break
                case .documentAttributeVideo(let flags, let duration, let w, let h):
                    if boxed {
                        buffer.appendInt32(250621158)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    break
    }
    }
        fileprivate static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DocumentAttribute.documentAttributeImageSize(w: _1!, h: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return SecretApi144.DocumentAttribute.documentAttributeAnimated
        }
        fileprivate static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DocumentAttribute.documentAttributeFilename(fileName: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            var _2: SecretApi144.InputStickerSet?
            if let signature = reader.readInt32() {
                _2 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.InputStickerSet
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DocumentAttribute.documentAttributeSticker(alt: _1!, stickerset: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeAudio(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return SecretApi144.DocumentAttribute.documentAttributeAudio(flags: _1!, duration: _2!, title: _3, performer: _4, waveform: _5)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeVideo(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi144.DocumentAttribute.documentAttributeVideo(flags: _1!, duration: _2!, w: _3!, h: _4!)
            }
            else {
                return nil
            }
        }
    
    
    }

    public enum InputStickerSet {
        case inputStickerSetShortName(shortName: String)
        case inputStickerSetEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputStickerSetShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2044933984)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
                case .inputStickerSetEmpty:
                    if boxed {
                        buffer.appendInt32(-4838507)
                    }
                    
                    break
    }
    }
        fileprivate static func parse_inputStickerSetShortName(_ reader: BufferReader) -> InputStickerSet? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.InputStickerSet.inputStickerSetShortName(shortName: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            return SecretApi144.InputStickerSet.inputStickerSetEmpty
        }
    
    
    }

    public enum MessageEntity {
        case messageEntityUnknown(offset: Int32, length: Int32)
        case messageEntityMention(offset: Int32, length: Int32)
        case messageEntityHashtag(offset: Int32, length: Int32)
        case messageEntityBotCommand(offset: Int32, length: Int32)
        case messageEntityUrl(offset: Int32, length: Int32)
        case messageEntityEmail(offset: Int32, length: Int32)
        case messageEntityBold(offset: Int32, length: Int32)
        case messageEntityItalic(offset: Int32, length: Int32)
        case messageEntityCode(offset: Int32, length: Int32)
        case messageEntityPre(offset: Int32, length: Int32, language: String)
        case messageEntityTextUrl(offset: Int32, length: Int32, url: String)
        case messageEntityUnderline(offset: Int32, length: Int32)
        case messageEntityStrike(offset: Int32, length: Int32)
        case messageEntityBlockquote(offset: Int32, length: Int32)
        case messageEntityCustomEmoji(offset: Int32, length: Int32, documentId: Int64)
        case messageEntitySpoiler(offset: Int32, length: Int32)
        
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageEntityUnknown(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1148011883)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityMention(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-100378723)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityHashtag(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1868782349)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBotCommand(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1827637959)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityUrl(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1859134776)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityEmail(let offset, let length):
                    if boxed {
                        buffer.appendInt32(1692693954)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBold(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1117713463)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityItalic(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-2106619040)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCode(let offset, let length):
                    if boxed {
                        buffer.appendInt32(681706865)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityPre(let offset, let length, let language):
                    if boxed {
                        buffer.appendInt32(1938967520)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(language, buffer: buffer, boxed: false)
                    break
                case .messageEntityTextUrl(let offset, let length, let url):
                    if boxed {
                        buffer.appendInt32(1990644519)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .messageEntityUnderline(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1672577397)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityStrike(let offset, let length):
                    if boxed {
                        buffer.appendInt32(-1090087980)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityBlockquote(let offset, let length):
                    if boxed {
                        buffer.appendInt32(34469328)
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .messageEntityCustomEmoji(let offset, let length, let documentId):
                    if boxed {
                        buffer.appendInt32(Int32(bitPattern: 0xc8cf05f8 as UInt32))
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    break
                case .messageEntitySpoiler(let offset, let length):
                    if boxed {
                        buffer.appendInt32(Int32(bitPattern: 0x32ca960f as UInt32))
                    }
                    serializeInt32(offset, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
        fileprivate static func parse_messageEntityUnknown(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityUnknown(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityMention(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityMention(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityHashtag(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityHashtag(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityBotCommand(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityBotCommand(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityUrl(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityEmail(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityEmail(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityBold(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityBold(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityItalic(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityItalic(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityCode(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityCode(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityPre(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return SecretApi144.MessageEntity.messageEntityPre(offset: _1!, length: _2!, language: _3!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityTextUrl(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return SecretApi144.MessageEntity.messageEntityTextUrl(offset: _1!, length: _2!, url: _3!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityUnderline(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityUnderline(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityStrike(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityStrike(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityBlockquote(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntityBlockquote(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageEntityCustomEmoji(_ reader: BufferReader) -> MessageEntity? {
                var _1: Int32?
                _1 = reader.readInt32()
                var _2: Int32?
                _2 = reader.readInt32()
                var _3: Int64?
                _3 = reader.readInt64()
                let _c1 = _1 != nil
                let _c2 = _2 != nil
                let _c3 = _3 != nil
                if _c1 && _c2 && _c3 {
                    return SecretApi144.MessageEntity.messageEntityCustomEmoji(offset: _1!, length: _2!, documentId: _3!)
                }
                else {
                    return nil
                }
            }
        fileprivate static func parse_messageEntitySpoiler(_ reader: BufferReader) -> MessageEntity? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.MessageEntity.messageEntitySpoiler(offset: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    }

    public enum DecryptedMessageMedia {
        case decryptedMessageMediaEmpty
        case decryptedMessageMediaGeoPoint(lat: Double, long: Double)
        case decryptedMessageMediaContact(phoneNumber: String, firstName: String, lastName: String, userId: Int32)
        case decryptedMessageMediaAudio(duration: Int32, mimeType: String, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaExternalDocument(id: Int64, accessHash: Int64, date: Int32, mimeType: String, size: Int32, thumb: SecretApi144.PhotoSize, dcId: Int32, attributes: [SecretApi144.DocumentAttribute])
        case decryptedMessageMediaPhoto(thumb: Buffer, thumbW: Int32, thumbH: Int32, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer, caption: String)
        case decryptedMessageMediaDocument(thumb: Buffer, thumbW: Int32, thumbH: Int32, mimeType: String, size: Int64, key: Buffer, iv: Buffer, attributes: [SecretApi144.DocumentAttribute], caption: String)
        case decryptedMessageMediaVideo(thumb: Buffer, thumbW: Int32, thumbH: Int32, duration: Int32, mimeType: String, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer, caption: String)
        case decryptedMessageMediaVenue(lat: Double, long: Double, title: String, address: String, provider: String, venueId: String)
        case decryptedMessageMediaWebPage(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .decryptedMessageMediaEmpty:
                    if boxed {
                        buffer.appendInt32(144661578)
                    }
                    
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
                case .decryptedMessageMediaAudio(let duration, let mimeType, let size, let key, let iv):
                    if boxed {
                        buffer.appendInt32(1474341323)
                    }
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaExternalDocument(let id, let accessHash, let date, let mimeType, let size, let thumb, let dcId, let attributes):
                    if boxed {
                        buffer.appendInt32(-90853155)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    thumb.serialize(buffer, true)
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
                case .decryptedMessageMediaPhoto(let thumb, let thumbW, let thumbH, let w, let h, let size, let key, let iv, let caption):
                    if boxed {
                        buffer.appendInt32(-235238024)
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    serializeString(caption, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaDocument(let thumb, let thumbW, let thumbH, let mimeType, let size, let key, let iv, let attributes, let caption):
                    if boxed {
                        buffer.appendInt32(Int32(bitPattern: 0x6abd9782 as UInt32))
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt64(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    serializeString(caption, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaVideo(let thumb, let thumbW, let thumbH, let duration, let mimeType, let w, let h, let size, let key, let iv, let caption):
                    if boxed {
                        buffer.appendInt32(-1760785394)
                    }
                    serializeBytes(thumb, buffer: buffer, boxed: false)
                    serializeInt32(thumbW, buffer: buffer, boxed: false)
                    serializeInt32(thumbH, buffer: buffer, boxed: false)
                    serializeInt32(duration, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeBytes(key, buffer: buffer, boxed: false)
                    serializeBytes(iv, buffer: buffer, boxed: false)
                    serializeString(caption, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaVenue(let lat, let long, let title, let address, let provider, let venueId):
                    if boxed {
                        buffer.appendInt32(-1978796689)
                    }
                    serializeDouble(lat, buffer: buffer, boxed: false)
                    serializeDouble(long, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    break
                case .decryptedMessageMediaWebPage(let url):
                    if boxed {
                        buffer.appendInt32(-452652584)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
        fileprivate static func parse_decryptedMessageMediaEmpty(_ reader: BufferReader) -> DecryptedMessageMedia? {
            return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaEmpty
        }
        fileprivate static func parse_decryptedMessageMediaGeoPoint(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaGeoPoint(lat: _1!, long: _2!)
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
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, userId: _4!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaAudio(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
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
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaAudio(duration: _1!, mimeType: _2!, size: _3!, key: _4!, iv: _5!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaExternalDocument(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: SecretApi144.PhotoSize?
            if let signature = reader.readInt32() {
                _6 = SecretApi144.parse(reader, signature: signature) as? SecretApi144.PhotoSize
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: [SecretApi144.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _8 = SecretApi144.parseVector(reader, elementSignature: 0, elementType: SecretApi144.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaExternalDocument(id: _1!, accessHash: _2!, date: _3!, mimeType: _4!, size: _5!, thumb: _6!, dcId: _7!, attributes: _8!)
            }
            else {
                return nil
            }
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
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: _1!, thumbW: _2!, thumbH: _3!, w: _4!, h: _5!, size: _6!, key: _7!, iv: _8!, caption: _9!)
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
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Buffer?
            _7 = parseBytes(reader)
            var _8: [SecretApi144.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _8 = SecretApi144.parseVector(reader, elementSignature: 0, elementType: SecretApi144.DocumentAttribute.self)
            }
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
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: _1!, thumbW: _2!, thumbH: _3!, mimeType: _4!, size: _5!, key: _6!, iv: _7!, attributes: _8!, caption: _9!)
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
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Buffer?
            _9 = parseBytes(reader)
            var _10: Buffer?
            _10 = parseBytes(reader)
            var _11: String?
            _11 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaVideo(thumb: _1!, thumbW: _2!, thumbH: _3!, duration: _4!, mimeType: _5!, w: _6!, h: _7!, size: _8!, key: _9!, iv: _10!, caption: _11!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaVenue(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaVenue(lat: _1!, long: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaWebPage(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi144.DecryptedMessageMedia.decryptedMessageMediaWebPage(url: _1!)
            }
            else {
                return nil
            }
        }
    
    
    }

    public struct functions {
        
    }

}
