
fileprivate final class FunctionDescription: CustomStringConvertible {
    let generator: () -> String
    init(_ generator: @escaping () -> String) {
        self.generator = generator
    }
    
    var description: String {
        return self.generator()
    }
}

fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {
    var dict: [Int32 : (BufferReader) -> Any?] = [:]
    dict[-1471112230] = { return $0.readInt32() }
    dict[570911930] = { return $0.readInt64() }
    dict[571523412] = { return $0.readDouble() }
    dict[-1255641564] = { return parseString($0) }
    dict[590459437] = { return MacosLegacy.Photo.parse_photoEmpty($0) }
    dict[-1836524247] = { return MacosLegacy.Photo.parse_photo($0) }
    dict[-1160714821] = { return MacosLegacy.Peer.parse_peerChat($0) }
    dict[2] = { return MacosLegacy.Peer.parse_peerSecret($0) }
    dict[164646985] = { return MacosLegacy.UserStatus.parse_userStatusEmpty($0) }
    dict[-306628279] = { return MacosLegacy.UserStatus.parse_userStatusOnline($0) }
    dict[9203775] = { return MacosLegacy.UserStatus.parse_userStatusOffline($0) }
    dict[-496024847] = { return MacosLegacy.UserStatus.parse_userStatusRecently($0) }
    dict[129960444] = { return MacosLegacy.UserStatus.parse_userStatusLastWeek($0) }
    dict[2011940674] = { return MacosLegacy.UserStatus.parse_userStatusLastMonth($0) }
    dict[236446268] = { return MacosLegacy.PhotoSize.parse_photoSizeEmpty($0) }
    dict[2009052699] = { return MacosLegacy.PhotoSize.parse_photoSize($0) }
    dict[-374917894] = { return MacosLegacy.PhotoSize.parse_photoCachedSize($0) }
    dict[2086234950] = { return MacosLegacy.FileLocation.parse_fileLocationUnavailable($0) }
    dict[1406570614] = { return MacosLegacy.FileLocation.parse_fileLocation($0) }
    dict[-350980120] = { return MacosLegacy.WebPage.parse_webPageEmpty($0) }
    dict[-981018084] = { return MacosLegacy.WebPage.parse_webPagePending($0) }
    dict[1594340540] = { return MacosLegacy.WebPage.parse_webPage($0) }
    dict[-2054908813] = { return MacosLegacy.WebPage.parse_webPageNotModified($0) }
    dict[1038967584] = { return MacosLegacy.MessageMedia.parse_messageMediaEmpty($0) }
    dict[1032643901] = { return MacosLegacy.MessageMedia.parse_messageMediaPhoto($0) }
    dict[1457575028] = { return MacosLegacy.MessageMedia.parse_messageMediaGeo($0) }
    dict[1585262393] = { return MacosLegacy.MessageMedia.parse_messageMediaContact($0) }
    dict[-1618676578] = { return MacosLegacy.MessageMedia.parse_messageMediaUnsupported($0) }
    dict[-203411800] = { return MacosLegacy.MessageMedia.parse_messageMediaDocument($0) }
    dict[-1557277184] = { return MacosLegacy.MessageMedia.parse_messageMediaWebPage($0) }
    dict[1815593308] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeImageSize($0) }
    dict[297109817] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeAnimated($0) }
    dict[1662637586] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeSticker($0) }
    dict[1494273227] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeVideo($0) }
    dict[-1739392570] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeAudio($0) }
    dict[358154344] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeFilename($0) }
    dict[-1744710921] = { return MacosLegacy.DocumentAttribute.parse_documentAttributeHasStickers($0) }
    dict[-4838507] = { return MacosLegacy.InputStickerSet.parse_inputStickerSetEmpty($0) }
    dict[537022650] = { return MacosLegacy.User.parse_userEmpty($0) }
    dict[-787638374] = { return MacosLegacy.User.parse_user($0) }
    dict[4] = { return MacosLegacy.Message.parse_destructMessage($0) }
    dict[286776671] = { return MacosLegacy.GeoPoint.parse_geoPointEmpty($0) }
    dict[541710092] = { return MacosLegacy.GeoPoint.parse_geoPoint($0) }
    dict[-1361650766] = { return MacosLegacy.MaskCoords.parse_maskCoords($0) }
    dict[1326562017] = { return MacosLegacy.UserProfilePhoto.parse_userProfilePhotoEmpty($0) }
    dict[-715532088] = { return MacosLegacy.UserProfilePhoto.parse_userProfilePhoto($0) }
    dict[-94974410] = { return MacosLegacy.EncryptedChat.parse_encryptedChat($0) }
    dict[922273905] = { return MacosLegacy.Document.parse_documentEmpty($0) }
    dict[-2027738169] = { return MacosLegacy.Document.parse_document($0) }
    return dict
}()

public struct MacosLegacy {
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
            print("Type constructor \(String(signature, radix: 16, uppercase: false)) not found")
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
                if let item = MacosLegacy.parse(reader, signature: signature) as? T {
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
    
    public static func serializeObject(_ object: Any, buffer: Buffer, boxed: Swift.Bool) -> Swift.Bool {
        switch object {
        case let _1 as MacosLegacy.Photo:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.Peer:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.UserStatus:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.PhotoSize:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.FileLocation:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.WebPage:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.MessageMedia:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.DocumentAttribute:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.InputStickerSet:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.User:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.Message:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.GeoPoint:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.MaskCoords:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.UserProfilePhoto:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.EncryptedChat:
            return _1.serialize(buffer, boxed)
        case let _1 as MacosLegacy.Document:
            return _1.serialize(buffer, boxed)
        default:
            break
        }
        return false
    }
    
    public enum Photo: CustomStringConvertible {
        case photoEmpty(id: Int64)
        case photo(flags: Int32, id: Int64, accessHash: Int64, date: Int32, sizes: [MacosLegacy.PhotoSize])
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .photoEmpty(let id):
                if boxed {
                    buffer.appendInt32(590459437)
                }
                serializeInt64(id, buffer: buffer, boxed: false)
                break
            case .photo(let flags, let id, let accessHash, let date, let sizes):
                if boxed {
                    buffer.appendInt32(-1836524247)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeInt64(id, buffer: buffer, boxed: false)
                serializeInt64(accessHash, buffer: buffer, boxed: false)
                serializeInt32(date, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(sizes.count))
                for item in sizes {
                    item.serialize(buffer, true)
                }
                break
            }
            return true
        }
        
        fileprivate static func parse_photoEmpty(_ reader: BufferReader) -> Photo? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.Photo.photoEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: [MacosLegacy.PhotoSize]?
            if let _ = reader.readInt32() {
                _5 = MacosLegacy.parseVector(reader, elementSignature: 0, elementType: MacosLegacy.PhotoSize.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return MacosLegacy.Photo.photo(flags: _1!, id: _2!, accessHash: _3!, date: _4!, sizes: _5!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .photoEmpty(let id):
                    return "(photoEmpty id: \(id))"
                case .photo(let flags, let id, let accessHash, let date, let sizes):
                    return "(photo flags: \(flags), id: \(id), accessHash: \(accessHash), date: \(date), sizes: \(sizes))"
                }
            }
        }
    }
    
    public enum Peer: CustomStringConvertible {
        case peerChat(chatId: Int32)
        case peerSecret(chatId: Int32)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .peerChat(let chatId):
                if boxed {
                    buffer.appendInt32(-1160714821)
                }
                serializeInt32(chatId, buffer: buffer, boxed: false)
                break
            case .peerSecret(let chatId):
                if boxed {
                    buffer.appendInt32(2)
                }
                serializeInt32(chatId, buffer: buffer, boxed: false)
                break
            }
            return true
        }
        
        fileprivate static func parse_peerChat(_ reader: BufferReader) -> Peer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.Peer.peerChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_peerSecret(_ reader: BufferReader) -> Peer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.Peer.peerSecret(chatId: _1!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .peerChat(let chatId):
                    return "(peerChat chatId: \(chatId))"
                case .peerSecret(let chatId):
                    return "(peerSecret chatId: \(chatId))"
                }
            }
        }
    }
    
    public enum UserStatus: CustomStringConvertible {
        case userStatusEmpty
        case userStatusOnline(expires: Int32)
        case userStatusOffline(wasOnline: Int32)
        case userStatusRecently
        case userStatusLastWeek
        case userStatusLastMonth
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .userStatusEmpty:
                if boxed {
                    buffer.appendInt32(164646985)
                }
                
                break
            case .userStatusOnline(let expires):
                if boxed {
                    buffer.appendInt32(-306628279)
                }
                serializeInt32(expires, buffer: buffer, boxed: false)
                break
            case .userStatusOffline(let wasOnline):
                if boxed {
                    buffer.appendInt32(9203775)
                }
                serializeInt32(wasOnline, buffer: buffer, boxed: false)
                break
            case .userStatusRecently:
                if boxed {
                    buffer.appendInt32(-496024847)
                }
                
                break
            case .userStatusLastWeek:
                if boxed {
                    buffer.appendInt32(129960444)
                }
                
                break
            case .userStatusLastMonth:
                if boxed {
                    buffer.appendInt32(2011940674)
                }
                
                break
            }
            return true
        }
        
        fileprivate static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            return MacosLegacy.UserStatus.userStatusEmpty
        }
        fileprivate static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.UserStatus.userStatusOnline(expires: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.UserStatus.userStatusOffline(wasOnline: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            return MacosLegacy.UserStatus.userStatusRecently
        }
        fileprivate static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            return MacosLegacy.UserStatus.userStatusLastWeek
        }
        fileprivate static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            return MacosLegacy.UserStatus.userStatusLastMonth
        }
        
        public var description: String {
            get {
                switch self {
                case .userStatusEmpty:
                    return "(userStatusEmpty)"
                case .userStatusOnline(let expires):
                    return "(userStatusOnline expires: \(expires))"
                case .userStatusOffline(let wasOnline):
                    return "(userStatusOffline wasOnline: \(wasOnline))"
                case .userStatusRecently:
                    return "(userStatusRecently)"
                case .userStatusLastWeek:
                    return "(userStatusLastWeek)"
                case .userStatusLastMonth:
                    return "(userStatusLastMonth)"
                }
            }
        }
    }
    
    public enum PhotoSize: CustomStringConvertible {
        case photoSizeEmpty(type: String)
        case photoSize(type: String, location: MacosLegacy.FileLocation, w: Int32, h: Int32, size: Int32)
        case photoCachedSize(type: String, location: MacosLegacy.FileLocation, w: Int32, h: Int32, bytes: Buffer)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
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
            return true
        }
        
        fileprivate static func parse_photoSizeEmpty(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.PhotoSize.photoSizeEmpty(type: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_photoSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: MacosLegacy.FileLocation?
            if let signature = reader.readInt32() {
                _2 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.FileLocation
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
                return MacosLegacy.PhotoSize.photoSize(type: _1!, location: _2!, w: _3!, h: _4!, size: _5!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_photoCachedSize(_ reader: BufferReader) -> PhotoSize? {
            var _1: String?
            _1 = parseString(reader)
            var _2: MacosLegacy.FileLocation?
            if let signature = reader.readInt32() {
                _2 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.FileLocation
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
                return MacosLegacy.PhotoSize.photoCachedSize(type: _1!, location: _2!, w: _3!, h: _4!, bytes: _5!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .photoSizeEmpty(let type):
                    return "(photoSizeEmpty type: \(type))"
                case .photoSize(let type, let location, let w, let h, let size):
                    return "(photoSize type: \(type), location: \(location), w: \(w), h: \(h), size: \(size))"
                case .photoCachedSize(let type, let location, let w, let h, let bytes):
                    return "(photoCachedSize type: \(type), location: \(location), w: \(w), h: \(h), bytes: \(bytes))"
                }
            }
        }
    }
    
    public enum FileLocation: CustomStringConvertible {
        case fileLocationUnavailable(volumeId: Int64, localId: Int32, secret: Int64)
        case fileLocation(dcId: Int32, volumeId: Int64, localId: Int32, secret: Int64)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
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
            return true
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
                return MacosLegacy.FileLocation.fileLocationUnavailable(volumeId: _1!, localId: _2!, secret: _3!)
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
                return MacosLegacy.FileLocation.fileLocation(dcId: _1!, volumeId: _2!, localId: _3!, secret: _4!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .fileLocationUnavailable(let volumeId, let localId, let secret):
                    return "(fileLocationUnavailable volumeId: \(volumeId), localId: \(localId), secret: \(secret))"
                case .fileLocation(let dcId, let volumeId, let localId, let secret):
                    return "(fileLocation dcId: \(dcId), volumeId: \(volumeId), localId: \(localId), secret: \(secret))"
                }
            }
        }
    }
    
    public enum WebPage: CustomStringConvertible {
        case webPageEmpty(id: Int64)
        case webPagePending(id: Int64, date: Int32)
        case webPage(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: MacosLegacy.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: MacosLegacy.Document?)
        case webPageNotModified
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .webPageEmpty(let id):
                if boxed {
                    buffer.appendInt32(-350980120)
                }
                serializeInt64(id, buffer: buffer, boxed: false)
                break
            case .webPagePending(let id, let date):
                if boxed {
                    buffer.appendInt32(-981018084)
                }
                serializeInt64(id, buffer: buffer, boxed: false)
                serializeInt32(date, buffer: buffer, boxed: false)
                break
            case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document):
                if boxed {
                    buffer.appendInt32(1594340540)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeInt64(id, buffer: buffer, boxed: false)
                serializeString(url, buffer: buffer, boxed: false)
                serializeString(displayUrl, buffer: buffer, boxed: false)
                serializeInt32(hash, buffer: buffer, boxed: false)
                if Int(flags) & Int(1 << 0) != 0 {serializeString(type!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 1) != 0 {serializeString(siteName!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 3) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 4) != 0 {photo!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 5) != 0 {serializeString(embedUrl!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 5) != 0 {serializeString(embedType!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedWidth!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedHeight!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 7) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 8) != 0 {serializeString(author!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 9) != 0 {document!.serialize(buffer, true)}
                break
            case .webPageNotModified:
                if boxed {
                    buffer.appendInt32(-2054908813)
                }
                
                break
            }
            return true
        }
        
        fileprivate static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.WebPage.webPageEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return MacosLegacy.WebPage.webPagePending(id: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_webPage(_ reader: BufferReader) -> WebPage? {
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
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 2) != 0 {_8 = parseString(reader) }
            var _9: String?
            if Int(_1!) & Int(1 << 3) != 0 {_9 = parseString(reader) }
            var _10: MacosLegacy.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _10 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.Photo
                } }
            var _11: String?
            if Int(_1!) & Int(1 << 5) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 5) != 0 {_12 = parseString(reader) }
            var _13: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_14 = reader.readInt32() }
            var _15: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_15 = reader.readInt32() }
            var _16: String?
            if Int(_1!) & Int(1 << 8) != 0 {_16 = parseString(reader) }
            var _17: MacosLegacy.Document?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _17 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.Document
                } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 5) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 6) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 7) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 9) == 0) || _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return MacosLegacy.WebPage.webPage(flags: _1!, id: _2!, url: _3!, displayUrl: _4!, hash: _5!, type: _6, siteName: _7, title: _8, description: _9, photo: _10, embedUrl: _11, embedType: _12, embedWidth: _13, embedHeight: _14, duration: _15, author: _16, document: _17)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            return MacosLegacy.WebPage.webPageNotModified
        }
        
        public var description: String {
            get {
                switch self {
                case .webPageEmpty(let id):
                    return "(webPageEmpty id: \(id))"
                case .webPagePending(let id, let date):
                    return "(webPagePending id: \(id), date: \(date))"
                case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document):
                    return "(webPage flags: \(flags), id: \(id), url: \(url), displayUrl: \(displayUrl), hash: \(hash), type: \(type), siteName: \(siteName), title: \(title), description: \(description), photo: \(photo), embedUrl: \(embedUrl), embedType: \(embedType), embedWidth: \(embedWidth), embedHeight: \(embedHeight), duration: \(duration), author: \(author), document: \(document))"
                case .webPageNotModified:
                    return "(webPageNotModified)"
                }
            }
        }
    }
    
    public enum MessageMedia: CustomStringConvertible {
        case messageMediaEmpty
        case messageMediaPhoto(photo: MacosLegacy.Photo, caption: String)
        case messageMediaGeo(geo: MacosLegacy.GeoPoint)
        case messageMediaContact(phoneNumber: String, firstName: String, lastName: String, userId: Int32)
        case messageMediaUnsupported
        case messageMediaDocument(document: MacosLegacy.Document, caption: String)
        case messageMediaWebPage(webpage: MacosLegacy.WebPage)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .messageMediaEmpty:
                if boxed {
                    buffer.appendInt32(1038967584)
                }
                
                break
            case .messageMediaPhoto(let photo, let caption):
                if boxed {
                    buffer.appendInt32(1032643901)
                }
                photo.serialize(buffer, true)
                serializeString(caption, buffer: buffer, boxed: false)
                break
            case .messageMediaGeo(let geo):
                if boxed {
                    buffer.appendInt32(1457575028)
                }
                geo.serialize(buffer, true)
                break
            case .messageMediaContact(let phoneNumber, let firstName, let lastName, let userId):
                if boxed {
                    buffer.appendInt32(1585262393)
                }
                serializeString(phoneNumber, buffer: buffer, boxed: false)
                serializeString(firstName, buffer: buffer, boxed: false)
                serializeString(lastName, buffer: buffer, boxed: false)
                serializeInt32(userId, buffer: buffer, boxed: false)
                break
            case .messageMediaUnsupported:
                if boxed {
                    buffer.appendInt32(-1618676578)
                }
                
                break
            case .messageMediaDocument(let document, let caption):
                if boxed {
                    buffer.appendInt32(-203411800)
                }
                document.serialize(buffer, true)
                serializeString(caption, buffer: buffer, boxed: false)
                break
            case .messageMediaWebPage(let webpage):
                if boxed {
                    buffer.appendInt32(-1557277184)
                }
                webpage.serialize(buffer, true)
                break
            }
            return true
        }
        
        fileprivate static func parse_messageMediaEmpty(_ reader: BufferReader) -> MessageMedia? {
            return MacosLegacy.MessageMedia.messageMediaEmpty
        }
        fileprivate static func parse_messageMediaPhoto(_ reader: BufferReader) -> MessageMedia? {
            var _1: MacosLegacy.Photo?
            if let signature = reader.readInt32() {
                _1 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.Photo
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return MacosLegacy.MessageMedia.messageMediaPhoto(photo: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageMediaGeo(_ reader: BufferReader) -> MessageMedia? {
            var _1: MacosLegacy.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.GeoPoint
            }
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.MessageMedia.messageMediaGeo(geo: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageMediaContact(_ reader: BufferReader) -> MessageMedia? {
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
                return MacosLegacy.MessageMedia.messageMediaContact(phoneNumber: _1!, firstName: _2!, lastName: _3!, userId: _4!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageMediaUnsupported(_ reader: BufferReader) -> MessageMedia? {
            return MacosLegacy.MessageMedia.messageMediaUnsupported
        }
        fileprivate static func parse_messageMediaDocument(_ reader: BufferReader) -> MessageMedia? {
            var _1: MacosLegacy.Document?
            if let signature = reader.readInt32() {
                _1 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.Document
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return MacosLegacy.MessageMedia.messageMediaDocument(document: _1!, caption: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_messageMediaWebPage(_ reader: BufferReader) -> MessageMedia? {
            var _1: MacosLegacy.WebPage?
            if let signature = reader.readInt32() {
                _1 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.WebPage
            }
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.MessageMedia.messageMediaWebPage(webpage: _1!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .messageMediaEmpty:
                    return "(messageMediaEmpty)"
                case .messageMediaPhoto(let photo, let caption):
                    return "(messageMediaPhoto photo: \(photo), caption: \(caption))"
                case .messageMediaGeo(let geo):
                    return "(messageMediaGeo geo: \(geo))"
                case .messageMediaContact(let phoneNumber, let firstName, let lastName, let userId):
                    return "(messageMediaContact phoneNumber: \(phoneNumber), firstName: \(firstName), lastName: \(lastName), userId: \(userId))"
                case .messageMediaUnsupported:
                    return "(messageMediaUnsupported)"
                case .messageMediaDocument(let document, let caption):
                    return "(messageMediaDocument document: \(document), caption: \(caption))"
                case .messageMediaWebPage(let webpage):
                    return "(messageMediaWebPage webpage: \(webpage))"
                }
            }
        }
    }
    
    public enum DocumentAttribute: CustomStringConvertible {
        case documentAttributeImageSize(w: Int32, h: Int32)
        case documentAttributeAnimated
        case documentAttributeSticker(flags: Int32, alt: String, stickerset: MacosLegacy.InputStickerSet, maskCoords: MacosLegacy.MaskCoords?)
        case documentAttributeVideo(duration: Int32, w: Int32, h: Int32)
        case documentAttributeAudio(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?)
        case documentAttributeFilename(fileName: String)
        case documentAttributeHasStickers
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
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
            case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                if boxed {
                    buffer.appendInt32(1662637586)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeString(alt, buffer: buffer, boxed: false)
                stickerset.serialize(buffer, true)
                if Int(flags) & Int(1 << 0) != 0 {maskCoords!.serialize(buffer, true)}
                break
            case .documentAttributeVideo(let duration, let w, let h):
                if boxed {
                    buffer.appendInt32(1494273227)
                }
                serializeInt32(duration, buffer: buffer, boxed: false)
                serializeInt32(w, buffer: buffer, boxed: false)
                serializeInt32(h, buffer: buffer, boxed: false)
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
            case .documentAttributeFilename(let fileName):
                if boxed {
                    buffer.appendInt32(358154344)
                }
                serializeString(fileName, buffer: buffer, boxed: false)
                break
            case .documentAttributeHasStickers:
                if boxed {
                    buffer.appendInt32(-1744710921)
                }
                
                break
            }
            return true
        }
        
        fileprivate static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return MacosLegacy.DocumentAttribute.documentAttributeImageSize(w: _1!, h: _2!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return MacosLegacy.DocumentAttribute.documentAttributeAnimated
        }
        fileprivate static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: MacosLegacy.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.InputStickerSet
            }
            var _4: MacosLegacy.MaskCoords?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.MaskCoords
                } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return MacosLegacy.DocumentAttribute.documentAttributeSticker(flags: _1!, alt: _2!, stickerset: _3!, maskCoords: _4)
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return MacosLegacy.DocumentAttribute.documentAttributeVideo(duration: _1!, w: _2!, h: _3!)
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
                return MacosLegacy.DocumentAttribute.documentAttributeAudio(flags: _1!, duration: _2!, title: _3, performer: _4, waveform: _5)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.DocumentAttribute.documentAttributeFilename(fileName: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_documentAttributeHasStickers(_ reader: BufferReader) -> DocumentAttribute? {
            return MacosLegacy.DocumentAttribute.documentAttributeHasStickers
        }
        
        public var description: String {
            get {
                switch self {
                case .documentAttributeImageSize(let w, let h):
                    return "(documentAttributeImageSize w: \(w), h: \(h))"
                case .documentAttributeAnimated:
                    return "(documentAttributeAnimated)"
                case .documentAttributeSticker(let flags, let alt, let stickerset, let maskCoords):
                    return "(documentAttributeSticker flags: \(flags), alt: \(alt), stickerset: \(stickerset), maskCoords: \(maskCoords))"
                case .documentAttributeVideo(let duration, let w, let h):
                    return "(documentAttributeVideo duration: \(duration), w: \(w), h: \(h))"
                case .documentAttributeAudio(let flags, let duration, let title, let performer, let waveform):
                    return "(documentAttributeAudio flags: \(flags), duration: \(duration), title: \(title), performer: \(performer), waveform: \(waveform))"
                case .documentAttributeFilename(let fileName):
                    return "(documentAttributeFilename fileName: \(fileName))"
                case .documentAttributeHasStickers:
                    return "(documentAttributeHasStickers)"
                }
            }
        }
    }
    
    public enum InputStickerSet: CustomStringConvertible {
        case inputStickerSetEmpty
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .inputStickerSetEmpty:
                if boxed {
                    buffer.appendInt32(-4838507)
                }
                
                break
            }
            return true
        }
        
        fileprivate static func parse_inputStickerSetEmpty(_ reader: BufferReader) -> InputStickerSet? {
            return MacosLegacy.InputStickerSet.inputStickerSetEmpty
        }
        
        public var description: String {
            get {
                switch self {
                case .inputStickerSetEmpty:
                    return "(inputStickerSetEmpty)"
                }
            }
        }
    }
    
    public enum User: CustomStringConvertible {
        case userEmpty(id: Int32)
        case user(flags: Int32, id: Int32, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: MacosLegacy.UserProfilePhoto?, status: MacosLegacy.UserStatus?, botInfoVersion: Int32?, restrictionReason: String?, botInlinePlaceholder: String?)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .userEmpty(let id):
                if boxed {
                    buffer.appendInt32(537022650)
                }
                serializeInt32(id, buffer: buffer, boxed: false)
                break
            case .user(let flags, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder):
                if boxed {
                    buffer.appendInt32(-787638374)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeInt32(id, buffer: buffer, boxed: false)
                if Int(flags) & Int(1 << 0) != 0 {serializeInt64(accessHash!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 1) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 2) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 3) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 4) != 0 {serializeString(phone!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 6) != 0 {status!.serialize(buffer, true)}
                if Int(flags) & Int(1 << 14) != 0 {serializeInt32(botInfoVersion!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 18) != 0 {serializeString(restrictionReason!, buffer: buffer, boxed: false)}
                if Int(flags) & Int(1 << 19) != 0 {serializeString(botInlinePlaceholder!, buffer: buffer, boxed: false)}
                break
            }
            return true
        }
        
        fileprivate static func parse_userEmpty(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.User.userEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_user(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt64() }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
            var _8: MacosLegacy.UserProfilePhoto?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.UserProfilePhoto
                } }
            var _9: MacosLegacy.UserStatus?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _9 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.UserStatus
                } }
            var _10: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_10 = reader.readInt32() }
            var _11: String?
            if Int(_1!) & Int(1 << 18) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 19) != 0 {_12 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 18) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 19) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return MacosLegacy.User.user(flags: _1!, id: _2!, accessHash: _3, firstName: _4, lastName: _5, username: _6, phone: _7, photo: _8, status: _9, botInfoVersion: _10, restrictionReason: _11, botInlinePlaceholder: _12)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .userEmpty(let id):
                    return "(userEmpty id: \(id))"
                case .user(let flags, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder):
                    return "(user flags: \(flags), id: \(id), accessHash: \(accessHash), firstName: \(firstName), lastName: \(lastName), username: \(username), phone: \(phone), photo: \(photo), status: \(status), botInfoVersion: \(botInfoVersion), restrictionReason: \(restrictionReason), botInlinePlaceholder: \(botInlinePlaceholder))"
                }
            }
        }
    }
    
    public enum Message: CustomStringConvertible {
        case destructMessage(flags: Int32, id: Int32, fromId: Int32, toId: MacosLegacy.Peer, date: Int32, message: String, media: MacosLegacy.MessageMedia, destructionTime: Int32, random: Int64, fakeId: Int32, ttlSeconds: Int32, outSeqNo: Int32, dstate: Int32)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .destructMessage(let flags, let id, let fromId, let toId, let date, let message, let media, let destructionTime, let random, let fakeId, let ttlSeconds, let outSeqNo, let dstate):
                if boxed {
                    buffer.appendInt32(4)
                }
                serializeInt32(flags, buffer: buffer, boxed: false)
                serializeInt32(id, buffer: buffer, boxed: false)
                serializeInt32(fromId, buffer: buffer, boxed: false)
                toId.serialize(buffer, true)
                serializeInt32(date, buffer: buffer, boxed: false)
                serializeString(message, buffer: buffer, boxed: false)
                media.serialize(buffer, true)
                serializeInt32(destructionTime, buffer: buffer, boxed: false)
                serializeInt64(random, buffer: buffer, boxed: false)
                serializeInt32(fakeId, buffer: buffer, boxed: false)
                serializeInt32(ttlSeconds, buffer: buffer, boxed: false)
                serializeInt32(outSeqNo, buffer: buffer, boxed: false)
                serializeInt32(dstate, buffer: buffer, boxed: false)
                break
            }
            return true
        }
        
        fileprivate static func parse_destructMessage(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: MacosLegacy.Peer?
            if let signature = reader.readInt32() {
                _4 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.Peer
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            _6 = parseString(reader)
            var _7: MacosLegacy.MessageMedia?
            if let signature = reader.readInt32() {
                _7 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.MessageMedia
            }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int64?
            _9 = reader.readInt64()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Int32?
            _13 = reader.readInt32()
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
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return MacosLegacy.Message.destructMessage(flags: _1!, id: _2!, fromId: _3!, toId: _4!, date: _5!, message: _6!, media: _7!, destructionTime: _8!, random: _9!, fakeId: _10!, ttlSeconds: _11!, outSeqNo: _12!, dstate: _13!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .destructMessage(let flags, let id, let fromId, let toId, let date, let message, let media, let destructionTime, let random, let fakeId, let ttlSeconds, let outSeqNo, let dstate):
                    return "(destructMessage flags: \(flags), id: \(id), fromId: \(fromId), toId: \(toId), date: \(date), message: \(message), media: \(media), destructionTime: \(destructionTime), random: \(random), fakeId: \(fakeId), ttlSeconds: \(ttlSeconds), outSeqNo: \(outSeqNo), dstate: \(dstate))"
                }
            }
        }
    }
    
    public enum GeoPoint: CustomStringConvertible {
        case geoPointEmpty
        case geoPoint(long: Double, lat: Double)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .geoPointEmpty:
                if boxed {
                    buffer.appendInt32(286776671)
                }
                
                break
            case .geoPoint(let long, let lat):
                if boxed {
                    buffer.appendInt32(541710092)
                }
                serializeDouble(long, buffer: buffer, boxed: false)
                serializeDouble(lat, buffer: buffer, boxed: false)
                break
            }
            return true
        }
        
        fileprivate static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return MacosLegacy.GeoPoint.geoPointEmpty
        }
        fileprivate static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return MacosLegacy.GeoPoint.geoPoint(long: _1!, lat: _2!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .geoPointEmpty:
                    return "(geoPointEmpty)"
                case .geoPoint(let long, let lat):
                    return "(geoPoint long: \(long), lat: \(lat))"
                }
            }
        }
    }
    
    public enum MaskCoords: CustomStringConvertible {
        case maskCoords(n: Int32, x: Double, y: Double, zoom: Double)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .maskCoords(let n, let x, let y, let zoom):
                if boxed {
                    buffer.appendInt32(-1361650766)
                }
                serializeInt32(n, buffer: buffer, boxed: false)
                serializeDouble(x, buffer: buffer, boxed: false)
                serializeDouble(y, buffer: buffer, boxed: false)
                serializeDouble(zoom, buffer: buffer, boxed: false)
                break
            }
            return true
        }
        
        fileprivate static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
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
                return MacosLegacy.MaskCoords.maskCoords(n: _1!, x: _2!, y: _3!, zoom: _4!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .maskCoords(let n, let x, let y, let zoom):
                    return "(maskCoords n: \(n), x: \(x), y: \(y), zoom: \(zoom))"
                }
            }
        }
    }
    
    public enum UserProfilePhoto: CustomStringConvertible {
        case userProfilePhotoEmpty
        case userProfilePhoto(photoId: Int64, photoSmall: MacosLegacy.FileLocation, photoBig: MacosLegacy.FileLocation)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .userProfilePhotoEmpty:
                if boxed {
                    buffer.appendInt32(1326562017)
                }
                
                break
            case .userProfilePhoto(let photoId, let photoSmall, let photoBig):
                if boxed {
                    buffer.appendInt32(-715532088)
                }
                serializeInt64(photoId, buffer: buffer, boxed: false)
                photoSmall.serialize(buffer, true)
                photoBig.serialize(buffer, true)
                break
            }
            return true
        }
        
        fileprivate static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            return MacosLegacy.UserProfilePhoto.userProfilePhotoEmpty
        }
        fileprivate static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: MacosLegacy.FileLocation?
            if let signature = reader.readInt32() {
                _2 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.FileLocation
            }
            var _3: MacosLegacy.FileLocation?
            if let signature = reader.readInt32() {
                _3 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.FileLocation
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return MacosLegacy.UserProfilePhoto.userProfilePhoto(photoId: _1!, photoSmall: _2!, photoBig: _3!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .userProfilePhotoEmpty:
                    return "(userProfilePhotoEmpty)"
                case .userProfilePhoto(let photoId, let photoSmall, let photoBig):
                    return "(userProfilePhoto photoId: \(photoId), photoSmall: \(photoSmall), photoBig: \(photoBig))"
                }
            }
        }
    }
    
    public enum EncryptedChat: CustomStringConvertible {
        case encryptedChat(id: Int32, accessHash: Int64, date: Int32, adminId: Int32, participantId: Int32, gAOrB: Buffer, keyFingerprint: Int64)
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                if boxed {
                    buffer.appendInt32(-94974410)
                }
                serializeInt32(id, buffer: buffer, boxed: false)
                serializeInt64(accessHash, buffer: buffer, boxed: false)
                serializeInt32(date, buffer: buffer, boxed: false)
                serializeInt32(adminId, buffer: buffer, boxed: false)
                serializeInt32(participantId, buffer: buffer, boxed: false)
                serializeBytes(gAOrB, buffer: buffer, boxed: false)
                serializeInt64(keyFingerprint, buffer: buffer, boxed: false)
                break
            }
            return true
        }
        
        fileprivate static func parse_encryptedChat(_ reader: BufferReader) -> EncryptedChat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return MacosLegacy.EncryptedChat.encryptedChat(id: _1!, accessHash: _2!, date: _3!, adminId: _4!, participantId: _5!, gAOrB: _6!, keyFingerprint: _7!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .encryptedChat(let id, let accessHash, let date, let adminId, let participantId, let gAOrB, let keyFingerprint):
                    return "(encryptedChat id: \(id), accessHash: \(accessHash), date: \(date), adminId: \(adminId), participantId: \(participantId), gAOrB: \(gAOrB), keyFingerprint: \(keyFingerprint))"
                }
            }
        }
    }
    
    public enum Document: CustomStringConvertible {
        case documentEmpty(id: Int64)
        case document(id: Int64, accessHash: Int64, date: Int32, mimeType: String, size: Int32, thumb: MacosLegacy.PhotoSize, dcId: Int32, version: Int32, attributes: [MacosLegacy.DocumentAttribute])
        
        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) -> Swift.Bool {
            switch self {
            case .documentEmpty(let id):
                if boxed {
                    buffer.appendInt32(922273905)
                }
                serializeInt64(id, buffer: buffer, boxed: false)
                break
            case .document(let id, let accessHash, let date, let mimeType, let size, let thumb, let dcId, let version, let attributes):
                if boxed {
                    buffer.appendInt32(-2027738169)
                }
                serializeInt64(id, buffer: buffer, boxed: false)
                serializeInt64(accessHash, buffer: buffer, boxed: false)
                serializeInt32(date, buffer: buffer, boxed: false)
                serializeString(mimeType, buffer: buffer, boxed: false)
                serializeInt32(size, buffer: buffer, boxed: false)
                thumb.serialize(buffer, true)
                serializeInt32(dcId, buffer: buffer, boxed: false)
                serializeInt32(version, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(attributes.count))
                for item in attributes {
                    item.serialize(buffer, true)
                }
                break
            }
            return true
        }
        
        fileprivate static func parse_documentEmpty(_ reader: BufferReader) -> Document? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return MacosLegacy.Document.documentEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        fileprivate static func parse_document(_ reader: BufferReader) -> Document? {
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
            var _6: MacosLegacy.PhotoSize?
            if let signature = reader.readInt32() {
                _6 = MacosLegacy.parse(reader, signature: signature) as? MacosLegacy.PhotoSize
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: [MacosLegacy.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _9 = MacosLegacy.parseVector(reader, elementSignature: 0, elementType: MacosLegacy.DocumentAttribute.self)
            }
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
                return MacosLegacy.Document.document(id: _1!, accessHash: _2!, date: _3!, mimeType: _4!, size: _5!, thumb: _6!, dcId: _7!, version: _8!, attributes: _9!)
            }
            else {
                return nil
            }
        }
        
        public var description: String {
            get {
                switch self {
                case .documentEmpty(let id):
                    return "(documentEmpty id: \(id))"
                case .document(let id, let accessHash, let date, let mimeType, let size, let thumb, let dcId, let version, let attributes):
                    return "(document id: \(id), accessHash: \(accessHash), date: \(date), mimeType: \(mimeType), size: \(size), thumb: \(thumb), dcId: \(dcId), version: \(version), attributes: \(attributes))"
                }
            }
        }
    }
    
    public struct functions {
        
    }
    
}
