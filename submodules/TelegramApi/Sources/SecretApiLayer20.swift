
fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[-1255641564] = { return parseString($0) }
    dict[-1132882121] = { return SecretApi20.Bool.parse_boolFalse($0) }
    dict[-1720552011] = { return SecretApi20.Bool.parse_boolTrue($0) }
    dict[541931640] = { return SecretApi20.DecryptedMessage.parse_decryptedMessage($0) }
    dict[1930838368] = { return SecretApi20.DecryptedMessage.parse_decryptedMessageService($0) }
    dict[-586814357] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionAbortKey($0) }
    dict[1877046107] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionAcceptKey($0) }
    dict[-332526693] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionCommitKey($0) }
    dict[1700872964] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionDeleteMessages($0) }
    dict[1729750108] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionFlushHistory($0) }
    dict[-1473258141] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionNoop($0) }
    dict[-217806717] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionNotifyLayer($0) }
    dict[206520510] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionReadMessages($0) }
    dict[-204906213] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionRequestKey($0) }
    dict[1360072880] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionResend($0) }
    dict[-1967000459] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionScreenshotMessages($0) }
    dict[-1586283796] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionSetMessageTTL($0) }
    dict[-860719551] = { return SecretApi20.DecryptedMessageAction.parse_decryptedMessageActionTyping($0) }
    dict[467867529] = { return SecretApi20.DecryptedMessageLayer.parse_decryptedMessageLayer($0) }
    dict[1474341323] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaAudio($0) }
    dict[1485441687] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaContact($0) }
    dict[-1332395189] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaDocument($0) }
    dict[144661578] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaEmpty($0) }
    dict[893913689] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaGeoPoint($0) }
    dict[846826124] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaPhoto($0) }
    dict[1380598109] = { return SecretApi20.DecryptedMessageMedia.parse_decryptedMessageMediaVideo($0) }
    dict[-44119819] = { return SecretApi20.SendMessageAction.parse_sendMessageCancelAction($0) }
    dict[1653390447] = { return SecretApi20.SendMessageAction.parse_sendMessageChooseContactAction($0) }
    dict[393186209] = { return SecretApi20.SendMessageAction.parse_sendMessageGeoLocationAction($0) }
    dict[-718310409] = { return SecretApi20.SendMessageAction.parse_sendMessageRecordAudioAction($0) }
    dict[-1584933265] = { return SecretApi20.SendMessageAction.parse_sendMessageRecordVideoAction($0) }
    dict[381645902] = { return SecretApi20.SendMessageAction.parse_sendMessageTypingAction($0) }
    dict[-424899985] = { return SecretApi20.SendMessageAction.parse_sendMessageUploadAudioAction($0) }
    dict[-1884362354] = { return SecretApi20.SendMessageAction.parse_sendMessageUploadDocumentAction($0) }
    dict[-1727382502] = { return SecretApi20.SendMessageAction.parse_sendMessageUploadPhotoAction($0) }
    dict[-1845219337] = { return SecretApi20.SendMessageAction.parse_sendMessageUploadVideoAction($0) }
    return dict
}()

public struct SecretApi20 {
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
                if let item = SecretApi20.parse(reader, signature: signature) as? T {
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
        case let _1 as SecretApi20.Bool:
            _1.serialize(buffer, boxed)
        case let _1 as SecretApi20.DecryptedMessage:
            _1.serialize(buffer, boxed)
        case let _1 as SecretApi20.DecryptedMessageAction:
            _1.serialize(buffer, boxed)
        case let _1 as SecretApi20.DecryptedMessageLayer:
            _1.serialize(buffer, boxed)
        case let _1 as SecretApi20.DecryptedMessageMedia:
            _1.serialize(buffer, boxed)
        case let _1 as SecretApi20.SendMessageAction:
            _1.serialize(buffer, boxed)
        default:
            break
        }
    }

    public enum Bool {
        case boolFalse
        case boolTrue

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .boolFalse:
                if boxed {
                    buffer.appendInt32(-1132882121)
                }
                break
            case .boolTrue:
                if boxed {
                    buffer.appendInt32(-1720552011)
                }
                break
            }
        }

        fileprivate static func parse_boolFalse(_ reader: BufferReader) -> Bool? {
            return SecretApi20.Bool.boolFalse
        }
        fileprivate static func parse_boolTrue(_ reader: BufferReader) -> Bool? {
            return SecretApi20.Bool.boolTrue
        }
    }

    public enum DecryptedMessage {
        case decryptedMessage(randomId: Int64, ttl: Int32, message: String, media: SecretApi20.DecryptedMessageMedia)
        case decryptedMessageService(randomId: Int64, action: SecretApi20.DecryptedMessageAction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .decryptedMessage(let randomId, let ttl, let message, let media):
                if boxed {
                    buffer.appendInt32(541931640)
                }
                serializeInt64(randomId, buffer: buffer, boxed: false)
                serializeInt32(ttl, buffer: buffer, boxed: false)
                serializeString(message, buffer: buffer, boxed: false)
                media.serialize(buffer, true)
                break
            case .decryptedMessageService(let randomId, let action):
                if boxed {
                    buffer.appendInt32(1930838368)
                }
                serializeInt64(randomId, buffer: buffer, boxed: false)
                action.serialize(buffer, true)
                break
            }
        }

        fileprivate static func parse_decryptedMessage(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: SecretApi20.DecryptedMessageMedia?
            if let signature = reader.readInt32() {
                _4 = SecretApi20.parse(reader, signature: signature) as? SecretApi20.DecryptedMessageMedia
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return SecretApi20.DecryptedMessage.decryptedMessage(randomId: _1!, ttl: _2!, message: _3!, media: _4!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageService(_ reader: BufferReader) -> DecryptedMessage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: SecretApi20.DecryptedMessageAction?
            if let signature = reader.readInt32() {
                _2 = SecretApi20.parse(reader, signature: signature) as? SecretApi20.DecryptedMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi20.DecryptedMessage.decryptedMessageService(randomId: _1!, action: _2!)
            }
            else {
                return nil
            }
        }
    }

    public enum DecryptedMessageAction {
        case decryptedMessageActionAbortKey(exchangeId: Int64)
        case decryptedMessageActionAcceptKey(exchangeId: Int64, gB: Buffer, keyFingerprint: Int64)
        case decryptedMessageActionCommitKey(exchangeId: Int64, keyFingerprint: Int64)
        case decryptedMessageActionDeleteMessages(randomIds: [Int64])
        case decryptedMessageActionFlushHistory
        case decryptedMessageActionNoop
        case decryptedMessageActionNotifyLayer(layer: Int32)
        case decryptedMessageActionReadMessages(randomIds: [Int64])
        case decryptedMessageActionRequestKey(exchangeId: Int64, gA: Buffer)
        case decryptedMessageActionResend(startSeqNo: Int32, endSeqNo: Int32)
        case decryptedMessageActionScreenshotMessages(randomIds: [Int64])
        case decryptedMessageActionSetMessageTTL(ttlSeconds: Int32)
        case decryptedMessageActionTyping(action: SecretApi20.SendMessageAction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .decryptedMessageActionAbortKey(let exchangeId):
                if boxed {
                    buffer.appendInt32(-586814357)
                }
                serializeInt64(exchangeId, buffer: buffer, boxed: false)
                break
            case .decryptedMessageActionAcceptKey(let exchangeId, let gB, let keyFingerprint):
                if boxed {
                    buffer.appendInt32(1877046107)
                }
                serializeInt64(exchangeId, buffer: buffer, boxed: false)
                serializeBytes(gB, buffer: buffer, boxed: false)
                serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                break
            case .decryptedMessageActionCommitKey(let exchangeId, let keyFingerprint):
                if boxed {
                    buffer.appendInt32(-332526693)
                }
                serializeInt64(exchangeId, buffer: buffer, boxed: false)
                serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
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
            case .decryptedMessageActionFlushHistory:
                if boxed {
                    buffer.appendInt32(1729750108)
                }
                break
            case .decryptedMessageActionNoop:
                if boxed {
                    buffer.appendInt32(-1473258141)
                }
                break
            case .decryptedMessageActionNotifyLayer(let layer):
                if boxed {
                    buffer.appendInt32(-217806717)
                }
                serializeInt32(layer, buffer: buffer, boxed: false)
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
            case .decryptedMessageActionRequestKey(let exchangeId, let gA):
                if boxed {
                    buffer.appendInt32(-204906213)
                }
                serializeInt64(exchangeId, buffer: buffer, boxed: false)
                serializeBytes(gA, buffer: buffer, boxed: false)
                break
            case .decryptedMessageActionResend(let startSeqNo, let endSeqNo):
                if boxed {
                    buffer.appendInt32(1360072880)
                }
                serializeInt32(startSeqNo, buffer: buffer, boxed: false)
                serializeInt32(endSeqNo, buffer: buffer, boxed: false)
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
            case .decryptedMessageActionSetMessageTTL(let ttlSeconds):
                if boxed {
                    buffer.appendInt32(-1586283796)
                }
                serializeInt32(ttlSeconds, buffer: buffer, boxed: false)
                break
            case .decryptedMessageActionTyping(let action):
                if boxed {
                    buffer.appendInt32(-860719551)
                }
                action.serialize(buffer, true)
                break
            }
        }

        fileprivate static func parse_decryptedMessageActionAbortKey(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionAbortKey(exchangeId: _1!)
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
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionAcceptKey(exchangeId: _1!, gB: _2!, keyFingerprint: _3!)
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
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionCommitKey(exchangeId: _1!, keyFingerprint: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionDeleteMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi20.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionDeleteMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionFlushHistory(_ reader: BufferReader) -> DecryptedMessageAction? {
            return SecretApi20.DecryptedMessageAction.decryptedMessageActionFlushHistory
        }
        fileprivate static func parse_decryptedMessageActionNoop(_ reader: BufferReader) -> DecryptedMessageAction? {
            return SecretApi20.DecryptedMessageAction.decryptedMessageActionNoop
        }
        fileprivate static func parse_decryptedMessageActionNotifyLayer(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionNotifyLayer(layer: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionReadMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi20.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionReadMessages(randomIds: _1!)
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
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionRequestKey(exchangeId: _1!, gA: _2!)
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
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionResend(startSeqNo: _1!, endSeqNo: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionScreenshotMessages(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = SecretApi20.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionScreenshotMessages(randomIds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionSetMessageTTL(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionSetMessageTTL(ttlSeconds: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageActionTyping(_ reader: BufferReader) -> DecryptedMessageAction? {
            var _1: SecretApi20.SendMessageAction?
            if let signature = reader.readInt32() {
                _1 = SecretApi20.parse(reader, signature: signature) as? SecretApi20.SendMessageAction
            }
            let _c1 = _1 != nil
            if _c1 {
                return SecretApi20.DecryptedMessageAction.decryptedMessageActionTyping(action: _1!)
            }
            else {
                return nil
            }
        }
    }

    public enum DecryptedMessageLayer {
        case decryptedMessageLayer(randomBytes: Buffer, layer: Int32, inSeqNo: Int32, outSeqNo: Int32, message: SecretApi20.DecryptedMessage)

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
            var _5: SecretApi20.DecryptedMessage?
            if let signature = reader.readInt32() {
                _5 = SecretApi20.parse(reader, signature: signature) as? SecretApi20.DecryptedMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return SecretApi20.DecryptedMessageLayer.decryptedMessageLayer(randomBytes: _1!, layer: _2!, inSeqNo: _3!, outSeqNo: _4!, message: _5!)
            }
            else {
                return nil
            }
        }
    }

    public enum DecryptedMessageMedia {
        case decryptedMessageMediaAudio(duration: Int32, mimeType: String, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaContact(phoneNumber: String, firstName: String, lastName: String, userId: Int32)
        case decryptedMessageMediaDocument(thumb: Buffer, thumbW: Int32, thumbH: Int32, fileName: String, mimeType: String, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaEmpty
        case decryptedMessageMediaGeoPoint(lat: Double, long: Double)
        case decryptedMessageMediaPhoto(thumb: Buffer, thumbW: Int32, thumbH: Int32, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer)
        case decryptedMessageMediaVideo(thumb: Buffer, thumbW: Int32, thumbH: Int32, duration: Int32, mimeType: String, w: Int32, h: Int32, size: Int32, key: Buffer, iv: Buffer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
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
            case .decryptedMessageMediaVideo(let thumb, let thumbW, let thumbH, let duration, let mimeType, let w, let h, let size, let key, let iv):
                if boxed {
                    buffer.appendInt32(1380598109)
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
                break
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
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaAudio(duration: _1!, mimeType: _2!, size: _3!, key: _4!, iv: _5!)
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
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, userId: _4!)
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
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaDocument(thumb: _1!, thumbW: _2!, thumbH: _3!, fileName: _4!, mimeType: _5!, size: _6!, key: _7!, iv: _8!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_decryptedMessageMediaEmpty(_ reader: BufferReader) -> DecryptedMessageMedia? {
            return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaEmpty
        }
        fileprivate static func parse_decryptedMessageMediaGeoPoint(_ reader: BufferReader) -> DecryptedMessageMedia? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaGeoPoint(lat: _1!, long: _2!)
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaPhoto(thumb: _1!, thumbW: _2!, thumbH: _3!, w: _4!, h: _5!, size: _6!, key: _7!, iv: _8!)
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return SecretApi20.DecryptedMessageMedia.decryptedMessageMediaVideo(thumb: _1!, thumbW: _2!, thumbH: _3!, duration: _4!, mimeType: _5!, w: _6!, h: _7!, size: _8!, key: _9!, iv: _10!)
            }
            else {
                return nil
            }
        }
    }

    public enum SendMessageAction {
        case sendMessageCancelAction
        case sendMessageChooseContactAction
        case sendMessageGeoLocationAction
        case sendMessageRecordAudioAction
        case sendMessageRecordVideoAction
        case sendMessageTypingAction
        case sendMessageUploadAudioAction
        case sendMessageUploadDocumentAction
        case sendMessageUploadPhotoAction
        case sendMessageUploadVideoAction

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
            case .sendMessageGeoLocationAction:
                if boxed {
                    buffer.appendInt32(393186209)
                }
                break
            case .sendMessageRecordAudioAction:
                if boxed {
                    buffer.appendInt32(-718310409)
                }
                break
            case .sendMessageRecordVideoAction:
                if boxed {
                    buffer.appendInt32(-1584933265)
                }
                break
            case .sendMessageTypingAction:
                if boxed {
                    buffer.appendInt32(381645902)
                }
                break
            case .sendMessageUploadAudioAction:
                if boxed {
                    buffer.appendInt32(-424899985)
                }
                break
            case .sendMessageUploadDocumentAction:
                if boxed {
                    buffer.appendInt32(-1884362354)
                }
                break
            case .sendMessageUploadPhotoAction:
                if boxed {
                    buffer.appendInt32(-1727382502)
                }
                break
            case .sendMessageUploadVideoAction:
                if boxed {
                    buffer.appendInt32(-1845219337)
                }
                break
            }
        }

        fileprivate static func parse_sendMessageCancelAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageCancelAction
        }
        fileprivate static func parse_sendMessageChooseContactAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageChooseContactAction
        }
        fileprivate static func parse_sendMessageGeoLocationAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageGeoLocationAction
        }
        fileprivate static func parse_sendMessageRecordAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageRecordAudioAction
        }
        fileprivate static func parse_sendMessageRecordVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageRecordVideoAction
        }
        fileprivate static func parse_sendMessageTypingAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageTypingAction
        }
        fileprivate static func parse_sendMessageUploadAudioAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageUploadAudioAction
        }
        fileprivate static func parse_sendMessageUploadDocumentAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageUploadDocumentAction
        }
        fileprivate static func parse_sendMessageUploadPhotoAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageUploadPhotoAction
        }
        fileprivate static func parse_sendMessageUploadVideoAction(_ reader: BufferReader) -> SendMessageAction? {
            return SecretApi20.SendMessageAction.sendMessageUploadVideoAction
        }
    }

}
