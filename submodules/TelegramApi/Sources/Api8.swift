public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        case groupCallParticipantVideoSourceGroup(semantics: String, sources: [Int32])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                    if boxed {
                        buffer.appendInt32(-592373577)
                    }
                    serializeString(semantics, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sources.count))
                    for item in sources {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallParticipantVideoSourceGroup(let semantics, let sources):
                return ("groupCallParticipantVideoSourceGroup", [("semantics", semantics as Any), ("sources", sources as Any)])
    }
    }
    
        public static func parse_groupCallParticipantVideoSourceGroup(_ reader: BufferReader) -> GroupCallParticipantVideoSourceGroup? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.GroupCallParticipantVideoSourceGroup.groupCallParticipantVideoSourceGroup(semantics: _1!, sources: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        case groupCallStreamChannel(channel: Int32, scale: Int32, lastTimestampMs: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                    if boxed {
                        buffer.appendInt32(-2132064081)
                    }
                    serializeInt32(channel, buffer: buffer, boxed: false)
                    serializeInt32(scale, buffer: buffer, boxed: false)
                    serializeInt64(lastTimestampMs, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannel(let channel, let scale, let lastTimestampMs):
                return ("groupCallStreamChannel", [("channel", channel as Any), ("scale", scale as Any), ("lastTimestampMs", lastTimestampMs as Any)])
    }
    }
    
        public static func parse_groupCallStreamChannel(_ reader: BufferReader) -> GroupCallStreamChannel? {
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
                return Api.GroupCallStreamChannel.groupCallStreamChannel(channel: _1!, scale: _2!, lastTimestampMs: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        case highScore(pos: Int32, userId: Int64, score: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .highScore(let pos, let userId, let score):
                    if boxed {
                        buffer.appendInt32(1940093419)
                    }
                    serializeInt32(pos, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .highScore(let pos, let userId, let score):
                return ("highScore", [("pos", pos as Any), ("userId", userId as Any), ("score", score as Any)])
    }
    }
    
        public static func parse_highScore(_ reader: BufferReader) -> HighScore? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.HighScore.highScore(pos: _1!, userId: _2!, score: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        case importedContact(userId: Int64, clientId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .importedContact(let userId, let clientId):
                    if boxed {
                        buffer.appendInt32(-1052885936)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .importedContact(let userId, let clientId):
                return ("importedContact", [("userId", userId as Any), ("clientId", clientId as Any)])
    }
    }
    
        public static func parse_importedContact(_ reader: BufferReader) -> ImportedContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ImportedContact.importedContact(userId: _1!, clientId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
        case inlineBotSwitchPM(text: String, startParam: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                    if boxed {
                        buffer.appendInt32(1008755359)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(startParam, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineBotSwitchPM(let text, let startParam):
                return ("inlineBotSwitchPM", [("text", text as Any), ("startParam", startParam as Any)])
    }
    }
    
        public static func parse_inlineBotSwitchPM(_ reader: BufferReader) -> InlineBotSwitchPM? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotSwitchPM.inlineBotSwitchPM(text: _1!, startParam: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription {
        case inlineBotWebView(text: String, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineBotWebView(let text, let url):
                    if boxed {
                        buffer.appendInt32(-1250781739)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineBotWebView(let text, let url):
                return ("inlineBotWebView", [("text", text as Any), ("url", url as Any)])
    }
    }
    
        public static func parse_inlineBotWebView(_ reader: BufferReader) -> InlineBotWebView? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineBotWebView.inlineBotWebView(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription {
        case inlineQueryPeerTypeBotPM
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inlineQueryPeerTypeBotPM:
                    if boxed {
                        buffer.appendInt32(238759180)
                    }
                    
                    break
                case .inlineQueryPeerTypeBroadcast:
                    if boxed {
                        buffer.appendInt32(1664413338)
                    }
                    
                    break
                case .inlineQueryPeerTypeChat:
                    if boxed {
                        buffer.appendInt32(-681130742)
                    }
                    
                    break
                case .inlineQueryPeerTypeMegagroup:
                    if boxed {
                        buffer.appendInt32(1589952067)
                    }
                    
                    break
                case .inlineQueryPeerTypePM:
                    if boxed {
                        buffer.appendInt32(-2093215828)
                    }
                    
                    break
                case .inlineQueryPeerTypeSameBotPM:
                    if boxed {
                        buffer.appendInt32(813821341)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inlineQueryPeerTypeBotPM:
                return ("inlineQueryPeerTypeBotPM", [])
                case .inlineQueryPeerTypeBroadcast:
                return ("inlineQueryPeerTypeBroadcast", [])
                case .inlineQueryPeerTypeChat:
                return ("inlineQueryPeerTypeChat", [])
                case .inlineQueryPeerTypeMegagroup:
                return ("inlineQueryPeerTypeMegagroup", [])
                case .inlineQueryPeerTypePM:
                return ("inlineQueryPeerTypePM", [])
                case .inlineQueryPeerTypeSameBotPM:
                return ("inlineQueryPeerTypeSameBotPM", [])
    }
    }
    
        public static func parse_inlineQueryPeerTypeBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBotPM
        }
        public static func parse_inlineQueryPeerTypeBroadcast(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeBroadcast
        }
        public static func parse_inlineQueryPeerTypeChat(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeChat
        }
        public static func parse_inlineQueryPeerTypeMegagroup(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeMegagroup
        }
        public static func parse_inlineQueryPeerTypePM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypePM
        }
        public static func parse_inlineQueryPeerTypeSameBotPM(_ reader: BufferReader) -> InlineQueryPeerType? {
            return Api.InlineQueryPeerType.inlineQueryPeerTypeSameBotPM
        }
    
    }
}
public extension Api {
    enum InputAppEvent: TypeConstructorDescription {
        case inputAppEvent(time: Double, type: String, peer: Int64, data: Api.JSONValue)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputAppEvent(let time, let type, let peer, let data):
                    if boxed {
                        buffer.appendInt32(488313413)
                    }
                    serializeDouble(time, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt64(peer, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputAppEvent(let time, let type, let peer, let data):
                return ("inputAppEvent", [("time", time as Any), ("type", type as Any), ("peer", peer as Any), ("data", data as Any)])
    }
    }
    
        public static func parse_inputAppEvent(_ reader: BufferReader) -> InputAppEvent? {
            var _1: Double?
            _1 = reader.readDouble()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.JSONValue?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.JSONValue
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputAppEvent.inputAppEvent(time: _1!, type: _2!, peer: _3!, data: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum InputBotApp: TypeConstructorDescription {
        case inputBotAppID(id: Int64, accessHash: Int64)
        case inputBotAppShortName(botId: Api.InputUser, shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotAppID(let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1457472134)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputBotAppShortName(let botId, let shortName):
                    if boxed {
                        buffer.appendInt32(-1869872121)
                    }
                    botId.serialize(buffer, true)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotAppID(let id, let accessHash):
                return ("inputBotAppID", [("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputBotAppShortName(let botId, let shortName):
                return ("inputBotAppShortName", [("botId", botId as Any), ("shortName", shortName as Any)])
    }
    }
    
        public static func parse_inputBotAppID(_ reader: BufferReader) -> InputBotApp? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppID(id: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotAppShortName(_ reader: BufferReader) -> InputBotApp? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputBotApp.inputBotAppShortName(botId: _1!, shortName: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBotInlineMessage: TypeConstructorDescription {
        case inputBotInlineMessageGame(flags: Int32, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaGeo(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaVenue(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaWebPage(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineMessageGame(let flags, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1262639204)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(864077702)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1494368259)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1768777083)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(heading!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(proximityNotificationRadius!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-672693723)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    providerData.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1098628881)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geoPoint.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageMediaWebPage(let flags, let message, let entities, let url, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1109605104)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1036876423)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineMessageGame(let flags, let replyMarkup):
                return ("inputBotInlineMessageGame", [("flags", flags as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageMediaAuto", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("inputBotInlineMessageMediaContact", [("flags", flags as Any), ("phoneNumber", phoneNumber as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("vcard", vcard as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                return ("inputBotInlineMessageMediaGeo", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("heading", heading as Any), ("period", period as Any), ("proximityNotificationRadius", proximityNotificationRadius as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let replyMarkup):
                return ("inputBotInlineMessageMediaInvoice", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("payload", payload as Any), ("provider", provider as Any), ("providerData", providerData as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("inputBotInlineMessageMediaVenue", [("flags", flags as Any), ("geoPoint", geoPoint as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageMediaWebPage(let flags, let message, let entities, let url, let replyMarkup):
                return ("inputBotInlineMessageMediaWebPage", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("url", url as Any), ("replyMarkup", replyMarkup as Any)])
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageText", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
    }
    }
    
        public static func parse_inputBotInlineMessageGame(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.InputBotInlineMessage.inputBotInlineMessageGame(flags: _1!, replyMarkup: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaAuto(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaContact(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaGeo(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = reader.readInt32() }
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaGeo(flags: _1!, geoPoint: _2!, heading: _3, period: _4, proximityNotificationRadius: _5, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaInvoice(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _5: Api.Invoice?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _6: Buffer?
            _6 = parseBytes(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.DataJSON?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _9: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, invoice: _5!, payload: _6!, provider: _7!, providerData: _8!, replyMarkup: _9)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaVenue(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            _7 = parseString(reader)
            var _8: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaVenue(flags: _1!, geoPoint: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageMediaWebPage(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.InputBotInlineMessage.inputBotInlineMessageMediaWebPage(flags: _1!, message: _2!, entities: _3, url: _4!, replyMarkup: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageText(_ reader: BufferReader) -> InputBotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessage.inputBotInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBotInlineMessageID: TypeConstructorDescription {
        case inputBotInlineMessageID(dcId: Int32, id: Int64, accessHash: Int64)
        case inputBotInlineMessageID64(dcId: Int32, ownerId: Int64, id: Int32, accessHash: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineMessageID(let dcId, let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1995686519)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputBotInlineMessageID64(let dcId, let ownerId, let id, let accessHash):
                    if boxed {
                        buffer.appendInt32(-1227287081)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeInt64(ownerId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineMessageID(let dcId, let id, let accessHash):
                return ("inputBotInlineMessageID", [("dcId", dcId as Any), ("id", id as Any), ("accessHash", accessHash as Any)])
                case .inputBotInlineMessageID64(let dcId, let ownerId, let id, let accessHash):
                return ("inputBotInlineMessageID64", [("dcId", dcId as Any), ("ownerId", ownerId as Any), ("id", id as Any), ("accessHash", accessHash as Any)])
    }
    }
    
        public static func parse_inputBotInlineMessageID(_ reader: BufferReader) -> InputBotInlineMessageID? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineMessageID.inputBotInlineMessageID(dcId: _1!, id: _2!, accessHash: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineMessageID64(_ reader: BufferReader) -> InputBotInlineMessageID? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineMessageID.inputBotInlineMessageID64(dcId: _1!, ownerId: _2!, id: _3!, accessHash: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBotInlineResult: TypeConstructorDescription {
        case inputBotInlineResult(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.InputWebDocument?, content: Api.InputWebDocument?, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResultDocument(flags: Int32, id: String, type: String, title: String?, description: String?, document: Api.InputDocument, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResultGame(id: String, shortName: String, sendMessage: Api.InputBotInlineMessage)
        case inputBotInlineResultPhoto(id: String, type: String, photo: Api.InputPhoto, sendMessage: Api.InputBotInlineMessage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBotInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-2000710887)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {thumb!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {content!.serialize(buffer, true)}
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResultDocument(let flags, let id, let type, let title, let description, let document, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-459324)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    document.serialize(buffer, true)
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResultGame(let id, let shortName, let sendMessage):
                    if boxed {
                        buffer.appendInt32(1336154098)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(shortName, buffer: buffer, boxed: false)
                    sendMessage.serialize(buffer, true)
                    break
                case .inputBotInlineResultPhoto(let id, let type, let photo, let sendMessage):
                    if boxed {
                        buffer.appendInt32(-1462213465)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    sendMessage.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBotInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                return ("inputBotInlineResult", [("flags", flags as Any), ("id", id as Any), ("type", type as Any), ("title", title as Any), ("description", description as Any), ("url", url as Any), ("thumb", thumb as Any), ("content", content as Any), ("sendMessage", sendMessage as Any)])
                case .inputBotInlineResultDocument(let flags, let id, let type, let title, let description, let document, let sendMessage):
                return ("inputBotInlineResultDocument", [("flags", flags as Any), ("id", id as Any), ("type", type as Any), ("title", title as Any), ("description", description as Any), ("document", document as Any), ("sendMessage", sendMessage as Any)])
                case .inputBotInlineResultGame(let id, let shortName, let sendMessage):
                return ("inputBotInlineResultGame", [("id", id as Any), ("shortName", shortName as Any), ("sendMessage", sendMessage as Any)])
                case .inputBotInlineResultPhoto(let id, let type, let photo, let sendMessage):
                return ("inputBotInlineResultPhoto", [("id", id as Any), ("type", type as Any), ("photo", photo as Any), ("sendMessage", sendMessage as Any)])
    }
    }
    
        public static func parse_inputBotInlineResult(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _8: Api.InputWebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.InputWebDocument
            } }
            var _9: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 5) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.InputBotInlineResult.inputBotInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultDocument(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: Api.InputDocument?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputDocument
            }
            var _7: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.InputBotInlineResult.inputBotInlineResultDocument(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, document: _6!, sendMessage: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultGame(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBotInlineResult.inputBotInlineResultGame(id: _1!, shortName: _2!, sendMessage: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputBotInlineResultPhoto(_ reader: BufferReader) -> InputBotInlineResult? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            var _4: Api.InputBotInlineMessage?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBotInlineResult.inputBotInlineResultPhoto(id: _1!, type: _2!, photo: _3!, sendMessage: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBusinessAwayMessage: TypeConstructorDescription {
        case inputBusinessAwayMessage(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.InputBusinessRecipients)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessAwayMessage(let flags, let shortcutId, let schedule, let recipients):
                    if boxed {
                        buffer.appendInt32(-2094959136)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    schedule.serialize(buffer, true)
                    recipients.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessAwayMessage(let flags, let shortcutId, let schedule, let recipients):
                return ("inputBusinessAwayMessage", [("flags", flags as Any), ("shortcutId", shortcutId as Any), ("schedule", schedule as Any), ("recipients", recipients as Any)])
    }
    }
    
        public static func parse_inputBusinessAwayMessage(_ reader: BufferReader) -> InputBusinessAwayMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.BusinessAwayMessageSchedule?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.BusinessAwayMessageSchedule
            }
            var _4: Api.InputBusinessRecipients?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBusinessRecipients
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBusinessAwayMessage.inputBusinessAwayMessage(flags: _1!, shortcutId: _2!, schedule: _3!, recipients: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription {
        case inputBusinessBotRecipients(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessBotRecipients(let flags, let users, let excludeUsers):
                    if boxed {
                        buffer.appendInt32(-991587810)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users!.count))
                    for item in users! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(excludeUsers!.count))
                    for item in excludeUsers! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessBotRecipients(let flags, let users, let excludeUsers):
                return ("inputBusinessBotRecipients", [("flags", flags as Any), ("users", users as Any), ("excludeUsers", excludeUsers as Any)])
    }
    }
    
        public static func parse_inputBusinessBotRecipients(_ reader: BufferReader) -> InputBusinessBotRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.InputUser]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            } }
            var _3: [Api.InputUser]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InputUser.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputBusinessBotRecipients.inputBusinessBotRecipients(flags: _1!, users: _2, excludeUsers: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputBusinessChatLink: TypeConstructorDescription {
        case inputBusinessChatLink(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputBusinessChatLink(let flags, let message, let entities, let title):
                    if boxed {
                        buffer.appendInt32(292003751)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputBusinessChatLink(let flags, let message, let entities, let title):
                return ("inputBusinessChatLink", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("title", title as Any)])
    }
    }
    
        public static func parse_inputBusinessChatLink(_ reader: BufferReader) -> InputBusinessChatLink? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputBusinessChatLink.inputBusinessChatLink(flags: _1!, message: _2!, entities: _3, title: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
