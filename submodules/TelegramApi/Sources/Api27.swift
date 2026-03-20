public extension Api {
    enum StatsAbsValueAndPrev: TypeConstructorDescription {
        public class Cons_statsAbsValueAndPrev: TypeConstructorDescription {
            public var current: Double
            public var previous: Double
            public init(current: Double, previous: Double) {
                self.current = current
                self.previous = previous
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsAbsValueAndPrev", [("current", self.current as Any), ("previous", self.previous as Any)])
            }
        }
        case statsAbsValueAndPrev(Cons_statsAbsValueAndPrev)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsAbsValueAndPrev(let _data):
                if boxed {
                    buffer.appendInt32(-884757282)
                }
                serializeDouble(_data.current, buffer: buffer, boxed: false)
                serializeDouble(_data.previous, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsAbsValueAndPrev(let _data):
                return ("statsAbsValueAndPrev", [("current", _data.current as Any), ("previous", _data.previous as Any)])
            }
        }

        public static func parse_statsAbsValueAndPrev(_ reader: BufferReader) -> StatsAbsValueAndPrev? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsAbsValueAndPrev.statsAbsValueAndPrev(Cons_statsAbsValueAndPrev(current: _1!, previous: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsDateRangeDays: TypeConstructorDescription {
        public class Cons_statsDateRangeDays: TypeConstructorDescription {
            public var minDate: Int32
            public var maxDate: Int32
            public init(minDate: Int32, maxDate: Int32) {
                self.minDate = minDate
                self.maxDate = maxDate
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsDateRangeDays", [("minDate", self.minDate as Any), ("maxDate", self.maxDate as Any)])
            }
        }
        case statsDateRangeDays(Cons_statsDateRangeDays)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsDateRangeDays(let _data):
                if boxed {
                    buffer.appendInt32(-1237848657)
                }
                serializeInt32(_data.minDate, buffer: buffer, boxed: false)
                serializeInt32(_data.maxDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsDateRangeDays(let _data):
                return ("statsDateRangeDays", [("minDate", _data.minDate as Any), ("maxDate", _data.maxDate as Any)])
            }
        }

        public static func parse_statsDateRangeDays(_ reader: BufferReader) -> StatsDateRangeDays? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsDateRangeDays.statsDateRangeDays(Cons_statsDateRangeDays(minDate: _1!, maxDate: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsGraph: TypeConstructorDescription {
        public class Cons_statsGraph: TypeConstructorDescription {
            public var flags: Int32
            public var json: Api.DataJSON
            public var zoomToken: String?
            public init(flags: Int32, json: Api.DataJSON, zoomToken: String?) {
                self.flags = flags
                self.json = json
                self.zoomToken = zoomToken
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGraph", [("flags", self.flags as Any), ("json", self.json as Any), ("zoomToken", self.zoomToken as Any)])
            }
        }
        public class Cons_statsGraphAsync: TypeConstructorDescription {
            public var token: String
            public init(token: String) {
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGraphAsync", [("token", self.token as Any)])
            }
        }
        public class Cons_statsGraphError: TypeConstructorDescription {
            public var error: String
            public init(error: String) {
                self.error = error
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGraphError", [("error", self.error as Any)])
            }
        }
        case statsGraph(Cons_statsGraph)
        case statsGraphAsync(Cons_statsGraphAsync)
        case statsGraphError(Cons_statsGraphError)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsGraph(let _data):
                if boxed {
                    buffer.appendInt32(-1901828938)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.json.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.zoomToken!, buffer: buffer, boxed: false)
                }
                break
            case .statsGraphAsync(let _data):
                if boxed {
                    buffer.appendInt32(1244130093)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                break
            case .statsGraphError(let _data):
                if boxed {
                    buffer.appendInt32(-1092839390)
                }
                serializeString(_data.error, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsGraph(let _data):
                return ("statsGraph", [("flags", _data.flags as Any), ("json", _data.json as Any), ("zoomToken", _data.zoomToken as Any)])
            case .statsGraphAsync(let _data):
                return ("statsGraphAsync", [("token", _data.token as Any)])
            case .statsGraphError(let _data):
                return ("statsGraphError", [("error", _data.error as Any)])
            }
        }

        public static func parse_statsGraph(_ reader: BufferReader) -> StatsGraph? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StatsGraph.statsGraph(Cons_statsGraph(flags: _1!, json: _2!, zoomToken: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_statsGraphAsync(_ reader: BufferReader) -> StatsGraph? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsGraph.statsGraphAsync(Cons_statsGraphAsync(token: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_statsGraphError(_ reader: BufferReader) -> StatsGraph? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsGraph.statsGraphError(Cons_statsGraphError(error: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsGroupTopAdmin: TypeConstructorDescription {
        public class Cons_statsGroupTopAdmin: TypeConstructorDescription {
            public var userId: Int64
            public var deleted: Int32
            public var kicked: Int32
            public var banned: Int32
            public init(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32) {
                self.userId = userId
                self.deleted = deleted
                self.kicked = kicked
                self.banned = banned
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGroupTopAdmin", [("userId", self.userId as Any), ("deleted", self.deleted as Any), ("kicked", self.kicked as Any), ("banned", self.banned as Any)])
            }
        }
        case statsGroupTopAdmin(Cons_statsGroupTopAdmin)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsGroupTopAdmin(let _data):
                if boxed {
                    buffer.appendInt32(-682079097)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.deleted, buffer: buffer, boxed: false)
                serializeInt32(_data.kicked, buffer: buffer, boxed: false)
                serializeInt32(_data.banned, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsGroupTopAdmin(let _data):
                return ("statsGroupTopAdmin", [("userId", _data.userId as Any), ("deleted", _data.deleted as Any), ("kicked", _data.kicked as Any), ("banned", _data.banned as Any)])
            }
        }

        public static func parse_statsGroupTopAdmin(_ reader: BufferReader) -> StatsGroupTopAdmin? {
            var _1: Int64?
            _1 = reader.readInt64()
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
                return Api.StatsGroupTopAdmin.statsGroupTopAdmin(Cons_statsGroupTopAdmin(userId: _1!, deleted: _2!, kicked: _3!, banned: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsGroupTopInviter: TypeConstructorDescription {
        public class Cons_statsGroupTopInviter: TypeConstructorDescription {
            public var userId: Int64
            public var invitations: Int32
            public init(userId: Int64, invitations: Int32) {
                self.userId = userId
                self.invitations = invitations
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGroupTopInviter", [("userId", self.userId as Any), ("invitations", self.invitations as Any)])
            }
        }
        case statsGroupTopInviter(Cons_statsGroupTopInviter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsGroupTopInviter(let _data):
                if boxed {
                    buffer.appendInt32(1398765469)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.invitations, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsGroupTopInviter(let _data):
                return ("statsGroupTopInviter", [("userId", _data.userId as Any), ("invitations", _data.invitations as Any)])
            }
        }

        public static func parse_statsGroupTopInviter(_ reader: BufferReader) -> StatsGroupTopInviter? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsGroupTopInviter.statsGroupTopInviter(Cons_statsGroupTopInviter(userId: _1!, invitations: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsGroupTopPoster: TypeConstructorDescription {
        public class Cons_statsGroupTopPoster: TypeConstructorDescription {
            public var userId: Int64
            public var messages: Int32
            public var avgChars: Int32
            public init(userId: Int64, messages: Int32, avgChars: Int32) {
                self.userId = userId
                self.messages = messages
                self.avgChars = avgChars
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsGroupTopPoster", [("userId", self.userId as Any), ("messages", self.messages as Any), ("avgChars", self.avgChars as Any)])
            }
        }
        case statsGroupTopPoster(Cons_statsGroupTopPoster)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsGroupTopPoster(let _data):
                if boxed {
                    buffer.appendInt32(-1660637285)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.messages, buffer: buffer, boxed: false)
                serializeInt32(_data.avgChars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsGroupTopPoster(let _data):
                return ("statsGroupTopPoster", [("userId", _data.userId as Any), ("messages", _data.messages as Any), ("avgChars", _data.avgChars as Any)])
            }
        }

        public static func parse_statsGroupTopPoster(_ reader: BufferReader) -> StatsGroupTopPoster? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StatsGroupTopPoster.statsGroupTopPoster(Cons_statsGroupTopPoster(userId: _1!, messages: _2!, avgChars: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsPercentValue: TypeConstructorDescription {
        public class Cons_statsPercentValue: TypeConstructorDescription {
            public var part: Double
            public var total: Double
            public init(part: Double, total: Double) {
                self.part = part
                self.total = total
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsPercentValue", [("part", self.part as Any), ("total", self.total as Any)])
            }
        }
        case statsPercentValue(Cons_statsPercentValue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsPercentValue(let _data):
                if boxed {
                    buffer.appendInt32(-875679776)
                }
                serializeDouble(_data.part, buffer: buffer, boxed: false)
                serializeDouble(_data.total, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsPercentValue(let _data):
                return ("statsPercentValue", [("part", _data.part as Any), ("total", _data.total as Any)])
            }
        }

        public static func parse_statsPercentValue(_ reader: BufferReader) -> StatsPercentValue? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StatsPercentValue.statsPercentValue(Cons_statsPercentValue(part: _1!, total: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StatsURL: TypeConstructorDescription {
        public class Cons_statsURL: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("statsURL", [("url", self.url as Any)])
            }
        }
        case statsURL(Cons_statsURL)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .statsURL(let _data):
                if boxed {
                    buffer.appendInt32(1202287072)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .statsURL(let _data):
                return ("statsURL", [("url", _data.url as Any)])
            }
        }

        public static func parse_statsURL(_ reader: BufferReader) -> StatsURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsURL.statsURL(Cons_statsURL(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StickerKeyword: TypeConstructorDescription {
        public class Cons_stickerKeyword: TypeConstructorDescription {
            public var documentId: Int64
            public var keyword: [String]
            public init(documentId: Int64, keyword: [String]) {
                self.documentId = documentId
                self.keyword = keyword
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerKeyword", [("documentId", self.documentId as Any), ("keyword", self.keyword as Any)])
            }
        }
        case stickerKeyword(Cons_stickerKeyword)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerKeyword(let _data):
                if boxed {
                    buffer.appendInt32(-50416996)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.keyword.count))
                for item in _data.keyword {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .stickerKeyword(let _data):
                return ("stickerKeyword", [("documentId", _data.documentId as Any), ("keyword", _data.keyword as Any)])
            }
        }

        public static func parse_stickerKeyword(_ reader: BufferReader) -> StickerKeyword? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerKeyword.stickerKeyword(Cons_stickerKeyword(documentId: _1!, keyword: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StickerPack: TypeConstructorDescription {
        public class Cons_stickerPack: TypeConstructorDescription {
            public var emoticon: String
            public var documents: [Int64]
            public init(emoticon: String, documents: [Int64]) {
                self.emoticon = emoticon
                self.documents = documents
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerPack", [("emoticon", self.emoticon as Any), ("documents", self.documents as Any)])
            }
        }
        case stickerPack(Cons_stickerPack)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerPack(let _data):
                if boxed {
                    buffer.appendInt32(313694676)
                }
                serializeString(_data.emoticon, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .stickerPack(let _data):
                return ("stickerPack", [("emoticon", _data.emoticon as Any), ("documents", _data.documents as Any)])
            }
        }

        public static func parse_stickerPack(_ reader: BufferReader) -> StickerPack? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerPack.stickerPack(Cons_stickerPack(emoticon: _1!, documents: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StickerSet: TypeConstructorDescription {
        public class Cons_stickerSet: TypeConstructorDescription {
            public var flags: Int32
            public var installedDate: Int32?
            public var id: Int64
            public var accessHash: Int64
            public var title: String
            public var shortName: String
            public var thumbs: [Api.PhotoSize]?
            public var thumbDcId: Int32?
            public var thumbVersion: Int32?
            public var thumbDocumentId: Int64?
            public var count: Int32
            public var hash: Int32
            public init(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, thumbDocumentId: Int64?, count: Int32, hash: Int32) {
                self.flags = flags
                self.installedDate = installedDate
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.shortName = shortName
                self.thumbs = thumbs
                self.thumbDcId = thumbDcId
                self.thumbVersion = thumbVersion
                self.thumbDocumentId = thumbDocumentId
                self.count = count
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerSet", [("flags", self.flags as Any), ("installedDate", self.installedDate as Any), ("id", self.id as Any), ("accessHash", self.accessHash as Any), ("title", self.title as Any), ("shortName", self.shortName as Any), ("thumbs", self.thumbs as Any), ("thumbDcId", self.thumbDcId as Any), ("thumbVersion", self.thumbVersion as Any), ("thumbDocumentId", self.thumbDocumentId as Any), ("count", self.count as Any), ("hash", self.hash as Any)])
            }
        }
        case stickerSet(Cons_stickerSet)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerSet(let _data):
                if boxed {
                    buffer.appendInt32(768691932)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.installedDate!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.thumbs!.count))
                    for item in _data.thumbs! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.thumbDcId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.thumbVersion!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.thumbDocumentId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .stickerSet(let _data):
                return ("stickerSet", [("flags", _data.flags as Any), ("installedDate", _data.installedDate as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("title", _data.title as Any), ("shortName", _data.shortName as Any), ("thumbs", _data.thumbs as Any), ("thumbDcId", _data.thumbDcId as Any), ("thumbVersion", _data.thumbVersion as Any), ("thumbDocumentId", _data.thumbDocumentId as Any), ("count", _data.count as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _10 = reader.readInt64()
            }
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 8) == 0) || _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.StickerSet.stickerSet(Cons_stickerSet(flags: _1!, installedDate: _2, id: _3!, accessHash: _4!, title: _5!, shortName: _6!, thumbs: _7, thumbDcId: _8, thumbVersion: _9, thumbDocumentId: _10, count: _11!, hash: _12!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        public class Cons_stickerSetCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public var cover: Api.Document
            public init(set: Api.StickerSet, cover: Api.Document) {
                self.set = set
                self.cover = cover
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerSetCovered", [("set", self.set as Any), ("cover", self.cover as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerSetFullCovered", [("set", self.set as Any), ("packs", self.packs as Any), ("keywords", self.keywords as Any), ("documents", self.documents as Any)])
            }
        }
        public class Cons_stickerSetMultiCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public var covers: [Api.Document]
            public init(set: Api.StickerSet, covers: [Api.Document]) {
                self.set = set
                self.covers = covers
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerSetMultiCovered", [("set", self.set as Any), ("covers", self.covers as Any)])
            }
        }
        public class Cons_stickerSetNoCovered: TypeConstructorDescription {
            public var set: Api.StickerSet
            public init(set: Api.StickerSet) {
                self.set = set
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("stickerSetNoCovered", [("set", self.set as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .stickerSetCovered(let _data):
                return ("stickerSetCovered", [("set", _data.set as Any), ("cover", _data.cover as Any)])
            case .stickerSetFullCovered(let _data):
                return ("stickerSetFullCovered", [("set", _data.set as Any), ("packs", _data.packs as Any), ("keywords", _data.keywords as Any), ("documents", _data.documents as Any)])
            case .stickerSetMultiCovered(let _data):
                return ("stickerSetMultiCovered", [("set", _data.set as Any), ("covers", _data.covers as Any)])
            case .stickerSetNoCovered(let _data):
                return ("stickerSetNoCovered", [("set", _data.set as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storiesStealthMode", [("flags", self.flags as Any), ("activeUntilDate", self.activeUntilDate as Any), ("cooldownUntilDate", self.cooldownUntilDate as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storiesStealthMode(let _data):
                return ("storiesStealthMode", [("flags", _data.flags as Any), ("activeUntilDate", _data.activeUntilDate as Any), ("cooldownUntilDate", _data.cooldownUntilDate as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyAlbum", [("flags", self.flags as Any), ("albumId", self.albumId as Any), ("title", self.title as Any), ("iconPhoto", self.iconPhoto as Any), ("iconVideo", self.iconVideo as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyAlbum(let _data):
                return ("storyAlbum", [("flags", _data.flags as Any), ("albumId", _data.albumId as Any), ("title", _data.title as Any), ("iconPhoto", _data.iconPhoto as Any), ("iconVideo", _data.iconVideo as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyFwdHeader", [("flags", self.flags as Any), ("from", self.from as Any), ("fromName", self.fromName as Any), ("storyId", self.storyId as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyFwdHeader(let _data):
                return ("storyFwdHeader", [("flags", _data.flags as Any), ("from", _data.from as Any), ("fromName", _data.fromName as Any), ("storyId", _data.storyId as Any)])
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
            public init(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?) {
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
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyItem", [("flags", self.flags as Any), ("id", self.id as Any), ("date", self.date as Any), ("fromId", self.fromId as Any), ("fwdFrom", self.fwdFrom as Any), ("expireDate", self.expireDate as Any), ("caption", self.caption as Any), ("entities", self.entities as Any), ("media", self.media as Any), ("mediaAreas", self.mediaAreas as Any), ("privacy", self.privacy as Any), ("views", self.views as Any), ("sentReaction", self.sentReaction as Any), ("albums", self.albums as Any)])
            }
        }
        public class Cons_storyItemDeleted: TypeConstructorDescription {
            public var id: Int32
            public init(id: Int32) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyItemDeleted", [("id", self.id as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyItemSkipped", [("flags", self.flags as Any), ("id", self.id as Any), ("date", self.date as Any), ("expireDate", self.expireDate as Any)])
            }
        }
        case storyItem(Cons_storyItem)
        case storyItemDeleted(Cons_storyItemDeleted)
        case storyItemSkipped(Cons_storyItemSkipped)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyItem(let _data):
                if boxed {
                    buffer.appendInt32(-302947087)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyItem(let _data):
                return ("storyItem", [("flags", _data.flags as Any), ("id", _data.id as Any), ("date", _data.date as Any), ("fromId", _data.fromId as Any), ("fwdFrom", _data.fwdFrom as Any), ("expireDate", _data.expireDate as Any), ("caption", _data.caption as Any), ("entities", _data.entities as Any), ("media", _data.media as Any), ("mediaAreas", _data.mediaAreas as Any), ("privacy", _data.privacy as Any), ("views", _data.views as Any), ("sentReaction", _data.sentReaction as Any), ("albums", _data.albums as Any)])
            case .storyItemDeleted(let _data):
                return ("storyItemDeleted", [("id", _data.id as Any)])
            case .storyItemSkipped(let _data):
                return ("storyItemSkipped", [("flags", _data.flags as Any), ("id", _data.id as Any), ("date", _data.date as Any), ("expireDate", _data.expireDate as Any)])
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.StoryItem.storyItem(Cons_storyItem(flags: _1!, id: _2!, date: _3!, fromId: _4, fwdFrom: _5, expireDate: _6!, caption: _7, entities: _8, media: _9!, mediaAreas: _10, privacy: _11, views: _12, sentReaction: _13, albums: _14))
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyReaction", [("peerId", self.peerId as Any), ("date", self.date as Any), ("reaction", self.reaction as Any)])
            }
        }
        public class Cons_storyReactionPublicForward: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyReactionPublicForward", [("message", self.message as Any)])
            }
        }
        public class Cons_storyReactionPublicRepost: TypeConstructorDescription {
            public var peerId: Api.Peer
            public var story: Api.StoryItem
            public init(peerId: Api.Peer, story: Api.StoryItem) {
                self.peerId = peerId
                self.story = story
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyReactionPublicRepost", [("peerId", self.peerId as Any), ("story", self.story as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyReaction(let _data):
                return ("storyReaction", [("peerId", _data.peerId as Any), ("date", _data.date as Any), ("reaction", _data.reaction as Any)])
            case .storyReactionPublicForward(let _data):
                return ("storyReactionPublicForward", [("message", _data.message as Any)])
            case .storyReactionPublicRepost(let _data):
                return ("storyReactionPublicRepost", [("peerId", _data.peerId as Any), ("story", _data.story as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyView", [("flags", self.flags as Any), ("userId", self.userId as Any), ("date", self.date as Any), ("reaction", self.reaction as Any)])
            }
        }
        public class Cons_storyViewPublicForward: TypeConstructorDescription {
            public var flags: Int32
            public var message: Api.Message
            public init(flags: Int32, message: Api.Message) {
                self.flags = flags
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyViewPublicForward", [("flags", self.flags as Any), ("message", self.message as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyViewPublicRepost", [("flags", self.flags as Any), ("peerId", self.peerId as Any), ("story", self.story as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyView(let _data):
                return ("storyView", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("date", _data.date as Any), ("reaction", _data.reaction as Any)])
            case .storyViewPublicForward(let _data):
                return ("storyViewPublicForward", [("flags", _data.flags as Any), ("message", _data.message as Any)])
            case .storyViewPublicRepost(let _data):
                return ("storyViewPublicRepost", [("flags", _data.flags as Any), ("peerId", _data.peerId as Any), ("story", _data.story as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("storyViews", [("flags", self.flags as Any), ("viewsCount", self.viewsCount as Any), ("forwardsCount", self.forwardsCount as Any), ("reactions", self.reactions as Any), ("reactionsCount", self.reactionsCount as Any), ("recentViewers", self.recentViewers as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyViews(let _data):
                return ("storyViews", [("flags", _data.flags as Any), ("viewsCount", _data.viewsCount as Any), ("forwardsCount", _data.forwardsCount as Any), ("reactions", _data.reactions as Any), ("reactionsCount", _data.reactionsCount as Any), ("recentViewers", _data.recentViewers as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("suggestedPost", [("flags", self.flags as Any), ("price", self.price as Any), ("scheduleDate", self.scheduleDate as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .suggestedPost(let _data):
                return ("suggestedPost", [("flags", _data.flags as Any), ("price", _data.price as Any), ("scheduleDate", _data.scheduleDate as Any)])
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
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("textWithEntities", [("text", self.text as Any), ("entities", self.entities as Any)])
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .textWithEntities(let _data):
                return ("textWithEntities", [("text", _data.text as Any), ("entities", _data.entities as Any)])
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
