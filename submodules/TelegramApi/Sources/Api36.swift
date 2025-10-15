public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription {
        case paymentResult(updates: Api.Updates)
        case paymentVerificationNeeded(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentResult(let updates):
                    if boxed {
                        buffer.appendInt32(1314881805)
                    }
                    updates.serialize(buffer, true)
                    break
                case .paymentVerificationNeeded(let url):
                    if boxed {
                        buffer.appendInt32(-666824391)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentResult(let updates):
                return ("paymentResult", [("updates", updates as Any)])
                case .paymentVerificationNeeded(let url):
                return ("paymentVerificationNeeded", [("url", url as Any)])
    }
    }
    
        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentResult(updates: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_paymentVerificationNeeded(_ reader: BufferReader) -> PaymentResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentVerificationNeeded(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum ResaleStarGifts: TypeConstructorDescription {
        case resaleStarGifts(flags: Int32, count: Int32, gifts: [Api.StarGift], nextOffset: String?, attributes: [Api.StarGiftAttribute]?, attributesHash: Int64?, chats: [Api.Chat], counters: [Api.StarGiftAttributeCounter]?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resaleStarGifts(let flags, let count, let gifts, let nextOffset, let attributes, let attributesHash, let chats, let counters, let users):
                    if boxed {
                        buffer.appendInt32(-1803939105)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes!.count))
                    for item in attributes! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(attributesHash!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(counters!.count))
                    for item in counters! {
                        item.serialize(buffer, true)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .resaleStarGifts(let flags, let count, let gifts, let nextOffset, let attributes, let attributesHash, let chats, let counters, let users):
                return ("resaleStarGifts", [("flags", flags as Any), ("count", count as Any), ("gifts", gifts as Any), ("nextOffset", nextOffset as Any), ("attributes", attributes as Any), ("attributesHash", attributesHash as Any), ("chats", chats as Any), ("counters", counters as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_resaleStarGifts(_ reader: BufferReader) -> ResaleStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StarGift]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGift.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.StarGiftAttribute]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            } }
            var _6: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt64() }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.StarGiftAttributeCounter]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttributeCounter.self)
            } }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.ResaleStarGifts.resaleStarGifts(flags: _1!, count: _2!, gifts: _3!, nextOffset: _4, attributes: _5, attributesHash: _6, chats: _7!, counters: _8, users: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription {
        case savedInfo(flags: Int32, savedInfo: Api.PaymentRequestedInfo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedInfo(let flags, let savedInfo):
                    if boxed {
                        buffer.appendInt32(-74456004)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {savedInfo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedInfo(let flags, let savedInfo):
                return ("savedInfo", [("flags", flags as Any), ("savedInfo", savedInfo as Any)])
    }
    }
    
        public static func parse_savedInfo(_ reader: BufferReader) -> SavedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.payments.SavedInfo.savedInfo(flags: _1!, savedInfo: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum SavedStarGifts: TypeConstructorDescription {
        case savedStarGifts(flags: Int32, count: Int32, chatNotificationsEnabled: Api.Bool?, gifts: [Api.SavedStarGift], nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedStarGifts(let flags, let count, let chatNotificationsEnabled, let gifts, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1779201615)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {chatNotificationsEnabled!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedStarGifts(let flags, let count, let chatNotificationsEnabled, let gifts, let nextOffset, let chats, let users):
                return ("savedStarGifts", [("flags", flags as Any), ("count", count as Any), ("chatNotificationsEnabled", chatNotificationsEnabled as Any), ("gifts", gifts as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_savedStarGifts(_ reader: BufferReader) -> SavedStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: [Api.SavedStarGift]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedStarGift.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.payments.SavedStarGifts.savedStarGifts(flags: _1!, count: _2!, chatNotificationsEnabled: _3, gifts: _4!, nextOffset: _5, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarGiftCollections: TypeConstructorDescription {
        case starGiftCollections(collections: [Api.StarGiftCollection])
        case starGiftCollectionsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftCollections(let collections):
                    if boxed {
                        buffer.appendInt32(-1977011469)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(collections.count))
                    for item in collections {
                        item.serialize(buffer, true)
                    }
                    break
                case .starGiftCollectionsNotModified:
                    if boxed {
                        buffer.appendInt32(-1598402793)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftCollections(let collections):
                return ("starGiftCollections", [("collections", collections as Any)])
                case .starGiftCollectionsNotModified:
                return ("starGiftCollectionsNotModified", [])
    }
    }
    
        public static func parse_starGiftCollections(_ reader: BufferReader) -> StarGiftCollections? {
            var _1: [Api.StarGiftCollection]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftCollection.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarGiftCollections.starGiftCollections(collections: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftCollectionsNotModified(_ reader: BufferReader) -> StarGiftCollections? {
            return Api.payments.StarGiftCollections.starGiftCollectionsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarGiftUpgradePreview: TypeConstructorDescription {
        case starGiftUpgradePreview(sampleAttributes: [Api.StarGiftAttribute], prices: [Api.StarGiftUpgradePrice], nextPrices: [Api.StarGiftUpgradePrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftUpgradePreview(let sampleAttributes, let prices, let nextPrices):
                    if boxed {
                        buffer.appendInt32(1038213101)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sampleAttributes.count))
                    for item in sampleAttributes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(nextPrices.count))
                    for item in nextPrices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftUpgradePreview(let sampleAttributes, let prices, let nextPrices):
                return ("starGiftUpgradePreview", [("sampleAttributes", sampleAttributes as Any), ("prices", prices as Any), ("nextPrices", nextPrices as Any)])
    }
    }
    
        public static func parse_starGiftUpgradePreview(_ reader: BufferReader) -> StarGiftUpgradePreview? {
            var _1: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _2: [Api.StarGiftUpgradePrice]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftUpgradePrice.self)
            }
            var _3: [Api.StarGiftUpgradePrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftUpgradePrice.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.StarGiftUpgradePreview.starGiftUpgradePreview(sampleAttributes: _1!, prices: _2!, nextPrices: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarGiftWithdrawalUrl: TypeConstructorDescription {
        case starGiftWithdrawalUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftWithdrawalUrl(let url):
                    if boxed {
                        buffer.appendInt32(-2069218660)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftWithdrawalUrl(let url):
                return ("starGiftWithdrawalUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starGiftWithdrawalUrl(_ reader: BufferReader) -> StarGiftWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarGiftWithdrawalUrl.starGiftWithdrawalUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription {
        case starGifts(hash: Int32, gifts: [Api.StarGift], chats: [Api.Chat], users: [Api.User])
        case starGiftsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGifts(let hash, let gifts, let chats, let users):
                    if boxed {
                        buffer.appendInt32(785918357)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .starGiftsNotModified:
                    if boxed {
                        buffer.appendInt32(-1551326360)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGifts(let hash, let gifts, let chats, let users):
                return ("starGifts", [("hash", hash as Any), ("gifts", gifts as Any), ("chats", chats as Any), ("users", users as Any)])
                case .starGiftsNotModified:
                return ("starGiftsNotModified", [])
    }
    }
    
        public static func parse_starGifts(_ reader: BufferReader) -> StarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StarGift]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGift.self)
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
                return Api.payments.StarGifts.starGifts(hash: _1!, gifts: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftsNotModified(_ reader: BufferReader) -> StarGifts? {
            return Api.payments.StarGifts.starGiftsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription {
        case starsRevenueAdsAccountUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueAdsAccountUrl(let url):
                    if boxed {
                        buffer.appendInt32(961445665)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueAdsAccountUrl(let url):
                return ("starsRevenueAdsAccountUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueAdsAccountUrl(_ reader: BufferReader) -> StarsRevenueAdsAccountUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueAdsAccountUrl.starsRevenueAdsAccountUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription {
        case starsRevenueStats(flags: Int32, topHoursGraph: Api.StatsGraph?, revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueStats(let flags, let topHoursGraph, let revenueGraph, let status, let usdRate):
                    if boxed {
                        buffer.appendInt32(1814066038)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {topHoursGraph!.serialize(buffer, true)}
                    revenueGraph.serialize(buffer, true)
                    status.serialize(buffer, true)
                    serializeDouble(usdRate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueStats(let flags, let topHoursGraph, let revenueGraph, let status, let usdRate):
                return ("starsRevenueStats", [("flags", flags as Any), ("topHoursGraph", topHoursGraph as Any), ("revenueGraph", revenueGraph as Any), ("status", status as Any), ("usdRate", usdRate as Any)])
    }
    }
    
        public static func parse_starsRevenueStats(_ reader: BufferReader) -> StarsRevenueStats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StatsGraph?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            } }
            var _3: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _4: Api.StarsRevenueStatus?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarsRevenueStatus
            }
            var _5: Double?
            _5 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.StarsRevenueStats.starsRevenueStats(flags: _1!, topHoursGraph: _2, revenueGraph: _3!, status: _4!, usdRate: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription {
        case starsRevenueWithdrawalUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueWithdrawalUrl(let url):
                    if boxed {
                        buffer.appendInt32(497778871)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueWithdrawalUrl(let url):
                return ("starsRevenueWithdrawalUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueWithdrawalUrl(_ reader: BufferReader) -> StarsRevenueWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueWithdrawalUrl.starsRevenueWithdrawalUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription {
        case starsStatus(flags: Int32, balance: Api.StarsAmount, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1822222573)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    balance.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(subscriptions!.count))
                    for item in subscriptions! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(subscriptionsNextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(subscriptionsMissingBalance!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(history!.count))
                    for item in history! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                return ("starsStatus", [("flags", flags as Any), ("balance", balance as Any), ("subscriptions", subscriptions as Any), ("subscriptionsNextOffset", subscriptionsNextOffset as Any), ("subscriptionsMissingBalance", subscriptionsMissingBalance as Any), ("history", history as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_starsStatus(_ reader: BufferReader) -> StarsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _3: [Api.StarsSubscription]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsSubscription.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt64() }
            var _6: [Api.StarsTransaction]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsTransaction.self)
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
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
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.StarsStatus.starsStatus(flags: _1!, balance: _2!, subscriptions: _3, subscriptionsNextOffset: _4, subscriptionsMissingBalance: _5, history: _6, nextOffset: _7, chats: _8!, users: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum SuggestedStarRefBots: TypeConstructorDescription {
        case suggestedStarRefBots(flags: Int32, count: Int32, suggestedBots: [Api.StarRefProgram], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedStarRefBots(let flags, let count, let suggestedBots, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(-1261053863)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(suggestedBots.count))
                    for item in suggestedBots {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedStarRefBots(let flags, let count, let suggestedBots, let users, let nextOffset):
                return ("suggestedStarRefBots", [("flags", flags as Any), ("count", count as Any), ("suggestedBots", suggestedBots as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
    }
    }
    
        public static func parse_suggestedStarRefBots(_ reader: BufferReader) -> SuggestedStarRefBots? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StarRefProgram]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarRefProgram.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.SuggestedStarRefBots.suggestedStarRefBots(flags: _1!, count: _2!, suggestedBots: _3!, users: _4!, nextOffset: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum UniqueStarGift: TypeConstructorDescription {
        case uniqueStarGift(gift: Api.StarGift, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .uniqueStarGift(let gift, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1097619176)
                    }
                    gift.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .uniqueStarGift(let gift, let chats, let users):
                return ("uniqueStarGift", [("gift", gift as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_uniqueStarGift(_ reader: BufferReader) -> UniqueStarGift? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
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
                return Api.payments.UniqueStarGift.uniqueStarGift(gift: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum UniqueStarGiftValueInfo: TypeConstructorDescription {
        case uniqueStarGiftValueInfo(flags: Int32, currency: String, value: Int64, initialSaleDate: Int32, initialSaleStars: Int64, initialSalePrice: Int64, lastSaleDate: Int32?, lastSalePrice: Int64?, floorPrice: Int64?, averagePrice: Int64?, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .uniqueStarGiftValueInfo(let flags, let currency, let value, let initialSaleDate, let initialSaleStars, let initialSalePrice, let lastSaleDate, let lastSalePrice, let floorPrice, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                    if boxed {
                        buffer.appendInt32(1362093126)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(value, buffer: buffer, boxed: false)
                    serializeInt32(initialSaleDate, buffer: buffer, boxed: false)
                    serializeInt64(initialSaleStars, buffer: buffer, boxed: false)
                    serializeInt64(initialSalePrice, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(lastSaleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(lastSalePrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(floorPrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(averagePrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(listedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(fragmentListedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(fragmentListedUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .uniqueStarGiftValueInfo(let flags, let currency, let value, let initialSaleDate, let initialSaleStars, let initialSalePrice, let lastSaleDate, let lastSalePrice, let floorPrice, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                return ("uniqueStarGiftValueInfo", [("flags", flags as Any), ("currency", currency as Any), ("value", value as Any), ("initialSaleDate", initialSaleDate as Any), ("initialSaleStars", initialSaleStars as Any), ("initialSalePrice", initialSalePrice as Any), ("lastSaleDate", lastSaleDate as Any), ("lastSalePrice", lastSalePrice as Any), ("floorPrice", floorPrice as Any), ("averagePrice", averagePrice as Any), ("listedCount", listedCount as Any), ("fragmentListedCount", fragmentListedCount as Any), ("fragmentListedUrl", fragmentListedUrl as Any)])
    }
    }
    
        public static func parse_uniqueStarGiftValueInfo(_ reader: BufferReader) -> UniqueStarGiftValueInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = reader.readInt32() }
            var _8: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_8 = reader.readInt64() }
            var _9: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_9 = reader.readInt64() }
            var _10: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_10 = reader.readInt64() }
            var _11: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_11 = reader.readInt32() }
            var _12: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_12 = reader.readInt32() }
            var _13: String?
            if Int(_1!) & Int(1 << 5) != 0 {_13 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 4) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 5) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.payments.UniqueStarGiftValueInfo.uniqueStarGiftValueInfo(flags: _1!, currency: _2!, value: _3!, initialSaleDate: _4!, initialSaleStars: _5!, initialSalePrice: _6!, lastSaleDate: _7, lastSalePrice: _8, floorPrice: _9, averagePrice: _10, listedCount: _11, fragmentListedCount: _12, fragmentListedUrl: _13)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription {
        case validatedRequestedInfo(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                    if boxed {
                        buffer.appendInt32(-784000893)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(id!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(shippingOptions!.count))
                    for item in shippingOptions! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                return ("validatedRequestedInfo", [("flags", flags as Any), ("id", id as Any), ("shippingOptions", shippingOptions as Any)])
    }
    }
    
        public static func parse_validatedRequestedInfo(_ reader: BufferReader) -> ValidatedRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: [Api.ShippingOption]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ShippingOption.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.ValidatedRequestedInfo.validatedRequestedInfo(flags: _1!, id: _2, shippingOptions: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription {
        case exportedGroupCallInvite(link: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedGroupCallInvite(let link):
                    if boxed {
                        buffer.appendInt32(541839704)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedGroupCallInvite(let link):
                return ("exportedGroupCallInvite", [("link", link as Any)])
    }
    }
    
        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.ExportedGroupCallInvite.exportedGroupCallInvite(link: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1636664659)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(participantsNextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                return ("groupCall", [("call", call as Any), ("participants", participants as Any), ("participantsNextOffset", participantsNextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Api.GroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
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
                return Api.phone.GroupCall.groupCall(call: _1!, participants: _2!, participantsNextOffset: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription {
        case groupCallStreamChannels(channels: [Api.GroupCallStreamChannel])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannels(let channels):
                    if boxed {
                        buffer.appendInt32(-790330702)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(channels.count))
                    for item in channels {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannels(let channels):
                return ("groupCallStreamChannels", [("channels", channels as Any)])
    }
    }
    
        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            var _1: [Api.GroupCallStreamChannel]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallStreamChannel.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.GroupCallStreamChannels.groupCallStreamChannels(channels: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription {
        case groupCallStreamRtmpUrl(url: String, key: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                    if boxed {
                        buffer.appendInt32(767505458)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                return ("groupCallStreamRtmpUrl", [("url", url as Any), ("key", key as Any)])
    }
    }
    
        public static func parse_groupCallStreamRtmpUrl(_ reader: BufferReader) -> GroupCallStreamRtmpUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.GroupCallStreamRtmpUrl.groupCallStreamRtmpUrl(url: _1!, key: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        case groupParticipants(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                    if boxed {
                        buffer.appendInt32(-193506890)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(nextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                return ("groupParticipants", [("count", count as Any), ("participants", participants as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any), ("version", version as Any)])
    }
    }
    
        public static func parse_groupParticipants(_ reader: BufferReader) -> GroupParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.phone.GroupParticipants.groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        case joinAsPeers(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .joinAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1343921601)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .joinAsPeers(let peers, let chats, let users):
                return ("joinAsPeers", [("peers", peers as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_joinAsPeers(_ reader: BufferReader) -> JoinAsPeers? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.phone.JoinAsPeers.joinAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(phoneCall: Api.PhoneCall, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let phoneCall, let users):
                    if boxed {
                        buffer.appendInt32(-326966976)
                    }
                    phoneCall.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .phoneCall(let phoneCall, let users):
                return ("phoneCall", [("phoneCall", phoneCall as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.PhoneCall.phoneCall(phoneCall: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        case photo(photo: Api.Photo, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let photo, let users):
                    if boxed {
                        buffer.appendInt32(539045032)
                    }
                    photo.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photo(let photo, let users):
                return ("photo", [("photo", photo as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photo.photo(photo: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        case photos(photos: [Api.Photo], users: [Api.User])
        case photosSlice(count: Int32, photos: [Api.Photo], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photos(let photos, let users):
                    if boxed {
                        buffer.appendInt32(-1916114267)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .photosSlice(let count, let photos, let users):
                    if boxed {
                        buffer.appendInt32(352657236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .photos(let photos, let users):
                return ("photos", [("photos", photos as Any), ("users", users as Any)])
                case .photosSlice(let count, let photos, let users):
                return ("photosSlice", [("count", count as Any), ("photos", photos as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_photos(_ reader: BufferReader) -> Photos? {
            var _1: [Api.Photo]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photos.photos(photos: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Photo]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.photos.Photos.photosSlice(count: _1!, photos: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum BoostsList: TypeConstructorDescription {
        case boostsList(flags: Int32, count: Int32, boosts: [Api.Boost], nextOffset: String?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostsList(let flags, let count, let boosts, let nextOffset, let users):
                    if boxed {
                        buffer.appendInt32(-2030542532)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(boosts.count))
                    for item in boosts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boostsList(let flags, let count, let boosts, let nextOffset, let users):
                return ("boostsList", [("flags", flags as Any), ("count", count as Any), ("boosts", boosts as Any), ("nextOffset", nextOffset as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_boostsList(_ reader: BufferReader) -> BoostsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.Boost]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Boost.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.premium.BoostsList.boostsList(flags: _1!, count: _2!, boosts: _3!, nextOffset: _4, users: _5!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum BoostsStatus: TypeConstructorDescription {
        case boostsStatus(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, giftBoosts: Int32?, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?, boostUrl: String, prepaidGiveaways: [Api.PrepaidGiveaway]?, myBoostSlots: [Int32]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let giftBoosts, let nextLevelBoosts, let premiumAudience, let boostUrl, let prepaidGiveaways, let myBoostSlots):
                    if boxed {
                        buffer.appendInt32(1230586490)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(level, buffer: buffer, boxed: false)
                    serializeInt32(currentLevelBoosts, buffer: buffer, boxed: false)
                    serializeInt32(boosts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(giftBoosts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(nextLevelBoosts!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {premiumAudience!.serialize(buffer, true)}
                    serializeString(boostUrl, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prepaidGiveaways!.count))
                    for item in prepaidGiveaways! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(myBoostSlots!.count))
                    for item in myBoostSlots! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .boostsStatus(let flags, let level, let currentLevelBoosts, let boosts, let giftBoosts, let nextLevelBoosts, let premiumAudience, let boostUrl, let prepaidGiveaways, let myBoostSlots):
                return ("boostsStatus", [("flags", flags as Any), ("level", level as Any), ("currentLevelBoosts", currentLevelBoosts as Any), ("boosts", boosts as Any), ("giftBoosts", giftBoosts as Any), ("nextLevelBoosts", nextLevelBoosts as Any), ("premiumAudience", premiumAudience as Any), ("boostUrl", boostUrl as Any), ("prepaidGiveaways", prepaidGiveaways as Any), ("myBoostSlots", myBoostSlots as Any)])
    }
    }
    
        public static func parse_boostsStatus(_ reader: BufferReader) -> BoostsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            var _7: Api.StatsPercentValue?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            } }
            var _8: String?
            _8 = parseString(reader)
            var _9: [Api.PrepaidGiveaway]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrepaidGiveaway.self)
            } }
            var _10: [Int32]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.premium.BoostsStatus.boostsStatus(flags: _1!, level: _2!, currentLevelBoosts: _3!, boosts: _4!, giftBoosts: _5, nextLevelBoosts: _6, premiumAudience: _7, boostUrl: _8!, prepaidGiveaways: _9, myBoostSlots: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.premium {
    enum MyBoosts: TypeConstructorDescription {
        case myBoosts(myBoosts: [Api.MyBoost], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .myBoosts(let myBoosts, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1696454430)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(myBoosts.count))
                    for item in myBoosts {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .myBoosts(let myBoosts, let chats, let users):
                return ("myBoosts", [("myBoosts", myBoosts as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_myBoosts(_ reader: BufferReader) -> MyBoosts? {
            var _1: [Api.MyBoost]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MyBoost.self)
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
                return Api.premium.MyBoosts.myBoosts(myBoosts: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
