public extension Api {
    enum SavedReactionTag: TypeConstructorDescription {
        public class Cons_savedReactionTag: TypeConstructorDescription {
            public var flags: Int32
            public var reaction: Api.Reaction
            public var title: String?
            public var count: Int32
            public init(flags: Int32, reaction: Api.Reaction, title: String?, count: Int32) {
                self.flags = flags
                self.reaction = reaction
                self.title = title
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("savedReactionTag", [("flags", self.flags as Any), ("reaction", self.reaction as Any), ("title", self.title as Any), ("count", self.count as Any)])
            }
        }
        case savedReactionTag(Cons_savedReactionTag)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedReactionTag(let _data):
                if boxed {
                    buffer.appendInt32(-881854424)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.reaction.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedReactionTag(let _data):
                return ("savedReactionTag", [("flags", _data.flags as Any), ("reaction", _data.reaction as Any), ("title", _data.title as Any), ("count", _data.count as Any)])
            }
        }

        public static func parse_savedReactionTag(_ reader: BufferReader) -> SavedReactionTag? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Reaction?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SavedReactionTag.savedReactionTag(Cons_savedReactionTag(flags: _1!, reaction: _2!, title: _3, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SavedStarGift: TypeConstructorDescription {
        public class Cons_savedStarGift: TypeConstructorDescription {
            public var flags: Int32
            public var fromId: Api.Peer?
            public var date: Int32
            public var gift: Api.StarGift
            public var message: Api.TextWithEntities?
            public var msgId: Int32?
            public var savedId: Int64?
            public var convertStars: Int64?
            public var upgradeStars: Int64?
            public var canExportAt: Int32?
            public var transferStars: Int64?
            public var canTransferAt: Int32?
            public var canResellAt: Int32?
            public var collectionId: [Int32]?
            public var prepaidUpgradeHash: String?
            public var dropOriginalDetailsStars: Int64?
            public var giftNum: Int32?
            public var canCraftAt: Int32?
            public init(flags: Int32, fromId: Api.Peer?, date: Int32, gift: Api.StarGift, message: Api.TextWithEntities?, msgId: Int32?, savedId: Int64?, convertStars: Int64?, upgradeStars: Int64?, canExportAt: Int32?, transferStars: Int64?, canTransferAt: Int32?, canResellAt: Int32?, collectionId: [Int32]?, prepaidUpgradeHash: String?, dropOriginalDetailsStars: Int64?, giftNum: Int32?, canCraftAt: Int32?) {
                self.flags = flags
                self.fromId = fromId
                self.date = date
                self.gift = gift
                self.message = message
                self.msgId = msgId
                self.savedId = savedId
                self.convertStars = convertStars
                self.upgradeStars = upgradeStars
                self.canExportAt = canExportAt
                self.transferStars = transferStars
                self.canTransferAt = canTransferAt
                self.canResellAt = canResellAt
                self.collectionId = collectionId
                self.prepaidUpgradeHash = prepaidUpgradeHash
                self.dropOriginalDetailsStars = dropOriginalDetailsStars
                self.giftNum = giftNum
                self.canCraftAt = canCraftAt
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("savedStarGift", [("flags", self.flags as Any), ("fromId", self.fromId as Any), ("date", self.date as Any), ("gift", self.gift as Any), ("message", self.message as Any), ("msgId", self.msgId as Any), ("savedId", self.savedId as Any), ("convertStars", self.convertStars as Any), ("upgradeStars", self.upgradeStars as Any), ("canExportAt", self.canExportAt as Any), ("transferStars", self.transferStars as Any), ("canTransferAt", self.canTransferAt as Any), ("canResellAt", self.canResellAt as Any), ("collectionId", self.collectionId as Any), ("prepaidUpgradeHash", self.prepaidUpgradeHash as Any), ("dropOriginalDetailsStars", self.dropOriginalDetailsStars as Any), ("giftNum", self.giftNum as Any), ("canCraftAt", self.canCraftAt as Any)])
            }
        }
        case savedStarGift(Cons_savedStarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedStarGift(let _data):
                if boxed {
                    buffer.appendInt32(1105150972)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.fromId!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.gift.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.msgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt64(_data.savedId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.convertStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt64(_data.upgradeStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.canExportAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt64(_data.transferStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.canTransferAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt32(_data.canResellAt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.collectionId!.count))
                    for item in _data.collectionId! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.prepaidUpgradeHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    serializeInt64(_data.dropOriginalDetailsStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    serializeInt32(_data.giftNum!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt32(_data.canCraftAt!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedStarGift(let _data):
                return ("savedStarGift", [("flags", _data.flags as Any), ("fromId", _data.fromId as Any), ("date", _data.date as Any), ("gift", _data.gift as Any), ("message", _data.message as Any), ("msgId", _data.msgId as Any), ("savedId", _data.savedId as Any), ("convertStars", _data.convertStars as Any), ("upgradeStars", _data.upgradeStars as Any), ("canExportAt", _data.canExportAt as Any), ("transferStars", _data.transferStars as Any), ("canTransferAt", _data.canTransferAt as Any), ("canResellAt", _data.canResellAt as Any), ("collectionId", _data.collectionId as Any), ("prepaidUpgradeHash", _data.prepaidUpgradeHash as Any), ("dropOriginalDetailsStars", _data.dropOriginalDetailsStars as Any), ("giftNum", _data.giftNum as Any), ("canCraftAt", _data.canCraftAt as Any)])
            }
        }

        public static func parse_savedStarGift(_ reader: BufferReader) -> SavedStarGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.StarGift?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _5: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {
                _7 = reader.readInt64()
            }
            var _8: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = reader.readInt64()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {
                _11 = reader.readInt64()
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {
                _12 = reader.readInt32()
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {
                _13 = reader.readInt32()
            }
            var _14: [Int32]?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _15: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _15 = parseString(reader)
            }
            var _16: Int64?
            if Int(_1!) & Int(1 << 18) != 0 {
                _16 = reader.readInt64()
            }
            var _17: Int32?
            if Int(_1!) & Int(1 << 19) != 0 {
                _17 = reader.readInt32()
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {
                _18 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 7) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 8) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 13) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 14) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 15) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 16) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 18) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 19) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 20) == 0) || _18 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 {
                return Api.SavedStarGift.savedStarGift(Cons_savedStarGift(flags: _1!, fromId: _2, date: _3!, gift: _4!, message: _5, msgId: _6, savedId: _7, convertStars: _8, upgradeStars: _9, canExportAt: _10, transferStars: _11, canTransferAt: _12, canResellAt: _13, collectionId: _14, prepaidUpgradeHash: _15, dropOriginalDetailsStars: _16, giftNum: _17, canCraftAt: _18))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchPostsFlood: TypeConstructorDescription {
        public class Cons_searchPostsFlood: TypeConstructorDescription {
            public var flags: Int32
            public var totalDaily: Int32
            public var remains: Int32
            public var waitTill: Int32?
            public var starsAmount: Int64
            public init(flags: Int32, totalDaily: Int32, remains: Int32, waitTill: Int32?, starsAmount: Int64) {
                self.flags = flags
                self.totalDaily = totalDaily
                self.remains = remains
                self.waitTill = waitTill
                self.starsAmount = starsAmount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("searchPostsFlood", [("flags", self.flags as Any), ("totalDaily", self.totalDaily as Any), ("remains", self.remains as Any), ("waitTill", self.waitTill as Any), ("starsAmount", self.starsAmount as Any)])
            }
        }
        case searchPostsFlood(Cons_searchPostsFlood)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchPostsFlood(let _data):
                if boxed {
                    buffer.appendInt32(1040931690)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.totalDaily, buffer: buffer, boxed: false)
                serializeInt32(_data.remains, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.waitTill!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchPostsFlood(let _data):
                return ("searchPostsFlood", [("flags", _data.flags as Any), ("totalDaily", _data.totalDaily as Any), ("remains", _data.remains as Any), ("waitTill", _data.waitTill as Any), ("starsAmount", _data.starsAmount as Any)])
            }
        }

        public static func parse_searchPostsFlood(_ reader: BufferReader) -> SearchPostsFlood? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.SearchPostsFlood.searchPostsFlood(Cons_searchPostsFlood(flags: _1!, totalDaily: _2!, remains: _3!, waitTill: _4, starsAmount: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchResultsCalendarPeriod: TypeConstructorDescription {
        public class Cons_searchResultsCalendarPeriod: TypeConstructorDescription {
            public var date: Int32
            public var minMsgId: Int32
            public var maxMsgId: Int32
            public var count: Int32
            public init(date: Int32, minMsgId: Int32, maxMsgId: Int32, count: Int32) {
                self.date = date
                self.minMsgId = minMsgId
                self.maxMsgId = maxMsgId
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("searchResultsCalendarPeriod", [("date", self.date as Any), ("minMsgId", self.minMsgId as Any), ("maxMsgId", self.maxMsgId as Any), ("count", self.count as Any)])
            }
        }
        case searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultsCalendarPeriod(let _data):
                if boxed {
                    buffer.appendInt32(-911191137)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.minMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxMsgId, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchResultsCalendarPeriod(let _data):
                return ("searchResultsCalendarPeriod", [("date", _data.date as Any), ("minMsgId", _data.minMsgId as Any), ("maxMsgId", _data.maxMsgId as Any), ("count", _data.count as Any)])
            }
        }

        public static func parse_searchResultsCalendarPeriod(_ reader: BufferReader) -> SearchResultsCalendarPeriod? {
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
                return Api.SearchResultsCalendarPeriod.searchResultsCalendarPeriod(Cons_searchResultsCalendarPeriod(date: _1!, minMsgId: _2!, maxMsgId: _3!, count: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SearchResultsPosition: TypeConstructorDescription {
        public class Cons_searchResultPosition: TypeConstructorDescription {
            public var msgId: Int32
            public var date: Int32
            public var offset: Int32
            public init(msgId: Int32, date: Int32, offset: Int32) {
                self.msgId = msgId
                self.date = date
                self.offset = offset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("searchResultPosition", [("msgId", self.msgId as Any), ("date", self.date as Any), ("offset", self.offset as Any)])
            }
        }
        case searchResultPosition(Cons_searchResultPosition)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .searchResultPosition(let _data):
                if boxed {
                    buffer.appendInt32(2137295719)
                }
                serializeInt32(_data.msgId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.offset, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .searchResultPosition(let _data):
                return ("searchResultPosition", [("msgId", _data.msgId as Any), ("date", _data.date as Any), ("offset", _data.offset as Any)])
            }
        }

        public static func parse_searchResultPosition(_ reader: BufferReader) -> SearchResultsPosition? {
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
                return Api.SearchResultsPosition.searchResultPosition(Cons_searchResultPosition(msgId: _1!, date: _2!, offset: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureCredentialsEncrypted: TypeConstructorDescription {
        public class Cons_secureCredentialsEncrypted: TypeConstructorDescription {
            public var data: Buffer
            public var hash: Buffer
            public var secret: Buffer
            public init(data: Buffer, hash: Buffer, secret: Buffer) {
                self.data = data
                self.hash = hash
                self.secret = secret
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureCredentialsEncrypted", [("data", self.data as Any), ("hash", self.hash as Any), ("secret", self.secret as Any)])
            }
        }
        case secureCredentialsEncrypted(Cons_secureCredentialsEncrypted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureCredentialsEncrypted(let _data):
                if boxed {
                    buffer.appendInt32(871426631)
                }
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureCredentialsEncrypted(let _data):
                return ("secureCredentialsEncrypted", [("data", _data.data as Any), ("hash", _data.hash as Any), ("secret", _data.secret as Any)])
            }
        }

        public static func parse_secureCredentialsEncrypted(_ reader: BufferReader) -> SecureCredentialsEncrypted? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureCredentialsEncrypted.secureCredentialsEncrypted(Cons_secureCredentialsEncrypted(data: _1!, hash: _2!, secret: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureData: TypeConstructorDescription {
        public class Cons_secureData: TypeConstructorDescription {
            public var data: Buffer
            public var dataHash: Buffer
            public var secret: Buffer
            public init(data: Buffer, dataHash: Buffer, secret: Buffer) {
                self.data = data
                self.dataHash = dataHash
                self.secret = secret
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureData", [("data", self.data as Any), ("dataHash", self.dataHash as Any), ("secret", self.secret as Any)])
            }
        }
        case secureData(Cons_secureData)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureData(let _data):
                if boxed {
                    buffer.appendInt32(-1964327229)
                }
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                serializeBytes(_data.dataHash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureData(let _data):
                return ("secureData", [("data", _data.data as Any), ("dataHash", _data.dataHash as Any), ("secret", _data.secret as Any)])
            }
        }

        public static func parse_secureData(_ reader: BufferReader) -> SecureData? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureData.secureData(Cons_secureData(data: _1!, dataHash: _2!, secret: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureFile: TypeConstructorDescription {
        public class Cons_secureFile: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var size: Int64
            public var dcId: Int32
            public var date: Int32
            public var fileHash: Buffer
            public var secret: Buffer
            public init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, date: Int32, fileHash: Buffer, secret: Buffer) {
                self.id = id
                self.accessHash = accessHash
                self.size = size
                self.dcId = dcId
                self.date = date
                self.fileHash = fileHash
                self.secret = secret
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureFile", [("id", self.id as Any), ("accessHash", self.accessHash as Any), ("size", self.size as Any), ("dcId", self.dcId as Any), ("date", self.date as Any), ("fileHash", self.fileHash as Any), ("secret", self.secret as Any)])
            }
        }
        case secureFile(Cons_secureFile)
        case secureFileEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureFile(let _data):
                if boxed {
                    buffer.appendInt32(2097791614)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt64(_data.size, buffer: buffer, boxed: false)
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeBytes(_data.secret, buffer: buffer, boxed: false)
                break
            case .secureFileEmpty:
                if boxed {
                    buffer.appendInt32(1679398724)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureFile(let _data):
                return ("secureFile", [("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("size", _data.size as Any), ("dcId", _data.dcId as Any), ("date", _data.date as Any), ("fileHash", _data.fileHash as Any), ("secret", _data.secret as Any)])
            case .secureFileEmpty:
                return ("secureFileEmpty", [])
            }
        }

        public static func parse_secureFile(_ reader: BufferReader) -> SecureFile? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: Buffer?
            _7 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.SecureFile.secureFile(Cons_secureFile(id: _1!, accessHash: _2!, size: _3!, dcId: _4!, date: _5!, fileHash: _6!, secret: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureFileEmpty(_ reader: BufferReader) -> SecureFile? {
            return Api.SecureFile.secureFileEmpty
        }
    }
}
public extension Api {
    enum SecurePasswordKdfAlgo: TypeConstructorDescription {
        public class Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000: TypeConstructorDescription {
            public var salt: Buffer
            public init(salt: Buffer) {
                self.salt = salt
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("securePasswordKdfAlgoPBKDF2HMACSHA512iter100000", [("salt", self.salt as Any)])
            }
        }
        public class Cons_securePasswordKdfAlgoSHA512: TypeConstructorDescription {
            public var salt: Buffer
            public init(salt: Buffer) {
                self.salt = salt
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("securePasswordKdfAlgoSHA512", [("salt", self.salt as Any)])
            }
        }
        case securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000)
        case securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512)
        case securePasswordKdfAlgoUnknown

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let _data):
                if boxed {
                    buffer.appendInt32(-1141711456)
                }
                serializeBytes(_data.salt, buffer: buffer, boxed: false)
                break
            case .securePasswordKdfAlgoSHA512(let _data):
                if boxed {
                    buffer.appendInt32(-2042159726)
                }
                serializeBytes(_data.salt, buffer: buffer, boxed: false)
                break
            case .securePasswordKdfAlgoUnknown:
                if boxed {
                    buffer.appendInt32(4883767)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(let _data):
                return ("securePasswordKdfAlgoPBKDF2HMACSHA512iter100000", [("salt", _data.salt as Any)])
            case .securePasswordKdfAlgoSHA512(let _data):
                return ("securePasswordKdfAlgoSHA512", [("salt", _data.salt as Any)])
            case .securePasswordKdfAlgoUnknown:
                return ("securePasswordKdfAlgoUnknown", [])
            }
        }

        public static func parse_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(Cons_securePasswordKdfAlgoPBKDF2HMACSHA512iter100000(salt: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoSHA512(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoSHA512(Cons_securePasswordKdfAlgoSHA512(salt: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePasswordKdfAlgoUnknown(_ reader: BufferReader) -> SecurePasswordKdfAlgo? {
            return Api.SecurePasswordKdfAlgo.securePasswordKdfAlgoUnknown
        }
    }
}
public extension Api {
    enum SecurePlainData: TypeConstructorDescription {
        public class Cons_securePlainEmail: TypeConstructorDescription {
            public var email: String
            public init(email: String) {
                self.email = email
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("securePlainEmail", [("email", self.email as Any)])
            }
        }
        public class Cons_securePlainPhone: TypeConstructorDescription {
            public var phone: String
            public init(phone: String) {
                self.phone = phone
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("securePlainPhone", [("phone", self.phone as Any)])
            }
        }
        case securePlainEmail(Cons_securePlainEmail)
        case securePlainPhone(Cons_securePlainPhone)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .securePlainEmail(let _data):
                if boxed {
                    buffer.appendInt32(569137759)
                }
                serializeString(_data.email, buffer: buffer, boxed: false)
                break
            case .securePlainPhone(let _data):
                if boxed {
                    buffer.appendInt32(2103482845)
                }
                serializeString(_data.phone, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .securePlainEmail(let _data):
                return ("securePlainEmail", [("email", _data.email as Any)])
            case .securePlainPhone(let _data):
                return ("securePlainPhone", [("phone", _data.phone as Any)])
            }
        }

        public static func parse_securePlainEmail(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainEmail(Cons_securePlainEmail(email: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_securePlainPhone(_ reader: BufferReader) -> SecurePlainData? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecurePlainData.securePlainPhone(Cons_securePlainPhone(phone: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureRequiredType: TypeConstructorDescription {
        public class Cons_secureRequiredType: TypeConstructorDescription {
            public var flags: Int32
            public var type: Api.SecureValueType
            public init(flags: Int32, type: Api.SecureValueType) {
                self.flags = flags
                self.type = type
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureRequiredType", [("flags", self.flags as Any), ("type", self.type as Any)])
            }
        }
        public class Cons_secureRequiredTypeOneOf: TypeConstructorDescription {
            public var types: [Api.SecureRequiredType]
            public init(types: [Api.SecureRequiredType]) {
                self.types = types
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureRequiredTypeOneOf", [("types", self.types as Any)])
            }
        }
        case secureRequiredType(Cons_secureRequiredType)
        case secureRequiredTypeOneOf(Cons_secureRequiredTypeOneOf)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureRequiredType(let _data):
                if boxed {
                    buffer.appendInt32(-2103600678)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                break
            case .secureRequiredTypeOneOf(let _data):
                if boxed {
                    buffer.appendInt32(41187252)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.types.count))
                for item in _data.types {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureRequiredType(let _data):
                return ("secureRequiredType", [("flags", _data.flags as Any), ("type", _data.type as Any)])
            case .secureRequiredTypeOneOf(let _data):
                return ("secureRequiredTypeOneOf", [("types", _data.types as Any)])
            }
        }

        public static func parse_secureRequiredType(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureRequiredType.secureRequiredType(Cons_secureRequiredType(flags: _1!, type: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureRequiredTypeOneOf(_ reader: BufferReader) -> SecureRequiredType? {
            var _1: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.SecureRequiredType.secureRequiredTypeOneOf(Cons_secureRequiredTypeOneOf(types: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureSecretSettings: TypeConstructorDescription {
        public class Cons_secureSecretSettings: TypeConstructorDescription {
            public var secureAlgo: Api.SecurePasswordKdfAlgo
            public var secureSecret: Buffer
            public var secureSecretId: Int64
            public init(secureAlgo: Api.SecurePasswordKdfAlgo, secureSecret: Buffer, secureSecretId: Int64) {
                self.secureAlgo = secureAlgo
                self.secureSecret = secureSecret
                self.secureSecretId = secureSecretId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureSecretSettings", [("secureAlgo", self.secureAlgo as Any), ("secureSecret", self.secureSecret as Any), ("secureSecretId", self.secureSecretId as Any)])
            }
        }
        case secureSecretSettings(Cons_secureSecretSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureSecretSettings(let _data):
                if boxed {
                    buffer.appendInt32(354925740)
                }
                _data.secureAlgo.serialize(buffer, true)
                serializeBytes(_data.secureSecret, buffer: buffer, boxed: false)
                serializeInt64(_data.secureSecretId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureSecretSettings(let _data):
                return ("secureSecretSettings", [("secureAlgo", _data.secureAlgo as Any), ("secureSecret", _data.secureSecret as Any), ("secureSecretId", _data.secureSecretId as Any)])
            }
        }

        public static func parse_secureSecretSettings(_ reader: BufferReader) -> SecureSecretSettings? {
            var _1: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureSecretSettings.secureSecretSettings(Cons_secureSecretSettings(secureAlgo: _1!, secureSecret: _2!, secureSecretId: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValue: TypeConstructorDescription {
        public class Cons_secureValue: TypeConstructorDescription {
            public var flags: Int32
            public var type: Api.SecureValueType
            public var data: Api.SecureData?
            public var frontSide: Api.SecureFile?
            public var reverseSide: Api.SecureFile?
            public var selfie: Api.SecureFile?
            public var translation: [Api.SecureFile]?
            public var files: [Api.SecureFile]?
            public var plainData: Api.SecurePlainData?
            public var hash: Buffer
            public init(flags: Int32, type: Api.SecureValueType, data: Api.SecureData?, frontSide: Api.SecureFile?, reverseSide: Api.SecureFile?, selfie: Api.SecureFile?, translation: [Api.SecureFile]?, files: [Api.SecureFile]?, plainData: Api.SecurePlainData?, hash: Buffer) {
                self.flags = flags
                self.type = type
                self.data = data
                self.frontSide = frontSide
                self.reverseSide = reverseSide
                self.selfie = selfie
                self.translation = translation
                self.files = files
                self.plainData = plainData
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValue", [("flags", self.flags as Any), ("type", self.type as Any), ("data", self.data as Any), ("frontSide", self.frontSide as Any), ("reverseSide", self.reverseSide as Any), ("selfie", self.selfie as Any), ("translation", self.translation as Any), ("files", self.files as Any), ("plainData", self.plainData as Any), ("hash", self.hash as Any)])
            }
        }
        case secureValue(Cons_secureValue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValue(let _data):
                if boxed {
                    buffer.appendInt32(411017418)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.data!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.frontSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.reverseSide!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.selfie!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.translation!.count))
                    for item in _data.translation! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.files!.count))
                    for item in _data.files! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.plainData!.serialize(buffer, true)
                }
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValue(let _data):
                return ("secureValue", [("flags", _data.flags as Any), ("type", _data.type as Any), ("data", _data.data as Any), ("frontSide", _data.frontSide as Any), ("reverseSide", _data.reverseSide as Any), ("selfie", _data.selfie as Any), ("translation", _data.translation as Any), ("files", _data.files as Any), ("plainData", _data.plainData as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_secureValue(_ reader: BufferReader) -> SecureValue? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _3: Api.SecureData?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureData
                }
            }
            var _4: Api.SecureFile?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _5: Api.SecureFile?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _6: Api.SecureFile?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.SecureFile
                }
            }
            var _7: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
                }
            }
            var _8: [Api.SecureFile]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureFile.self)
                }
            }
            var _9: Api.SecurePlainData?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.SecurePlainData
                }
            }
            var _10: Buffer?
            _10 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.SecureValue.secureValue(Cons_secureValue(flags: _1!, type: _2!, data: _3, frontSide: _4, reverseSide: _5, selfie: _6, translation: _7, files: _8, plainData: _9, hash: _10!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueError: TypeConstructorDescription {
        public class Cons_secureValueError: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, hash: Buffer, text: String) {
                self.type = type
                self.hash = hash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueError", [("type", self.type as Any), ("hash", self.hash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorData: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var dataHash: Buffer
            public var field: String
            public var text: String
            public init(type: Api.SecureValueType, dataHash: Buffer, field: String, text: String) {
                self.type = type
                self.dataHash = dataHash
                self.field = field
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorData", [("type", self.type as Any), ("dataHash", self.dataHash as Any), ("field", self.field as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorFile: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorFile", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorFiles: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorFiles", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorFrontSide: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorFrontSide", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorReverseSide: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorReverseSide", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorSelfie: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorSelfie", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorTranslationFile: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: Buffer
            public var text: String
            public init(type: Api.SecureValueType, fileHash: Buffer, text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorTranslationFile", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        public class Cons_secureValueErrorTranslationFiles: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var fileHash: [Buffer]
            public var text: String
            public init(type: Api.SecureValueType, fileHash: [Buffer], text: String) {
                self.type = type
                self.fileHash = fileHash
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueErrorTranslationFiles", [("type", self.type as Any), ("fileHash", self.fileHash as Any), ("text", self.text as Any)])
            }
        }
        case secureValueError(Cons_secureValueError)
        case secureValueErrorData(Cons_secureValueErrorData)
        case secureValueErrorFile(Cons_secureValueErrorFile)
        case secureValueErrorFiles(Cons_secureValueErrorFiles)
        case secureValueErrorFrontSide(Cons_secureValueErrorFrontSide)
        case secureValueErrorReverseSide(Cons_secureValueErrorReverseSide)
        case secureValueErrorSelfie(Cons_secureValueErrorSelfie)
        case secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile)
        case secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueError(let _data):
                if boxed {
                    buffer.appendInt32(-2036501105)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorData(let _data):
                if boxed {
                    buffer.appendInt32(-391902247)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.dataHash, buffer: buffer, boxed: false)
                serializeString(_data.field, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFile(let _data):
                if boxed {
                    buffer.appendInt32(2054162547)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFiles(let _data):
                if boxed {
                    buffer.appendInt32(1717706985)
                }
                _data.type.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.fileHash.count))
                for item in _data.fileHash {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorFrontSide(let _data):
                if boxed {
                    buffer.appendInt32(12467706)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorReverseSide(let _data):
                if boxed {
                    buffer.appendInt32(-2037765467)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorSelfie(let _data):
                if boxed {
                    buffer.appendInt32(-449327402)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorTranslationFile(let _data):
                if boxed {
                    buffer.appendInt32(-1592506512)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.fileHash, buffer: buffer, boxed: false)
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            case .secureValueErrorTranslationFiles(let _data):
                if boxed {
                    buffer.appendInt32(878931416)
                }
                _data.type.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.fileHash.count))
                for item in _data.fileHash {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueError(let _data):
                return ("secureValueError", [("type", _data.type as Any), ("hash", _data.hash as Any), ("text", _data.text as Any)])
            case .secureValueErrorData(let _data):
                return ("secureValueErrorData", [("type", _data.type as Any), ("dataHash", _data.dataHash as Any), ("field", _data.field as Any), ("text", _data.text as Any)])
            case .secureValueErrorFile(let _data):
                return ("secureValueErrorFile", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorFiles(let _data):
                return ("secureValueErrorFiles", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorFrontSide(let _data):
                return ("secureValueErrorFrontSide", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorReverseSide(let _data):
                return ("secureValueErrorReverseSide", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorSelfie(let _data):
                return ("secureValueErrorSelfie", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorTranslationFile(let _data):
                return ("secureValueErrorTranslationFile", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            case .secureValueErrorTranslationFiles(let _data):
                return ("secureValueErrorTranslationFiles", [("type", _data.type as Any), ("fileHash", _data.fileHash as Any), ("text", _data.text as Any)])
            }
        }

        public static func parse_secureValueError(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueError(Cons_secureValueError(type: _1!, hash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorData(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SecureValueError.secureValueErrorData(Cons_secureValueErrorData(type: _1!, dataHash: _2!, field: _3!, text: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFile(Cons_secureValueErrorFile(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFiles(Cons_secureValueErrorFiles(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorFrontSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorFrontSide(Cons_secureValueErrorFrontSide(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorReverseSide(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorReverseSide(Cons_secureValueErrorReverseSide(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorSelfie(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorSelfie(Cons_secureValueErrorSelfie(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFile(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFile(Cons_secureValueErrorTranslationFile(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_secureValueErrorTranslationFiles(_ reader: BufferReader) -> SecureValueError? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SecureValueError.secureValueErrorTranslationFiles(Cons_secureValueErrorTranslationFiles(type: _1!, fileHash: _2!, text: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueHash: TypeConstructorDescription {
        public class Cons_secureValueHash: TypeConstructorDescription {
            public var type: Api.SecureValueType
            public var hash: Buffer
            public init(type: Api.SecureValueType, hash: Buffer) {
                self.type = type
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("secureValueHash", [("type", self.type as Any), ("hash", self.hash as Any)])
            }
        }
        case secureValueHash(Cons_secureValueHash)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueHash(let _data):
                if boxed {
                    buffer.appendInt32(-316748368)
                }
                _data.type.serialize(buffer, true)
                serializeBytes(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueHash(let _data):
                return ("secureValueHash", [("type", _data.type as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_secureValueHash(_ reader: BufferReader) -> SecureValueHash? {
            var _1: Api.SecureValueType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.SecureValueType
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.SecureValueHash.secureValueHash(Cons_secureValueHash(type: _1!, hash: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum SecureValueType: TypeConstructorDescription {
        case secureValueTypeAddress
        case secureValueTypeBankStatement
        case secureValueTypeDriverLicense
        case secureValueTypeEmail
        case secureValueTypeIdentityCard
        case secureValueTypeInternalPassport
        case secureValueTypePassport
        case secureValueTypePassportRegistration
        case secureValueTypePersonalDetails
        case secureValueTypePhone
        case secureValueTypeRentalAgreement
        case secureValueTypeTemporaryRegistration
        case secureValueTypeUtilityBill

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .secureValueTypeAddress:
                if boxed {
                    buffer.appendInt32(-874308058)
                }
                break
            case .secureValueTypeBankStatement:
                if boxed {
                    buffer.appendInt32(-1995211763)
                }
                break
            case .secureValueTypeDriverLicense:
                if boxed {
                    buffer.appendInt32(115615172)
                }
                break
            case .secureValueTypeEmail:
                if boxed {
                    buffer.appendInt32(-1908627474)
                }
                break
            case .secureValueTypeIdentityCard:
                if boxed {
                    buffer.appendInt32(-1596951477)
                }
                break
            case .secureValueTypeInternalPassport:
                if boxed {
                    buffer.appendInt32(-1717268701)
                }
                break
            case .secureValueTypePassport:
                if boxed {
                    buffer.appendInt32(1034709504)
                }
                break
            case .secureValueTypePassportRegistration:
                if boxed {
                    buffer.appendInt32(-1713143702)
                }
                break
            case .secureValueTypePersonalDetails:
                if boxed {
                    buffer.appendInt32(-1658158621)
                }
                break
            case .secureValueTypePhone:
                if boxed {
                    buffer.appendInt32(-1289704741)
                }
                break
            case .secureValueTypeRentalAgreement:
                if boxed {
                    buffer.appendInt32(-1954007928)
                }
                break
            case .secureValueTypeTemporaryRegistration:
                if boxed {
                    buffer.appendInt32(-368907213)
                }
                break
            case .secureValueTypeUtilityBill:
                if boxed {
                    buffer.appendInt32(-63531698)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .secureValueTypeAddress:
                return ("secureValueTypeAddress", [])
            case .secureValueTypeBankStatement:
                return ("secureValueTypeBankStatement", [])
            case .secureValueTypeDriverLicense:
                return ("secureValueTypeDriverLicense", [])
            case .secureValueTypeEmail:
                return ("secureValueTypeEmail", [])
            case .secureValueTypeIdentityCard:
                return ("secureValueTypeIdentityCard", [])
            case .secureValueTypeInternalPassport:
                return ("secureValueTypeInternalPassport", [])
            case .secureValueTypePassport:
                return ("secureValueTypePassport", [])
            case .secureValueTypePassportRegistration:
                return ("secureValueTypePassportRegistration", [])
            case .secureValueTypePersonalDetails:
                return ("secureValueTypePersonalDetails", [])
            case .secureValueTypePhone:
                return ("secureValueTypePhone", [])
            case .secureValueTypeRentalAgreement:
                return ("secureValueTypeRentalAgreement", [])
            case .secureValueTypeTemporaryRegistration:
                return ("secureValueTypeTemporaryRegistration", [])
            case .secureValueTypeUtilityBill:
                return ("secureValueTypeUtilityBill", [])
            }
        }

        public static func parse_secureValueTypeAddress(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeAddress
        }
        public static func parse_secureValueTypeBankStatement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeBankStatement
        }
        public static func parse_secureValueTypeDriverLicense(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeDriverLicense
        }
        public static func parse_secureValueTypeEmail(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeEmail
        }
        public static func parse_secureValueTypeIdentityCard(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeIdentityCard
        }
        public static func parse_secureValueTypeInternalPassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeInternalPassport
        }
        public static func parse_secureValueTypePassport(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassport
        }
        public static func parse_secureValueTypePassportRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePassportRegistration
        }
        public static func parse_secureValueTypePersonalDetails(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePersonalDetails
        }
        public static func parse_secureValueTypePhone(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypePhone
        }
        public static func parse_secureValueTypeRentalAgreement(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeRentalAgreement
        }
        public static func parse_secureValueTypeTemporaryRegistration(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeTemporaryRegistration
        }
        public static func parse_secureValueTypeUtilityBill(_ reader: BufferReader) -> SecureValueType? {
            return Api.SecureValueType.secureValueTypeUtilityBill
        }
    }
}
