public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        public class Cons_stickerSetCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public var cover: Api.Document
            public init(set: Api.StickerSet, cover: Api.Document) {
                self.set = set
                self.cover = cover
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSetCovered", [("set", ConstructorParameterDescription(self.set)), ("cover", ConstructorParameterDescription(self.cover))])
            }
        }
        public class Cons_stickerSetFullCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public var packs: [Api.StickerPack]
            public var keywords: [Api.StickerKeyword]
            public var documents: [Api.Document]
            public init(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document]) {
                self.set = set
                self.packs = packs
                self.keywords = keywords
                self.documents = documents
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSetFullCovered", [("set", ConstructorParameterDescription(self.set)), ("packs", ConstructorParameterDescription(self.packs)), ("keywords", ConstructorParameterDescription(self.keywords)), ("documents", ConstructorParameterDescription(self.documents))])
            }
        }
        public class Cons_stickerSetMultiCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public var covers: [Api.Document]
            public init(set: Api.StickerSet, covers: [Api.Document]) {
                self.set = set
                self.covers = covers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSetMultiCovered", [("set", ConstructorParameterDescription(self.set)), ("covers", ConstructorParameterDescription(self.covers))])
            }
        }
        public class Cons_stickerSetNoCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public init(set: Api.StickerSet) {
                self.set = set
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSetNoCovered", [("set", ConstructorParameterDescription(self.set))])
            }
        }
        case stickerSetCovered(Cons_stickerSetCovered)
        case stickerSetFullCovered(Cons_stickerSetFullCovered)
        case stickerSetMultiCovered(Cons_stickerSetMultiCovered)
        case stickerSetNoCovered(Cons_stickerSetNoCovered)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerSetCovered(let _data):
                if boxed {
                    buffer.appendInt32(1678812626)
                }
                _data.set.serialize(buffer, true)
                _data.cover.serialize(buffer, true)
                break
            case .stickerSetFullCovered(let _data):
                if boxed {
                    buffer.appendInt32(1087454222)
                }
                _data.set.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.packs.count))
                for item in _data.packs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.keywords.count))
                for item in _data.keywords {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    item.serialize(buffer, true)
                }
                break
            case .stickerSetMultiCovered(let _data):
                if boxed {
                    buffer.appendInt32(872932635)
                }
                _data.set.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.covers.count))
                for item in _data.covers {
                    item.serialize(buffer, true)
                }
                break
            case .stickerSetNoCovered(let _data):
                if boxed {
                    buffer.appendInt32(2008112412)
                }
                _data.set.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerSetCovered(let _data):
                return ("stickerSetCovered", [("set", ConstructorParameterDescription(_data.set)), ("cover", ConstructorParameterDescription(_data.cover))])
            case .stickerSetFullCovered(let _data):
                return ("stickerSetFullCovered", [("set", ConstructorParameterDescription(_data.set)), ("packs", ConstructorParameterDescription(_data.packs)), ("keywords", ConstructorParameterDescription(_data.keywords)), ("documents", ConstructorParameterDescription(_data.documents))])
            case .stickerSetMultiCovered(let _data):
                return ("stickerSetMultiCovered", [("set", ConstructorParameterDescription(_data.set)), ("covers", ConstructorParameterDescription(_data.covers))])
            case .stickerSetNoCovered(let _data):
                return ("stickerSetNoCovered", [("set", ConstructorParameterDescription(_data.set))])
            }
        }

        public static func parse_stickerSetCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetCovered(Cons_stickerSetCovered(set: _1!, cover: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetFullCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.StickerKeyword]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerKeyword.self)
            }
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StickerSetCovered.stickerSetFullCovered(Cons_stickerSetFullCovered(set: _1!, packs: _2!, keywords: _3!, documents: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetMultiCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetMultiCovered(Cons_stickerSetMultiCovered(set: _1!, covers: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetNoCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.StickerSetCovered.stickerSetNoCovered(Cons_stickerSetNoCovered(set: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StoriesStealthMode: TypeConstructorDescription {
        public class Cons_storiesStealthMode: TypeConstructorDescription {
            public var flags: Int32
            public var activeUntilDate: Int32?
            public var cooldownUntilDate: Int32?
            public init(flags: Int32, activeUntilDate: Int32?, cooldownUntilDate: Int32?) {
                self.flags = flags
                self.activeUntilDate = activeUntilDate
                self.cooldownUntilDate = cooldownUntilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storiesStealthMode", [("flags", ConstructorParameterDescription(self.flags)), ("activeUntilDate", ConstructorParameterDescription(self.activeUntilDate)), ("cooldownUntilDate", ConstructorParameterDescription(self.cooldownUntilDate))])
            }
        }
        case storiesStealthMode(Cons_storiesStealthMode)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storiesStealthMode(let _data):
                if boxed {
                    buffer.appendInt32(1898850301)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.activeUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.cooldownUntilDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storiesStealthMode(let _data):
                return ("storiesStealthMode", [("flags", ConstructorParameterDescription(_data.flags)), ("activeUntilDate", ConstructorParameterDescription(_data.activeUntilDate)), ("cooldownUntilDate", ConstructorParameterDescription(_data.cooldownUntilDate))])
            }
        }

        public static func parse_storiesStealthMode(_ reader: BufferReader) -> StoriesStealthMode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoriesStealthMode.storiesStealthMode(Cons_storiesStealthMode(flags: _1!, activeUntilDate: _2, cooldownUntilDate: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StoryAlbum: TypeConstructorDescription {
        public class Cons_storyAlbum: TypeConstructorDescription {
            public var flags: Int32
            public var albumId: Int32
            public var title: String
            public var iconPhoto: Api.Photo?
            public var iconVideo: Api.Document?
            public init(flags: Int32, albumId: Int32, title: String, iconPhoto: Api.Photo?, iconVideo: Api.Document?) {
                self.flags = flags
                self.albumId = albumId
                self.title = title
                self.iconPhoto = iconPhoto
                self.iconVideo = iconVideo
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyAlbum", [("flags", ConstructorParameterDescription(self.flags)), ("albumId", ConstructorParameterDescription(self.albumId)), ("title", ConstructorParameterDescription(self.title)), ("iconPhoto", ConstructorParameterDescription(self.iconPhoto)), ("iconVideo", ConstructorParameterDescription(self.iconVideo))])
            }
        }
        case storyAlbum(Cons_storyAlbum)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyAlbum(let _data):
                if boxed {
                    buffer.appendInt32(-1826262950)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.albumId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.iconPhoto!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.iconVideo!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyAlbum(let _data):
                return ("storyAlbum", [("flags", ConstructorParameterDescription(_data.flags)), ("albumId", ConstructorParameterDescription(_data.albumId)), ("title", ConstructorParameterDescription(_data.title)), ("iconPhoto", ConstructorParameterDescription(_data.iconPhoto)), ("iconVideo", ConstructorParameterDescription(_data.iconVideo))])
            }
        }

        public static func parse_storyAlbum(_ reader: BufferReader) -> StoryAlbum? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StoryAlbum.storyAlbum(Cons_storyAlbum(flags: _1!, albumId: _2!, title: _3!, iconPhoto: _4, iconVideo: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StoryFwdHeader: TypeConstructorDescription {
        public class Cons_storyFwdHeader: TypeConstructorDescription {
            public var flags: Int32
            public var from: Api.Peer?
            public var fromName: String?
            public var storyId: Int32?
            public init(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?) {
                self.flags = flags
                self.from = from
                self.fromName = fromName
                self.storyId = storyId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyFwdHeader", [("flags", ConstructorParameterDescription(self.flags)), ("from", ConstructorParameterDescription(self.from)), ("fromName", ConstructorParameterDescription(self.fromName)), ("storyId", ConstructorParameterDescription(self.storyId))])
            }
        }
        case storyFwdHeader(Cons_storyFwdHeader)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyFwdHeader(let _data):
                if boxed {
                    buffer.appendInt32(-1205411504)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.from!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.fromName!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.storyId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyFwdHeader(let _data):
                return ("storyFwdHeader", [("flags", ConstructorParameterDescription(_data.flags)), ("from", ConstructorParameterDescription(_data.from)), ("fromName", ConstructorParameterDescription(_data.fromName)), ("storyId", ConstructorParameterDescription(_data.storyId))])
            }
        }

        public static func parse_storyFwdHeader(_ reader: BufferReader) -> StoryFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryFwdHeader.storyFwdHeader(Cons_storyFwdHeader(flags: _1!, from: _2, fromName: _3, storyId: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription {
        public class Cons_storyItem: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var fromId: Api.Peer?
            public var fwdFrom: Api.StoryFwdHeader?
            public var expireDate: Int32
            public var caption: String?
            public var entities: [Api.MessageEntity]?
            public var media: Api.MessageMedia
            public var mediaAreas: [Api.MediaArea]?
            public var privacy: [Api.PrivacyRule]?
            public var views: Api.StoryViews?
            public var sentReaction: Api.Reaction?
            public var albums: [Int32]?
            public var music: Api.Document?
            public init(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?, music: Api.Document?) {
                self.flags = flags
                self.id = id
                self.date = date
                self.fromId = fromId
                self.fwdFrom = fwdFrom
                self.expireDate = expireDate
                self.caption = caption
                self.entities = entities
                self.media = media
                self.mediaAreas = mediaAreas
                self.privacy = privacy
                self.views = views
                self.sentReaction = sentReaction
                self.albums = albums
                self.music = music
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyItem", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("date", ConstructorParameterDescription(self.date)), ("fromId", ConstructorParameterDescription(self.fromId)), ("fwdFrom", ConstructorParameterDescription(self.fwdFrom)), ("expireDate", ConstructorParameterDescription(self.expireDate)), ("caption", ConstructorParameterDescription(self.caption)), ("entities", ConstructorParameterDescription(self.entities)), ("media", ConstructorParameterDescription(self.media)), ("mediaAreas", ConstructorParameterDescription(self.mediaAreas)), ("privacy", ConstructorParameterDescription(self.privacy)), ("views", ConstructorParameterDescription(self.views)), ("sentReaction", ConstructorParameterDescription(self.sentReaction)), ("albums", ConstructorParameterDescription(self.albums)), ("music", ConstructorParameterDescription(self.music))])
            }
        }
        public class Cons_storyItemDeleted: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyItemDeleted", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_storyItemSkipped: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var date: Int32
            public var expireDate: Int32
            public init(flags: Int32, id: Int32, date: Int32, expireDate: Int32) {
                self.flags = flags
                self.id = id
                self.date = date
                self.expireDate = expireDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyItemSkipped", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("date", ConstructorParameterDescription(self.date)), ("expireDate", ConstructorParameterDescription(self.expireDate))])
            }
        }
        case storyItem(Cons_storyItem)
        case storyItemDeleted(Cons_storyItemDeleted)
        case storyItemSkipped(Cons_storyItemSkipped)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyItem(let _data):
                if boxed {
                    buffer.appendInt32(379894076)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    _data.fwdFrom!.serialize(buffer, true)
                }
                serializeInt32(_data.expireDate, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.caption!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                _data.media.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.mediaAreas!.count))
                    for item in _data.mediaAreas! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.privacy!.count))
                    for item in _data.privacy! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.views!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.sentReaction!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.albums!.count))
                    for item in _data.albums! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    _data.music!.serialize(buffer, true)
                }
                break
            case .storyItemDeleted(let _data):
                if boxed {
                    buffer.appendInt32(1374088783)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                break
            case .storyItemSkipped(let _data):
                if boxed {
                    buffer.appendInt32(-5388013)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.expireDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyItem(let _data):
                return ("storyItem", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("date", ConstructorParameterDescription(_data.date)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("fwdFrom", ConstructorParameterDescription(_data.fwdFrom)), ("expireDate", ConstructorParameterDescription(_data.expireDate)), ("caption", ConstructorParameterDescription(_data.caption)), ("entities", ConstructorParameterDescription(_data.entities)), ("media", ConstructorParameterDescription(_data.media)), ("mediaAreas", ConstructorParameterDescription(_data.mediaAreas)), ("privacy", ConstructorParameterDescription(_data.privacy)), ("views", ConstructorParameterDescription(_data.views)), ("sentReaction", ConstructorParameterDescription(_data.sentReaction)), ("albums", ConstructorParameterDescription(_data.albums)), ("music", ConstructorParameterDescription(_data.music))])
            case .storyItemDeleted(let _data):
                return ("storyItemDeleted", [("id", ConstructorParameterDescription(_data.id))])
            case .storyItemSkipped(let _data):
                return ("storyItemSkipped", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("date", ConstructorParameterDescription(_data.date)), ("expireDate", ConstructorParameterDescription(_data.expireDate))])
            }
        }

        public static func parse_storyItem(_ reader: BufferReader) -> StoryItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _5: Api.StoryFwdHeader?
            if Int(_1!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.StoryFwdHeader
                }
            }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = parseString(reader)
            }
            var _8: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _9: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _10: [Api.MediaArea]?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let _ = reader.readInt32() {
                    _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MediaArea.self)
                }
            }
            var _11: [Api.PrivacyRule]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
                }
            }
            var _12: Api.StoryViews?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.StoryViews
                }
            }
            var _13: Api.Reaction?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _13 = Api.parse(reader, signature: signature) as? Api.Reaction
                }
            }
            var _14: [Int32]?
            if Int(_1!) & Int(1 << 19) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _15: Api.Document?
            if Int(_1!) & Int(1 << 20) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 18) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 17) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 2) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 3) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 15) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 19) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 20) == 0) || _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.StoryItem.storyItem(Cons_storyItem(flags: _1!, id: _2!, date: _3!, fromId: _4, fwdFrom: _5, expireDate: _6!, caption: _7, entities: _8, media: _9!, mediaAreas: _10, privacy: _11, views: _12, sentReaction: _13, albums: _14, music: _15))
            }
            else {
                return nil
            }
        }
        public static func parse_storyItemDeleted(_ reader: BufferReader) -> StoryItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StoryItem.storyItemDeleted(Cons_storyItemDeleted(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_storyItemSkipped(_ reader: BufferReader) -> StoryItem? {
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
                return Api.StoryItem.storyItemSkipped(Cons_storyItemSkipped(flags: _1!, id: _2!, date: _3!, expireDate: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum StoryReaction: TypeConstructorDescription {
        public class Cons_storyReaction: TypeConstructorDescription {
            public var peerId: Api.Peer
            public var date: Int32
            public var reaction: Api.Reaction
            public init(peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
                self.peerId = peerId
                self.date = date
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyReaction", [("peerId", ConstructorParameterDescription(self.peerId)), ("date", ConstructorParameterDescription(self.date)), ("reaction", ConstructorParameterDescription(self.reaction))])
            }
        }
        public class Cons_storyReactionPublicForward: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyReactionPublicForward", [("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_storyReactionPublicRepost: TypeConstructorDescription {
            public var peerId: Api.Peer
            public var story: Api.StoryItem
            public init(peerId: Api.Peer, story: Api.StoryItem) {
                self.peerId = peerId
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyReactionPublicRepost", [("peerId", ConstructorParameterDescription(self.peerId)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        case storyReaction(Cons_storyReaction)
        case storyReactionPublicForward(Cons_storyReactionPublicForward)
        case storyReactionPublicRepost(Cons_storyReactionPublicRepost)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyReaction(let _data):
                if boxed {
                    buffer.appendInt32(1620104917)
                }
                _data.peerId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.reaction.serialize(buffer, true)
                break
            case .storyReactionPublicForward(let _data):
                if boxed {
                    buffer.appendInt32(-1146411453)
                }
                _data.message.serialize(buffer, true)
                break
            case .storyReactionPublicRepost(let _data):
                if boxed {
                    buffer.appendInt32(-808644845)
                }
                _data.peerId.serialize(buffer, true)
                _data.story.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyReaction(let _data):
                return ("storyReaction", [("peerId", ConstructorParameterDescription(_data.peerId)), ("date", ConstructorParameterDescription(_data.date)), ("reaction", ConstructorParameterDescription(_data.reaction))])
            case .storyReactionPublicForward(let _data):
                return ("storyReactionPublicForward", [("message", ConstructorParameterDescription(_data.message))])
            case .storyReactionPublicRepost(let _data):
                return ("storyReactionPublicRepost", [("peerId", ConstructorParameterDescription(_data.peerId)), ("story", ConstructorParameterDescription(_data.story))])
            }
        }

        public static func parse_storyReaction(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoryReaction.storyReaction(Cons_storyReaction(peerId: _1!, date: _2!, reaction: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_storyReactionPublicForward(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.StoryReaction.storyReactionPublicForward(Cons_storyReactionPublicForward(message: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_storyReactionPublicRepost(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StoryReaction.storyReactionPublicRepost(Cons_storyReactionPublicRepost(peerId: _1!, story: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum StoryView: TypeConstructorDescription {
        public class Cons_storyView: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var reaction: Api.Reaction?
            public init(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.reaction = reaction
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyView", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("date", ConstructorParameterDescription(self.date)), ("reaction", ConstructorParameterDescription(self.reaction))])
            }
        }
        public class Cons_storyViewPublicForward: TypeConstructorDescription {
            public var flags: Int32
            public var message: Api.Message
            public init(flags: Int32, message: Api.Message) {
                self.flags = flags
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyViewPublicForward", [("flags", ConstructorParameterDescription(self.flags)), ("message", ConstructorParameterDescription(self.message))])
            }
        }
        public class Cons_storyViewPublicRepost: TypeConstructorDescription {
            public var flags: Int32
            public var peerId: Api.Peer
            public var story: Api.StoryItem
            public init(flags: Int32, peerId: Api.Peer, story: Api.StoryItem) {
                self.flags = flags
                self.peerId = peerId
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyViewPublicRepost", [("flags", ConstructorParameterDescription(self.flags)), ("peerId", ConstructorParameterDescription(self.peerId)), ("story", ConstructorParameterDescription(self.story))])
            }
        }
        case storyView(Cons_storyView)
        case storyViewPublicForward(Cons_storyViewPublicForward)
        case storyViewPublicRepost(Cons_storyViewPublicRepost)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyView(let _data):
                if boxed {
                    buffer.appendInt32(-1329730875)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.reaction!.serialize(buffer, true)
                }
                break
            case .storyViewPublicForward(let _data):
                if boxed {
                    buffer.appendInt32(-1870436597)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                break
            case .storyViewPublicRepost(let _data):
                if boxed {
                    buffer.appendInt32(-1116418231)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peerId.serialize(buffer, true)
                _data.story.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyView(let _data):
                return ("storyView", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("date", ConstructorParameterDescription(_data.date)), ("reaction", ConstructorParameterDescription(_data.reaction))])
            case .storyViewPublicForward(let _data):
                return ("storyViewPublicForward", [("flags", ConstructorParameterDescription(_data.flags)), ("message", ConstructorParameterDescription(_data.message))])
            case .storyViewPublicRepost(let _data):
                return ("storyViewPublicRepost", [("flags", ConstructorParameterDescription(_data.flags)), ("peerId", ConstructorParameterDescription(_data.peerId)), ("story", ConstructorParameterDescription(_data.story))])
            }
        }

        public static func parse_storyView(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Reaction?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Reaction
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryView.storyView(Cons_storyView(flags: _1!, userId: _2!, date: _3!, reaction: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_storyViewPublicForward(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Message?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StoryView.storyViewPublicForward(Cons_storyViewPublicForward(flags: _1!, message: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_storyViewPublicRepost(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.StoryItem?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoryView.storyViewPublicRepost(Cons_storyViewPublicRepost(flags: _1!, peerId: _2!, story: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StoryViews: TypeConstructorDescription {
        public class Cons_storyViews: TypeConstructorDescription {
            public var flags: Int32
            public var viewsCount: Int32
            public var forwardsCount: Int32?
            public var reactions: [Api.ReactionCount]?
            public var reactionsCount: Int32?
            public var recentViewers: [Int64]?
            public init(flags: Int32, viewsCount: Int32, forwardsCount: Int32?, reactions: [Api.ReactionCount]?, reactionsCount: Int32?, recentViewers: [Int64]?) {
                self.flags = flags
                self.viewsCount = viewsCount
                self.forwardsCount = forwardsCount
                self.reactions = reactions
                self.reactionsCount = reactionsCount
                self.recentViewers = recentViewers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("storyViews", [("flags", ConstructorParameterDescription(self.flags)), ("viewsCount", ConstructorParameterDescription(self.viewsCount)), ("forwardsCount", ConstructorParameterDescription(self.forwardsCount)), ("reactions", ConstructorParameterDescription(self.reactions)), ("reactionsCount", ConstructorParameterDescription(self.reactionsCount)), ("recentViewers", ConstructorParameterDescription(self.recentViewers))])
            }
        }
        case storyViews(Cons_storyViews)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyViews(let _data):
                if boxed {
                    buffer.appendInt32(-1923523370)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.viewsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.forwardsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.reactions!.count))
                    for item in _data.reactions! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.reactionsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.recentViewers!.count))
                    for item in _data.recentViewers! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .storyViews(let _data):
                return ("storyViews", [("flags", ConstructorParameterDescription(_data.flags)), ("viewsCount", ConstructorParameterDescription(_data.viewsCount)), ("forwardsCount", ConstructorParameterDescription(_data.forwardsCount)), ("reactions", ConstructorParameterDescription(_data.reactions)), ("reactionsCount", ConstructorParameterDescription(_data.reactionsCount)), ("recentViewers", ConstructorParameterDescription(_data.recentViewers))])
            }
        }

        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = reader.readInt32()
            }
            var _4: [Api.ReactionCount]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReactionCount.self)
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            var _6: [Int64]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StoryViews.storyViews(Cons_storyViews(flags: _1!, viewsCount: _2!, forwardsCount: _3, reactions: _4, reactionsCount: _5, recentViewers: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SuggestedPost: TypeConstructorDescription {
        public class Cons_suggestedPost: TypeConstructorDescription {
            public var flags: Int32
            public var price: Api.StarsAmount?
            public var scheduleDate: Int32?
            public init(flags: Int32, price: Api.StarsAmount?, scheduleDate: Int32?) {
                self.flags = flags
                self.price = price
                self.scheduleDate = scheduleDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("suggestedPost", [("flags", ConstructorParameterDescription(self.flags)), ("price", ConstructorParameterDescription(self.price)), ("scheduleDate", ConstructorParameterDescription(self.scheduleDate))])
            }
        }
        case suggestedPost(Cons_suggestedPost)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .suggestedPost(let _data):
                if boxed {
                    buffer.appendInt32(244201445)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.price!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.scheduleDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .suggestedPost(let _data):
                return ("suggestedPost", [("flags", ConstructorParameterDescription(_data.flags)), ("price", ConstructorParameterDescription(_data.price)), ("scheduleDate", ConstructorParameterDescription(_data.scheduleDate))])
            }
        }

        public static func parse_suggestedPost(_ reader: BufferReader) -> SuggestedPost? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarsAmount?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SuggestedPost.suggestedPost(Cons_suggestedPost(flags: _1!, price: _2, scheduleDate: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TextWithEntities: TypeConstructorDescription {
        public class Cons_textWithEntities: TypeConstructorDescription {
            public var text: String
            public var entities: [Api.MessageEntity]
            public init(text: String, entities: [Api.MessageEntity]) {
                self.text = text
                self.entities = entities
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("textWithEntities", [("text", ConstructorParameterDescription(self.text)), ("entities", ConstructorParameterDescription(self.entities))])
            }
        }
        case textWithEntities(Cons_textWithEntities)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .textWithEntities(let _data):
                if boxed {
                    buffer.appendInt32(1964978502)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.entities.count))
                for item in _data.entities {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .textWithEntities(let _data):
                return ("textWithEntities", [("text", ConstructorParameterDescription(_data.text)), ("entities", ConstructorParameterDescription(_data.entities))])
            }
        }

        public static func parse_textWithEntities(_ reader: BufferReader) -> TextWithEntities? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TextWithEntities.textWithEntities(Cons_textWithEntities(text: _1!, entities: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Theme: TypeConstructorDescription {
        public class Cons_theme: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var slug: String
            public var title: String
            public var document: Api.Document?
            public var settings: [Api.ThemeSettings]?
            public var emoticon: String?
            public var installsCount: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.slug = slug
                self.title = title
                self.document = document
                self.settings = settings
                self.emoticon = emoticon
                self.installsCount = installsCount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("theme", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("slug", ConstructorParameterDescription(self.slug)), ("title", ConstructorParameterDescription(self.title)), ("document", ConstructorParameterDescription(self.document)), ("settings", ConstructorParameterDescription(self.settings)), ("emoticon", ConstructorParameterDescription(self.emoticon)), ("installsCount", ConstructorParameterDescription(self.installsCount))])
            }
        }
        case theme(Cons_theme)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .theme(let _data):
                if boxed {
                    buffer.appendInt32(-1609668650)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.slug, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.settings!.count))
                    for item in _data.settings! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.emoticon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.installsCount!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .theme(let _data):
                return ("theme", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("slug", ConstructorParameterDescription(_data.slug)), ("title", ConstructorParameterDescription(_data.title)), ("document", ConstructorParameterDescription(_data.document)), ("settings", ConstructorParameterDescription(_data.settings)), ("emoticon", ConstructorParameterDescription(_data.emoticon)), ("installsCount", ConstructorParameterDescription(_data.installsCount))])
            }
        }

        public static func parse_theme(_ reader: BufferReader) -> Theme? {
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
            var _6: Api.Document?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _7: [Api.ThemeSettings]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ThemeSettings.self)
                }
            }
            var _8: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _8 = parseString(reader)
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _9 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Theme.theme(Cons_theme(flags: _1!, id: _2!, accessHash: _3!, slug: _4!, title: _5!, document: _6, settings: _7, emoticon: _8, installsCount: _9))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ThemeSettings: TypeConstructorDescription {
        public class Cons_themeSettings: TypeConstructorDescription {
            public var flags: Int32
            public var baseTheme: Api.BaseTheme
            public var accentColor: Int32
            public var outboxAccentColor: Int32?
            public var messageColors: [Int32]?
            public var wallpaper: Api.WallPaper?
            public init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?) {
                self.flags = flags
                self.baseTheme = baseTheme
                self.accentColor = accentColor
                self.outboxAccentColor = outboxAccentColor
                self.messageColors = messageColors
                self.wallpaper = wallpaper
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("themeSettings", [("flags", ConstructorParameterDescription(self.flags)), ("baseTheme", ConstructorParameterDescription(self.baseTheme)), ("accentColor", ConstructorParameterDescription(self.accentColor)), ("outboxAccentColor", ConstructorParameterDescription(self.outboxAccentColor)), ("messageColors", ConstructorParameterDescription(self.messageColors)), ("wallpaper", ConstructorParameterDescription(self.wallpaper))])
            }
        }
        case themeSettings(Cons_themeSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .themeSettings(let _data):
                if boxed {
                    buffer.appendInt32(-94849324)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.baseTheme.serialize(buffer, true)
                serializeInt32(_data.accentColor, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.outboxAccentColor!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.messageColors!.count))
                    for item in _data.messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .themeSettings(let _data):
                return ("themeSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("baseTheme", ConstructorParameterDescription(_data.baseTheme)), ("accentColor", ConstructorParameterDescription(_data.accentColor)), ("outboxAccentColor", ConstructorParameterDescription(_data.outboxAccentColor)), ("messageColors", ConstructorParameterDescription(_data.messageColors)), ("wallpaper", ConstructorParameterDescription(_data.wallpaper))])
            }
        }

        public static func parse_themeSettings(_ reader: BufferReader) -> ThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _6: Api.WallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.WallPaper
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ThemeSettings.themeSettings(Cons_themeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Timezone: TypeConstructorDescription {
        public class Cons_timezone: TypeConstructorDescription {
            public var id: String
            public var name: String
            public var utcOffset: Int32
            public init(id: String, name: String, utcOffset: Int32) {
                self.id = id
                self.name = name
                self.utcOffset = utcOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("timezone", [("id", ConstructorParameterDescription(self.id)), ("name", ConstructorParameterDescription(self.name)), ("utcOffset", ConstructorParameterDescription(self.utcOffset))])
            }
        }
        case timezone(Cons_timezone)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .timezone(let _data):
                if boxed {
                    buffer.appendInt32(-7173643)
                }
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeInt32(_data.utcOffset, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .timezone(let _data):
                return ("timezone", [("id", ConstructorParameterDescription(_data.id)), ("name", ConstructorParameterDescription(_data.name)), ("utcOffset", ConstructorParameterDescription(_data.utcOffset))])
            }
        }

        public static func parse_timezone(_ reader: BufferReader) -> Timezone? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Timezone.timezone(Cons_timezone(id: _1!, name: _2!, utcOffset: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TodoCompletion: TypeConstructorDescription {
        public class Cons_todoCompletion: TypeConstructorDescription {
            public var id: Int32
            public var completedBy: Api.Peer
            public var date: Int32
            public init(id: Int32, completedBy: Api.Peer, date: Int32) {
                self.id = id
                self.completedBy = completedBy
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("todoCompletion", [("id", ConstructorParameterDescription(self.id)), ("completedBy", ConstructorParameterDescription(self.completedBy)), ("date", ConstructorParameterDescription(self.date))])
            }
        }
        case todoCompletion(Cons_todoCompletion)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .todoCompletion(let _data):
                if boxed {
                    buffer.appendInt32(572241380)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.completedBy.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .todoCompletion(let _data):
                return ("todoCompletion", [("id", ConstructorParameterDescription(_data.id)), ("completedBy", ConstructorParameterDescription(_data.completedBy)), ("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_todoCompletion(_ reader: BufferReader) -> TodoCompletion? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TodoCompletion.todoCompletion(Cons_todoCompletion(id: _1!, completedBy: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TodoItem: TypeConstructorDescription {
        public class Cons_todoItem: TypeConstructorDescription {
            public var id: Int32
            public var title: Api.TextWithEntities
            public init(id: Int32, title: Api.TextWithEntities) {
                self.id = id
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("todoItem", [("id", ConstructorParameterDescription(self.id)), ("title", ConstructorParameterDescription(self.title))])
            }
        }
        case todoItem(Cons_todoItem)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .todoItem(let _data):
                if boxed {
                    buffer.appendInt32(-878074577)
                }
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .todoItem(let _data):
                return ("todoItem", [("id", ConstructorParameterDescription(_data.id)), ("title", ConstructorParameterDescription(_data.title))])
            }
        }

        public static func parse_todoItem(_ reader: BufferReader) -> TodoItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TodoItem.todoItem(Cons_todoItem(id: _1!, title: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TodoList: TypeConstructorDescription {
        public class Cons_todoList: TypeConstructorDescription {
            public var flags: Int32
            public var title: Api.TextWithEntities
            public var list: [Api.TodoItem]
            public init(flags: Int32, title: Api.TextWithEntities, list: [Api.TodoItem]) {
                self.flags = flags
                self.title = title
                self.list = list
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("todoList", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("list", ConstructorParameterDescription(self.list))])
            }
        }
        case todoList(Cons_todoList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .todoList(let _data):
                if boxed {
                    buffer.appendInt32(1236871718)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.list.count))
                for item in _data.list {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .todoList(let _data):
                return ("todoList", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("list", ConstructorParameterDescription(_data.list))])
            }
        }

        public static func parse_todoList(_ reader: BufferReader) -> TodoList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _3: [Api.TodoItem]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TodoItem.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TodoList.todoList(Cons_todoList(flags: _1!, title: _2!, list: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TopPeer: TypeConstructorDescription {
        public class Cons_topPeer: TypeConstructorDescription {
            public var peer: Api.Peer
            public var rating: Double
            public init(peer: Api.Peer, rating: Double) {
                self.peer = peer
                self.rating = rating
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("topPeer", [("peer", ConstructorParameterDescription(self.peer)), ("rating", ConstructorParameterDescription(self.rating))])
            }
        }
        case topPeer(Cons_topPeer)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .topPeer(let _data):
                if boxed {
                    buffer.appendInt32(-305282981)
                }
                _data.peer.serialize(buffer, true)
                serializeDouble(_data.rating, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .topPeer(let _data):
                return ("topPeer", [("peer", ConstructorParameterDescription(_data.peer)), ("rating", ConstructorParameterDescription(_data.rating))])
            }
        }

        public static func parse_topPeer(_ reader: BufferReader) -> TopPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TopPeer.topPeer(Cons_topPeer(peer: _1!, rating: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum TopPeerCategory: TypeConstructorDescription {
        case topPeerCategoryBotsApp
        case topPeerCategoryBotsInline
        case topPeerCategoryBotsPM
        case topPeerCategoryChannels
        case topPeerCategoryCorrespondents
        case topPeerCategoryForwardChats
        case topPeerCategoryForwardUsers
        case topPeerCategoryGroups
        case topPeerCategoryPhoneCalls

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .topPeerCategoryBotsApp:
                if boxed {
                    buffer.appendInt32(-39945236)
                }
                break
            case .topPeerCategoryBotsInline:
                if boxed {
                    buffer.appendInt32(344356834)
                }
                break
            case .topPeerCategoryBotsPM:
                if boxed {
                    buffer.appendInt32(-1419371685)
                }
                break
            case .topPeerCategoryChannels:
                if boxed {
                    buffer.appendInt32(371037736)
                }
                break
            case .topPeerCategoryCorrespondents:
                if boxed {
                    buffer.appendInt32(104314861)
                }
                break
            case .topPeerCategoryForwardChats:
                if boxed {
                    buffer.appendInt32(-68239120)
                }
                break
            case .topPeerCategoryForwardUsers:
                if boxed {
                    buffer.appendInt32(-1472172887)
                }
                break
            case .topPeerCategoryGroups:
                if boxed {
                    buffer.appendInt32(-1122524854)
                }
                break
            case .topPeerCategoryPhoneCalls:
                if boxed {
                    buffer.appendInt32(511092620)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .topPeerCategoryBotsApp:
                return ("topPeerCategoryBotsApp", [])
            case .topPeerCategoryBotsInline:
                return ("topPeerCategoryBotsInline", [])
            case .topPeerCategoryBotsPM:
                return ("topPeerCategoryBotsPM", [])
            case .topPeerCategoryChannels:
                return ("topPeerCategoryChannels", [])
            case .topPeerCategoryCorrespondents:
                return ("topPeerCategoryCorrespondents", [])
            case .topPeerCategoryForwardChats:
                return ("topPeerCategoryForwardChats", [])
            case .topPeerCategoryForwardUsers:
                return ("topPeerCategoryForwardUsers", [])
            case .topPeerCategoryGroups:
                return ("topPeerCategoryGroups", [])
            case .topPeerCategoryPhoneCalls:
                return ("topPeerCategoryPhoneCalls", [])
            }
        }

        public static func parse_topPeerCategoryBotsApp(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsApp
        }
        public static func parse_topPeerCategoryBotsInline(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsInline
        }
        public static func parse_topPeerCategoryBotsPM(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsPM
        }
        public static func parse_topPeerCategoryChannels(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryChannels
        }
        public static func parse_topPeerCategoryCorrespondents(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryCorrespondents
        }
        public static func parse_topPeerCategoryForwardChats(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardChats
        }
        public static func parse_topPeerCategoryForwardUsers(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardUsers
        }
        public static func parse_topPeerCategoryGroups(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryGroups
        }
        public static func parse_topPeerCategoryPhoneCalls(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryPhoneCalls
        }
    }
}
