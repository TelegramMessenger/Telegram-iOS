public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription {
        public class Cons_inputDocumentFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputDocumentFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("thumbSize", ConstructorParameterDescription(self.thumbSize))])
            }
        }
        public class Cons_inputEncryptedFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEncryptedFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputFileLocation: TypeConstructorDescription {
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public var fileReference: Buffer
            public init(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer) {
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
                self.fileReference = fileReference
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFileLocation", [("volumeId", ConstructorParameterDescription(self.volumeId)), ("localId", ConstructorParameterDescription(self.localId)), ("secret", ConstructorParameterDescription(self.secret)), ("fileReference", ConstructorParameterDescription(self.fileReference))])
            }
        }
        public class Cons_inputGroupCallStream: TypeConstructorDescription {
            public var flags: Int32
            public var call: Api.InputGroupCall
            public var timeMs: Int64
            public var scale: Int32
            public var videoChannel: Int32?
            public var videoQuality: Int32?
            public init(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?) {
                self.flags = flags
                self.call = call
                self.timeMs = timeMs
                self.scale = scale
                self.videoChannel = videoChannel
                self.videoQuality = videoQuality
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGroupCallStream", [("flags", ConstructorParameterDescription(self.flags)), ("call", ConstructorParameterDescription(self.call)), ("timeMs", ConstructorParameterDescription(self.timeMs)), ("scale", ConstructorParameterDescription(self.scale)), ("videoChannel", ConstructorParameterDescription(self.videoChannel)), ("videoQuality", ConstructorParameterDescription(self.videoQuality))])
            }
        }
        public class Cons_inputPeerPhotoFileLocation: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.InputPeer
            public var photoId: Int64
            public init(flags: Int32, peer: Api.InputPeer, photoId: Int64) {
                self.flags = flags
                self.peer = peer
                self.photoId = photoId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPeerPhotoFileLocation", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("photoId", ConstructorParameterDescription(self.photoId))])
            }
        }
        public class Cons_inputPhotoFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var thumbSize: String
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.thumbSize = thumbSize
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhotoFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("thumbSize", ConstructorParameterDescription(self.thumbSize))])
            }
        }
        public class Cons_inputPhotoLegacyFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var volumeId: Int64
            public var localId: Int32
            public var secret: Int64
            public init(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64) {
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.volumeId = volumeId
                self.localId = localId
                self.secret = secret
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPhotoLegacyFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("volumeId", ConstructorParameterDescription(self.volumeId)), ("localId", ConstructorParameterDescription(self.localId)), ("secret", ConstructorParameterDescription(self.secret))])
            }
        }
        public class Cons_inputSecureFileLocation: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputSecureFileLocation", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputStickerSetThumb: TypeConstructorDescription {
            public var stickerset: Api.InputStickerSet
            public var thumbVersion: Int32
            public init(stickerset: Api.InputStickerSet, thumbVersion: Int32) {
                self.stickerset = stickerset
                self.thumbVersion = thumbVersion
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputStickerSetThumb", [("stickerset", ConstructorParameterDescription(self.stickerset)), ("thumbVersion", ConstructorParameterDescription(self.thumbVersion))])
            }
        }
        case inputDocumentFileLocation(Cons_inputDocumentFileLocation)
        case inputEncryptedFileLocation(Cons_inputEncryptedFileLocation)
        case inputFileLocation(Cons_inputFileLocation)
        case inputGroupCallStream(Cons_inputGroupCallStream)
        case inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation)
        case inputPhotoFileLocation(Cons_inputPhotoFileLocation)
        case inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation)
        case inputSecureFileLocation(Cons_inputSecureFileLocation)
        case inputStickerSetThumb(Cons_inputStickerSetThumb)
        case inputTakeoutFileLocation

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputDocumentFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1160743548)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeString(_data.thumbSize, buffer: buffer, boxed: false)
                break
            case .inputEncryptedFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-182231723)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-539317279)
                }
                serializeInt64(_data.volumeId, buffer: buffer, boxed: false)
                serializeInt32(_data.localId, buffer: buffer, boxed: false)
                serializeInt64(_data.secret, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                break
            case .inputGroupCallStream(let _data):
                if boxed {
                    buffer.appendInt32(93890858)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.call.serialize(buffer, true)
                serializeInt64(_data.timeMs, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.videoChannel!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.videoQuality!, buffer: buffer, boxed: false)
                }
                break
            case .inputPeerPhotoFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(925204121)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                break
            case .inputPhotoFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(1075322878)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeString(_data.thumbSize, buffer: buffer, boxed: false)
                break
            case .inputPhotoLegacyFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-667654413)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeInt64(_data.volumeId, buffer: buffer, boxed: false)
                serializeInt32(_data.localId, buffer: buffer, boxed: false)
                serializeInt64(_data.secret, buffer: buffer, boxed: false)
                break
            case .inputSecureFileLocation(let _data):
                if boxed {
                    buffer.appendInt32(-876089816)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputStickerSetThumb(let _data):
                if boxed {
                    buffer.appendInt32(-1652231205)
                }
                _data.stickerset.serialize(buffer, true)
                serializeInt32(_data.thumbVersion, buffer: buffer, boxed: false)
                break
            case .inputTakeoutFileLocation:
                if boxed {
                    buffer.appendInt32(700340377)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputDocumentFileLocation(let _data):
                return ("inputDocumentFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("thumbSize", ConstructorParameterDescription(_data.thumbSize))])
            case .inputEncryptedFileLocation(let _data):
                return ("inputEncryptedFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputFileLocation(let _data):
                return ("inputFileLocation", [("volumeId", ConstructorParameterDescription(_data.volumeId)), ("localId", ConstructorParameterDescription(_data.localId)), ("secret", ConstructorParameterDescription(_data.secret)), ("fileReference", ConstructorParameterDescription(_data.fileReference))])
            case .inputGroupCallStream(let _data):
                return ("inputGroupCallStream", [("flags", ConstructorParameterDescription(_data.flags)), ("call", ConstructorParameterDescription(_data.call)), ("timeMs", ConstructorParameterDescription(_data.timeMs)), ("scale", ConstructorParameterDescription(_data.scale)), ("videoChannel", ConstructorParameterDescription(_data.videoChannel)), ("videoQuality", ConstructorParameterDescription(_data.videoQuality))])
            case .inputPeerPhotoFileLocation(let _data):
                return ("inputPeerPhotoFileLocation", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("photoId", ConstructorParameterDescription(_data.photoId))])
            case .inputPhotoFileLocation(let _data):
                return ("inputPhotoFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("thumbSize", ConstructorParameterDescription(_data.thumbSize))])
            case .inputPhotoLegacyFileLocation(let _data):
                return ("inputPhotoLegacyFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("volumeId", ConstructorParameterDescription(_data.volumeId)), ("localId", ConstructorParameterDescription(_data.localId)), ("secret", ConstructorParameterDescription(_data.secret))])
            case .inputSecureFileLocation(let _data):
                return ("inputSecureFileLocation", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputStickerSetThumb(let _data):
                return ("inputStickerSetThumb", [("stickerset", ConstructorParameterDescription(_data.stickerset)), ("thumbVersion", ConstructorParameterDescription(_data.thumbVersion))])
            case .inputTakeoutFileLocation:
                return ("inputTakeoutFileLocation", [])
            }
        }

        public static func parse_inputDocumentFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputDocumentFileLocation(Cons_inputDocumentFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputEncryptedFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputEncryptedFileLocation(Cons_inputEncryptedFileLocation(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputFileLocation(Cons_inputFileLocation(volumeId: _1!, localId: _2!, secret: _3!, fileReference: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGroupCallStream(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputGroupCallStream(Cons_inputGroupCallStream(flags: _1!, call: _2!, timeMs: _3!, scale: _4!, videoChannel: _5, videoQuality: _6))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPeerPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputFileLocation.inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation(flags: _1!, peer: _2!, photoId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputFileLocation.inputPhotoFileLocation(Cons_inputPhotoFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, thumbSize: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputPhotoLegacyFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputFileLocation.inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation(id: _1!, accessHash: _2!, fileReference: _3!, volumeId: _4!, localId: _5!, secret: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputSecureFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputSecureFileLocation(Cons_inputSecureFileLocation(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputStickerSetThumb(_ reader: BufferReader) -> InputFileLocation? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFileLocation.inputStickerSetThumb(Cons_inputStickerSetThumb(stickerset: _1!, thumbVersion: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputTakeoutFileLocation(_ reader: BufferReader) -> InputFileLocation? {
            return Api.InputFileLocation.inputTakeoutFileLocation
        }
    }
}
public extension Api {
    indirect enum InputFolderPeer: TypeConstructorDescription {
        public class Cons_inputFolderPeer: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var folderId: Int32
            public init(peer: Api.InputPeer, folderId: Int32) {
                self.peer = peer
                self.folderId = folderId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputFolderPeer", [("peer", ConstructorParameterDescription(self.peer)), ("folderId", ConstructorParameterDescription(self.folderId))])
            }
        }
        case inputFolderPeer(Cons_inputFolderPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputFolderPeer(let _data):
                if boxed {
                    buffer.appendInt32(-70073706)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.folderId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputFolderPeer(let _data):
                return ("inputFolderPeer", [("peer", ConstructorParameterDescription(_data.peer)), ("folderId", ConstructorParameterDescription(_data.folderId))])
            }
        }

        public static func parse_inputFolderPeer(_ reader: BufferReader) -> InputFolderPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputFolderPeer.inputFolderPeer(Cons_inputFolderPeer(peer: _1!, folderId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputGame: TypeConstructorDescription {
        public class Cons_inputGameID: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGameID", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputGameShortName: TypeConstructorDescription {
            public var botId: Api.InputUser
            public var shortName: String
            public init(botId: Api.InputUser, shortName: String) {
                self.botId = botId
                self.shortName = shortName
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGameShortName", [("botId", ConstructorParameterDescription(self.botId)), ("shortName", ConstructorParameterDescription(self.shortName))])
            }
        }
        case inputGameID(Cons_inputGameID)
        case inputGameShortName(Cons_inputGameShortName)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputGameID(let _data):
                if boxed {
                    buffer.appendInt32(53231223)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputGameShortName(let _data):
                if boxed {
                    buffer.appendInt32(-1020139510)
                }
                _data.botId.serialize(buffer, true)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputGameID(let _data):
                return ("inputGameID", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputGameShortName(let _data):
                return ("inputGameShortName", [("botId", ConstructorParameterDescription(_data.botId)), ("shortName", ConstructorParameterDescription(_data.shortName))])
            }
        }

        public static func parse_inputGameID(_ reader: BufferReader) -> InputGame? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameID(Cons_inputGameID(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGameShortName(_ reader: BufferReader) -> InputGame? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGame.inputGameShortName(Cons_inputGameShortName(botId: _1!, shortName: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InputGeoPoint: TypeConstructorDescription {
        public class Cons_inputGeoPoint: TypeConstructorDescription {
            public var flags: Int32
            public var lat: Double
            public var long: Double
            public var accuracyRadius: Int32?
            public init(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?) {
                self.flags = flags
                self.lat = lat
                self.long = long
                self.accuracyRadius = accuracyRadius
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGeoPoint", [("flags", ConstructorParameterDescription(self.flags)), ("lat", ConstructorParameterDescription(self.lat)), ("long", ConstructorParameterDescription(self.long)), ("accuracyRadius", ConstructorParameterDescription(self.accuracyRadius))])
            }
        }
        case inputGeoPoint(Cons_inputGeoPoint)
        case inputGeoPointEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputGeoPoint(let _data):
                if boxed {
                    buffer.appendInt32(1210199983)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeDouble(_data.lat, buffer: buffer, boxed: false)
                serializeDouble(_data.long, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.accuracyRadius!, buffer: buffer, boxed: false)
                }
                break
            case .inputGeoPointEmpty:
                if boxed {
                    buffer.appendInt32(-457104426)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputGeoPoint(let _data):
                return ("inputGeoPoint", [("flags", ConstructorParameterDescription(_data.flags)), ("lat", ConstructorParameterDescription(_data.lat)), ("long", ConstructorParameterDescription(_data.long)), ("accuracyRadius", ConstructorParameterDescription(_data.accuracyRadius))])
            case .inputGeoPointEmpty:
                return ("inputGeoPointEmpty", [])
            }
        }

        public static func parse_inputGeoPoint(_ reader: BufferReader) -> InputGeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputGeoPoint.inputGeoPoint(Cons_inputGeoPoint(flags: _1!, lat: _2!, long: _3!, accuracyRadius: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGeoPointEmpty(_ reader: BufferReader) -> InputGeoPoint? {
            return Api.InputGeoPoint.inputGeoPointEmpty
        }
    }
}
public extension Api {
    enum InputGroupCall: TypeConstructorDescription {
        public class Cons_inputGroupCall: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public init(id: Int64, accessHash: Int64) {
                self.id = id
                self.accessHash = accessHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGroupCall", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash))])
            }
        }
        public class Cons_inputGroupCallInviteMessage: TypeConstructorDescription {
            public var msgId: Int32
            public init(msgId: Int32) {
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGroupCallInviteMessage", [("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_inputGroupCallSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputGroupCallSlug", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        case inputGroupCall(Cons_inputGroupCall)
        case inputGroupCallInviteMessage(Cons_inputGroupCallInviteMessage)
        case inputGroupCallSlug(Cons_inputGroupCallSlug)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(-659913713)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                break
            case .inputGroupCallInviteMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1945083841)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .inputGroupCallSlug(let _data):
                if boxed {
                    buffer.appendInt32(-33127873)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputGroupCall(let _data):
                return ("inputGroupCall", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash))])
            case .inputGroupCallInviteMessage(let _data):
                return ("inputGroupCallInviteMessage", [("msgId", ConstructorParameterDescription(_data.msgId))])
            case .inputGroupCallSlug(let _data):
                return ("inputGroupCallSlug", [("slug", ConstructorParameterDescription(_data.slug))])
            }
        }

        public static func parse_inputGroupCall(_ reader: BufferReader) -> InputGroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputGroupCall.inputGroupCall(Cons_inputGroupCall(id: _1!, accessHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGroupCallInviteMessage(_ reader: BufferReader) -> InputGroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputGroupCall.inputGroupCallInviteMessage(Cons_inputGroupCallInviteMessage(msgId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputGroupCallSlug(_ reader: BufferReader) -> InputGroupCall? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputGroupCall.inputGroupCallSlug(Cons_inputGroupCallSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription {
        public class Cons_inputInvoiceBusinessBotTransferStars: TypeConstructorDescription {
            public var bot: Api.InputUser
            public var stars: Int64
            public init(bot: Api.InputUser, stars: Int64) {
                self.bot = bot
                self.stars = stars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceBusinessBotTransferStars", [("bot", ConstructorParameterDescription(self.bot)), ("stars", ConstructorParameterDescription(self.stars))])
            }
        }
        public class Cons_inputInvoiceChatInviteSubscription: TypeConstructorDescription {
            public var hash: String
            public init(hash: String) {
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceChatInviteSubscription", [("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        public class Cons_inputInvoiceMessage: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var msgId: Int32
            public init(peer: Api.InputPeer, msgId: Int32) {
                self.peer = peer
                self.msgId = msgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceMessage", [("peer", ConstructorParameterDescription(self.peer)), ("msgId", ConstructorParameterDescription(self.msgId))])
            }
        }
        public class Cons_inputInvoicePremiumAuthCode: TypeConstructorDescription {
            public var purpose: Api.InputStorePaymentPurpose
            public init(purpose: Api.InputStorePaymentPurpose) {
                self.purpose = purpose
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoicePremiumAuthCode", [("purpose", ConstructorParameterDescription(self.purpose))])
            }
        }
        public class Cons_inputInvoicePremiumGiftCode: TypeConstructorDescription {
            public var purpose: Api.InputStorePaymentPurpose
            public var option: Api.PremiumGiftCodeOption
            public init(purpose: Api.InputStorePaymentPurpose, option: Api.PremiumGiftCodeOption) {
                self.purpose = purpose
                self.option = option
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoicePremiumGiftCode", [("purpose", ConstructorParameterDescription(self.purpose)), ("option", ConstructorParameterDescription(self.option))])
            }
        }
        public class Cons_inputInvoicePremiumGiftStars: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Api.InputUser
            public var months: Int32
            public var message: Api.TextWithEntities?
            public init(flags: Int32, userId: Api.InputUser, months: Int32, message: Api.TextWithEntities?) {
                self.flags = flags
                self.userId = userId
                self.months = months
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoicePremiumGiftStars", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("months", ConstructorParameterDescription(self.months)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_inputInvoiceSlug: TypeConstructorDescription {
            public var slug: String
            public init(slug: String) {
                self.slug = slug
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceSlug", [("slug", ConstructorParameterDescription(self.slug))])
            }
        }
        public class Cons_inputInvoiceStarGift: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.InputPeer
            public var giftId: Int64
            public var message: Api.TextWithEntities?
            public init(flags: Int32, peer: Api.InputPeer, giftId: Int64, message: Api.TextWithEntities?) {
                self.flags = flags
                self.peer = peer
                self.giftId = giftId
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGift", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("giftId", ConstructorParameterDescription(self.giftId)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_inputInvoiceStarGiftAuctionBid: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.InputPeer?
            public var giftId: Int64
            public var bidAmount: Int64
            public var message: Api.TextWithEntities?
            public init(flags: Int32, peer: Api.InputPeer?, giftId: Int64, bidAmount: Int64, message: Api.TextWithEntities?) {
                self.flags = flags
                self.peer = peer
                self.giftId = giftId
                self.bidAmount = bidAmount
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftAuctionBid", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("giftId", ConstructorParameterDescription(self.giftId)), ("bidAmount", ConstructorParameterDescription(self.bidAmount)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_inputInvoiceStarGiftDropOriginalDetails: TypeConstructorDescription {
            public var stargift: Api.InputSavedStarGift
            public init(stargift: Api.InputSavedStarGift) {
                self.stargift = stargift
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftDropOriginalDetails", [("stargift", ConstructorParameterDescription(self.stargift))])
            }
        }
        public class Cons_inputInvoiceStarGiftPrepaidUpgrade: TypeConstructorDescription {
            public var peer: Api.InputPeer
            public var hash: String
            public init(peer: Api.InputPeer, hash: String) {
                self.peer = peer
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftPrepaidUpgrade", [("peer", ConstructorParameterDescription(self.peer)), ("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        public class Cons_inputInvoiceStarGiftResale: TypeConstructorDescription {
            public var flags: Int32
            public var slug: String
            public var toId: Api.InputPeer
            public init(flags: Int32, slug: String, toId: Api.InputPeer) {
                self.flags = flags
                self.slug = slug
                self.toId = toId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftResale", [("flags", ConstructorParameterDescription(self.flags)), ("slug", ConstructorParameterDescription(self.slug)), ("toId", ConstructorParameterDescription(self.toId))])
            }
        }
        public class Cons_inputInvoiceStarGiftTransfer: TypeConstructorDescription {
            public var stargift: Api.InputSavedStarGift
            public var toId: Api.InputPeer
            public init(stargift: Api.InputSavedStarGift, toId: Api.InputPeer) {
                self.stargift = stargift
                self.toId = toId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftTransfer", [("stargift", ConstructorParameterDescription(self.stargift)), ("toId", ConstructorParameterDescription(self.toId))])
            }
        }
        public class Cons_inputInvoiceStarGiftUpgrade: TypeConstructorDescription {
            public var flags: Int32
            public var stargift: Api.InputSavedStarGift
            public init(flags: Int32, stargift: Api.InputSavedStarGift) {
                self.flags = flags
                self.stargift = stargift
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStarGiftUpgrade", [("flags", ConstructorParameterDescription(self.flags)), ("stargift", ConstructorParameterDescription(self.stargift))])
            }
        }
        public class Cons_inputInvoiceStars: TypeConstructorDescription {
            public var purpose: Api.InputStorePaymentPurpose
            public init(purpose: Api.InputStorePaymentPurpose) {
                self.purpose = purpose
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInvoiceStars", [("purpose", ConstructorParameterDescription(self.purpose))])
            }
        }
        case inputInvoiceBusinessBotTransferStars(Cons_inputInvoiceBusinessBotTransferStars)
        case inputInvoiceChatInviteSubscription(Cons_inputInvoiceChatInviteSubscription)
        case inputInvoiceMessage(Cons_inputInvoiceMessage)
        case inputInvoicePremiumAuthCode(Cons_inputInvoicePremiumAuthCode)
        case inputInvoicePremiumGiftCode(Cons_inputInvoicePremiumGiftCode)
        case inputInvoicePremiumGiftStars(Cons_inputInvoicePremiumGiftStars)
        case inputInvoiceSlug(Cons_inputInvoiceSlug)
        case inputInvoiceStarGift(Cons_inputInvoiceStarGift)
        case inputInvoiceStarGiftAuctionBid(Cons_inputInvoiceStarGiftAuctionBid)
        case inputInvoiceStarGiftDropOriginalDetails(Cons_inputInvoiceStarGiftDropOriginalDetails)
        case inputInvoiceStarGiftPrepaidUpgrade(Cons_inputInvoiceStarGiftPrepaidUpgrade)
        case inputInvoiceStarGiftResale(Cons_inputInvoiceStarGiftResale)
        case inputInvoiceStarGiftTransfer(Cons_inputInvoiceStarGiftTransfer)
        case inputInvoiceStarGiftUpgrade(Cons_inputInvoiceStarGiftUpgrade)
        case inputInvoiceStars(Cons_inputInvoiceStars)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputInvoiceBusinessBotTransferStars(let _data):
                if boxed {
                    buffer.appendInt32(-191267262)
                }
                _data.bot.serialize(buffer, true)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                break
            case .inputInvoiceChatInviteSubscription(let _data):
                if boxed {
                    buffer.appendInt32(887591921)
                }
                serializeString(_data.hash, buffer: buffer, boxed: false)
                break
            case .inputInvoiceMessage(let _data):
                if boxed {
                    buffer.appendInt32(-977967015)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                break
            case .inputInvoicePremiumAuthCode(let _data):
                if boxed {
                    buffer.appendInt32(1048049172)
                }
                _data.purpose.serialize(buffer, true)
                break
            case .inputInvoicePremiumGiftCode(let _data):
                if boxed {
                    buffer.appendInt32(-1734841331)
                }
                _data.purpose.serialize(buffer, true)
                _data.option.serialize(buffer, true)
                break
            case .inputInvoicePremiumGiftStars(let _data):
                if boxed {
                    buffer.appendInt32(-625298705)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.userId.serialize(buffer, true)
                serializeInt32(_data.months, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .inputInvoiceSlug(let _data):
                if boxed {
                    buffer.appendInt32(-1020867857)
                }
                serializeString(_data.slug, buffer: buffer, boxed: false)
                break
            case .inputInvoiceStarGift(let _data):
                if boxed {
                    buffer.appendInt32(-396206446)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .inputInvoiceStarGiftAuctionBid(let _data):
                if boxed {
                    buffer.appendInt32(516618768)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                serializeInt64(_data.giftId, buffer: buffer, boxed: false)
                serializeInt64(_data.bidAmount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                break
            case .inputInvoiceStarGiftDropOriginalDetails(let _data):
                if boxed {
                    buffer.appendInt32(153344209)
                }
                _data.stargift.serialize(buffer, true)
                break
            case .inputInvoiceStarGiftPrepaidUpgrade(let _data):
                if boxed {
                    buffer.appendInt32(-1710536520)
                }
                _data.peer.serialize(buffer, true)
                serializeString(_data.hash, buffer: buffer, boxed: false)
                break
            case .inputInvoiceStarGiftResale(let _data):
                if boxed {
                    buffer.appendInt32(-1012968668)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                _data.toId.serialize(buffer, true)
                break
            case .inputInvoiceStarGiftTransfer(let _data):
                if boxed {
                    buffer.appendInt32(1247763417)
                }
                _data.stargift.serialize(buffer, true)
                _data.toId.serialize(buffer, true)
                break
            case .inputInvoiceStarGiftUpgrade(let _data):
                if boxed {
                    buffer.appendInt32(1300335965)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.stargift.serialize(buffer, true)
                break
            case .inputInvoiceStars(let _data):
                if boxed {
                    buffer.appendInt32(1710230755)
                }
                _data.purpose.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputInvoiceBusinessBotTransferStars(let _data):
                return ("inputInvoiceBusinessBotTransferStars", [("bot", ConstructorParameterDescription(_data.bot)), ("stars", ConstructorParameterDescription(_data.stars))])
            case .inputInvoiceChatInviteSubscription(let _data):
                return ("inputInvoiceChatInviteSubscription", [("hash", ConstructorParameterDescription(_data.hash))])
            case .inputInvoiceMessage(let _data):
                return ("inputInvoiceMessage", [("peer", ConstructorParameterDescription(_data.peer)), ("msgId", ConstructorParameterDescription(_data.msgId))])
            case .inputInvoicePremiumAuthCode(let _data):
                return ("inputInvoicePremiumAuthCode", [("purpose", ConstructorParameterDescription(_data.purpose))])
            case .inputInvoicePremiumGiftCode(let _data):
                return ("inputInvoicePremiumGiftCode", [("purpose", ConstructorParameterDescription(_data.purpose)), ("option", ConstructorParameterDescription(_data.option))])
            case .inputInvoicePremiumGiftStars(let _data):
                return ("inputInvoicePremiumGiftStars", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("months", ConstructorParameterDescription(_data.months)), ("message", ConstructorParameterDescription(_data.message))])
            case .inputInvoiceSlug(let _data):
                return ("inputInvoiceSlug", [("slug", ConstructorParameterDescription(_data.slug))])
            case .inputInvoiceStarGift(let _data):
                return ("inputInvoiceStarGift", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("giftId", ConstructorParameterDescription(_data.giftId)), ("message", ConstructorParameterDescription(_data.message))])
            case .inputInvoiceStarGiftAuctionBid(let _data):
                return ("inputInvoiceStarGiftAuctionBid", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("giftId", ConstructorParameterDescription(_data.giftId)), ("bidAmount", ConstructorParameterDescription(_data.bidAmount)), ("message", ConstructorParameterDescription(_data.message))])
            case .inputInvoiceStarGiftDropOriginalDetails(let _data):
                return ("inputInvoiceStarGiftDropOriginalDetails", [("stargift", ConstructorParameterDescription(_data.stargift))])
            case .inputInvoiceStarGiftPrepaidUpgrade(let _data):
                return ("inputInvoiceStarGiftPrepaidUpgrade", [("peer", ConstructorParameterDescription(_data.peer)), ("hash", ConstructorParameterDescription(_data.hash))])
            case .inputInvoiceStarGiftResale(let _data):
                return ("inputInvoiceStarGiftResale", [("flags", ConstructorParameterDescription(_data.flags)), ("slug", ConstructorParameterDescription(_data.slug)), ("toId", ConstructorParameterDescription(_data.toId))])
            case .inputInvoiceStarGiftTransfer(let _data):
                return ("inputInvoiceStarGiftTransfer", [("stargift", ConstructorParameterDescription(_data.stargift)), ("toId", ConstructorParameterDescription(_data.toId))])
            case .inputInvoiceStarGiftUpgrade(let _data):
                return ("inputInvoiceStarGiftUpgrade", [("flags", ConstructorParameterDescription(_data.flags)), ("stargift", ConstructorParameterDescription(_data.stargift))])
            case .inputInvoiceStars(let _data):
                return ("inputInvoiceStars", [("purpose", ConstructorParameterDescription(_data.purpose))])
            }
        }

        public static func parse_inputInvoiceBusinessBotTransferStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceBusinessBotTransferStars(Cons_inputInvoiceBusinessBotTransferStars(bot: _1!, stars: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceChatInviteSubscription(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceChatInviteSubscription(Cons_inputInvoiceChatInviteSubscription(hash: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceMessage(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceMessage(Cons_inputInvoiceMessage(peer: _1!, msgId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoicePremiumAuthCode(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoicePremiumAuthCode(Cons_inputInvoicePremiumAuthCode(purpose: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoicePremiumGiftCode(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            var _2: Api.PremiumGiftCodeOption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PremiumGiftCodeOption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoicePremiumGiftCode(Cons_inputInvoicePremiumGiftCode(purpose: _1!, option: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoicePremiumGiftStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputInvoice.inputInvoicePremiumGiftStars(Cons_inputInvoicePremiumGiftStars(flags: _1!, userId: _2!, months: _3!, message: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceSlug(_ reader: BufferReader) -> InputInvoice? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceSlug(Cons_inputInvoiceSlug(slug: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGift(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputInvoice.inputInvoiceStarGift(Cons_inputInvoiceStarGift(flags: _1!, peer: _2!, giftId: _3!, message: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftAuctionBid(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputPeer?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
                }
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputInvoice.inputInvoiceStarGiftAuctionBid(Cons_inputInvoiceStarGiftAuctionBid(flags: _1!, peer: _2, giftId: _3!, bidAmount: _4!, message: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftDropOriginalDetails(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceStarGiftDropOriginalDetails(Cons_inputInvoiceStarGiftDropOriginalDetails(stargift: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftPrepaidUpgrade(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceStarGiftPrepaidUpgrade(Cons_inputInvoiceStarGiftPrepaidUpgrade(peer: _1!, hash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftResale(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputInvoice.inputInvoiceStarGiftResale(Cons_inputInvoiceStarGiftResale(flags: _1!, slug: _2!, toId: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftTransfer(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            var _2: Api.InputPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceStarGiftTransfer(Cons_inputInvoiceStarGiftTransfer(stargift: _1!, toId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStarGiftUpgrade(_ reader: BufferReader) -> InputInvoice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputSavedStarGift?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputSavedStarGift
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputInvoice.inputInvoiceStarGiftUpgrade(Cons_inputInvoiceStarGiftUpgrade(flags: _1!, stargift: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInvoiceStars(_ reader: BufferReader) -> InputInvoice? {
            var _1: Api.InputStorePaymentPurpose?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStorePaymentPurpose
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputInvoice.inputInvoiceStars(Cons_inputInvoiceStars(purpose: _1!))
            }
            else {
                return nil
            }
        }
    }
}
