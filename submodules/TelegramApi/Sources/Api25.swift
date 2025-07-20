public extension Api {
    enum StarRefProgram: TypeConstructorDescription {
        case starRefProgram(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                    if boxed {
                        buffer.appendInt32(-586389774)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt32(commissionPermille, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(durationMonths!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(endDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {dailyRevenuePerUser!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starRefProgram(let flags, let botId, let commissionPermille, let durationMonths, let endDate, let dailyRevenuePerUser):
                return ("starRefProgram", [("flags", flags as Any), ("botId", botId as Any), ("commissionPermille", commissionPermille as Any), ("durationMonths", durationMonths as Any), ("endDate", endDate as Any), ("dailyRevenuePerUser", dailyRevenuePerUser as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            var _6: Api.StarsAmount?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StarRefProgram.starRefProgram(flags: _1!, botId: _2!, commissionPermille: _3!, durationMonths: _4, endDate: _5, dailyRevenuePerUser: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsAmount: TypeConstructorDescription {
        case starsAmount(amount: Int64, nanos: Int32)
        case starsTonAmount(amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsAmount(let amount, let nanos):
                    if boxed {
                        buffer.appendInt32(-1145654109)
                    }
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeInt32(nanos, buffer: buffer, boxed: false)
                    break
                case .starsTonAmount(let amount):
                    if boxed {
                        buffer.appendInt32(1957618656)
                    }
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsAmount(let amount, let nanos):
                return ("starsAmount", [("amount", amount as Any), ("nanos", nanos as Any)])
                case .starsTonAmount(let amount):
                return ("starsTonAmount", [("amount", amount as Any)])
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
                return Api.StarsAmount.starsAmount(amount: _1!, nanos: _2!)
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
                return Api.StarsAmount.starsTonAmount(amount: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription {
        case starsGiftOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(1577421297)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiftOption(let flags, let stars, let storeProduct, let currency, let amount):
                return ("starsGiftOption", [("flags", flags as Any), ("stars", stars as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsGiftOption(_ reader: BufferReader) -> StarsGiftOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
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
                return Api.StarsGiftOption.starsGiftOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription {
        case starsGiveawayOption(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                    if boxed {
                        buffer.appendInt32(-1798404822)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    serializeInt32(yearlyBoosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(winners.count))
                    for item in winners {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayOption(let flags, let stars, let yearlyBoosts, let storeProduct, let currency, let amount, let winners):
                return ("starsGiveawayOption", [("flags", flags as Any), ("stars", stars as Any), ("yearlyBoosts", yearlyBoosts as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any), ("winners", winners as Any)])
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
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
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
                return Api.StarsGiveawayOption.starsGiveawayOption(flags: _1!, stars: _2!, yearlyBoosts: _3!, storeProduct: _4, currency: _5!, amount: _6!, winners: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription {
        case starsGiveawayWinnersOption(flags: Int32, users: Int32, perUserStars: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                    if boxed {
                        buffer.appendInt32(1411605001)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(users, buffer: buffer, boxed: false)
                    serializeInt64(perUserStars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsGiveawayWinnersOption(let flags, let users, let perUserStars):
                return ("starsGiveawayWinnersOption", [("flags", flags as Any), ("users", users as Any), ("perUserStars", perUserStars as Any)])
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
                return Api.StarsGiveawayWinnersOption.starsGiveawayWinnersOption(flags: _1!, users: _2!, perUserStars: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsRevenueStatus: TypeConstructorDescription {
        case starsRevenueStatus(flags: Int32, currentBalance: Api.StarsAmount, availableBalance: Api.StarsAmount, overallRevenue: Api.StarsAmount, nextWithdrawalAt: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueStatus(let flags, let currentBalance, let availableBalance, let overallRevenue, let nextWithdrawalAt):
                    if boxed {
                        buffer.appendInt32(-21080943)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    currentBalance.serialize(buffer, true)
                    availableBalance.serialize(buffer, true)
                    overallRevenue.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(nextWithdrawalAt!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueStatus(let flags, let currentBalance, let availableBalance, let overallRevenue, let nextWithdrawalAt):
                return ("starsRevenueStatus", [("flags", flags as Any), ("currentBalance", currentBalance as Any), ("availableBalance", availableBalance as Any), ("overallRevenue", overallRevenue as Any), ("nextWithdrawalAt", nextWithdrawalAt as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.StarsRevenueStatus.starsRevenueStatus(flags: _1!, currentBalance: _2!, availableBalance: _3!, overallRevenue: _4!, nextWithdrawalAt: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsSubscription: TypeConstructorDescription {
        case starsSubscription(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?, title: String?, photo: Api.WebDocument?, invoiceSlug: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsSubscription(let flags, let id, let peer, let untilDate, let pricing, let chatInviteHash, let title, let photo, let invoiceSlug):
                    if boxed {
                        buffer.appendInt32(779004698)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    pricing.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(chatInviteHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(invoiceSlug!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsSubscription(let flags, let id, let peer, let untilDate, let pricing, let chatInviteHash, let title, let photo, let invoiceSlug):
                return ("starsSubscription", [("flags", flags as Any), ("id", id as Any), ("peer", peer as Any), ("untilDate", untilDate as Any), ("pricing", pricing as Any), ("chatInviteHash", chatInviteHash as Any), ("title", title as Any), ("photo", photo as Any), ("invoiceSlug", invoiceSlug as Any)])
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
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _9: String?
            if Int(_1!) & Int(1 << 6) != 0 {_9 = parseString(reader) }
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
                return Api.StarsSubscription.starsSubscription(flags: _1!, id: _2!, peer: _3!, untilDate: _4!, pricing: _5!, chatInviteHash: _6, title: _7, photo: _8, invoiceSlug: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsSubscriptionPricing: TypeConstructorDescription {
        case starsSubscriptionPricing(period: Int32, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsSubscriptionPricing(let period, let amount):
                    if boxed {
                        buffer.appendInt32(88173912)
                    }
                    serializeInt32(period, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsSubscriptionPricing(let period, let amount):
                return ("starsSubscriptionPricing", [("period", period as Any), ("amount", amount as Any)])
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
                return Api.StarsSubscriptionPricing.starsSubscriptionPricing(period: _1!, amount: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsTopupOption: TypeConstructorDescription {
        case starsTopupOption(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTopupOption(let flags, let stars, let storeProduct, let currency, let amount):
                    if boxed {
                        buffer.appendInt32(198776256)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stars, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(storeProduct!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsTopupOption(let flags, let stars, let storeProduct, let currency, let amount):
                return ("starsTopupOption", [("flags", flags as Any), ("stars", stars as Any), ("storeProduct", storeProduct as Any), ("currency", currency as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_starsTopupOption(_ reader: BufferReader) -> StarsTopupOption? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
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
                return Api.StarsTopupOption.starsTopupOption(flags: _1!, stars: _2!, storeProduct: _3, currency: _4!, amount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsTransaction: TypeConstructorDescription {
        case starsTransaction(flags: Int32, id: String, amount: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?, paidMessages: Int32?, premiumGiftMonths: Int32?, adsProceedsFromDate: Int32?, adsProceedsToDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTransaction(let flags, let id, let amount, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift, let floodskipNumber, let starrefCommissionPermille, let starrefPeer, let starrefAmount, let paidMessages, let premiumGiftMonths, let adsProceedsFromDate, let adsProceedsToDate):
                    if boxed {
                        buffer.appendInt32(325426864)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    amount.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(transactionDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(transactionUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeBytes(botPayload!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt32(msgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(extendedMedia!.count))
                    for item in extendedMedia! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 12) != 0 {serializeInt32(subscriptionPeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(giveawayPostId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {stargift!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(floodskipNumber!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeInt32(starrefCommissionPermille!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {starrefPeer!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {starrefAmount!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 19) != 0 {serializeInt32(paidMessages!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 20) != 0 {serializeInt32(premiumGiftMonths!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 23) != 0 {serializeInt32(adsProceedsFromDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 23) != 0 {serializeInt32(adsProceedsToDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsTransaction(let flags, let id, let amount, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift, let floodskipNumber, let starrefCommissionPermille, let starrefPeer, let starrefAmount, let paidMessages, let premiumGiftMonths, let adsProceedsFromDate, let adsProceedsToDate):
                return ("starsTransaction", [("flags", flags as Any), ("id", id as Any), ("amount", amount as Any), ("date", date as Any), ("peer", peer as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("transactionDate", transactionDate as Any), ("transactionUrl", transactionUrl as Any), ("botPayload", botPayload as Any), ("msgId", msgId as Any), ("extendedMedia", extendedMedia as Any), ("subscriptionPeriod", subscriptionPeriod as Any), ("giveawayPostId", giveawayPostId as Any), ("stargift", stargift as Any), ("floodskipNumber", floodskipNumber as Any), ("starrefCommissionPermille", starrefCommissionPermille as Any), ("starrefPeer", starrefPeer as Any), ("starrefAmount", starrefAmount as Any), ("paidMessages", paidMessages as Any), ("premiumGiftMonths", premiumGiftMonths as Any), ("adsProceedsFromDate", adsProceedsFromDate as Any), ("adsProceedsToDate", adsProceedsToDate as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_9 = reader.readInt32() }
            var _10: String?
            if Int(_1!) & Int(1 << 5) != 0 {_10 = parseString(reader) }
            var _11: Buffer?
            if Int(_1!) & Int(1 << 7) != 0 {_11 = parseBytes(reader) }
            var _12: Int32?
            if Int(_1!) & Int(1 << 8) != 0 {_12 = reader.readInt32() }
            var _13: [Api.MessageMedia]?
            if Int(_1!) & Int(1 << 9) != 0 {if let _ = reader.readInt32() {
                _13 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageMedia.self)
            } }
            var _14: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {_14 = reader.readInt32() }
            var _15: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_15 = reader.readInt32() }
            var _16: Api.StarGift?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.StarGift
            } }
            var _17: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_17 = reader.readInt32() }
            var _18: Int32?
            if Int(_1!) & Int(1 << 16) != 0 {_18 = reader.readInt32() }
            var _19: Api.Peer?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _20: Api.StarsAmount?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            } }
            var _21: Int32?
            if Int(_1!) & Int(1 << 19) != 0 {_21 = reader.readInt32() }
            var _22: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {_22 = reader.readInt32() }
            var _23: Int32?
            if Int(_1!) & Int(1 << 23) != 0 {_23 = reader.readInt32() }
            var _24: Int32?
            if Int(_1!) & Int(1 << 23) != 0 {_24 = reader.readInt32() }
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
                return Api.StarsTransaction.starsTransaction(flags: _1!, id: _2!, amount: _3!, date: _4!, peer: _5!, title: _6, description: _7, photo: _8, transactionDate: _9, transactionUrl: _10, botPayload: _11, msgId: _12, extendedMedia: _13, subscriptionPeriod: _14, giveawayPostId: _15, stargift: _16, floodskipNumber: _17, starrefCommissionPermille: _18, starrefPeer: _19, starrefAmount: _20, paidMessages: _21, premiumGiftMonths: _22, adsProceedsFromDate: _23, adsProceedsToDate: _24)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StarsTransactionPeer: TypeConstructorDescription {
        case starsTransactionPeer(peer: Api.Peer)
        case starsTransactionPeerAPI
        case starsTransactionPeerAds
        case starsTransactionPeerAppStore
        case starsTransactionPeerFragment
        case starsTransactionPeerPlayMarket
        case starsTransactionPeerPremiumBot
        case starsTransactionPeerUnsupported
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTransactionPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-670195363)
                    }
                    peer.serialize(buffer, true)
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
                case .starsTransactionPeer(let peer):
                return ("starsTransactionPeer", [("peer", peer as Any)])
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
                return Api.StarsTransactionPeer.starsTransactionPeer(peer: _1!)
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
        case statsAbsValueAndPrev(current: Double, previous: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsAbsValueAndPrev(let current, let previous):
                    if boxed {
                        buffer.appendInt32(-884757282)
                    }
                    serializeDouble(current, buffer: buffer, boxed: false)
                    serializeDouble(previous, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsAbsValueAndPrev(let current, let previous):
                return ("statsAbsValueAndPrev", [("current", current as Any), ("previous", previous as Any)])
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
                return Api.StatsAbsValueAndPrev.statsAbsValueAndPrev(current: _1!, previous: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsDateRangeDays: TypeConstructorDescription {
        case statsDateRangeDays(minDate: Int32, maxDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsDateRangeDays(let minDate, let maxDate):
                    if boxed {
                        buffer.appendInt32(-1237848657)
                    }
                    serializeInt32(minDate, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsDateRangeDays(let minDate, let maxDate):
                return ("statsDateRangeDays", [("minDate", minDate as Any), ("maxDate", maxDate as Any)])
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
                return Api.StatsDateRangeDays.statsDateRangeDays(minDate: _1!, maxDate: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGraph: TypeConstructorDescription {
        case statsGraph(flags: Int32, json: Api.DataJSON, zoomToken: String?)
        case statsGraphAsync(token: String)
        case statsGraphError(error: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGraph(let flags, let json, let zoomToken):
                    if boxed {
                        buffer.appendInt32(-1901828938)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    json.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(zoomToken!, buffer: buffer, boxed: false)}
                    break
                case .statsGraphAsync(let token):
                    if boxed {
                        buffer.appendInt32(1244130093)
                    }
                    serializeString(token, buffer: buffer, boxed: false)
                    break
                case .statsGraphError(let error):
                    if boxed {
                        buffer.appendInt32(-1092839390)
                    }
                    serializeString(error, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGraph(let flags, let json, let zoomToken):
                return ("statsGraph", [("flags", flags as Any), ("json", json as Any), ("zoomToken", zoomToken as Any)])
                case .statsGraphAsync(let token):
                return ("statsGraphAsync", [("token", token as Any)])
                case .statsGraphError(let error):
                return ("statsGraphError", [("error", error as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StatsGraph.statsGraph(flags: _1!, json: _2!, zoomToken: _3)
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
                return Api.StatsGraph.statsGraphAsync(token: _1!)
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
                return Api.StatsGraph.statsGraphError(error: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopAdmin: TypeConstructorDescription {
        case statsGroupTopAdmin(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopAdmin(let userId, let deleted, let kicked, let banned):
                    if boxed {
                        buffer.appendInt32(-682079097)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(deleted, buffer: buffer, boxed: false)
                    serializeInt32(kicked, buffer: buffer, boxed: false)
                    serializeInt32(banned, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopAdmin(let userId, let deleted, let kicked, let banned):
                return ("statsGroupTopAdmin", [("userId", userId as Any), ("deleted", deleted as Any), ("kicked", kicked as Any), ("banned", banned as Any)])
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
                return Api.StatsGroupTopAdmin.statsGroupTopAdmin(userId: _1!, deleted: _2!, kicked: _3!, banned: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopInviter: TypeConstructorDescription {
        case statsGroupTopInviter(userId: Int64, invitations: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopInviter(let userId, let invitations):
                    if boxed {
                        buffer.appendInt32(1398765469)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(invitations, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopInviter(let userId, let invitations):
                return ("statsGroupTopInviter", [("userId", userId as Any), ("invitations", invitations as Any)])
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
                return Api.StatsGroupTopInviter.statsGroupTopInviter(userId: _1!, invitations: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsGroupTopPoster: TypeConstructorDescription {
        case statsGroupTopPoster(userId: Int64, messages: Int32, avgChars: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsGroupTopPoster(let userId, let messages, let avgChars):
                    if boxed {
                        buffer.appendInt32(-1660637285)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(messages, buffer: buffer, boxed: false)
                    serializeInt32(avgChars, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsGroupTopPoster(let userId, let messages, let avgChars):
                return ("statsGroupTopPoster", [("userId", userId as Any), ("messages", messages as Any), ("avgChars", avgChars as Any)])
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
                return Api.StatsGroupTopPoster.statsGroupTopPoster(userId: _1!, messages: _2!, avgChars: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsPercentValue: TypeConstructorDescription {
        case statsPercentValue(part: Double, total: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsPercentValue(let part, let total):
                    if boxed {
                        buffer.appendInt32(-875679776)
                    }
                    serializeDouble(part, buffer: buffer, boxed: false)
                    serializeDouble(total, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsPercentValue(let part, let total):
                return ("statsPercentValue", [("part", part as Any), ("total", total as Any)])
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
                return Api.StatsPercentValue.statsPercentValue(part: _1!, total: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StatsURL: TypeConstructorDescription {
        case statsURL(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .statsURL(let url):
                    if boxed {
                        buffer.appendInt32(1202287072)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .statsURL(let url):
                return ("statsURL", [("url", url as Any)])
    }
    }
    
        public static func parse_statsURL(_ reader: BufferReader) -> StatsURL? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.StatsURL.statsURL(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StickerKeyword: TypeConstructorDescription {
        case stickerKeyword(documentId: Int64, keyword: [String])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerKeyword(let documentId, let keyword):
                    if boxed {
                        buffer.appendInt32(-50416996)
                    }
                    serializeInt64(documentId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keyword.count))
                    for item in keyword {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerKeyword(let documentId, let keyword):
                return ("stickerKeyword", [("documentId", documentId as Any), ("keyword", keyword as Any)])
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
                return Api.StickerKeyword.stickerKeyword(documentId: _1!, keyword: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StickerPack: TypeConstructorDescription {
        case stickerPack(emoticon: String, documents: [Int64])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerPack(let emoticon, let documents):
                    if boxed {
                        buffer.appendInt32(313694676)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerPack(let emoticon, let documents):
                return ("stickerPack", [("emoticon", emoticon as Any), ("documents", documents as Any)])
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
                return Api.StickerPack.stickerPack(emoticon: _1!, documents: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, thumbDocumentId: Int64?, count: Int32, hash: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumbs, let thumbDcId, let thumbVersion, let thumbDocumentId, let count, let hash):
                    if boxed {
                        buffer.appendInt32(768691932)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(installedDate!, buffer: buffer, boxed: false)}
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(thumbs!.count))
                    for item in thumbs! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(thumbDcId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(thumbVersion!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeInt64(thumbDocumentId!, buffer: buffer, boxed: false)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let flags, let installedDate, let id, let accessHash, let title, let shortName, let thumbs, let thumbDcId, let thumbVersion, let thumbDocumentId, let count, let hash):
                return ("stickerSet", [("flags", flags as Any), ("installedDate", installedDate as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("title", title as Any), ("shortName", shortName as Any), ("thumbs", thumbs as Any), ("thumbDcId", thumbDcId as Any), ("thumbVersion", thumbVersion as Any), ("thumbDocumentId", thumbDocumentId as Any), ("count", count as Any), ("hash", hash as Any)])
    }
    }
    
        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: [Api.PhotoSize]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PhotoSize.self)
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_9 = reader.readInt32() }
            var _10: Int64?
            if Int(_1!) & Int(1 << 8) != 0 {_10 = reader.readInt64() }
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
                return Api.StickerSet.stickerSet(flags: _1!, installedDate: _2, id: _3!, accessHash: _4!, title: _5!, shortName: _6!, thumbs: _7, thumbDcId: _8, thumbVersion: _9, thumbDocumentId: _10, count: _11!, hash: _12!)
            }
            else {
                return nil
            }
        }
    
    }
}
