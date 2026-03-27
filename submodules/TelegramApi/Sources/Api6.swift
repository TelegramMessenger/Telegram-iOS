public extension Api {
    enum DisallowedGiftsSettings: TypeConstructorDescription {
        public class Cons_disallowedGiftsSettings: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("disallowedGiftsSettings", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        case disallowedGiftsSettings(Cons_disallowedGiftsSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .disallowedGiftsSettings(let _data):
                if boxed {
                    buffer.appendInt32(1911715524)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .disallowedGiftsSettings(let _data):
                return ("disallowedGiftsSettings", [("flags", ConstructorParameterDescription(_data.flags))])
            }
        }

        public static func parse_disallowedGiftsSettings(_ reader: BufferReader) -> DisallowedGiftsSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.DisallowedGiftsSettings.disallowedGiftsSettings(Cons_disallowedGiftsSettings(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Document: TypeConstructorDescription {
        public class Cons_document: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var fileReference: Buffer
            public var date: Int32
            public var mimeType: String
            public var size: Int64
            public var thumbs: [Api.PhotoSize]?
            public var videoThumbs: [Api.VideoSize]?
            public var dcId: Int32
            public var attributes: [Api.DocumentAttribute]
            public init(flags: Int32, id: Int64, accessHash: Int64, fileReference: Buffer, date: Int32, mimeType: String, size: Int64, thumbs: [Api.PhotoSize]?, videoThumbs: [Api.VideoSize]?, dcId: Int32, attributes: [Api.DocumentAttribute]) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.fileReference = fileReference
                self.date = date
                self.mimeType = mimeType
                self.size = size
                self.thumbs = thumbs
                self.videoThumbs = videoThumbs
                self.dcId = dcId
                self.attributes = attributes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("document", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("fileReference", ConstructorParameterDescription(self.fileReference)), ("date", ConstructorParameterDescription(self.date)), ("mimeType", ConstructorParameterDescription(self.mimeType)), ("size", ConstructorParameterDescription(self.size)), ("thumbs", ConstructorParameterDescription(self.thumbs)), ("videoThumbs", ConstructorParameterDescription(self.videoThumbs)), ("dcId", ConstructorParameterDescription(self.dcId)), ("attributes", ConstructorParameterDescription(self.attributes))])
            }
        }
        public class Cons_documentEmpty: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentEmpty", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case document(Cons_document)
        case documentEmpty(Cons_documentEmpty)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .document(let _data):
                if boxed {
                    buffer.appendInt32(-1881881384)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeBytes(_data.fileReference, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                serializeInt64(_data.size, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.thumbs!.count))
                    for item in _data.thumbs! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.videoThumbs!.count))
                    for item in _data.videoThumbs! {
                        item.serialize(buffer, true)
                    }
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            case .documentEmpty(let _data):
                if boxed {
                    buffer.appendInt32(922273905)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .document(let _data):
                return ("document", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("fileReference", ConstructorParameterDescription(_data.fileReference)), ("date", ConstructorParameterDescription(_data.date)), ("mimeType", ConstructorParameterDescription(_data.mimeType)), ("size", ConstructorParameterDescription(_data.size)), ("thumbs", ConstructorParameterDescription(_data.thumbs)), ("videoThumbs", ConstructorParameterDescription(_data.videoThumbs)), ("dcId", ConstructorParameterDescription(_data.dcId)), ("attributes", ConstructorParameterDescription(_data.attributes))])
            case .documentEmpty(let _data):
                return ("documentEmpty", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_document(_ reader: BufferReader) -> Document? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
                }
            }
            var _9: [Api.VideoSize]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.VideoSize.self)
                }
            }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.Document.document(Cons_document(flags: _1!, id: _2!, accessHash: _3!, fileReference: _4!, date: _5!, mimeType: _6!, size: _7!, thumbs: _8, videoThumbs: _9, dcId: _10!, attributes: _11!))
            }
            else {
                return nil
            }
        }
        public static func parse_documentEmpty(_ reader: BufferReader) -> Document? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Document.documentEmpty(Cons_documentEmpty(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum DocumentAttribute: TypeConstructorDescription {
        public class Cons_documentAttributeAudio: TypeConstructorDescription {
            public var flags: Int32
            public var duration: Int32
            public var title: String?
            public var performer: String?
            public var waveform: Buffer?
            public init(flags: Int32, duration: Int32, title: String?, performer: String?, waveform: Buffer?) {
                self.flags = flags
                self.duration = duration
                self.title = title
                self.performer = performer
                self.waveform = waveform
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeAudio", [("flags", ConstructorParameterDescription(self.flags)), ("duration", ConstructorParameterDescription(self.duration)), ("title", ConstructorParameterDescription(self.title)), ("performer", ConstructorParameterDescription(self.performer)), ("waveform", ConstructorParameterDescription(self.waveform))])
            }
        }
        public class Cons_documentAttributeCustomEmoji: TypeConstructorDescription {
            public var flags: Int32
            public var alt: String
            public var stickerset: Api.InputStickerSet
            public init(flags: Int32, alt: String, stickerset: Api.InputStickerSet) {
                self.flags = flags
                self.alt = alt
                self.stickerset = stickerset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeCustomEmoji", [("flags", ConstructorParameterDescription(self.flags)), ("alt", ConstructorParameterDescription(self.alt)), ("stickerset", ConstructorParameterDescription(self.stickerset))])
            }
        }
        public class Cons_documentAttributeFilename: TypeConstructorDescription {
            public var fileName: String
            public init(fileName: String) {
                self.fileName = fileName
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeFilename", [("fileName", ConstructorParameterDescription(self.fileName))])
            }
        }
        public class Cons_documentAttributeImageSize: TypeConstructorDescription {
            public var w: Int32
            public var h: Int32
            public init(w: Int32, h: Int32) {
                self.w = w
                self.h = h
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeImageSize", [("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h))])
            }
        }
        public class Cons_documentAttributeSticker: TypeConstructorDescription {
            public var flags: Int32
            public var alt: String
            public var stickerset: Api.InputStickerSet
            public var maskCoords: Api.MaskCoords?
            public init(flags: Int32, alt: String, stickerset: Api.InputStickerSet, maskCoords: Api.MaskCoords?) {
                self.flags = flags
                self.alt = alt
                self.stickerset = stickerset
                self.maskCoords = maskCoords
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeSticker", [("flags", ConstructorParameterDescription(self.flags)), ("alt", ConstructorParameterDescription(self.alt)), ("stickerset", ConstructorParameterDescription(self.stickerset)), ("maskCoords", ConstructorParameterDescription(self.maskCoords))])
            }
        }
        public class Cons_documentAttributeVideo: TypeConstructorDescription {
            public var flags: Int32
            public var duration: Double
            public var w: Int32
            public var h: Int32
            public var preloadPrefixSize: Int32?
            public var videoStartTs: Double?
            public var videoCodec: String?
            public init(flags: Int32, duration: Double, w: Int32, h: Int32, preloadPrefixSize: Int32?, videoStartTs: Double?, videoCodec: String?) {
                self.flags = flags
                self.duration = duration
                self.w = w
                self.h = h
                self.preloadPrefixSize = preloadPrefixSize
                self.videoStartTs = videoStartTs
                self.videoCodec = videoCodec
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("documentAttributeVideo", [("flags", ConstructorParameterDescription(self.flags)), ("duration", ConstructorParameterDescription(self.duration)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("preloadPrefixSize", ConstructorParameterDescription(self.preloadPrefixSize)), ("videoStartTs", ConstructorParameterDescription(self.videoStartTs)), ("videoCodec", ConstructorParameterDescription(self.videoCodec))])
            }
        }
        case documentAttributeAnimated
        case documentAttributeAudio(Cons_documentAttributeAudio)
        case documentAttributeCustomEmoji(Cons_documentAttributeCustomEmoji)
        case documentAttributeFilename(Cons_documentAttributeFilename)
        case documentAttributeHasStickers
        case documentAttributeImageSize(Cons_documentAttributeImageSize)
        case documentAttributeSticker(Cons_documentAttributeSticker)
        case documentAttributeVideo(Cons_documentAttributeVideo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .documentAttributeAnimated:
                if boxed {
                    buffer.appendInt32(297109817)
                }
                break
            case .documentAttributeAudio(let _data):
                if boxed {
                    buffer.appendInt32(-1739392570)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.performer!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeBytes(_data.waveform!, buffer: buffer, boxed: false)
                }
                break
            case .documentAttributeCustomEmoji(let _data):
                if boxed {
                    buffer.appendInt32(-48981863)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.alt, buffer: buffer, boxed: false)
                _data.stickerset.serialize(buffer, true)
                break
            case .documentAttributeFilename(let _data):
                if boxed {
                    buffer.appendInt32(358154344)
                }
                serializeString(_data.fileName, buffer: buffer, boxed: false)
                break
            case .documentAttributeHasStickers:
                if boxed {
                    buffer.appendInt32(-1744710921)
                }
                break
            case .documentAttributeImageSize(let _data):
                if boxed {
                    buffer.appendInt32(1815593308)
                }
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                break
            case .documentAttributeSticker(let _data):
                if boxed {
                    buffer.appendInt32(1662637586)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.alt, buffer: buffer, boxed: false)
                _data.stickerset.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.maskCoords!.serialize(buffer, true)
                }
                break
            case .documentAttributeVideo(let _data):
                if boxed {
                    buffer.appendInt32(1137015880)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeDouble(_data.duration, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.preloadPrefixSize!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeDouble(_data.videoStartTs!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.videoCodec!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .documentAttributeAnimated:
                return ("documentAttributeAnimated", [])
            case .documentAttributeAudio(let _data):
                return ("documentAttributeAudio", [("flags", ConstructorParameterDescription(_data.flags)), ("duration", ConstructorParameterDescription(_data.duration)), ("title", ConstructorParameterDescription(_data.title)), ("performer", ConstructorParameterDescription(_data.performer)), ("waveform", ConstructorParameterDescription(_data.waveform))])
            case .documentAttributeCustomEmoji(let _data):
                return ("documentAttributeCustomEmoji", [("flags", ConstructorParameterDescription(_data.flags)), ("alt", ConstructorParameterDescription(_data.alt)), ("stickerset", ConstructorParameterDescription(_data.stickerset))])
            case .documentAttributeFilename(let _data):
                return ("documentAttributeFilename", [("fileName", ConstructorParameterDescription(_data.fileName))])
            case .documentAttributeHasStickers:
                return ("documentAttributeHasStickers", [])
            case .documentAttributeImageSize(let _data):
                return ("documentAttributeImageSize", [("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h))])
            case .documentAttributeSticker(let _data):
                return ("documentAttributeSticker", [("flags", ConstructorParameterDescription(_data.flags)), ("alt", ConstructorParameterDescription(_data.alt)), ("stickerset", ConstructorParameterDescription(_data.stickerset)), ("maskCoords", ConstructorParameterDescription(_data.maskCoords))])
            case .documentAttributeVideo(let _data):
                return ("documentAttributeVideo", [("flags", ConstructorParameterDescription(_data.flags)), ("duration", ConstructorParameterDescription(_data.duration)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("preloadPrefixSize", ConstructorParameterDescription(_data.preloadPrefixSize)), ("videoStartTs", ConstructorParameterDescription(_data.videoStartTs)), ("videoCodec", ConstructorParameterDescription(_data.videoCodec))])
            }
        }

        public static func parse_documentAttributeAnimated(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeAnimated
        }
        public static func parse_documentAttributeAudio(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.DocumentAttribute.documentAttributeAudio(Cons_documentAttributeAudio(flags: _1!, duration: _2!, title: _3, performer: _4, waveform: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeCustomEmoji(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.DocumentAttribute.documentAttributeCustomEmoji(Cons_documentAttributeCustomEmoji(flags: _1!, alt: _2!, stickerset: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeFilename(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.DocumentAttribute.documentAttributeFilename(Cons_documentAttributeFilename(fileName: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeHasStickers(_ reader: BufferReader) -> DocumentAttribute? {
            return Api.DocumentAttribute.documentAttributeHasStickers
        }
        public static func parse_documentAttributeImageSize(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.DocumentAttribute.documentAttributeImageSize(Cons_documentAttributeImageSize(w: _1!, h: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeSticker(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _4: Api.MaskCoords?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MaskCoords
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.DocumentAttribute.documentAttributeSticker(Cons_documentAttributeSticker(flags: _1!, alt: _2!, stickerset: _3!, maskCoords: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_documentAttributeVideo(_ reader: BufferReader) -> DocumentAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Double?
            if Int(_1!) & Int(1 << 4) != 0 {
                _6 = reader.readDouble()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 5) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.DocumentAttribute.documentAttributeVideo(Cons_documentAttributeVideo(flags: _1!, duration: _2!, w: _3!, h: _4!, preloadPrefixSize: _5, videoStartTs: _6, videoCodec: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum DraftMessage: TypeConstructorDescription {
        public class Cons_draftMessage: TypeConstructorDescription {
            public var flags: Int32
            public var replyTo: Api.InputReplyTo?
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var media: Api.InputMedia?
            public var date: Int32
            public var effect: Int64?
            public var suggestedPost: Api.SuggestedPost?
            public init(flags: Int32, replyTo: Api.InputReplyTo?, message: String, entities: [Api.MessageEntity]?, media: Api.InputMedia?, date: Int32, effect: Int64?, suggestedPost: Api.SuggestedPost?) {
                self.flags = flags
                self.replyTo = replyTo
                self.message = message
                self.entities = entities
                self.media = media
                self.date = date
                self.effect = effect
                self.suggestedPost = suggestedPost
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("draftMessage", [("flags", ConstructorParameterDescription(self.flags)), ("replyTo", ConstructorParameterDescription(self.replyTo)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities)), ("media", ConstructorParameterDescription(self.media)), ("date", ConstructorParameterDescription(self.date)), ("effect", ConstructorParameterDescription(self.effect)), ("suggestedPost", ConstructorParameterDescription(self.suggestedPost))])
            }
        }
        public class Cons_draftMessageEmpty: TypeConstructorDescription {
            public var flags: Int32
            public var date: Int32?
            public init(flags: Int32, date: Int32?) {
                self.flags = flags
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("draftMessageEmpty", [("flags", ConstructorParameterDescription(self.flags)), ("date", ConstructorParameterDescription(self.date))])
            }
        }
        case draftMessage(Cons_draftMessage)
        case draftMessageEmpty(Cons_draftMessageEmpty)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .draftMessage(let _data):
                if boxed {
                    buffer.appendInt32(-1763006997)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.replyTo!.serialize(buffer, true)
                }
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.media!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt64(_data.effect!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.suggestedPost!.serialize(buffer, true)
                }
                break
            case .draftMessageEmpty(let _data):
                if boxed {
                    buffer.appendInt32(453805082)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.date!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .draftMessage(let _data):
                return ("draftMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("replyTo", ConstructorParameterDescription(_data.replyTo)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities)), ("media", ConstructorParameterDescription(_data.media)), ("date", ConstructorParameterDescription(_data.date)), ("effect", ConstructorParameterDescription(_data.effect)), ("suggestedPost", ConstructorParameterDescription(_data.suggestedPost))])
            case .draftMessageEmpty(let _data):
                return ("draftMessageEmpty", [("flags", ConstructorParameterDescription(_data.flags)), ("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_draftMessage(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputReplyTo?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.InputReplyTo
                }
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _5: Api.InputMedia?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.InputMedia
                }
            }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int64?
            if Int(_1!) & Int(1 << 7) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Api.SuggestedPost?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.SuggestedPost
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 8) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.DraftMessage.draftMessage(Cons_draftMessage(flags: _1!, replyTo: _2, message: _3!, entities: _4, media: _5, date: _6!, effect: _7, suggestedPost: _8))
            }
            else {
                return nil
            }
        }
        public static func parse_draftMessageEmpty(_ reader: BufferReader) -> DraftMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.DraftMessage.draftMessageEmpty(Cons_draftMessageEmpty(flags: _1!, date: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmailVerification: TypeConstructorDescription {
        public class Cons_emailVerificationApple: TypeConstructorDescription {
            public var token: String
            public init(token: String) {
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerificationApple", [("token", ConstructorParameterDescription(self.token))])
            }
        }
        public class Cons_emailVerificationCode: TypeConstructorDescription {
            public var code: String
            public init(code: String) {
                self.code = code
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerificationCode", [("code", ConstructorParameterDescription(self.code))])
            }
        }
        public class Cons_emailVerificationGoogle: TypeConstructorDescription {
            public var token: String
            public init(token: String) {
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerificationGoogle", [("token", ConstructorParameterDescription(self.token))])
            }
        }
        case emailVerificationApple(Cons_emailVerificationApple)
        case emailVerificationCode(Cons_emailVerificationCode)
        case emailVerificationGoogle(Cons_emailVerificationGoogle)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emailVerificationApple(let _data):
                if boxed {
                    buffer.appendInt32(-1764723459)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                break
            case .emailVerificationCode(let _data):
                if boxed {
                    buffer.appendInt32(-1842457175)
                }
                serializeString(_data.code, buffer: buffer, boxed: false)
                break
            case .emailVerificationGoogle(let _data):
                if boxed {
                    buffer.appendInt32(-611279166)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emailVerificationApple(let _data):
                return ("emailVerificationApple", [("token", ConstructorParameterDescription(_data.token))])
            case .emailVerificationCode(let _data):
                return ("emailVerificationCode", [("code", ConstructorParameterDescription(_data.code))])
            case .emailVerificationGoogle(let _data):
                return ("emailVerificationGoogle", [("token", ConstructorParameterDescription(_data.token))])
            }
        }

        public static func parse_emailVerificationApple(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationApple(Cons_emailVerificationApple(token: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationCode(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationCode(Cons_emailVerificationCode(code: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerificationGoogle(_ reader: BufferReader) -> EmailVerification? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmailVerification.emailVerificationGoogle(Cons_emailVerificationGoogle(token: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmailVerifyPurpose: TypeConstructorDescription {
        public class Cons_emailVerifyPurposeLoginSetup: TypeConstructorDescription {
            public var phoneNumber: String
            public var phoneCodeHash: String
            public init(phoneNumber: String, phoneCodeHash: String) {
                self.phoneNumber = phoneNumber
                self.phoneCodeHash = phoneCodeHash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emailVerifyPurposeLoginSetup", [("phoneNumber", ConstructorParameterDescription(self.phoneNumber)), ("phoneCodeHash", ConstructorParameterDescription(self.phoneCodeHash))])
            }
        }
        case emailVerifyPurposeLoginChange
        case emailVerifyPurposeLoginSetup(Cons_emailVerifyPurposeLoginSetup)
        case emailVerifyPurposePassport

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emailVerifyPurposeLoginChange:
                if boxed {
                    buffer.appendInt32(1383932651)
                }
                break
            case .emailVerifyPurposeLoginSetup(let _data):
                if boxed {
                    buffer.appendInt32(1128644211)
                }
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                break
            case .emailVerifyPurposePassport:
                if boxed {
                    buffer.appendInt32(-1141565819)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emailVerifyPurposeLoginChange:
                return ("emailVerifyPurposeLoginChange", [])
            case .emailVerifyPurposeLoginSetup(let _data):
                return ("emailVerifyPurposeLoginSetup", [("phoneNumber", ConstructorParameterDescription(_data.phoneNumber)), ("phoneCodeHash", ConstructorParameterDescription(_data.phoneCodeHash))])
            case .emailVerifyPurposePassport:
                return ("emailVerifyPurposePassport", [])
            }
        }

        public static func parse_emailVerifyPurposeLoginChange(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposeLoginChange
        }
        public static func parse_emailVerifyPurposeLoginSetup(_ reader: BufferReader) -> EmailVerifyPurpose? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmailVerifyPurpose.emailVerifyPurposeLoginSetup(Cons_emailVerifyPurposeLoginSetup(phoneNumber: _1!, phoneCodeHash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_emailVerifyPurposePassport(_ reader: BufferReader) -> EmailVerifyPurpose? {
            return Api.EmailVerifyPurpose.emailVerifyPurposePassport
        }
    }
}
public extension Api {
    enum EmojiGroup: TypeConstructorDescription {
        public class Cons_emojiGroup: TypeConstructorDescription {
            public var title: String
            public var iconEmojiId: Int64
            public var emoticons: [String]
            public init(title: String, iconEmojiId: Int64, emoticons: [String]) {
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.emoticons = emoticons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGroup", [("title", ConstructorParameterDescription(self.title)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId)), ("emoticons", ConstructorParameterDescription(self.emoticons))])
            }
        }
        public class Cons_emojiGroupGreeting: TypeConstructorDescription {
            public var title: String
            public var iconEmojiId: Int64
            public var emoticons: [String]
            public init(title: String, iconEmojiId: Int64, emoticons: [String]) {
                self.title = title
                self.iconEmojiId = iconEmojiId
                self.emoticons = emoticons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGroupGreeting", [("title", ConstructorParameterDescription(self.title)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId)), ("emoticons", ConstructorParameterDescription(self.emoticons))])
            }
        }
        public class Cons_emojiGroupPremium: TypeConstructorDescription {
            public var title: String
            public var iconEmojiId: Int64
            public init(title: String, iconEmojiId: Int64) {
                self.title = title
                self.iconEmojiId = iconEmojiId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiGroupPremium", [("title", ConstructorParameterDescription(self.title)), ("iconEmojiId", ConstructorParameterDescription(self.iconEmojiId))])
            }
        }
        case emojiGroup(Cons_emojiGroup)
        case emojiGroupGreeting(Cons_emojiGroupGreeting)
        case emojiGroupPremium(Cons_emojiGroupPremium)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiGroup(let _data):
                if boxed {
                    buffer.appendInt32(2056961449)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt64(_data.iconEmojiId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.emoticons.count))
                for item in _data.emoticons {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            case .emojiGroupGreeting(let _data):
                if boxed {
                    buffer.appendInt32(-2133693241)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt64(_data.iconEmojiId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.emoticons.count))
                for item in _data.emoticons {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            case .emojiGroupPremium(let _data):
                if boxed {
                    buffer.appendInt32(154914612)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeInt64(_data.iconEmojiId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiGroup(let _data):
                return ("emojiGroup", [("title", ConstructorParameterDescription(_data.title)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId)), ("emoticons", ConstructorParameterDescription(_data.emoticons))])
            case .emojiGroupGreeting(let _data):
                return ("emojiGroupGreeting", [("title", ConstructorParameterDescription(_data.title)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId)), ("emoticons", ConstructorParameterDescription(_data.emoticons))])
            case .emojiGroupPremium(let _data):
                return ("emojiGroupPremium", [("title", ConstructorParameterDescription(_data.title)), ("iconEmojiId", ConstructorParameterDescription(_data.iconEmojiId))])
            }
        }

        public static func parse_emojiGroup(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [String]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiGroup.emojiGroup(Cons_emojiGroup(title: _1!, iconEmojiId: _2!, emoticons: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGroupGreeting(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [String]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiGroup.emojiGroupGreeting(Cons_emojiGroupGreeting(title: _1!, iconEmojiId: _2!, emoticons: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiGroupPremium(_ reader: BufferReader) -> EmojiGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiGroup.emojiGroupPremium(Cons_emojiGroupPremium(title: _1!, iconEmojiId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiKeyword: TypeConstructorDescription {
        public class Cons_emojiKeyword: TypeConstructorDescription {
            public var keyword: String
            public var emoticons: [String]
            public init(keyword: String, emoticons: [String]) {
                self.keyword = keyword
                self.emoticons = emoticons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiKeyword", [("keyword", ConstructorParameterDescription(self.keyword)), ("emoticons", ConstructorParameterDescription(self.emoticons))])
            }
        }
        public class Cons_emojiKeywordDeleted: TypeConstructorDescription {
            public var keyword: String
            public var emoticons: [String]
            public init(keyword: String, emoticons: [String]) {
                self.keyword = keyword
                self.emoticons = emoticons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiKeywordDeleted", [("keyword", ConstructorParameterDescription(self.keyword)), ("emoticons", ConstructorParameterDescription(self.emoticons))])
            }
        }
        case emojiKeyword(Cons_emojiKeyword)
        case emojiKeywordDeleted(Cons_emojiKeywordDeleted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiKeyword(let _data):
                if boxed {
                    buffer.appendInt32(-709641735)
                }
                serializeString(_data.keyword, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.emoticons.count))
                for item in _data.emoticons {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            case .emojiKeywordDeleted(let _data):
                if boxed {
                    buffer.appendInt32(594408994)
                }
                serializeString(_data.keyword, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.emoticons.count))
                for item in _data.emoticons {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiKeyword(let _data):
                return ("emojiKeyword", [("keyword", ConstructorParameterDescription(_data.keyword)), ("emoticons", ConstructorParameterDescription(_data.emoticons))])
            case .emojiKeywordDeleted(let _data):
                return ("emojiKeywordDeleted", [("keyword", ConstructorParameterDescription(_data.keyword)), ("emoticons", ConstructorParameterDescription(_data.emoticons))])
            }
        }

        public static func parse_emojiKeyword(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeyword(Cons_emojiKeyword(keyword: _1!, emoticons: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiKeywordDeleted(_ reader: BufferReader) -> EmojiKeyword? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiKeyword.emojiKeywordDeleted(Cons_emojiKeywordDeleted(keyword: _1!, emoticons: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiKeywordsDifference: TypeConstructorDescription {
        public class Cons_emojiKeywordsDifference: TypeConstructorDescription {
            public var langCode: String
            public var fromVersion: Int32
            public var version: Int32
            public var keywords: [Api.EmojiKeyword]
            public init(langCode: String, fromVersion: Int32, version: Int32, keywords: [Api.EmojiKeyword]) {
                self.langCode = langCode
                self.fromVersion = fromVersion
                self.version = version
                self.keywords = keywords
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiKeywordsDifference", [("langCode", ConstructorParameterDescription(self.langCode)), ("fromVersion", ConstructorParameterDescription(self.fromVersion)), ("version", ConstructorParameterDescription(self.version)), ("keywords", ConstructorParameterDescription(self.keywords))])
            }
        }
        case emojiKeywordsDifference(Cons_emojiKeywordsDifference)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiKeywordsDifference(let _data):
                if boxed {
                    buffer.appendInt32(1556570557)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                serializeInt32(_data.fromVersion, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.keywords.count))
                for item in _data.keywords {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiKeywordsDifference(let _data):
                return ("emojiKeywordsDifference", [("langCode", ConstructorParameterDescription(_data.langCode)), ("fromVersion", ConstructorParameterDescription(_data.fromVersion)), ("version", ConstructorParameterDescription(_data.version)), ("keywords", ConstructorParameterDescription(_data.keywords))])
            }
        }

        public static func parse_emojiKeywordsDifference(_ reader: BufferReader) -> EmojiKeywordsDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.EmojiKeyword]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiKeyword.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.EmojiKeywordsDifference.emojiKeywordsDifference(Cons_emojiKeywordsDifference(langCode: _1!, fromVersion: _2!, version: _3!, keywords: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiLanguage: TypeConstructorDescription {
        public class Cons_emojiLanguage: TypeConstructorDescription {
            public var langCode: String
            public init(langCode: String) {
                self.langCode = langCode
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiLanguage", [("langCode", ConstructorParameterDescription(self.langCode))])
            }
        }
        case emojiLanguage(Cons_emojiLanguage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiLanguage(let _data):
                if boxed {
                    buffer.appendInt32(-1275374751)
                }
                serializeString(_data.langCode, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiLanguage(let _data):
                return ("emojiLanguage", [("langCode", ConstructorParameterDescription(_data.langCode))])
            }
        }

        public static func parse_emojiLanguage(_ reader: BufferReader) -> EmojiLanguage? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.EmojiLanguage.emojiLanguage(Cons_emojiLanguage(langCode: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum EmojiList: TypeConstructorDescription {
        public class Cons_emojiList: TypeConstructorDescription {
            public var hash: Int64
            public var documentId: [Int64]
            public init(hash: Int64, documentId: [Int64]) {
                self.hash = hash
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiList", [("hash", ConstructorParameterDescription(self.hash)), ("documentId", ConstructorParameterDescription(self.documentId))])
            }
        }
        case emojiList(Cons_emojiList)
        case emojiListNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiList(let _data):
                if boxed {
                    buffer.appendInt32(2048790993)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documentId.count))
                for item in _data.documentId {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .emojiListNotModified:
                if boxed {
                    buffer.appendInt32(1209970170)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiList(let _data):
                return ("emojiList", [("hash", ConstructorParameterDescription(_data.hash)), ("documentId", ConstructorParameterDescription(_data.documentId))])
            case .emojiListNotModified:
                return ("emojiListNotModified", [])
            }
        }

        public static func parse_emojiList(_ reader: BufferReader) -> EmojiList? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.EmojiList.emojiList(Cons_emojiList(hash: _1!, documentId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiListNotModified(_ reader: BufferReader) -> EmojiList? {
            return Api.EmojiList.emojiListNotModified
        }
    }
}
public extension Api {
    enum EmojiStatus: TypeConstructorDescription {
        public class Cons_emojiStatus: TypeConstructorDescription {
            public var flags: Int32
            public var documentId: Int64
            public var until: Int32?
            public init(flags: Int32, documentId: Int64, until: Int32?) {
                self.flags = flags
                self.documentId = documentId
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatus", [("flags", ConstructorParameterDescription(self.flags)), ("documentId", ConstructorParameterDescription(self.documentId)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        public class Cons_emojiStatusCollectible: TypeConstructorDescription {
            public var flags: Int32
            public var collectibleId: Int64
            public var documentId: Int64
            public var title: String
            public var slug: String
            public var patternDocumentId: Int64
            public var centerColor: Int32
            public var edgeColor: Int32
            public var patternColor: Int32
            public var textColor: Int32
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, documentId: Int64, title: String, slug: String, patternDocumentId: Int64, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.documentId = documentId
                self.title = title
                self.slug = slug
                self.patternDocumentId = patternDocumentId
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.patternColor = patternColor
                self.textColor = textColor
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatusCollectible", [("flags", ConstructorParameterDescription(self.flags)), ("collectibleId", ConstructorParameterDescription(self.collectibleId)), ("documentId", ConstructorParameterDescription(self.documentId)), ("title", ConstructorParameterDescription(self.title)), ("slug", ConstructorParameterDescription(self.slug)), ("patternDocumentId", ConstructorParameterDescription(self.patternDocumentId)), ("centerColor", ConstructorParameterDescription(self.centerColor)), ("edgeColor", ConstructorParameterDescription(self.edgeColor)), ("patternColor", ConstructorParameterDescription(self.patternColor)), ("textColor", ConstructorParameterDescription(self.textColor)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        public class Cons_inputEmojiStatusCollectible: TypeConstructorDescription {
            public var flags: Int32
            public var collectibleId: Int64
            public var until: Int32?
            public init(flags: Int32, collectibleId: Int64, until: Int32?) {
                self.flags = flags
                self.collectibleId = collectibleId
                self.until = until
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputEmojiStatusCollectible", [("flags", ConstructorParameterDescription(self.flags)), ("collectibleId", ConstructorParameterDescription(self.collectibleId)), ("until", ConstructorParameterDescription(self.until))])
            }
        }
        case emojiStatus(Cons_emojiStatus)
        case emojiStatusCollectible(Cons_emojiStatusCollectible)
        case emojiStatusEmpty
        case inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiStatus(let _data):
                if boxed {
                    buffer.appendInt32(-402717046)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            case .emojiStatusCollectible(let _data):
                if boxed {
                    buffer.appendInt32(1904500795)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                serializeInt64(_data.patternDocumentId, buffer: buffer, boxed: false)
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.patternColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            case .emojiStatusEmpty:
                if boxed {
                    buffer.appendInt32(769727150)
                }
                break
            case .inputEmojiStatusCollectible(let _data):
                if boxed {
                    buffer.appendInt32(118758847)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.collectibleId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.until!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiStatus(let _data):
                return ("emojiStatus", [("flags", ConstructorParameterDescription(_data.flags)), ("documentId", ConstructorParameterDescription(_data.documentId)), ("until", ConstructorParameterDescription(_data.until))])
            case .emojiStatusCollectible(let _data):
                return ("emojiStatusCollectible", [("flags", ConstructorParameterDescription(_data.flags)), ("collectibleId", ConstructorParameterDescription(_data.collectibleId)), ("documentId", ConstructorParameterDescription(_data.documentId)), ("title", ConstructorParameterDescription(_data.title)), ("slug", ConstructorParameterDescription(_data.slug)), ("patternDocumentId", ConstructorParameterDescription(_data.patternDocumentId)), ("centerColor", ConstructorParameterDescription(_data.centerColor)), ("edgeColor", ConstructorParameterDescription(_data.edgeColor)), ("patternColor", ConstructorParameterDescription(_data.patternColor)), ("textColor", ConstructorParameterDescription(_data.textColor)), ("until", ConstructorParameterDescription(_data.until))])
            case .emojiStatusEmpty:
                return ("emojiStatusEmpty", [])
            case .inputEmojiStatusCollectible(let _data):
                return ("inputEmojiStatusCollectible", [("flags", ConstructorParameterDescription(_data.flags)), ("collectibleId", ConstructorParameterDescription(_data.collectibleId)), ("until", ConstructorParameterDescription(_data.until))])
            }
        }

        public static func parse_emojiStatus(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.emojiStatus(Cons_emojiStatus(flags: _1!, documentId: _2!, until: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _11 = reader.readInt32()
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
            let _c10 = _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 0) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.EmojiStatus.emojiStatusCollectible(Cons_emojiStatusCollectible(flags: _1!, collectibleId: _2!, documentId: _3!, title: _4!, slug: _5!, patternDocumentId: _6!, centerColor: _7!, edgeColor: _8!, patternColor: _9!, textColor: _10!, until: _11))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusEmpty(_ reader: BufferReader) -> EmojiStatus? {
            return Api.EmojiStatus.emojiStatusEmpty
        }
        public static func parse_inputEmojiStatusCollectible(_ reader: BufferReader) -> EmojiStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.EmojiStatus.inputEmojiStatusCollectible(Cons_inputEmojiStatusCollectible(flags: _1!, collectibleId: _2!, until: _3))
            }
            else {
                return nil
            }
        }
    }
}
