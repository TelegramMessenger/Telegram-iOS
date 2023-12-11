public extension Api {
    enum ShippingOption: TypeConstructorDescription {
        case shippingOption(id: String, title: String, prices: [Api.LabeledPrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .shippingOption(let id, let title, let prices):
                    if boxed {
                        buffer.appendInt32(-1239335713)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .shippingOption(let id, let title, let prices):
                return ("shippingOption", [("id", id as Any), ("title", title as Any), ("prices", prices as Any)])
    }
    }
    
        public static func parse_shippingOption(_ reader: BufferReader) -> ShippingOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.LabeledPrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LabeledPrice.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ShippingOption.shippingOption(id: _1!, title: _2!, prices: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SimpleWebViewResult: TypeConstructorDescription {
        case simpleWebViewResultUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .simpleWebViewResultUrl(let url):
                    if boxed {
                        buffer.appendInt32(-2010155333)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .simpleWebViewResultUrl(let url):
                return ("simpleWebViewResultUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_simpleWebViewResultUrl(_ reader: BufferReader) -> SimpleWebViewResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.SimpleWebViewResult.simpleWebViewResultUrl(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription {
        case sponsoredMessage(flags: Int32, randomId: Buffer, fromId: Api.Peer?, chatInvite: Api.ChatInvite?, chatInviteHash: String?, channelPost: Int32?, startParam: String?, webpage: Api.SponsoredWebPage?, app: Api.BotApp?, message: String, entities: [Api.MessageEntity]?, buttonText: String?, sponsorInfo: String?, additionalInfo: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessage(let flags, let randomId, let fromId, let chatInvite, let chatInviteHash, let channelPost, let startParam, let webpage, let app, let message, let entities, let buttonText, let sponsorInfo, let additionalInfo):
                    if boxed {
                        buffer.appendInt32(-313293833)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeBytes(randomId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {chatInvite!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(chatInviteHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(channelPost!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(startParam!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {webpage!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 10) != 0 {app!.serialize(buffer, true)}
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 11) != 0 {serializeString(buttonText!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(sponsorInfo!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(additionalInfo!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredMessage(let flags, let randomId, let fromId, let chatInvite, let chatInviteHash, let channelPost, let startParam, let webpage, let app, let message, let entities, let buttonText, let sponsorInfo, let additionalInfo):
                return ("sponsoredMessage", [("flags", flags as Any), ("randomId", randomId as Any), ("fromId", fromId as Any), ("chatInvite", chatInvite as Any), ("chatInviteHash", chatInviteHash as Any), ("channelPost", channelPost as Any), ("startParam", startParam as Any), ("webpage", webpage as Any), ("app", app as Any), ("message", message as Any), ("entities", entities as Any), ("buttonText", buttonText as Any), ("sponsorInfo", sponsorInfo as Any), ("additionalInfo", additionalInfo as Any)])
    }
    }
    
        public static func parse_sponsoredMessage(_ reader: BufferReader) -> SponsoredMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.ChatInvite?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatInvite
            } }
            var _5: String?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            var _8: Api.SponsoredWebPage?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.SponsoredWebPage
            } }
            var _9: Api.BotApp?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.BotApp
            } }
            var _10: String?
            _10 = parseString(reader)
            var _11: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _12: String?
            if Int(_1!) & Int(1 << 11) != 0 {_12 = parseString(reader) }
            var _13: String?
            if Int(_1!) & Int(1 << 7) != 0 {_13 = parseString(reader) }
            var _14: String?
            if Int(_1!) & Int(1 << 8) != 0 {_14 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 3) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 9) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 1) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 11) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 7) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 8) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.SponsoredMessage.sponsoredMessage(flags: _1!, randomId: _2!, fromId: _3, chatInvite: _4, chatInviteHash: _5, channelPost: _6, startParam: _7, webpage: _8, app: _9, message: _10!, entities: _11, buttonText: _12, sponsorInfo: _13, additionalInfo: _14)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum SponsoredWebPage: TypeConstructorDescription {
        case sponsoredWebPage(flags: Int32, url: String, siteName: String, photo: Api.Photo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredWebPage(let flags, let url, let siteName, let photo):
                    if boxed {
                        buffer.appendInt32(1035529315)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(siteName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sponsoredWebPage(let flags, let url, let siteName, let photo):
                return ("sponsoredWebPage", [("flags", flags as Any), ("url", url as Any), ("siteName", siteName as Any), ("photo", photo as Any)])
    }
    }
    
        public static func parse_sponsoredWebPage(_ reader: BufferReader) -> SponsoredWebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.SponsoredWebPage.sponsoredWebPage(flags: _1!, url: _2!, siteName: _3!, photo: _4)
            }
            else {
                return nil
            }
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
        case storyItem(flags: Int32, id: Int32, date: Int32, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?)
        case storyItemDeleted(id: Int32)
        case storyItemSkipped(flags: Int32, id: Int32, date: Int32, expireDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyItem(let flags, let id, let date, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                    if boxed {
                        buffer.appendInt32(-1352440415)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
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
                case .storyItem(let flags, let id, let date, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                return ("storyItem", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("fwdFrom", fwdFrom as Any), ("expireDate", expireDate as Any), ("caption", caption as Any), ("entities", entities as Any), ("media", media as Any), ("mediaAreas", mediaAreas as Any), ("privacy", privacy as Any), ("views", views as Any), ("sentReaction", sentReaction as Any)])
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
            var _4: Api.StoryFwdHeader?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StoryFwdHeader
            } }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _8: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _9: [Api.MediaArea]?
            if Int(_1!) & Int(1 << 14) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MediaArea.self)
            } }
            var _10: [Api.PrivacyRule]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            } }
            var _11: Api.StoryViews?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StoryViews
            } }
            var _12: Api.Reaction?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.Reaction
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 17) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 14) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 15) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.StoryItem.storyItem(flags: _1!, id: _2!, date: _3!, fwdFrom: _4, expireDate: _5!, caption: _6, entities: _7, media: _8!, mediaAreas: _9, privacy: _10, views: _11, sentReaction: _12)
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
public extension Api {
    indirect enum StoryReaction: TypeConstructorDescription {
        case storyReaction(peerId: Api.Peer, date: Int32, reaction: Api.Reaction)
        case storyReactionPublicForward(message: Api.Message)
        case storyReactionPublicRepost(peerId: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyReaction(let peerId, let date, let reaction):
                    if boxed {
                        buffer.appendInt32(1620104917)
                    }
                    peerId.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    break
                case .storyReactionPublicForward(let message):
                    if boxed {
                        buffer.appendInt32(-1146411453)
                    }
                    message.serialize(buffer, true)
                    break
                case .storyReactionPublicRepost(let peerId, let story):
                    if boxed {
                        buffer.appendInt32(-808644845)
                    }
                    peerId.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyReaction(let peerId, let date, let reaction):
                return ("storyReaction", [("peerId", peerId as Any), ("date", date as Any), ("reaction", reaction as Any)])
                case .storyReactionPublicForward(let message):
                return ("storyReactionPublicForward", [("message", message as Any)])
                case .storyReactionPublicRepost(let peerId, let story):
                return ("storyReactionPublicRepost", [("peerId", peerId as Any), ("story", story as Any)])
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
                return Api.StoryReaction.storyReaction(peerId: _1!, date: _2!, reaction: _3!)
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
                return Api.StoryReaction.storyReactionPublicForward(message: _1!)
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
                return Api.StoryReaction.storyReactionPublicRepost(peerId: _1!, story: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum StoryView: TypeConstructorDescription {
        case storyView(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?)
        case storyViewPublicForward(flags: Int32, message: Api.Message)
        case storyViewPublicRepost(flags: Int32, peerId: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyView(let flags, let userId, let date, let reaction):
                    if boxed {
                        buffer.appendInt32(-1329730875)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {reaction!.serialize(buffer, true)}
                    break
                case .storyViewPublicForward(let flags, let message):
                    if boxed {
                        buffer.appendInt32(-1870436597)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    break
                case .storyViewPublicRepost(let flags, let peerId, let story):
                    if boxed {
                        buffer.appendInt32(-1116418231)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peerId.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyView(let flags, let userId, let date, let reaction):
                return ("storyView", [("flags", flags as Any), ("userId", userId as Any), ("date", date as Any), ("reaction", reaction as Any)])
                case .storyViewPublicForward(let flags, let message):
                return ("storyViewPublicForward", [("flags", flags as Any), ("message", message as Any)])
                case .storyViewPublicRepost(let flags, let peerId, let story):
                return ("storyViewPublicRepost", [("flags", flags as Any), ("peerId", peerId as Any), ("story", story as Any)])
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
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Reaction
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryView.storyView(flags: _1!, userId: _2!, date: _3!, reaction: _4)
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
                return Api.StoryView.storyViewPublicForward(flags: _1!, message: _2!)
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
                return Api.StoryView.storyViewPublicRepost(flags: _1!, peerId: _2!, story: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
