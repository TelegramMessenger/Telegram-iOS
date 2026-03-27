public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        public class Cons_starsAmount: TypeConstructorDescription {
            public var amount: Int64
            public var nanos: Int32
            public init(amount: Int64, nanos: Int32) {
                self.amount = amount
                self.nanos = nanos
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsAmount", [("amount", ConstructorParameterDescription(self.amount)), ("nanos", ConstructorParameterDescription(self.nanos))])
            }
        }
        public class Cons_starsTonAmount: TypeConstructorDescription {
            public var amount: Int64
            public init(amount: Int64) {
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsTonAmount", [("amount", ConstructorParameterDescription(self.amount))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsAmount(let _data):
                return ("starsAmount", [("amount", ConstructorParameterDescription(_data.amount)), ("nanos", ConstructorParameterDescription(_data.nanos))])
            case .starsTonAmount(let _data):
                return ("starsTonAmount", [("amount", ConstructorParameterDescription(_data.amount))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsGiftOption", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("storeProduct", ConstructorParameterDescription(self.storeProduct)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsGiftOption(let _data):
                return ("starsGiftOption", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("storeProduct", ConstructorParameterDescription(_data.storeProduct)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsGiveawayOption", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("yearlyBoosts", ConstructorParameterDescription(self.yearlyBoosts)), ("storeProduct", ConstructorParameterDescription(self.storeProduct)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount)), ("winners", ConstructorParameterDescription(self.winners))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsGiveawayOption(let _data):
                return ("starsGiveawayOption", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("yearlyBoosts", ConstructorParameterDescription(_data.yearlyBoosts)), ("storeProduct", ConstructorParameterDescription(_data.storeProduct)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount)), ("winners", ConstructorParameterDescription(_data.winners))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsGiveawayWinnersOption", [("flags", ConstructorParameterDescription(self.flags)), ("users", ConstructorParameterDescription(self.users)), ("perUserStars", ConstructorParameterDescription(self.perUserStars))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsGiveawayWinnersOption(let _data):
                return ("starsGiveawayWinnersOption", [("flags", ConstructorParameterDescription(_data.flags)), ("users", ConstructorParameterDescription(_data.users)), ("perUserStars", ConstructorParameterDescription(_data.perUserStars))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsRating", [("flags", ConstructorParameterDescription(self.flags)), ("level", ConstructorParameterDescription(self.level)), ("currentLevelStars", ConstructorParameterDescription(self.currentLevelStars)), ("stars", ConstructorParameterDescription(self.stars)), ("nextLevelStars", ConstructorParameterDescription(self.nextLevelStars))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsRating(let _data):
                return ("starsRating", [("flags", ConstructorParameterDescription(_data.flags)), ("level", ConstructorParameterDescription(_data.level)), ("currentLevelStars", ConstructorParameterDescription(_data.currentLevelStars)), ("stars", ConstructorParameterDescription(_data.stars)), ("nextLevelStars", ConstructorParameterDescription(_data.nextLevelStars))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsRevenueStatus", [("flags", ConstructorParameterDescription(self.flags)), ("currentBalance", ConstructorParameterDescription(self.currentBalance)), ("availableBalance", ConstructorParameterDescription(self.availableBalance)), ("overallRevenue", ConstructorParameterDescription(self.overallRevenue)), ("nextWithdrawalAt", ConstructorParameterDescription(self.nextWithdrawalAt))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsRevenueStatus(let _data):
                return ("starsRevenueStatus", [("flags", ConstructorParameterDescription(_data.flags)), ("currentBalance", ConstructorParameterDescription(_data.currentBalance)), ("availableBalance", ConstructorParameterDescription(_data.availableBalance)), ("overallRevenue", ConstructorParameterDescription(_data.overallRevenue)), ("nextWithdrawalAt", ConstructorParameterDescription(_data.nextWithdrawalAt))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsSubscription", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("peer", ConstructorParameterDescription(self.peer)), ("untilDate", ConstructorParameterDescription(self.untilDate)), ("pricing", ConstructorParameterDescription(self.pricing)), ("chatInviteHash", ConstructorParameterDescription(self.chatInviteHash)), ("title", ConstructorParameterDescription(self.title)), ("photo", ConstructorParameterDescription(self.photo)), ("invoiceSlug", ConstructorParameterDescription(self.invoiceSlug))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsSubscription(let _data):
                return ("starsSubscription", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("peer", ConstructorParameterDescription(_data.peer)), ("untilDate", ConstructorParameterDescription(_data.untilDate)), ("pricing", ConstructorParameterDescription(_data.pricing)), ("chatInviteHash", ConstructorParameterDescription(_data.chatInviteHash)), ("title", ConstructorParameterDescription(_data.title)), ("photo", ConstructorParameterDescription(_data.photo)), ("invoiceSlug", ConstructorParameterDescription(_data.invoiceSlug))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsSubscriptionPricing", [("period", ConstructorParameterDescription(self.period)), ("amount", ConstructorParameterDescription(self.amount))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsSubscriptionPricing(let _data):
                return ("starsSubscriptionPricing", [("period", ConstructorParameterDescription(_data.period)), ("amount", ConstructorParameterDescription(_data.amount))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsTopupOption", [("flags", ConstructorParameterDescription(self.flags)), ("stars", ConstructorParameterDescription(self.stars)), ("storeProduct", ConstructorParameterDescription(self.storeProduct)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsTopupOption(let _data):
                return ("starsTopupOption", [("flags", ConstructorParameterDescription(_data.flags)), ("stars", ConstructorParameterDescription(_data.stars)), ("storeProduct", ConstructorParameterDescription(_data.storeProduct)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsTransaction", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("amount", ConstructorParameterDescription(self.amount)), ("date", ConstructorParameterDescription(self.date)), ("peer", ConstructorParameterDescription(self.peer)), ("title", ConstructorParameterDescription(self.title)), ("description", ConstructorParameterDescription(self.description)), ("photo", ConstructorParameterDescription(self.photo)), ("transactionDate", ConstructorParameterDescription(self.transactionDate)), ("transactionUrl", ConstructorParameterDescription(self.transactionUrl)), ("botPayload", ConstructorParameterDescription(self.botPayload)), ("msgId", ConstructorParameterDescription(self.msgId)), ("extendedMedia", ConstructorParameterDescription(self.extendedMedia)), ("subscriptionPeriod", ConstructorParameterDescription(self.subscriptionPeriod)), ("giveawayPostId", ConstructorParameterDescription(self.giveawayPostId)), ("stargift", ConstructorParameterDescription(self.stargift)), ("floodskipNumber", ConstructorParameterDescription(self.floodskipNumber)), ("starrefCommissionPermille", ConstructorParameterDescription(self.starrefCommissionPermille)), ("starrefPeer", ConstructorParameterDescription(self.starrefPeer)), ("starrefAmount", ConstructorParameterDescription(self.starrefAmount)), ("paidMessages", ConstructorParameterDescription(self.paidMessages)), ("premiumGiftMonths", ConstructorParameterDescription(self.premiumGiftMonths)), ("adsProceedsFromDate", ConstructorParameterDescription(self.adsProceedsFromDate)), ("adsProceedsToDate", ConstructorParameterDescription(self.adsProceedsToDate))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsTransaction(let _data):
                return ("starsTransaction", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("amount", ConstructorParameterDescription(_data.amount)), ("date", ConstructorParameterDescription(_data.date)), ("peer", ConstructorParameterDescription(_data.peer)), ("title", ConstructorParameterDescription(_data.title)), ("description", ConstructorParameterDescription(_data.description)), ("photo", ConstructorParameterDescription(_data.photo)), ("transactionDate", ConstructorParameterDescription(_data.transactionDate)), ("transactionUrl", ConstructorParameterDescription(_data.transactionUrl)), ("botPayload", ConstructorParameterDescription(_data.botPayload)), ("msgId", ConstructorParameterDescription(_data.msgId)), ("extendedMedia", ConstructorParameterDescription(_data.extendedMedia)), ("subscriptionPeriod", ConstructorParameterDescription(_data.subscriptionPeriod)), ("giveawayPostId", ConstructorParameterDescription(_data.giveawayPostId)), ("stargift", ConstructorParameterDescription(_data.stargift)), ("floodskipNumber", ConstructorParameterDescription(_data.floodskipNumber)), ("starrefCommissionPermille", ConstructorParameterDescription(_data.starrefCommissionPermille)), ("starrefPeer", ConstructorParameterDescription(_data.starrefPeer)), ("starrefAmount", ConstructorParameterDescription(_data.starrefAmount)), ("paidMessages", ConstructorParameterDescription(_data.paidMessages)), ("premiumGiftMonths", ConstructorParameterDescription(_data.premiumGiftMonths)), ("adsProceedsFromDate", ConstructorParameterDescription(_data.adsProceedsFromDate)), ("adsProceedsToDate", ConstructorParameterDescription(_data.adsProceedsToDate))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("starsTransactionPeer", [("peer", ConstructorParameterDescription(self.peer))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .starsTransactionPeer(let _data):
                return ("starsTransactionPeer", [("peer", ConstructorParameterDescription(_data.peer))])
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
public extension Api {
    enum StatsAbsValueAndPrev: TypeConstructorDescription {
        public class Cons_statsAbsValueAndPrev: TypeConstructorDescription {
            public var current: Double
            public var previous: Double
            public init(current: Double, previous: Double) {
                self.current = current
                self.previous = previous
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsAbsValueAndPrev", [("current", ConstructorParameterDescription(self.current)), ("previous", ConstructorParameterDescription(self.previous))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsAbsValueAndPrev(let _data):
                return ("statsAbsValueAndPrev", [("current", ConstructorParameterDescription(_data.current)), ("previous", ConstructorParameterDescription(_data.previous))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsDateRangeDays", [("minDate", ConstructorParameterDescription(self.minDate)), ("maxDate", ConstructorParameterDescription(self.maxDate))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsDateRangeDays(let _data):
                return ("statsDateRangeDays", [("minDate", ConstructorParameterDescription(_data.minDate)), ("maxDate", ConstructorParameterDescription(_data.maxDate))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGraph", [("flags", ConstructorParameterDescription(self.flags)), ("json", ConstructorParameterDescription(self.json)), ("zoomToken", ConstructorParameterDescription(self.zoomToken))])
            }
        }
        public class Cons_statsGraphAsync: TypeConstructorDescription {
            public var token: String
            public init(token: String) {
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGraphAsync", [("token", ConstructorParameterDescription(self.token))])
            }
        }
        public class Cons_statsGraphError: TypeConstructorDescription {
            public var error: String
            public init(error: String) {
                self.error = error
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGraphError", [("error", ConstructorParameterDescription(self.error))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsGraph(let _data):
                return ("statsGraph", [("flags", ConstructorParameterDescription(_data.flags)), ("json", ConstructorParameterDescription(_data.json)), ("zoomToken", ConstructorParameterDescription(_data.zoomToken))])
            case .statsGraphAsync(let _data):
                return ("statsGraphAsync", [("token", ConstructorParameterDescription(_data.token))])
            case .statsGraphError(let _data):
                return ("statsGraphError", [("error", ConstructorParameterDescription(_data.error))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGroupTopAdmin", [("userId", ConstructorParameterDescription(self.userId)), ("deleted", ConstructorParameterDescription(self.deleted)), ("kicked", ConstructorParameterDescription(self.kicked)), ("banned", ConstructorParameterDescription(self.banned))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsGroupTopAdmin(let _data):
                return ("statsGroupTopAdmin", [("userId", ConstructorParameterDescription(_data.userId)), ("deleted", ConstructorParameterDescription(_data.deleted)), ("kicked", ConstructorParameterDescription(_data.kicked)), ("banned", ConstructorParameterDescription(_data.banned))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGroupTopInviter", [("userId", ConstructorParameterDescription(self.userId)), ("invitations", ConstructorParameterDescription(self.invitations))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsGroupTopInviter(let _data):
                return ("statsGroupTopInviter", [("userId", ConstructorParameterDescription(_data.userId)), ("invitations", ConstructorParameterDescription(_data.invitations))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsGroupTopPoster", [("userId", ConstructorParameterDescription(self.userId)), ("messages", ConstructorParameterDescription(self.messages)), ("avgChars", ConstructorParameterDescription(self.avgChars))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsGroupTopPoster(let _data):
                return ("statsGroupTopPoster", [("userId", ConstructorParameterDescription(_data.userId)), ("messages", ConstructorParameterDescription(_data.messages)), ("avgChars", ConstructorParameterDescription(_data.avgChars))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsPercentValue", [("part", ConstructorParameterDescription(self.part)), ("total", ConstructorParameterDescription(self.total))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsPercentValue(let _data):
                return ("statsPercentValue", [("part", ConstructorParameterDescription(_data.part)), ("total", ConstructorParameterDescription(_data.total))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("statsURL", [("url", ConstructorParameterDescription(self.url))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .statsURL(let _data):
                return ("statsURL", [("url", ConstructorParameterDescription(_data.url))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerKeyword", [("documentId", ConstructorParameterDescription(self.documentId)), ("keyword", ConstructorParameterDescription(self.keyword))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerKeyword(let _data):
                return ("stickerKeyword", [("documentId", ConstructorParameterDescription(_data.documentId)), ("keyword", ConstructorParameterDescription(_data.keyword))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerPack", [("emoticon", ConstructorParameterDescription(self.emoticon)), ("documents", ConstructorParameterDescription(self.documents))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerPack(let _data):
                return ("stickerPack", [("emoticon", ConstructorParameterDescription(_data.emoticon)), ("documents", ConstructorParameterDescription(_data.documents))])
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("stickerSet", [("flags", ConstructorParameterDescription(self.flags)), ("installedDate", ConstructorParameterDescription(self.installedDate)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("title", ConstructorParameterDescription(self.title)), ("shortName", ConstructorParameterDescription(self.shortName)), ("thumbs", ConstructorParameterDescription(self.thumbs)), ("thumbDcId", ConstructorParameterDescription(self.thumbDcId)), ("thumbVersion", ConstructorParameterDescription(self.thumbVersion)), ("thumbDocumentId", ConstructorParameterDescription(self.thumbDocumentId)), ("count", ConstructorParameterDescription(self.count)), ("hash", ConstructorParameterDescription(self.hash))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .stickerSet(let _data):
                return ("stickerSet", [("flags", ConstructorParameterDescription(_data.flags)), ("installedDate", ConstructorParameterDescription(_data.installedDate)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("title", ConstructorParameterDescription(_data.title)), ("shortName", ConstructorParameterDescription(_data.shortName)), ("thumbs", ConstructorParameterDescription(_data.thumbs)), ("thumbDcId", ConstructorParameterDescription(_data.thumbDcId)), ("thumbVersion", ConstructorParameterDescription(_data.thumbVersion)), ("thumbDocumentId", ConstructorParameterDescription(_data.thumbDocumentId)), ("count", ConstructorParameterDescription(_data.count)), ("hash", ConstructorParameterDescription(_data.hash))])
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
