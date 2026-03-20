public extension Api {
    enum StarGiftAttributeCounter: TypeConstructorDescription {
        public class Cons_starGiftAttributeCounter: TypeConstructorDescription {
            public var attribute: Api.StarGiftAttributeId
            public var count: Int32
            public init(attribute: Api.StarGiftAttributeId, count: Int32) {
                self.attribute = attribute
                self.count = count
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAttributeCounter", [("attribute", self.attribute as Any), ("count", self.count as Any)])
            }
        }
        case starGiftAttributeCounter(Cons_starGiftAttributeCounter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeCounter(let _data):
                if boxed {
                    buffer.appendInt32(783398488)
                }
                _data.attribute.serialize(buffer, true)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeCounter(let _data):
                return ("starGiftAttributeCounter", [("attribute", _data.attribute as Any), ("count", _data.count as Any)])
            }
        }

        public static func parse_starGiftAttributeCounter(_ reader: BufferReader) -> StarGiftAttributeCounter? {
            var _1: Api.StarGiftAttributeId?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGiftAttributeId
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftAttributeCounter.starGiftAttributeCounter(Cons_starGiftAttributeCounter(attribute: _1!, count: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttributeId: TypeConstructorDescription {
        public class Cons_starGiftAttributeIdBackdrop: TypeConstructorDescription {
            public var backdropId: Int32
            public init(backdropId: Int32) {
                self.backdropId = backdropId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAttributeIdBackdrop", [("backdropId", self.backdropId as Any)])
            }
        }
        public class Cons_starGiftAttributeIdModel: TypeConstructorDescription {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAttributeIdModel", [("documentId", self.documentId as Any)])
            }
        }
        public class Cons_starGiftAttributeIdPattern: TypeConstructorDescription {
            public var documentId: Int64
            public init(documentId: Int64) {
                self.documentId = documentId
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAttributeIdPattern", [("documentId", self.documentId as Any)])
            }
        }
        case starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop)
        case starGiftAttributeIdModel(Cons_starGiftAttributeIdModel)
        case starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeIdBackdrop(let _data):
                if boxed {
                    buffer.appendInt32(520210263)
                }
                serializeInt32(_data.backdropId, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeIdModel(let _data):
                if boxed {
                    buffer.appendInt32(1219145276)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeIdPattern(let _data):
                if boxed {
                    buffer.appendInt32(1242965043)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeIdBackdrop(let _data):
                return ("starGiftAttributeIdBackdrop", [("backdropId", _data.backdropId as Any)])
            case .starGiftAttributeIdModel(let _data):
                return ("starGiftAttributeIdModel", [("documentId", _data.documentId as Any)])
            case .starGiftAttributeIdPattern(let _data):
                return ("starGiftAttributeIdPattern", [("documentId", _data.documentId as Any)])
            }
        }

        public static func parse_starGiftAttributeIdBackdrop(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop(backdropId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeIdModel(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdModel(Cons_starGiftAttributeIdModel(documentId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeIdPattern(_ reader: BufferReader) -> StarGiftAttributeId? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeId.starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern(documentId: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAttributeRarity: TypeConstructorDescription {
        public class Cons_starGiftAttributeRarity: TypeConstructorDescription {
            public var permille: Int32
            public init(permille: Int32) {
                self.permille = permille
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAttributeRarity", [("permille", self.permille as Any)])
            }
        }
        case starGiftAttributeRarity(Cons_starGiftAttributeRarity)
        case starGiftAttributeRarityEpic
        case starGiftAttributeRarityLegendary
        case starGiftAttributeRarityRare
        case starGiftAttributeRarityUncommon

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAttributeRarity(let _data):
                if boxed {
                    buffer.appendInt32(910391095)
                }
                serializeInt32(_data.permille, buffer: buffer, boxed: false)
                break
            case .starGiftAttributeRarityEpic:
                if boxed {
                    buffer.appendInt32(2029777832)
                }
                break
            case .starGiftAttributeRarityLegendary:
                if boxed {
                    buffer.appendInt32(-822614104)
                }
                break
            case .starGiftAttributeRarityRare:
                if boxed {
                    buffer.appendInt32(-259174037)
                }
                break
            case .starGiftAttributeRarityUncommon:
                if boxed {
                    buffer.appendInt32(-607231095)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAttributeRarity(let _data):
                return ("starGiftAttributeRarity", [("permille", _data.permille as Any)])
            case .starGiftAttributeRarityEpic:
                return ("starGiftAttributeRarityEpic", [])
            case .starGiftAttributeRarityLegendary:
                return ("starGiftAttributeRarityLegendary", [])
            case .starGiftAttributeRarityRare:
                return ("starGiftAttributeRarityRare", [])
            case .starGiftAttributeRarityUncommon:
                return ("starGiftAttributeRarityUncommon", [])
            }
        }

        public static func parse_starGiftAttributeRarity(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarGiftAttributeRarity.starGiftAttributeRarity(Cons_starGiftAttributeRarity(permille: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAttributeRarityEpic(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityEpic
        }
        public static func parse_starGiftAttributeRarityLegendary(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityLegendary
        }
        public static func parse_starGiftAttributeRarityRare(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityRare
        }
        public static func parse_starGiftAttributeRarityUncommon(_ reader: BufferReader) -> StarGiftAttributeRarity? {
            return Api.StarGiftAttributeRarity.starGiftAttributeRarityUncommon
        }
    }
}
public extension Api {
    enum StarGiftAuctionAcquiredGift: TypeConstructorDescription {
        public class Cons_starGiftAuctionAcquiredGift: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var bidAmount: Int64
            public var round: Int32
            public var pos: Int32
            public var message: Api.TextWithEntities?
            public var giftNum: Int32?
            public init(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.bidAmount = bidAmount
                self.round = round
                self.pos = pos
                self.message = message
                self.giftNum = giftNum
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionAcquiredGift", [("flags", self.flags as Any), ("peer", self.peer as Any), ("date", self.date as Any), ("bidAmount", self.bidAmount as Any), ("round", self.round as Any), ("pos", self.pos as Any), ("message", self.message as Any), ("giftNum", self.giftNum as Any)])
            }
        }
        case starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionAcquiredGift(let _data):
                if boxed {
                    buffer.appendInt32(1118831432)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.bidAmount, buffer: buffer, boxed: false)
                serializeInt32(_data.round, buffer: buffer, boxed: false)
                serializeInt32(_data.pos, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.message!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.giftNum!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionAcquiredGift(let _data):
                return ("starGiftAuctionAcquiredGift", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("date", _data.date as Any), ("bidAmount", _data.bidAmount as Any), ("round", _data.round as Any), ("pos", _data.pos as Any), ("message", _data.message as Any), ("giftNum", _data.giftNum as Any)])
            }
        }

        public static func parse_starGiftAuctionAcquiredGift(_ reader: BufferReader) -> StarGiftAuctionAcquiredGift? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.TextWithEntities?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
                }
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _8 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.StarGiftAuctionAcquiredGift.starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift(flags: _1!, peer: _2!, date: _3!, bidAmount: _4!, round: _5!, pos: _6!, message: _7, giftNum: _8))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAuctionRound: TypeConstructorDescription {
        public class Cons_starGiftAuctionRound: TypeConstructorDescription {
            public var num: Int32
            public var duration: Int32
            public init(num: Int32, duration: Int32) {
                self.num = num
                self.duration = duration
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionRound", [("num", self.num as Any), ("duration", self.duration as Any)])
            }
        }
        public class Cons_starGiftAuctionRoundExtendable: TypeConstructorDescription {
            public var num: Int32
            public var duration: Int32
            public var extendTop: Int32
            public var extendWindow: Int32
            public init(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32) {
                self.num = num
                self.duration = duration
                self.extendTop = extendTop
                self.extendWindow = extendWindow
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionRoundExtendable", [("num", self.num as Any), ("duration", self.duration as Any), ("extendTop", self.extendTop as Any), ("extendWindow", self.extendWindow as Any)])
            }
        }
        case starGiftAuctionRound(Cons_starGiftAuctionRound)
        case starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionRound(let _data):
                if boxed {
                    buffer.appendInt32(984483112)
                }
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                break
            case .starGiftAuctionRoundExtendable(let _data):
                if boxed {
                    buffer.appendInt32(178266597)
                }
                serializeInt32(_data.num, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                serializeInt32(_data.extendTop, buffer: buffer, boxed: false)
                serializeInt32(_data.extendWindow, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionRound(let _data):
                return ("starGiftAuctionRound", [("num", _data.num as Any), ("duration", _data.duration as Any)])
            case .starGiftAuctionRoundExtendable(let _data):
                return ("starGiftAuctionRoundExtendable", [("num", _data.num as Any), ("duration", _data.duration as Any), ("extendTop", _data.extendTop as Any), ("extendWindow", _data.extendWindow as Any)])
            }
        }

        public static func parse_starGiftAuctionRound(_ reader: BufferReader) -> StarGiftAuctionRound? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftAuctionRound.starGiftAuctionRound(Cons_starGiftAuctionRound(num: _1!, duration: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionRoundExtendable(_ reader: BufferReader) -> StarGiftAuctionRound? {
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
                return Api.StarGiftAuctionRound.starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable(num: _1!, duration: _2!, extendTop: _3!, extendWindow: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftAuctionState: TypeConstructorDescription {
        public class Cons_starGiftAuctionState: TypeConstructorDescription {
            public var version: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var minBidAmount: Int64
            public var bidLevels: [Api.AuctionBidLevel]
            public var topBidders: [Int64]
            public var nextRoundAt: Int32
            public var lastGiftNum: Int32
            public var giftsLeft: Int32
            public var currentRound: Int32
            public var totalRounds: Int32
            public var rounds: [Api.StarGiftAuctionRound]
            public init(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound]) {
                self.version = version
                self.startDate = startDate
                self.endDate = endDate
                self.minBidAmount = minBidAmount
                self.bidLevels = bidLevels
                self.topBidders = topBidders
                self.nextRoundAt = nextRoundAt
                self.lastGiftNum = lastGiftNum
                self.giftsLeft = giftsLeft
                self.currentRound = currentRound
                self.totalRounds = totalRounds
                self.rounds = rounds
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionState", [("version", self.version as Any), ("startDate", self.startDate as Any), ("endDate", self.endDate as Any), ("minBidAmount", self.minBidAmount as Any), ("bidLevels", self.bidLevels as Any), ("topBidders", self.topBidders as Any), ("nextRoundAt", self.nextRoundAt as Any), ("lastGiftNum", self.lastGiftNum as Any), ("giftsLeft", self.giftsLeft as Any), ("currentRound", self.currentRound as Any), ("totalRounds", self.totalRounds as Any), ("rounds", self.rounds as Any)])
            }
        }
        public class Cons_starGiftAuctionStateFinished: TypeConstructorDescription {
            public var flags: Int32
            public var startDate: Int32
            public var endDate: Int32
            public var averagePrice: Int64
            public var listedCount: Int32?
            public var fragmentListedCount: Int32?
            public var fragmentListedUrl: String?
            public init(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
                self.flags = flags
                self.startDate = startDate
                self.endDate = endDate
                self.averagePrice = averagePrice
                self.listedCount = listedCount
                self.fragmentListedCount = fragmentListedCount
                self.fragmentListedUrl = fragmentListedUrl
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionStateFinished", [("flags", self.flags as Any), ("startDate", self.startDate as Any), ("endDate", self.endDate as Any), ("averagePrice", self.averagePrice as Any), ("listedCount", self.listedCount as Any), ("fragmentListedCount", self.fragmentListedCount as Any), ("fragmentListedUrl", self.fragmentListedUrl as Any)])
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)
        case starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished)
        case starGiftAuctionStateNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(1998212710)
                }
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
                serializeInt64(_data.minBidAmount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.bidLevels.count))
                for item in _data.bidLevels {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topBidders.count))
                for item in _data.topBidders {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.nextRoundAt, buffer: buffer, boxed: false)
                serializeInt32(_data.lastGiftNum, buffer: buffer, boxed: false)
                serializeInt32(_data.giftsLeft, buffer: buffer, boxed: false)
                serializeInt32(_data.currentRound, buffer: buffer, boxed: false)
                serializeInt32(_data.totalRounds, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rounds.count))
                for item in _data.rounds {
                    item.serialize(buffer, true)
                }
                break
            case .starGiftAuctionStateFinished(let _data):
                if boxed {
                    buffer.appendInt32(-1758614593)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
                serializeInt64(_data.averagePrice, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.listedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.fragmentListedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.fragmentListedUrl!, buffer: buffer, boxed: false)
                }
                break
            case .starGiftAuctionStateNotModified:
                if boxed {
                    buffer.appendInt32(-30197422)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionState(let _data):
                return ("starGiftAuctionState", [("version", _data.version as Any), ("startDate", _data.startDate as Any), ("endDate", _data.endDate as Any), ("minBidAmount", _data.minBidAmount as Any), ("bidLevels", _data.bidLevels as Any), ("topBidders", _data.topBidders as Any), ("nextRoundAt", _data.nextRoundAt as Any), ("lastGiftNum", _data.lastGiftNum as Any), ("giftsLeft", _data.giftsLeft as Any), ("currentRound", _data.currentRound as Any), ("totalRounds", _data.totalRounds as Any), ("rounds", _data.rounds as Any)])
            case .starGiftAuctionStateFinished(let _data):
                return ("starGiftAuctionStateFinished", [("flags", _data.flags as Any), ("startDate", _data.startDate as Any), ("endDate", _data.endDate as Any), ("averagePrice", _data.averagePrice as Any), ("listedCount", _data.listedCount as Any), ("fragmentListedCount", _data.fragmentListedCount as Any), ("fragmentListedUrl", _data.fragmentListedUrl as Any)])
            case .starGiftAuctionStateNotModified:
                return ("starGiftAuctionStateNotModified", [])
            }
        }

        public static func parse_starGiftAuctionState(_ reader: BufferReader) -> StarGiftAuctionState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: [Api.AuctionBidLevel]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AuctionBidLevel.self)
            }
            var _6: [Int64]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: [Api.StarGiftAuctionRound]?
            if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAuctionRound.self)
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
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.StarGiftAuctionState.starGiftAuctionState(Cons_starGiftAuctionState(version: _1!, startDate: _2!, endDate: _3!, minBidAmount: _4!, bidLevels: _5!, topBidders: _6!, nextRoundAt: _7!, lastGiftNum: _8!, giftsLeft: _9!, currentRound: _10!, totalRounds: _11!, rounds: _12!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionStateFinished(_ reader: BufferReader) -> StarGiftAuctionState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarGiftAuctionState.starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished(flags: _1!, startDate: _2!, endDate: _3!, averagePrice: _4!, listedCount: _5, fragmentListedCount: _6, fragmentListedUrl: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftAuctionStateNotModified(_ reader: BufferReader) -> StarGiftAuctionState? {
            return Api.StarGiftAuctionState.starGiftAuctionStateNotModified
        }
    }
}
public extension Api {
    enum StarGiftAuctionUserState: TypeConstructorDescription {
        public class Cons_starGiftAuctionUserState: TypeConstructorDescription {
            public var flags: Int32
            public var bidAmount: Int64?
            public var bidDate: Int32?
            public var minBidAmount: Int64?
            public var bidPeer: Api.Peer?
            public var acquiredCount: Int32
            public init(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32) {
                self.flags = flags
                self.bidAmount = bidAmount
                self.bidDate = bidDate
                self.minBidAmount = minBidAmount
                self.bidPeer = bidPeer
                self.acquiredCount = acquiredCount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftAuctionUserState", [("flags", self.flags as Any), ("bidAmount", self.bidAmount as Any), ("bidDate", self.bidDate as Any), ("minBidAmount", self.minBidAmount as Any), ("bidPeer", self.bidPeer as Any), ("acquiredCount", self.acquiredCount as Any)])
            }
        }
        case starGiftAuctionUserState(Cons_starGiftAuctionUserState)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionUserState(let _data):
                if boxed {
                    buffer.appendInt32(787403204)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.bidAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.bidDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.minBidAmount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.bidPeer!.serialize(buffer, true)
                }
                serializeInt32(_data.acquiredCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionUserState(let _data):
                return ("starGiftAuctionUserState", [("flags", _data.flags as Any), ("bidAmount", _data.bidAmount as Any), ("bidDate", _data.bidDate as Any), ("minBidAmount", _data.minBidAmount as Any), ("bidPeer", _data.bidPeer as Any), ("acquiredCount", _data.acquiredCount as Any)])
            }
        }

        public static func parse_starGiftAuctionUserState(_ reader: BufferReader) -> StarGiftAuctionUserState? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarGiftAuctionUserState.starGiftAuctionUserState(Cons_starGiftAuctionUserState(flags: _1!, bidAmount: _2, bidDate: _3, minBidAmount: _4, bidPeer: _5, acquiredCount: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftBackground: TypeConstructorDescription {
        public class Cons_starGiftBackground: TypeConstructorDescription {
            public var centerColor: Int32
            public var edgeColor: Int32
            public var textColor: Int32
            public init(centerColor: Int32, edgeColor: Int32, textColor: Int32) {
                self.centerColor = centerColor
                self.edgeColor = edgeColor
                self.textColor = textColor
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftBackground", [("centerColor", self.centerColor as Any), ("edgeColor", self.edgeColor as Any), ("textColor", self.textColor as Any)])
            }
        }
        case starGiftBackground(Cons_starGiftBackground)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftBackground(let _data):
                if boxed {
                    buffer.appendInt32(-1342872680)
                }
                serializeInt32(_data.centerColor, buffer: buffer, boxed: false)
                serializeInt32(_data.edgeColor, buffer: buffer, boxed: false)
                serializeInt32(_data.textColor, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftBackground(let _data):
                return ("starGiftBackground", [("centerColor", _data.centerColor as Any), ("edgeColor", _data.edgeColor as Any), ("textColor", _data.textColor as Any)])
            }
        }

        public static func parse_starGiftBackground(_ reader: BufferReader) -> StarGiftBackground? {
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
                return Api.StarGiftBackground.starGiftBackground(Cons_starGiftBackground(centerColor: _1!, edgeColor: _2!, textColor: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftCollection: TypeConstructorDescription {
        public class Cons_starGiftCollection: TypeConstructorDescription {
            public var flags: Int32
            public var collectionId: Int32
            public var title: String
            public var icon: Api.Document?
            public var giftsCount: Int32
            public var hash: Int64
            public init(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64) {
                self.flags = flags
                self.collectionId = collectionId
                self.title = title
                self.icon = icon
                self.giftsCount = giftsCount
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftCollection", [("flags", self.flags as Any), ("collectionId", self.collectionId as Any), ("title", self.title as Any), ("icon", self.icon as Any), ("giftsCount", self.giftsCount as Any), ("hash", self.hash as Any)])
            }
        }
        case starGiftCollection(Cons_starGiftCollection)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftCollection(let _data):
                if boxed {
                    buffer.appendInt32(-1653926992)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.collectionId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.icon!.serialize(buffer, true)
                }
                serializeInt32(_data.giftsCount, buffer: buffer, boxed: false)
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftCollection(let _data):
                return ("starGiftCollection", [("flags", _data.flags as Any), ("collectionId", _data.collectionId as Any), ("title", _data.title as Any), ("icon", _data.icon as Any), ("giftsCount", _data.giftsCount as Any), ("hash", _data.hash as Any)])
            }
        }

        public static func parse_starGiftCollection(_ reader: BufferReader) -> StarGiftCollection? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarGiftCollection.starGiftCollection(Cons_starGiftCollection(flags: _1!, collectionId: _2!, title: _3!, icon: _4, giftsCount: _5!, hash: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarGiftUpgradePrice: TypeConstructorDescription {
        public class Cons_starGiftUpgradePrice: TypeConstructorDescription {
            public var date: Int32
            public var upgradeStars: Int64
            public init(date: Int32, upgradeStars: Int64) {
                self.date = date
                self.upgradeStars = upgradeStars
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starGiftUpgradePrice", [("date", self.date as Any), ("upgradeStars", self.upgradeStars as Any)])
            }
        }
        case starGiftUpgradePrice(Cons_starGiftUpgradePrice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftUpgradePrice(let _data):
                if boxed {
                    buffer.appendInt32(-1712704739)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.upgradeStars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftUpgradePrice(let _data):
                return ("starGiftUpgradePrice", [("date", _data.date as Any), ("upgradeStars", _data.upgradeStars as Any)])
            }
        }

        public static func parse_starGiftUpgradePrice(_ reader: BufferReader) -> StarGiftUpgradePrice? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarGiftUpgradePrice.starGiftUpgradePrice(Cons_starGiftUpgradePrice(date: _1!, upgradeStars: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        public class Cons_starRefProgram: TypeConstructorDescription {
            public var flags: Int32
            public var botId: Int64
            public var commissionPermille: Int32
            public var durationMonths: Int32?
            public var endDate: Int32?
            public var dailyRevenuePerUser: Api.StarsAmount?
            public init(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?) {
                self.flags = flags
                self.botId = botId
                self.commissionPermille = commissionPermille
                self.durationMonths = durationMonths
                self.endDate = endDate
                self.dailyRevenuePerUser = dailyRevenuePerUser
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starRefProgram", [("flags", self.flags as Any), ("botId", self.botId as Any), ("commissionPermille", self.commissionPermille as Any), ("durationMonths", self.durationMonths as Any), ("endDate", self.endDate as Any), ("dailyRevenuePerUser", self.dailyRevenuePerUser as Any)])
            }
        }
        case starRefProgram(Cons_starRefProgram)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starRefProgram(let _data):
                if boxed {
                    buffer.appendInt32(-586389774)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeInt32(_data.commissionPermille, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.durationMonths!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.endDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.dailyRevenuePerUser!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starRefProgram(let _data):
                return ("starRefProgram", [("flags", _data.flags as Any), ("botId", _data.botId as Any), ("commissionPermille", _data.commissionPermille as Any), ("durationMonths", _data.durationMonths as Any), ("endDate", _data.endDate as Any), ("dailyRevenuePerUser", _data.dailyRevenuePerUser as Any)])
            }
        }

        public static func parse_starRefProgram(_ reader: BufferReader) -> StarRefProgram? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Api.StarsAmount?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarRefProgram.starRefProgram(Cons_starRefProgram(flags: _1!, botId: _2!, commissionPermille: _3!, durationMonths: _4, endDate: _5, dailyRevenuePerUser: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        public class Cons_starsAmount: TypeConstructorDescription {
            public var amount: Int64
            public var nanos: Int32
            public init(amount: Int64, nanos: Int32) {
                self.amount = amount
                self.nanos = nanos
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsAmount", [("amount", self.amount as Any), ("nanos", self.nanos as Any)])
            }
        }
        public class Cons_starsTonAmount: TypeConstructorDescription {
            public var amount: Int64
            public init(amount: Int64) {
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsTonAmount", [("amount", self.amount as Any)])
            }
        }
        case starsAmount(Cons_starsAmount)
        case starsTonAmount(Cons_starsTonAmount)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsAmount(let _data):
                if boxed {
                    buffer.appendInt32(-1145654109)
                }
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                serializeInt32(_data.nanos, buffer: buffer, boxed: false)
                break
            case .starsTonAmount(let _data):
                if boxed {
                    buffer.appendInt32(1957618656)
                }
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsAmount(let _data):
                return ("starsAmount", [("amount", _data.amount as Any), ("nanos", _data.nanos as Any)])
            case .starsTonAmount(let _data):
                return ("starsTonAmount", [("amount", _data.amount as Any)])
            }
        }

        public static func parse_starsAmount(_ reader: BufferReader) -> StarsAmount? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarsAmount.starsAmount(Cons_starsAmount(amount: _1!, nanos: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_starsTonAmount(_ reader: BufferReader) -> StarsAmount? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarsAmount.starsTonAmount(Cons_starsTonAmount(amount: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription {
        public class Cons_starsGiftOption: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var storeProduct: String?
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64) {
                self.flags = flags
                self.stars = stars
                self.storeProduct = storeProduct
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsGiftOption", [("flags", self.flags as Any), ("stars", self.stars as Any), ("storeProduct", self.storeProduct as Any), ("currency", self.currency as Any), ("amount", self.amount as Any)])
            }
        }
        case starsGiftOption(Cons_starsGiftOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsGiftOption(let _data):
                if boxed {
                    buffer.appendInt32(1577421297)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.storeProduct!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsGiftOption(let _data):
                return ("starsGiftOption", [("flags", _data.flags as Any), ("stars", _data.stars as Any), ("storeProduct", _data.storeProduct as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            }
        }

        public static func parse_starsGiftOption(_ reader: BufferReader) -> StarsGiftOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsGiftOption.starsGiftOption(Cons_starsGiftOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription {
        public class Cons_starsGiveawayOption: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var yearlyBoosts: Int32
            public var storeProduct: String?
            public var currency: String
            public var amount: Int64
            public var winners: [Api.StarsGiveawayWinnersOption]
            public init(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption]) {
                self.flags = flags
                self.stars = stars
                self.yearlyBoosts = yearlyBoosts
                self.storeProduct = storeProduct
                self.currency = currency
                self.amount = amount
                self.winners = winners
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsGiveawayOption", [("flags", self.flags as Any), ("stars", self.stars as Any), ("yearlyBoosts", self.yearlyBoosts as Any), ("storeProduct", self.storeProduct as Any), ("currency", self.currency as Any), ("amount", self.amount as Any), ("winners", self.winners as Any)])
            }
        }
        case starsGiveawayOption(Cons_starsGiveawayOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsGiveawayOption(let _data):
                if boxed {
                    buffer.appendInt32(-1798404822)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                serializeInt32(_data.yearlyBoosts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.storeProduct!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.winners.count))
                for item in _data.winners {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsGiveawayOption(let _data):
                return ("starsGiveawayOption", [("flags", _data.flags as Any), ("stars", _data.stars as Any), ("yearlyBoosts", _data.yearlyBoosts as Any), ("storeProduct", _data.storeProduct as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any), ("winners", _data.winners as Any)])
            }
        }

        public static func parse_starsGiveawayOption(_ reader: BufferReader) -> StarsGiveawayOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: [Api.StarsGiveawayWinnersOption]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsGiveawayWinnersOption.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.StarsGiveawayOption.starsGiveawayOption(Cons_starsGiveawayOption(flags: _1!, stars: _2!, yearlyBoosts: _3!, storeProduct: _4, currency: _5!, amount: _6!, winners: _7!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription {
        public class Cons_starsGiveawayWinnersOption: TypeConstructorDescription {
            public var flags: Int32
            public var users: Int32
            public var perUserStars: Int64
            public init(flags: Int32, users: Int32, perUserStars: Int64) {
                self.flags = flags
                self.users = users
                self.perUserStars = perUserStars
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsGiveawayWinnersOption", [("flags", self.flags as Any), ("users", self.users as Any), ("perUserStars", self.perUserStars as Any)])
            }
        }
        case starsGiveawayWinnersOption(Cons_starsGiveawayWinnersOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsGiveawayWinnersOption(let _data):
                if boxed {
                    buffer.appendInt32(1411605001)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.users, buffer: buffer, boxed: false)
                serializeInt64(_data.perUserStars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsGiveawayWinnersOption(let _data):
                return ("starsGiveawayWinnersOption", [("flags", _data.flags as Any), ("users", _data.users as Any), ("perUserStars", _data.perUserStars as Any)])
            }
        }

        public static func parse_starsGiveawayWinnersOption(_ reader: BufferReader) -> StarsGiveawayWinnersOption? {
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
                return Api.StarsGiveawayWinnersOption.starsGiveawayWinnersOption(Cons_starsGiveawayWinnersOption(flags: _1!, users: _2!, perUserStars: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsRating: TypeConstructorDescription {
        public class Cons_starsRating: TypeConstructorDescription {
            public var flags: Int32
            public var level: Int32
            public var currentLevelStars: Int64
            public var stars: Int64
            public var nextLevelStars: Int64?
            public init(flags: Int32, level: Int32, currentLevelStars: Int64, stars: Int64, nextLevelStars: Int64?) {
                self.flags = flags
                self.level = level
                self.currentLevelStars = currentLevelStars
                self.stars = stars
                self.nextLevelStars = nextLevelStars
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsRating", [("flags", self.flags as Any), ("level", self.level as Any), ("currentLevelStars", self.currentLevelStars as Any), ("stars", self.stars as Any), ("nextLevelStars", self.nextLevelStars as Any)])
            }
        }
        case starsRating(Cons_starsRating)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsRating(let _data):
                if boxed {
                    buffer.appendInt32(453922567)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.level, buffer: buffer, boxed: false)
                serializeInt64(_data.currentLevelStars, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.nextLevelStars!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsRating(let _data):
                return ("starsRating", [("flags", _data.flags as Any), ("level", _data.level as Any), ("currentLevelStars", _data.currentLevelStars as Any), ("stars", _data.stars as Any), ("nextLevelStars", _data.nextLevelStars as Any)])
            }
        }

        public static func parse_starsRating(_ reader: BufferReader) -> StarsRating? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsRating.starsRating(Cons_starsRating(flags: _1!, level: _2!, currentLevelStars: _3!, stars: _4!, nextLevelStars: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsRevenueStatus: TypeConstructorDescription {
        public class Cons_starsRevenueStatus: TypeConstructorDescription {
            public var flags: Int32
            public var currentBalance: Api.StarsAmount
            public var availableBalance: Api.StarsAmount
            public var overallRevenue: Api.StarsAmount
            public var nextWithdrawalAt: Int32?
            public init(flags: Int32, currentBalance: Api.StarsAmount, availableBalance: Api.StarsAmount, overallRevenue: Api.StarsAmount, nextWithdrawalAt: Int32?) {
                self.flags = flags
                self.currentBalance = currentBalance
                self.availableBalance = availableBalance
                self.overallRevenue = overallRevenue
                self.nextWithdrawalAt = nextWithdrawalAt
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsRevenueStatus", [("flags", self.flags as Any), ("currentBalance", self.currentBalance as Any), ("availableBalance", self.availableBalance as Any), ("overallRevenue", self.overallRevenue as Any), ("nextWithdrawalAt", self.nextWithdrawalAt as Any)])
            }
        }
        case starsRevenueStatus(Cons_starsRevenueStatus)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsRevenueStatus(let _data):
                if boxed {
                    buffer.appendInt32(-21080943)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.currentBalance.serialize(buffer, true)
                _data.availableBalance.serialize(buffer, true)
                _data.overallRevenue.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.nextWithdrawalAt!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsRevenueStatus(let _data):
                return ("starsRevenueStatus", [("flags", _data.flags as Any), ("currentBalance", _data.currentBalance as Any), ("availableBalance", _data.availableBalance as Any), ("overallRevenue", _data.overallRevenue as Any), ("nextWithdrawalAt", _data.nextWithdrawalAt as Any)])
            }
        }

        public static func parse_starsRevenueStatus(_ reader: BufferReader) -> StarsRevenueStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _3: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _4: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsRevenueStatus.starsRevenueStatus(Cons_starsRevenueStatus(flags: _1!, currentBalance: _2!, availableBalance: _3!, overallRevenue: _4!, nextWithdrawalAt: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsSubscription: TypeConstructorDescription {
        public class Cons_starsSubscription: TypeConstructorDescription {
            public var flags: Int32
            public var id: String
            public var peer: Api.Peer
            public var untilDate: Int32
            public var pricing: Api.StarsSubscriptionPricing
            public var chatInviteHash: String?
            public var title: String?
            public var photo: Api.WebDocument?
            public var invoiceSlug: String?
            public init(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?, title: String?, photo: Api.WebDocument?, invoiceSlug: String?) {
                self.flags = flags
                self.id = id
                self.peer = peer
                self.untilDate = untilDate
                self.pricing = pricing
                self.chatInviteHash = chatInviteHash
                self.title = title
                self.photo = photo
                self.invoiceSlug = invoiceSlug
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsSubscription", [("flags", self.flags as Any), ("id", self.id as Any), ("peer", self.peer as Any), ("untilDate", self.untilDate as Any), ("pricing", self.pricing as Any), ("chatInviteHash", self.chatInviteHash as Any), ("title", self.title as Any), ("photo", self.photo as Any), ("invoiceSlug", self.invoiceSlug as Any)])
            }
        }
        case starsSubscription(Cons_starsSubscription)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsSubscription(let _data):
                if boxed {
                    buffer.appendInt32(779004698)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                _data.pricing.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.chatInviteHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.invoiceSlug!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsSubscription(let _data):
                return ("starsSubscription", [("flags", _data.flags as Any), ("id", _data.id as Any), ("peer", _data.peer as Any), ("untilDate", _data.untilDate as Any), ("pricing", _data.pricing as Any), ("chatInviteHash", _data.chatInviteHash as Any), ("title", _data.title as Any), ("photo", _data.photo as Any), ("invoiceSlug", _data.invoiceSlug as Any)])
            }
        }

        public static func parse_starsSubscription(_ reader: BufferReader) -> StarsSubscription? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.StarsSubscriptionPricing?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {
                _7 = parseString(reader)
            }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _9: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.StarsSubscription.starsSubscription(Cons_starsSubscription(flags: _1!, id: _2!, peer: _3!, untilDate: _4!, pricing: _5!, chatInviteHash: _6, title: _7, photo: _8, invoiceSlug: _9))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsSubscriptionPricing: TypeConstructorDescription {
        public class Cons_starsSubscriptionPricing: TypeConstructorDescription {
            public var period: Int32
            public var amount: Int64
            public init(period: Int32, amount: Int64) {
                self.period = period
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsSubscriptionPricing", [("period", self.period as Any), ("amount", self.amount as Any)])
            }
        }
        case starsSubscriptionPricing(Cons_starsSubscriptionPricing)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsSubscriptionPricing(let _data):
                if boxed {
                    buffer.appendInt32(88173912)
                }
                serializeInt32(_data.period, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsSubscriptionPricing(let _data):
                return ("starsSubscriptionPricing", [("period", _data.period as Any), ("amount", _data.amount as Any)])
            }
        }

        public static func parse_starsSubscriptionPricing(_ reader: BufferReader) -> StarsSubscriptionPricing? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StarsSubscriptionPricing.starsSubscriptionPricing(Cons_starsSubscriptionPricing(period: _1!, amount: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsTopupOption: TypeConstructorDescription {
        public class Cons_starsTopupOption: TypeConstructorDescription {
            public var flags: Int32
            public var stars: Int64
            public var storeProduct: String?
            public var currency: String
            public var amount: Int64
            public init(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64) {
                self.flags = flags
                self.stars = stars
                self.storeProduct = storeProduct
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsTopupOption", [("flags", self.flags as Any), ("stars", self.stars as Any), ("storeProduct", self.storeProduct as Any), ("currency", self.currency as Any), ("amount", self.amount as Any)])
            }
        }
        case starsTopupOption(Cons_starsTopupOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsTopupOption(let _data):
                if boxed {
                    buffer.appendInt32(198776256)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.storeProduct!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsTopupOption(let _data):
                return ("starsTopupOption", [("flags", _data.flags as Any), ("stars", _data.stars as Any), ("storeProduct", _data.storeProduct as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            }
        }

        public static func parse_starsTopupOption(_ reader: BufferReader) -> StarsTopupOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int64?
            _5 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsTopupOption.starsTopupOption(Cons_starsTopupOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsTransaction: TypeConstructorDescription {
        public class Cons_starsTransaction: TypeConstructorDescription {
            public var flags: Int32
            public var id: String
            public var amount: Api.StarsAmount
            public var date: Int32
            public var peer: Api.StarsTransactionPeer
            public var title: String?
            public var description: String?
            public var photo: Api.WebDocument?
            public var transactionDate: Int32?
            public var transactionUrl: String?
            public var botPayload: Buffer?
            public var msgId: Int32?
            public var extendedMedia: [Api.MessageMedia]?
            public var subscriptionPeriod: Int32?
            public var giveawayPostId: Int32?
            public var stargift: Api.StarGift?
            public var floodskipNumber: Int32?
            public var starrefCommissionPermille: Int32?
            public var starrefPeer: Api.Peer?
            public var starrefAmount: Api.StarsAmount?
            public var paidMessages: Int32?
            public var premiumGiftMonths: Int32?
            public var adsProceedsFromDate: Int32?
            public var adsProceedsToDate: Int32?
            public init(flags: Int32, id: String, amount: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?, paidMessages: Int32?, premiumGiftMonths: Int32?, adsProceedsFromDate: Int32?, adsProceedsToDate: Int32?) {
                self.flags = flags
                self.id = id
                self.amount = amount
                self.date = date
                self.peer = peer
                self.title = title
                self.description = description
                self.photo = photo
                self.transactionDate = transactionDate
                self.transactionUrl = transactionUrl
                self.botPayload = botPayload
                self.msgId = msgId
                self.extendedMedia = extendedMedia
                self.subscriptionPeriod = subscriptionPeriod
                self.giveawayPostId = giveawayPostId
                self.stargift = stargift
                self.floodskipNumber = floodskipNumber
                self.starrefCommissionPermille = starrefCommissionPermille
                self.starrefPeer = starrefPeer
                self.starrefAmount = starrefAmount
                self.paidMessages = paidMessages
                self.premiumGiftMonths = premiumGiftMonths
                self.adsProceedsFromDate = adsProceedsFromDate
                self.adsProceedsToDate = adsProceedsToDate
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsTransaction", [("flags", self.flags as Any), ("id", self.id as Any), ("amount", self.amount as Any), ("date", self.date as Any), ("peer", self.peer as Any), ("title", self.title as Any), ("description", self.description as Any), ("photo", self.photo as Any), ("transactionDate", self.transactionDate as Any), ("transactionUrl", self.transactionUrl as Any), ("botPayload", self.botPayload as Any), ("msgId", self.msgId as Any), ("extendedMedia", self.extendedMedia as Any), ("subscriptionPeriod", self.subscriptionPeriod as Any), ("giveawayPostId", self.giveawayPostId as Any), ("stargift", self.stargift as Any), ("floodskipNumber", self.floodskipNumber as Any), ("starrefCommissionPermille", self.starrefCommissionPermille as Any), ("starrefPeer", self.starrefPeer as Any), ("starrefAmount", self.starrefAmount as Any), ("paidMessages", self.paidMessages as Any), ("premiumGiftMonths", self.premiumGiftMonths as Any), ("adsProceedsFromDate", self.adsProceedsFromDate as Any), ("adsProceedsToDate", self.adsProceedsToDate as Any)])
            }
        }
        case starsTransaction(Cons_starsTransaction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsTransaction(let _data):
                if boxed {
                    buffer.appendInt32(325426864)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                _data.amount.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.transactionDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.transactionUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeBytes(_data.botPayload!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    serializeInt32(_data.msgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.extendedMedia!.count))
                    for item in _data.extendedMedia! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt32(_data.subscriptionPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.giveawayPostId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.stargift!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    serializeInt32(_data.floodskipNumber!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt32(_data.starrefCommissionPermille!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    _data.starrefPeer!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    _data.starrefAmount!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 19) != 0 {
                    serializeInt32(_data.paidMessages!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt32(_data.premiumGiftMonths!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 23) != 0 {
                    serializeInt32(_data.adsProceedsFromDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 23) != 0 {
                    serializeInt32(_data.adsProceedsToDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsTransaction(let _data):
                return ("starsTransaction", [("flags", _data.flags as Any), ("id", _data.id as Any), ("amount", _data.amount as Any), ("date", _data.date as Any), ("peer", _data.peer as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("transactionDate", _data.transactionDate as Any), ("transactionUrl", _data.transactionUrl as Any), ("botPayload", _data.botPayload as Any), ("msgId", _data.msgId as Any), ("extendedMedia", _data.extendedMedia as Any), ("subscriptionPeriod", _data.subscriptionPeriod as Any), ("giveawayPostId", _data.giveawayPostId as Any), ("stargift", _data.stargift as Any), ("floodskipNumber", _data.floodskipNumber as Any), ("starrefCommissionPermille", _data.starrefCommissionPermille as Any), ("starrefPeer", _data.starrefPeer as Any), ("starrefAmount", _data.starrefAmount as Any), ("paidMessages", _data.paidMessages as Any), ("premiumGiftMonths", _data.premiumGiftMonths as Any), ("adsProceedsFromDate", _data.adsProceedsFromDate as Any), ("adsProceedsToDate", _data.adsProceedsToDate as Any)])
            }
        }

        public static func parse_starsTransaction(_ reader: BufferReader) -> StarsTransaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.StarsTransactionPeer?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StarsTransactionPeer
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _9 = reader.readInt32()
            }
            var _10: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _10 = parseString(reader)
            }
            var _11: Buffer?
            if Int(_1!) & Int(1 << 7) != 0 {
                _11 = parseBytes(reader)
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {
                _12 = reader.readInt32()
            }
            var _13: [Api.MessageMedia]?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let _ = reader.readInt32() {
                    _13 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageMedia.self)
                }
            }
            var _14: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {
                _14 = reader.readInt32()
            }
            var _15: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {
                _15 = reader.readInt32()
            }
            var _16: Api.StarGift?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _16 = Api.parse(reader, signature: signature) as? Api.StarGift
                }
            }
            var _17: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {
                _17 = reader.readInt32()
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 16) != 0 {
                _18 = reader.readInt32()
            }
            var _19: Api.Peer?
            if Int(_1!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _19 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _20: Api.StarsAmount?
            if Int(_1!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.StarsAmount
                }
            }
            var _21: Int32?
            if Int(_1!) & Int(1 << 19) != 0 {
                _21 = reader.readInt32()
            }
            var _22: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {
                _22 = reader.readInt32()
            }
            var _23: Int32?
            if Int(_1!) & Int(1 << 23) != 0 {
                _23 = reader.readInt32()
            }
            var _24: Int32?
            if Int(_1!) & Int(1 << 23) != 0 {
                _24 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 5) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 8) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 9) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 12) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 13) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 14) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 15) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 16) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 17) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 17) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 19) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 20) == 0) || _22 != nil
            let _c23 = (Int(_1!) & Int(1 << 23) == 0) || _23 != nil
            let _c24 = (Int(_1!) & Int(1 << 23) == 0) || _24 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 {
                return Api.StarsTransaction.starsTransaction(Cons_starsTransaction(flags: _1!, id: _2!, amount: _3!, date: _4!, peer: _5!, title: _6, description: _7, photo: _8, transactionDate: _9, transactionUrl: _10, botPayload: _11, msgId: _12, extendedMedia: _13, subscriptionPeriod: _14, giveawayPostId: _15, stargift: _16, floodskipNumber: _17, starrefCommissionPermille: _18, starrefPeer: _19, starrefAmount: _20, paidMessages: _21, premiumGiftMonths: _22, adsProceedsFromDate: _23, adsProceedsToDate: _24))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum StarsTransactionPeer: TypeConstructorDescription {
        public class Cons_starsTransactionPeer: TypeConstructorDescription {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("starsTransactionPeer", [("peer", self.peer as Any)])
            }
        }
        case starsTransactionPeer(Cons_starsTransactionPeer)
        case starsTransactionPeerAPI
        case starsTransactionPeerAds
        case starsTransactionPeerAppStore
        case starsTransactionPeerFragment
        case starsTransactionPeerPlayMarket
        case starsTransactionPeerPremiumBot
        case starsTransactionPeerUnsupported

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsTransactionPeer(let _data):
                if boxed {
                    buffer.appendInt32(-670195363)
                }
                _data.peer.serialize(buffer, true)
                break
            case .starsTransactionPeerAPI:
                if boxed {
                    buffer.appendInt32(-110658899)
                }
                break
            case .starsTransactionPeerAds:
                if boxed {
                    buffer.appendInt32(1617438738)
                }
                break
            case .starsTransactionPeerAppStore:
                if boxed {
                    buffer.appendInt32(-1269320843)
                }
                break
            case .starsTransactionPeerFragment:
                if boxed {
                    buffer.appendInt32(-382740222)
                }
                break
            case .starsTransactionPeerPlayMarket:
                if boxed {
                    buffer.appendInt32(2069236235)
                }
                break
            case .starsTransactionPeerPremiumBot:
                if boxed {
                    buffer.appendInt32(621656824)
                }
                break
            case .starsTransactionPeerUnsupported:
                if boxed {
                    buffer.appendInt32(-1779253276)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsTransactionPeer(let _data):
                return ("starsTransactionPeer", [("peer", _data.peer as Any)])
            case .starsTransactionPeerAPI:
                return ("starsTransactionPeerAPI", [])
            case .starsTransactionPeerAds:
                return ("starsTransactionPeerAds", [])
            case .starsTransactionPeerAppStore:
                return ("starsTransactionPeerAppStore", [])
            case .starsTransactionPeerFragment:
                return ("starsTransactionPeerFragment", [])
            case .starsTransactionPeerPlayMarket:
                return ("starsTransactionPeerPlayMarket", [])
            case .starsTransactionPeerPremiumBot:
                return ("starsTransactionPeerPremiumBot", [])
            case .starsTransactionPeerUnsupported:
                return ("starsTransactionPeerUnsupported", [])
            }
        }

        public static func parse_starsTransactionPeer(_ reader: BufferReader) -> StarsTransactionPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.StarsTransactionPeer.starsTransactionPeer(Cons_starsTransactionPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starsTransactionPeerAPI(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerAPI
        }
        public static func parse_starsTransactionPeerAds(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerAds
        }
        public static func parse_starsTransactionPeerAppStore(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerAppStore
        }
        public static func parse_starsTransactionPeerFragment(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerFragment
        }
        public static func parse_starsTransactionPeerPlayMarket(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerPlayMarket
        }
        public static func parse_starsTransactionPeerPremiumBot(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerPremiumBot
        }
        public static func parse_starsTransactionPeerUnsupported(_ reader: BufferReader) -> StarsTransactionPeer? {
            return Api.StarsTransactionPeer.starsTransactionPeerUnsupported
        }
    }
}
