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
        case starsTransaction(flags: Int32, id: String, stars: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsTransaction(let flags, let id, let stars, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift, let floodskipNumber, let starrefCommissionPermille, let starrefPeer, let starrefAmount):
                    if boxed {
                        buffer.appendInt32(1692387622)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    stars.serialize(buffer, true)
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
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsTransaction(let flags, let id, let stars, let date, let peer, let title, let description, let photo, let transactionDate, let transactionUrl, let botPayload, let msgId, let extendedMedia, let subscriptionPeriod, let giveawayPostId, let stargift, let floodskipNumber, let starrefCommissionPermille, let starrefPeer, let starrefAmount):
                return ("starsTransaction", [("flags", flags as Any), ("id", id as Any), ("stars", stars as Any), ("date", date as Any), ("peer", peer as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("transactionDate", transactionDate as Any), ("transactionUrl", transactionUrl as Any), ("botPayload", botPayload as Any), ("msgId", msgId as Any), ("extendedMedia", extendedMedia as Any), ("subscriptionPeriod", subscriptionPeriod as Any), ("giveawayPostId", giveawayPostId as Any), ("stargift", stargift as Any), ("floodskipNumber", floodskipNumber as Any), ("starrefCommissionPermille", starrefCommissionPermille as Any), ("starrefPeer", starrefPeer as Any), ("starrefAmount", starrefAmount as Any)])
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 {
                return Api.StarsTransaction.starsTransaction(flags: _1!, id: _2!, stars: _3!, date: _4!, peer: _5!, title: _6, description: _7, photo: _8, transactionDate: _9, transactionUrl: _10, botPayload: _11, msgId: _12, extendedMedia: _13, subscriptionPeriod: _14, giveawayPostId: _15, stargift: _16, floodskipNumber: _17, starrefCommissionPermille: _18, starrefPeer: _19, starrefAmount: _20)
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
public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        case stickerSetCovered(set: Api.StickerSet, cover: Api.Document)
        case stickerSetFullCovered(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document])
        case stickerSetMultiCovered(set: Api.StickerSet, covers: [Api.Document])
        case stickerSetNoCovered(set: Api.StickerSet)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSetCovered(let set, let cover):
                    if boxed {
                        buffer.appendInt32(1678812626)
                    }
                    set.serialize(buffer, true)
                    cover.serialize(buffer, true)
                    break
                case .stickerSetFullCovered(let set, let packs, let keywords, let documents):
                    if boxed {
                        buffer.appendInt32(1087454222)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetMultiCovered(let set, let covers):
                    if boxed {
                        buffer.appendInt32(872932635)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(covers.count))
                    for item in covers {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetNoCovered(let set):
                    if boxed {
                        buffer.appendInt32(2008112412)
                    }
                    set.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSetCovered(let set, let cover):
                return ("stickerSetCovered", [("set", set as Any), ("cover", cover as Any)])
                case .stickerSetFullCovered(let set, let packs, let keywords, let documents):
                return ("stickerSetFullCovered", [("set", set as Any), ("packs", packs as Any), ("keywords", keywords as Any), ("documents", documents as Any)])
                case .stickerSetMultiCovered(let set, let covers):
                return ("stickerSetMultiCovered", [("set", set as Any), ("covers", covers as Any)])
                case .stickerSetNoCovered(let set):
                return ("stickerSetNoCovered", [("set", set as Any)])
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
                return Api.StickerSetCovered.stickerSetCovered(set: _1!, cover: _2!)
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
                return Api.StickerSetCovered.stickerSetFullCovered(set: _1!, packs: _2!, keywords: _3!, documents: _4!)
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
                return Api.StickerSetCovered.stickerSetMultiCovered(set: _1!, covers: _2!)
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
                return Api.StickerSetCovered.stickerSetNoCovered(set: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StoriesStealthMode: TypeConstructorDescription {
        case storiesStealthMode(flags: Int32, activeUntilDate: Int32?, cooldownUntilDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storiesStealthMode(let flags, let activeUntilDate, let cooldownUntilDate):
                    if boxed {
                        buffer.appendInt32(1898850301)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(activeUntilDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(cooldownUntilDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storiesStealthMode(let flags, let activeUntilDate, let cooldownUntilDate):
                return ("storiesStealthMode", [("flags", flags as Any), ("activeUntilDate", activeUntilDate as Any), ("cooldownUntilDate", cooldownUntilDate as Any)])
    }
    }
    
        public static func parse_storiesStealthMode(_ reader: BufferReader) -> StoriesStealthMode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoriesStealthMode.storiesStealthMode(flags: _1!, activeUntilDate: _2, cooldownUntilDate: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StoryFwdHeader: TypeConstructorDescription {
        case storyFwdHeader(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyFwdHeader(let flags, let from, let fromName, let storyId):
                    if boxed {
                        buffer.appendInt32(-1205411504)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {from!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(fromName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(storyId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyFwdHeader(let flags, let from, let fromName, let storyId):
                return ("storyFwdHeader", [("flags", flags as Any), ("from", from as Any), ("fromName", fromName as Any), ("storyId", storyId as Any)])
    }
    }
    
        public static func parse_storyFwdHeader(_ reader: BufferReader) -> StoryFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryFwdHeader.storyFwdHeader(flags: _1!, from: _2, fromName: _3, storyId: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription {
        case storyItem(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?)
        case storyItemDeleted(id: Int32)
        case storyItemSkipped(flags: Int32, id: Int32, date: Int32, expireDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyItem(let flags, let id, let date, let fromId, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                    if boxed {
                        buffer.appendInt32(2041735716)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 18) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {fwdFrom!.serialize(buffer, true)}
                    serializeInt32(expireDate, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(caption!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    media.serialize(buffer, true)
                    if Int(flags) & Int(1 << 14) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(mediaAreas!.count))
                    for item in mediaAreas! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(privacy!.count))
                    for item in privacy! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 3) != 0 {views!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {sentReaction!.serialize(buffer, true)}
                    break
                case .storyItemDeleted(let id):
                    if boxed {
                        buffer.appendInt32(1374088783)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .storyItemSkipped(let flags, let id, let date, let expireDate):
                    if boxed {
                        buffer.appendInt32(-5388013)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(expireDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyItem(let flags, let id, let date, let fromId, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                return ("storyItem", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("fromId", fromId as Any), ("fwdFrom", fwdFrom as Any), ("expireDate", expireDate as Any), ("caption", caption as Any), ("entities", entities as Any), ("media", media as Any), ("mediaAreas", mediaAreas as Any), ("privacy", privacy as Any), ("views", views as Any), ("sentReaction", sentReaction as Any)])
                case .storyItemDeleted(let id):
                return ("storyItemDeleted", [("id", id as Any)])
                case .storyItemSkipped(let flags, let id, let date, let expireDate):
                return ("storyItemSkipped", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("expireDate", expireDate as Any)])
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
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _5: Api.StoryFwdHeader?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StoryFwdHeader
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            var _8: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _9: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _10: [Api.MediaArea]?
            if Int(_1!) & Int(1 << 14) != 0 {if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MediaArea.self)
            } }
            var _11: [Api.PrivacyRule]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            } }
            var _12: Api.StoryViews?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StoryViews
            } }
            var _13: Api.Reaction?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Reaction
            } }
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.StoryItem.storyItem(flags: _1!, id: _2!, date: _3!, fromId: _4, fwdFrom: _5, expireDate: _6!, caption: _7, entities: _8, media: _9!, mediaAreas: _10, privacy: _11, views: _12, sentReaction: _13)
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
                return Api.StoryItem.storyItemDeleted(id: _1!)
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
                return Api.StoryItem.storyItemSkipped(flags: _1!, id: _2!, date: _3!, expireDate: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
