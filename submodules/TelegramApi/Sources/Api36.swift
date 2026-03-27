public extension Api.messages {
    enum RecentStickers: TypeConstructorDescription {
        public class Cons_recentStickers: TypeConstructorDescription {
            public var hash: Int64
            public var packs: [Api.StickerPack]
            public var stickers: [Api.Document]
            public var dates: [Int32]
            public init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32]) {
                self.hash = hash
                self.packs = packs
                self.stickers = stickers
                self.dates = dates
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("recentStickers", [("hash", ConstructorParameterDescription(self.hash)), ("packs", ConstructorParameterDescription(self.packs)), ("stickers", ConstructorParameterDescription(self.stickers)), ("dates", ConstructorParameterDescription(self.dates))])
            }
        }
        case recentStickers(Cons_recentStickers)
        case recentStickersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .recentStickers(let _data):
                if boxed {
                    buffer.appendInt32(-1999405994)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.packs.count))
                for item in _data.packs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stickers.count))
                for item in _data.stickers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dates.count))
                for item in _data.dates {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            case .recentStickersNotModified:
                if boxed {
                    buffer.appendInt32(186120336)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .recentStickers(let _data):
                return ("recentStickers", [("hash", ConstructorParameterDescription(_data.hash)), ("packs", ConstructorParameterDescription(_data.packs)), ("stickers", ConstructorParameterDescription(_data.stickers)), ("dates", ConstructorParameterDescription(_data.dates))])
            case .recentStickersNotModified:
                return ("recentStickersNotModified", [])
            }
        }

        public static func parse_recentStickers(_ reader: BufferReader) -> RecentStickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            var _4: [Int32]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.RecentStickers.recentStickers(Cons_recentStickers(hash: _1!, packs: _2!, stickers: _3!, dates: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_recentStickersNotModified(_ reader: BufferReader) -> RecentStickers? {
            return Api.messages.RecentStickers.recentStickersNotModified
        }
    }
}
public extension Api.messages {
    enum SavedDialogs: TypeConstructorDescription {
        public class Cons_savedDialogs: TypeConstructorDescription {
            public var dialogs: [Api.SavedDialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedDialogs", [("dialogs", ConstructorParameterDescription(self.dialogs)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        public class Cons_savedDialogsNotModified: TypeConstructorDescription {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedDialogsNotModified", [("count", ConstructorParameterDescription(self.count))])
            }
        }
        public class Cons_savedDialogsSlice: TypeConstructorDescription {
            public var count: Int32
            public var dialogs: [Api.SavedDialog]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(count: Int32, dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.count = count
                self.dialogs = dialogs
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedDialogsSlice", [("count", ConstructorParameterDescription(self.count)), ("dialogs", ConstructorParameterDescription(self.dialogs)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case savedDialogs(Cons_savedDialogs)
        case savedDialogsNotModified(Cons_savedDialogsNotModified)
        case savedDialogsSlice(Cons_savedDialogsSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedDialogs(let _data):
                if boxed {
                    buffer.appendInt32(-130358751)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dialogs.count))
                for item in _data.dialogs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .savedDialogsNotModified(let _data):
                if boxed {
                    buffer.appendInt32(-1071681560)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            case .savedDialogsSlice(let _data):
                if boxed {
                    buffer.appendInt32(1153080793)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.dialogs.count))
                for item in _data.dialogs {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedDialogs(let _data):
                return ("savedDialogs", [("dialogs", ConstructorParameterDescription(_data.dialogs)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .savedDialogsNotModified(let _data):
                return ("savedDialogsNotModified", [("count", ConstructorParameterDescription(_data.count))])
            case .savedDialogsSlice(let _data):
                return ("savedDialogsSlice", [("count", ConstructorParameterDescription(_data.count)), ("dialogs", ConstructorParameterDescription(_data.dialogs)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_savedDialogs(_ reader: BufferReader) -> SavedDialogs? {
            var _1: [Api.SavedDialog]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedDialog.self)
            }
            var _2: [Api.Message]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.messages.SavedDialogs.savedDialogs(Cons_savedDialogs(dialogs: _1!, messages: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedDialogsNotModified(_ reader: BufferReader) -> SavedDialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.SavedDialogs.savedDialogsNotModified(Cons_savedDialogsNotModified(count: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedDialogsSlice(_ reader: BufferReader) -> SavedDialogs? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SavedDialog]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedDialog.self)
            }
            var _3: [Api.Message]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.SavedDialogs.savedDialogsSlice(Cons_savedDialogsSlice(count: _1!, dialogs: _2!, messages: _3!, chats: _4!, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum SavedGifs: TypeConstructorDescription {
        public class Cons_savedGifs: TypeConstructorDescription {
            public var hash: Int64
            public var gifs: [Api.Document]
            public init(hash: Int64, gifs: [Api.Document]) {
                self.hash = hash
                self.gifs = gifs
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedGifs", [("hash", ConstructorParameterDescription(self.hash)), ("gifs", ConstructorParameterDescription(self.gifs))])
            }
        }
        case savedGifs(Cons_savedGifs)
        case savedGifsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedGifs(let _data):
                if boxed {
                    buffer.appendInt32(-2069878259)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.gifs.count))
                for item in _data.gifs {
                    item.serialize(buffer, true)
                }
                break
            case .savedGifsNotModified:
                if boxed {
                    buffer.appendInt32(-402498398)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedGifs(let _data):
                return ("savedGifs", [("hash", ConstructorParameterDescription(_data.hash)), ("gifs", ConstructorParameterDescription(_data.gifs))])
            case .savedGifsNotModified:
                return ("savedGifsNotModified", [])
            }
        }

        public static func parse_savedGifs(_ reader: BufferReader) -> SavedGifs? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SavedGifs.savedGifs(Cons_savedGifs(hash: _1!, gifs: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedGifsNotModified(_ reader: BufferReader) -> SavedGifs? {
            return Api.messages.SavedGifs.savedGifsNotModified
        }
    }
}
public extension Api.messages {
    enum SavedReactionTags: TypeConstructorDescription {
        public class Cons_savedReactionTags: TypeConstructorDescription {
            public var tags: [Api.SavedReactionTag]
            public var hash: Int64
            public init(tags: [Api.SavedReactionTag], hash: Int64) {
                self.tags = tags
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedReactionTags", [("tags", ConstructorParameterDescription(self.tags)), ("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        case savedReactionTags(Cons_savedReactionTags)
        case savedReactionTagsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedReactionTags(let _data):
                if boxed {
                    buffer.appendInt32(844731658)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.tags.count))
                for item in _data.tags {
                    item.serialize(buffer, true)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            case .savedReactionTagsNotModified:
                if boxed {
                    buffer.appendInt32(-2003084817)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedReactionTags(let _data):
                return ("savedReactionTags", [("tags", ConstructorParameterDescription(_data.tags)), ("hash", ConstructorParameterDescription(_data.hash))])
            case .savedReactionTagsNotModified:
                return ("savedReactionTagsNotModified", [])
            }
        }

        public static func parse_savedReactionTags(_ reader: BufferReader) -> SavedReactionTags? {
            var _1: [Api.SavedReactionTag]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedReactionTag.self)
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SavedReactionTags.savedReactionTags(Cons_savedReactionTags(tags: _1!, hash: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedReactionTagsNotModified(_ reader: BufferReader) -> SavedReactionTags? {
            return Api.messages.SavedReactionTags.savedReactionTagsNotModified
        }
    }
}
public extension Api.messages {
    enum SearchCounter: TypeConstructorDescription {
        public class Cons_searchCounter: TypeConstructorDescription {
            public var flags: Int32
            public var filter: Api.MessagesFilter
            public var count: Int32
            public init(flags: Int32, filter: Api.MessagesFilter, count: Int32) {
                self.flags = flags
                self.filter = filter
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("searchCounter", [("flags", ConstructorParameterDescription(self.flags)), ("filter", ConstructorParameterDescription(self.filter)), ("count", ConstructorParameterDescription(self.count))])
            }
        }
        case searchCounter(Cons_searchCounter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchCounter(let _data):
                if boxed {
                    buffer.appendInt32(-398136321)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.filter.serialize(buffer, true)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .searchCounter(let _data):
                return ("searchCounter", [("flags", ConstructorParameterDescription(_data.flags)), ("filter", ConstructorParameterDescription(_data.filter)), ("count", ConstructorParameterDescription(_data.count))])
            }
        }

        public static func parse_searchCounter(_ reader: BufferReader) -> SearchCounter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MessagesFilter?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MessagesFilter
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.SearchCounter.searchCounter(Cons_searchCounter(flags: _1!, filter: _2!, count: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum SearchResultsCalendar: TypeConstructorDescription {
        public class Cons_searchResultsCalendar: TypeConstructorDescription {
            public var flags: Int32
            public var count: Int32
            public var minDate: Int32
            public var minMsgId: Int32
            public var offsetIdOffset: Int32?
            public var periods: [Api.SearchResultsCalendarPeriod]
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, minDate: Int32, minMsgId: Int32, offsetIdOffset: Int32?, periods: [Api.SearchResultsCalendarPeriod], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.minDate = minDate
                self.minMsgId = minMsgId
                self.offsetIdOffset = offsetIdOffset
                self.periods = periods
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("searchResultsCalendar", [("flags", ConstructorParameterDescription(self.flags)), ("count", ConstructorParameterDescription(self.count)), ("minDate", ConstructorParameterDescription(self.minDate)), ("minMsgId", ConstructorParameterDescription(self.minMsgId)), ("offsetIdOffset", ConstructorParameterDescription(self.offsetIdOffset)), ("periods", ConstructorParameterDescription(self.periods)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case searchResultsCalendar(Cons_searchResultsCalendar)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultsCalendar(let _data):
                if boxed {
                    buffer.appendInt32(343859772)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                serializeInt32(_data.minDate, buffer: buffer, boxed: false)
                serializeInt32(_data.minMsgId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.offsetIdOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.periods.count))
                for item in _data.periods {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .searchResultsCalendar(let _data):
                return ("searchResultsCalendar", [("flags", ConstructorParameterDescription(_data.flags)), ("count", ConstructorParameterDescription(_data.count)), ("minDate", ConstructorParameterDescription(_data.minDate)), ("minMsgId", ConstructorParameterDescription(_data.minMsgId)), ("offsetIdOffset", ConstructorParameterDescription(_data.offsetIdOffset)), ("periods", ConstructorParameterDescription(_data.periods)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_searchResultsCalendar(_ reader: BufferReader) -> SearchResultsCalendar? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            var _6: [Api.SearchResultsCalendarPeriod]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SearchResultsCalendarPeriod.self)
            }
            var _7: [Api.Message]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.messages.SearchResultsCalendar.searchResultsCalendar(Cons_searchResultsCalendar(flags: _1!, count: _2!, minDate: _3!, minMsgId: _4!, offsetIdOffset: _5, periods: _6!, messages: _7!, chats: _8!, users: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum SearchResultsPositions: TypeConstructorDescription {
        public class Cons_searchResultsPositions: TypeConstructorDescription {
            public var count: Int32
            public var positions: [Api.SearchResultsPosition]
            public init(count: Int32, positions: [Api.SearchResultsPosition]) {
                self.count = count
                self.positions = positions
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("searchResultsPositions", [("count", ConstructorParameterDescription(self.count)), ("positions", ConstructorParameterDescription(self.positions))])
            }
        }
        case searchResultsPositions(Cons_searchResultsPositions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultsPositions(let _data):
                if boxed {
                    buffer.appendInt32(1404185519)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.positions.count))
                for item in _data.positions {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .searchResultsPositions(let _data):
                return ("searchResultsPositions", [("count", ConstructorParameterDescription(_data.count)), ("positions", ConstructorParameterDescription(_data.positions))])
            }
        }

        public static func parse_searchResultsPositions(_ reader: BufferReader) -> SearchResultsPositions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SearchResultsPosition]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SearchResultsPosition.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SearchResultsPositions.searchResultsPositions(Cons_searchResultsPositions(count: _1!, positions: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum SentEncryptedMessage: TypeConstructorDescription {
        public class Cons_sentEncryptedFile: TypeConstructorDescription {
            public var date: Int32
            public var file: Api.EncryptedFile
            public init(date: Int32, file: Api.EncryptedFile) {
                self.date = date
                self.file = file
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentEncryptedFile", [("date", ConstructorParameterDescription(self.date)), ("file", ConstructorParameterDescription(self.file))])
            }
        }
        public class Cons_sentEncryptedMessage: TypeConstructorDescription {
            public var date: Int32
            public init(date: Int32) {
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentEncryptedMessage", [("date", ConstructorParameterDescription(self.date))])
            }
        }
        case sentEncryptedFile(Cons_sentEncryptedFile)
        case sentEncryptedMessage(Cons_sentEncryptedMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sentEncryptedFile(let _data):
                if boxed {
                    buffer.appendInt32(-1802240206)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.file.serialize(buffer, true)
                break
            case .sentEncryptedMessage(let _data):
                if boxed {
                    buffer.appendInt32(1443858741)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sentEncryptedFile(let _data):
                return ("sentEncryptedFile", [("date", ConstructorParameterDescription(_data.date)), ("file", ConstructorParameterDescription(_data.file))])
            case .sentEncryptedMessage(let _data):
                return ("sentEncryptedMessage", [("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_sentEncryptedFile(_ reader: BufferReader) -> SentEncryptedMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.EncryptedFile?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EncryptedFile
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.SentEncryptedMessage.sentEncryptedFile(Cons_sentEncryptedFile(date: _1!, file: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_sentEncryptedMessage(_ reader: BufferReader) -> SentEncryptedMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.SentEncryptedMessage.sentEncryptedMessage(Cons_sentEncryptedMessage(date: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum SponsoredMessages: TypeConstructorDescription {
        public class Cons_sponsoredMessages: TypeConstructorDescription {
            public var flags: Int32
            public var postsBetween: Int32?
            public var startDelay: Int32?
            public var betweenDelay: Int32?
            public var messages: [Api.SponsoredMessage]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, postsBetween: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.postsBetween = postsBetween
                self.startDelay = startDelay
                self.betweenDelay = betweenDelay
                self.messages = messages
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sponsoredMessages", [("flags", ConstructorParameterDescription(self.flags)), ("postsBetween", ConstructorParameterDescription(self.postsBetween)), ("startDelay", ConstructorParameterDescription(self.startDelay)), ("betweenDelay", ConstructorParameterDescription(self.betweenDelay)), ("messages", ConstructorParameterDescription(self.messages)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case sponsoredMessages(Cons_sponsoredMessages)
        case sponsoredMessagesEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sponsoredMessages(let _data):
                if boxed {
                    buffer.appendInt32(-2464403)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.postsBetween!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.startDelay!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.betweenDelay!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .sponsoredMessagesEmpty:
                if boxed {
                    buffer.appendInt32(406407439)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sponsoredMessages(let _data):
                return ("sponsoredMessages", [("flags", ConstructorParameterDescription(_data.flags)), ("postsBetween", ConstructorParameterDescription(_data.postsBetween)), ("startDelay", ConstructorParameterDescription(_data.startDelay)), ("betweenDelay", ConstructorParameterDescription(_data.betweenDelay)), ("messages", ConstructorParameterDescription(_data.messages)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            case .sponsoredMessagesEmpty:
                return ("sponsoredMessagesEmpty", [])
            }
        }

        public static func parse_sponsoredMessages(_ reader: BufferReader) -> SponsoredMessages? {
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
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = reader.readInt32()
            }
            var _5: [Api.SponsoredMessage]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SponsoredMessage.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.messages.SponsoredMessages.sponsoredMessages(Cons_sponsoredMessages(flags: _1!, postsBetween: _2, startDelay: _3, betweenDelay: _4, messages: _5!, chats: _6!, users: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_sponsoredMessagesEmpty(_ reader: BufferReader) -> SponsoredMessages? {
            return Api.messages.SponsoredMessages.sponsoredMessagesEmpty
        }
    }
}
public extension Api.messages {
    enum StickerSet: TypeConstructorDescription {
        public class Cons_stickerSet: TypeConstructorDescription {
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
                return ("stickerSet", [("set", ConstructorParameterDescription(self.set)), ("packs", ConstructorParameterDescription(self.packs)), ("keywords", ConstructorParameterDescription(self.keywords)), ("documents", ConstructorParameterDescription(self.documents))])
            }
        }
        case stickerSet(Cons_stickerSet)
        case stickerSetNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerSet(let _data):
                if boxed {
                    buffer.appendInt32(1846886166)
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
            case .stickerSetNotModified:
                if boxed {
                    buffer.appendInt32(-738646805)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerSet(let _data):
                return ("stickerSet", [("set", ConstructorParameterDescription(_data.set)), ("packs", ConstructorParameterDescription(_data.packs)), ("keywords", ConstructorParameterDescription(_data.keywords)), ("documents", ConstructorParameterDescription(_data.documents))])
            case .stickerSetNotModified:
                return ("stickerSetNotModified", [])
            }
        }

        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
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
                return Api.messages.StickerSet.stickerSet(Cons_stickerSet(set: _1!, packs: _2!, keywords: _3!, documents: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetNotModified(_ reader: BufferReader) -> StickerSet? {
            return Api.messages.StickerSet.stickerSetNotModified
        }
    }
}
public extension Api.messages {
    enum StickerSetInstallResult: TypeConstructorDescription {
        public class Cons_stickerSetInstallResultArchive: TypeConstructorDescription {
            public var sets: [Api.StickerSetCovered]
            public init(sets: [Api.StickerSetCovered]) {
                self.sets = sets
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSetInstallResultArchive", [("sets", ConstructorParameterDescription(self.sets))])
            }
        }
        case stickerSetInstallResultArchive(Cons_stickerSetInstallResultArchive)
        case stickerSetInstallResultSuccess

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickerSetInstallResultArchive(let _data):
                if boxed {
                    buffer.appendInt32(904138920)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sets.count))
                for item in _data.sets {
                    item.serialize(buffer, true)
                }
                break
            case .stickerSetInstallResultSuccess:
                if boxed {
                    buffer.appendInt32(946083368)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerSetInstallResultArchive(let _data):
                return ("stickerSetInstallResultArchive", [("sets", ConstructorParameterDescription(_data.sets))])
            case .stickerSetInstallResultSuccess:
                return ("stickerSetInstallResultSuccess", [])
            }
        }

        public static func parse_stickerSetInstallResultArchive(_ reader: BufferReader) -> StickerSetInstallResult? {
            var _1: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.StickerSetInstallResult.stickerSetInstallResultArchive(Cons_stickerSetInstallResultArchive(sets: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetInstallResultSuccess(_ reader: BufferReader) -> StickerSetInstallResult? {
            return Api.messages.StickerSetInstallResult.stickerSetInstallResultSuccess
        }
    }
}
public extension Api.messages {
    enum Stickers: TypeConstructorDescription {
        public class Cons_stickers: TypeConstructorDescription {
            public var hash: Int64
            public var stickers: [Api.Document]
            public init(hash: Int64, stickers: [Api.Document]) {
                self.hash = hash
                self.stickers = stickers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickers", [("hash", ConstructorParameterDescription(self.hash)), ("stickers", ConstructorParameterDescription(self.stickers))])
            }
        }
        case stickers(Cons_stickers)
        case stickersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stickers(let _data):
                if boxed {
                    buffer.appendInt32(816245886)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stickers.count))
                for item in _data.stickers {
                    item.serialize(buffer, true)
                }
                break
            case .stickersNotModified:
                if boxed {
                    buffer.appendInt32(-244016606)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickers(let _data):
                return ("stickers", [("hash", ConstructorParameterDescription(_data.hash)), ("stickers", ConstructorParameterDescription(_data.stickers))])
            case .stickersNotModified:
                return ("stickersNotModified", [])
            }
        }

        public static func parse_stickers(_ reader: BufferReader) -> Stickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Stickers.stickers(Cons_stickers(hash: _1!, stickers: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_stickersNotModified(_ reader: BufferReader) -> Stickers? {
            return Api.messages.Stickers.stickersNotModified
        }
    }
}
public extension Api.messages {
    enum TranscribedAudio: TypeConstructorDescription {
        public class Cons_transcribedAudio: TypeConstructorDescription {
            public var flags: Int32
            public var transcriptionId: Int64
            public var text: String
            public var trialRemainsNum: Int32?
            public var trialRemainsUntilDate: Int32?
            public init(flags: Int32, transcriptionId: Int64, text: String, trialRemainsNum: Int32?, trialRemainsUntilDate: Int32?) {
                self.flags = flags
                self.transcriptionId = transcriptionId
                self.text = text
                self.trialRemainsNum = trialRemainsNum
                self.trialRemainsUntilDate = trialRemainsUntilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("transcribedAudio", [("flags", ConstructorParameterDescription(self.flags)), ("transcriptionId", ConstructorParameterDescription(self.transcriptionId)), ("text", ConstructorParameterDescription(self.text)), ("trialRemainsNum", ConstructorParameterDescription(self.trialRemainsNum)), ("trialRemainsUntilDate", ConstructorParameterDescription(self.trialRemainsUntilDate))])
            }
        }
        case transcribedAudio(Cons_transcribedAudio)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .transcribedAudio(let _data):
                if boxed {
                    buffer.appendInt32(-809903785)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.transcriptionId, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.trialRemainsNum!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.trialRemainsUntilDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .transcribedAudio(let _data):
                return ("transcribedAudio", [("flags", ConstructorParameterDescription(_data.flags)), ("transcriptionId", ConstructorParameterDescription(_data.transcriptionId)), ("text", ConstructorParameterDescription(_data.text)), ("trialRemainsNum", ConstructorParameterDescription(_data.trialRemainsNum)), ("trialRemainsUntilDate", ConstructorParameterDescription(_data.trialRemainsUntilDate))])
            }
        }

        public static func parse_transcribedAudio(_ reader: BufferReader) -> TranscribedAudio? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.TranscribedAudio.transcribedAudio(Cons_transcribedAudio(flags: _1!, transcriptionId: _2!, text: _3!, trialRemainsNum: _4, trialRemainsUntilDate: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum TranslatedText: TypeConstructorDescription {
        public class Cons_translateResult: TypeConstructorDescription {
            public var result: [Api.TextWithEntities]
            public init(result: [Api.TextWithEntities]) {
                self.result = result
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("translateResult", [("result", ConstructorParameterDescription(self.result))])
            }
        }
        case translateResult(Cons_translateResult)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .translateResult(let _data):
                if boxed {
                    buffer.appendInt32(870003448)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.result.count))
                for item in _data.result {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .translateResult(let _data):
                return ("translateResult", [("result", ConstructorParameterDescription(_data.result))])
            }
        }

        public static func parse_translateResult(_ reader: BufferReader) -> TranslatedText? {
            var _1: [Api.TextWithEntities]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TextWithEntities.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.TranslatedText.translateResult(Cons_translateResult(result: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum VotesList: TypeConstructorDescription {
        public class Cons_votesList: TypeConstructorDescription {
            public var flags: Int32
            public var count: Int32
            public var votes: [Api.MessagePeerVote]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, votes: [Api.MessagePeerVote], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.votes = votes
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("votesList", [("flags", ConstructorParameterDescription(self.flags)), ("count", ConstructorParameterDescription(self.count)), ("votes", ConstructorParameterDescription(self.votes)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users)), ("nextOffset", ConstructorParameterDescription(self.nextOffset))])
            }
        }
        case votesList(Cons_votesList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .votesList(let _data):
                if boxed {
                    buffer.appendInt32(1218005070)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.votes.count))
                for item in _data.votes {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .votesList(let _data):
                return ("votesList", [("flags", ConstructorParameterDescription(_data.flags)), ("count", ConstructorParameterDescription(_data.count)), ("votes", ConstructorParameterDescription(_data.votes)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset))])
            }
        }

        public static func parse_votesList(_ reader: BufferReader) -> VotesList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessagePeerVote]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerVote.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.messages.VotesList.votesList(Cons_votesList(flags: _1!, count: _2!, votes: _3!, chats: _4!, users: _5!, nextOffset: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    enum WebPage: TypeConstructorDescription {
        public class Cons_webPage: TypeConstructorDescription {
            public var webpage: Api.WebPage
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(webpage: Api.WebPage, chats: [Api.Chat], users: [Api.User]) {
                self.webpage = webpage
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPage", [("webpage", ConstructorParameterDescription(self.webpage)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case webPage(Cons_webPage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPage(let _data):
                if boxed {
                    buffer.appendInt32(-44166467)
                }
                _data.webpage.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webPage(let _data):
                return ("webPage", [("webpage", ConstructorParameterDescription(_data.webpage)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.WebPage.webPage(Cons_webPage(webpage: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.messages {
    indirect enum WebPagePreview: TypeConstructorDescription {
        public class Cons_webPagePreview: TypeConstructorDescription {
            public var media: Api.MessageMedia
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(media: Api.MessageMedia, chats: [Api.Chat], users: [Api.User]) {
                self.media = media
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webPagePreview", [("media", ConstructorParameterDescription(self.media)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case webPagePreview(Cons_webPagePreview)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webPagePreview(let _data):
                if boxed {
                    buffer.appendInt32(-1936029524)
                }
                _data.media.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webPagePreview(let _data):
                return ("webPagePreview", [("media", ConstructorParameterDescription(_data.media)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_webPagePreview(_ reader: BufferReader) -> WebPagePreview? {
            var _1: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.WebPagePreview.webPagePreview(Cons_webPagePreview(media: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum BankCardData: TypeConstructorDescription {
        public class Cons_bankCardData: TypeConstructorDescription {
            public var title: String
            public var openUrls: [Api.BankCardOpenUrl]
            public init(title: String, openUrls: [Api.BankCardOpenUrl]) {
                self.title = title
                self.openUrls = openUrls
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("bankCardData", [("title", ConstructorParameterDescription(self.title)), ("openUrls", ConstructorParameterDescription(self.openUrls))])
            }
        }
        case bankCardData(Cons_bankCardData)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .bankCardData(let _data):
                if boxed {
                    buffer.appendInt32(1042605427)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.openUrls.count))
                for item in _data.openUrls {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .bankCardData(let _data):
                return ("bankCardData", [("title", ConstructorParameterDescription(_data.title)), ("openUrls", ConstructorParameterDescription(_data.openUrls))])
            }
        }

        public static func parse_bankCardData(_ reader: BufferReader) -> BankCardData? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.BankCardOpenUrl]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BankCardOpenUrl.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.payments.BankCardData.bankCardData(Cons_bankCardData(title: _1!, openUrls: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum CheckCanSendGiftResult: TypeConstructorDescription {
        public class Cons_checkCanSendGiftResultFail: TypeConstructorDescription {
            public var reason: Api.TextWithEntities
            public init(reason: Api.TextWithEntities) {
                self.reason = reason
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("checkCanSendGiftResultFail", [("reason", ConstructorParameterDescription(self.reason))])
            }
        }
        case checkCanSendGiftResultFail(Cons_checkCanSendGiftResultFail)
        case checkCanSendGiftResultOk

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .checkCanSendGiftResultFail(let _data):
                if boxed {
                    buffer.appendInt32(-706379148)
                }
                _data.reason.serialize(buffer, true)
                break
            case .checkCanSendGiftResultOk:
                if boxed {
                    buffer.appendInt32(927967149)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .checkCanSendGiftResultFail(let _data):
                return ("checkCanSendGiftResultFail", [("reason", ConstructorParameterDescription(_data.reason))])
            case .checkCanSendGiftResultOk:
                return ("checkCanSendGiftResultOk", [])
            }
        }

        public static func parse_checkCanSendGiftResultFail(_ reader: BufferReader) -> CheckCanSendGiftResult? {
            var _1: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.CheckCanSendGiftResult.checkCanSendGiftResultFail(Cons_checkCanSendGiftResultFail(reason: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_checkCanSendGiftResultOk(_ reader: BufferReader) -> CheckCanSendGiftResult? {
            return Api.payments.CheckCanSendGiftResult.checkCanSendGiftResultOk
        }
    }
}
public extension Api.payments {
    enum CheckedGiftCode: TypeConstructorDescription {
        public class Cons_checkedGiftCode: TypeConstructorDescription {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var giveawayMsgId: Int32?
            public var toId: Int64?
            public var date: Int32
            public var days: Int32
            public var usedDate: Int32?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, fromId: Api.Peer?, giveawayMsgId: Int32?, toId: Int64?, date: Int32, days: Int32, usedDate: Int32?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.fromId = fromId
                self.giveawayMsgId = giveawayMsgId
                self.toId = toId
                self.date = date
                self.days = days
                self.usedDate = usedDate
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("checkedGiftCode", [("flags", ConstructorParameterDescription(self.flags)), ("fromId", ConstructorParameterDescription(self.fromId)), ("giveawayMsgId", ConstructorParameterDescription(self.giveawayMsgId)), ("toId", ConstructorParameterDescription(self.toId)), ("date", ConstructorParameterDescription(self.date)), ("days", ConstructorParameterDescription(self.days)), ("usedDate", ConstructorParameterDescription(self.usedDate)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case checkedGiftCode(Cons_checkedGiftCode)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .checkedGiftCode(let _data):
                if boxed {
                    buffer.appendInt32(-342343793)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.giveawayMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.toId!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.days, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.usedDate!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .checkedGiftCode(let _data):
                return ("checkedGiftCode", [("flags", ConstructorParameterDescription(_data.flags)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("giveawayMsgId", ConstructorParameterDescription(_data.giveawayMsgId)), ("toId", ConstructorParameterDescription(_data.toId)), ("date", ConstructorParameterDescription(_data.date)), ("days", ConstructorParameterDescription(_data.days)), ("usedDate", ConstructorParameterDescription(_data.usedDate)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_checkedGiftCode(_ reader: BufferReader) -> CheckedGiftCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = reader.readInt32()
            }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.CheckedGiftCode.checkedGiftCode(Cons_checkedGiftCode(flags: _1!, fromId: _2, giveawayMsgId: _3, toId: _4, date: _5!, days: _6!, usedDate: _7, chats: _8!, users: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum ConnectedStarRefBots: TypeConstructorDescription {
        public class Cons_connectedStarRefBots: TypeConstructorDescription {
            public var count: Int32
            public var connectedBots: [Api.ConnectedBotStarRef]
            public var users: [Api.User]
            public init(count: Int32, connectedBots: [Api.ConnectedBotStarRef], users: [Api.User]) {
                self.count = count
                self.connectedBots = connectedBots
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("connectedStarRefBots", [("count", ConstructorParameterDescription(self.count)), ("connectedBots", ConstructorParameterDescription(self.connectedBots)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case connectedStarRefBots(Cons_connectedStarRefBots)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .connectedStarRefBots(let _data):
                if boxed {
                    buffer.appendInt32(-1730811363)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.connectedBots.count))
                for item in _data.connectedBots {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .connectedStarRefBots(let _data):
                return ("connectedStarRefBots", [("count", ConstructorParameterDescription(_data.count)), ("connectedBots", ConstructorParameterDescription(_data.connectedBots)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_connectedStarRefBots(_ reader: BufferReader) -> ConnectedStarRefBots? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ConnectedBotStarRef]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ConnectedBotStarRef.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.ConnectedStarRefBots.connectedStarRefBots(Cons_connectedStarRefBots(count: _1!, connectedBots: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
