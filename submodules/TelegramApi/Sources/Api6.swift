public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription {
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                return ("inputAppEvent", [("time", String(describing: time)), ("type", String(describing: type)), ("peer", String(describing: peer)), ("data", String(describing: data))])
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
    enum InputBotInlineMessage: TypeConstructorDescription {
        case inputBotInlineMessageGame(flags: Int32, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaGeo(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?)
        case inputBotInlineMessageMediaVenue(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
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
                return ("inputBotInlineMessageGame", [("flags", String(describing: flags)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageMediaAuto", [("flags", String(describing: flags)), ("message", String(describing: message)), ("entities", String(describing: entities)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("inputBotInlineMessageMediaContact", [("flags", String(describing: flags)), ("phoneNumber", String(describing: phoneNumber)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("vcard", String(describing: vcard)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageMediaGeo(let flags, let geoPoint, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                return ("inputBotInlineMessageMediaGeo", [("flags", String(describing: flags)), ("geoPoint", String(describing: geoPoint)), ("heading", String(describing: heading)), ("period", String(describing: period)), ("proximityNotificationRadius", String(describing: proximityNotificationRadius)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageMediaInvoice(let flags, let title, let description, let photo, let invoice, let payload, let provider, let providerData, let replyMarkup):
                return ("inputBotInlineMessageMediaInvoice", [("flags", String(describing: flags)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("invoice", String(describing: invoice)), ("payload", String(describing: payload)), ("provider", String(describing: provider)), ("providerData", String(describing: providerData)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageMediaVenue(let flags, let geoPoint, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("inputBotInlineMessageMediaVenue", [("flags", String(describing: flags)), ("geoPoint", String(describing: geoPoint)), ("title", String(describing: title)), ("address", String(describing: address)), ("provider", String(describing: provider)), ("venueId", String(describing: venueId)), ("venueType", String(describing: venueType)), ("replyMarkup", String(describing: replyMarkup))])
                case .inputBotInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("inputBotInlineMessageText", [("flags", String(describing: flags)), ("message", String(describing: message)), ("entities", String(describing: entities)), ("replyMarkup", String(describing: replyMarkup))])
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
                return ("inputBotInlineMessageID", [("dcId", String(describing: dcId)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
                case .inputBotInlineMessageID64(let dcId, let ownerId, let id, let accessHash):
                return ("inputBotInlineMessageID64", [("dcId", String(describing: dcId)), ("ownerId", String(describing: ownerId)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash))])
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
                return ("inputBotInlineResult", [("flags", String(describing: flags)), ("id", String(describing: id)), ("type", String(describing: type)), ("title", String(describing: title)), ("description", String(describing: description)), ("url", String(describing: url)), ("thumb", String(describing: thumb)), ("content", String(describing: content)), ("sendMessage", String(describing: sendMessage))])
                case .inputBotInlineResultDocument(let flags, let id, let type, let title, let description, let document, let sendMessage):
                return ("inputBotInlineResultDocument", [("flags", String(describing: flags)), ("id", String(describing: id)), ("type", String(describing: type)), ("title", String(describing: title)), ("description", String(describing: description)), ("document", String(describing: document)), ("sendMessage", String(describing: sendMessage))])
                case .inputBotInlineResultGame(let id, let shortName, let sendMessage):
                return ("inputBotInlineResultGame", [("id", String(describing: id)), ("shortName", String(describing: shortName)), ("sendMessage", String(describing: sendMessage))])
                case .inputBotInlineResultPhoto(let id, let type, let photo, let sendMessage):
                return ("inputBotInlineResultPhoto", [("id", String(describing: id)), ("type", String(describing: type)), ("photo", String(describing: photo)), ("sendMessage", String(describing: sendMessage))])
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
    enum InputChannel: TypeConstructorDescription {
        case inputChannel(channelId: Int64, accessHash: Int64)
        case inputChannelEmpty
        case inputChannelFromMessage(peer: Api.InputPeer, msgId: Int32, channelId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChannel(let channelId, let accessHash):
                    if boxed {
                        buffer.appendInt32(-212145112)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    break
                case .inputChannelEmpty:
                    if boxed {
                        buffer.appendInt32(-292807034)
                    }
                    
                    break
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                    if boxed {
                        buffer.appendInt32(1536380829)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChannel(let channelId, let accessHash):
                return ("inputChannel", [("channelId", String(describing: channelId)), ("accessHash", String(describing: accessHash))])
                case .inputChannelEmpty:
                return ("inputChannelEmpty", [])
                case .inputChannelFromMessage(let peer, let msgId, let channelId):
                return ("inputChannelFromMessage", [("peer", String(describing: peer)), ("msgId", String(describing: msgId)), ("channelId", String(describing: channelId))])
    }
    }
    
        public static func parse_inputChannel(_ reader: BufferReader) -> InputChannel? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputChannel.inputChannel(channelId: _1!, accessHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputChannelEmpty(_ reader: BufferReader) -> InputChannel? {
            return Api.InputChannel.inputChannelEmpty
        }
        public static func parse_inputChannelFromMessage(_ reader: BufferReader) -> InputChannel? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputChannel.inputChannelFromMessage(peer: _1!, msgId: _2!, channelId: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription {
        case inputChatPhoto(id: Api.InputPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputChatPhoto(let id):
                    if boxed {
                        buffer.appendInt32(-1991004873)
                    }
                    id.serialize(buffer, true)
                    break
                case .inputChatPhotoEmpty:
                    if boxed {
                        buffer.appendInt32(480546647)
                    }
                    
                    break
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs):
                    if boxed {
                        buffer.appendInt32(-968723890)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {file!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {video!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputChatPhoto(let id):
                return ("inputChatPhoto", [("id", String(describing: id))])
                case .inputChatPhotoEmpty:
                return ("inputChatPhotoEmpty", [])
                case .inputChatUploadedPhoto(let flags, let file, let video, let videoStartTs):
                return ("inputChatUploadedPhoto", [("flags", String(describing: flags)), ("file", String(describing: file)), ("video", String(describing: video)), ("videoStartTs", String(describing: videoStartTs))])
    }
    }
    
        public static func parse_inputChatPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Api.InputPhoto?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPhoto
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputChatPhoto.inputChatPhoto(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputChatPhotoEmpty(_ reader: BufferReader) -> InputChatPhoto? {
            return Api.InputChatPhoto.inputChatPhotoEmpty
        }
        public static func parse_inputChatUploadedPhoto(_ reader: BufferReader) -> InputChatPhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputFile?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _3: Api.InputFile?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.InputFile
            } }
            var _4: Double?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readDouble() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputChatPhoto.inputChatUploadedPhoto(flags: _1!, file: _2, video: _3, videoStartTs: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription {
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(srpId: Int64, A: Buffer, M1: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputCheckPasswordEmpty:
                    if boxed {
                        buffer.appendInt32(-1736378792)
                    }
                    
                    break
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                    if boxed {
                        buffer.appendInt32(-763367294)
                    }
                    serializeInt64(srpId, buffer: buffer, boxed: false)
                    serializeBytes(A, buffer: buffer, boxed: false)
                    serializeBytes(M1, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputCheckPasswordEmpty:
                return ("inputCheckPasswordEmpty", [])
                case .inputCheckPasswordSRP(let srpId, let A, let M1):
                return ("inputCheckPasswordSRP", [("srpId", String(describing: srpId)), ("A", String(describing: A)), ("M1", String(describing: M1))])
    }
    }
    
        public static func parse_inputCheckPasswordEmpty(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            return Api.InputCheckPasswordSRP.inputCheckPasswordEmpty
        }
        public static func parse_inputCheckPasswordSRP(_ reader: BufferReader) -> InputCheckPasswordSRP? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputCheckPasswordSRP.inputCheckPasswordSRP(srpId: _1!, A: _2!, M1: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription {
        case inputClientProxy(address: String, port: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputClientProxy(let address, let port):
                    if boxed {
                        buffer.appendInt32(1968737087)
                    }
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeInt32(port, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputClientProxy(let address, let port):
                return ("inputClientProxy", [("address", String(describing: address)), ("port", String(describing: port))])
    }
    }
    
        public static func parse_inputClientProxy(_ reader: BufferReader) -> InputClientProxy? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InputClientProxy.inputClientProxy(address: _1!, port: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription {
        case inputPhoneContact(clientId: Int64, phone: String, firstName: String, lastName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                    if boxed {
                        buffer.appendInt32(-208488460)
                    }
                    serializeInt64(clientId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputPhoneContact(let clientId, let phone, let firstName, let lastName):
                return ("inputPhoneContact", [("clientId", String(describing: clientId)), ("phone", String(describing: phone)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName))])
    }
    }
    
        public static func parse_inputPhoneContact(_ reader: BufferReader) -> InputContact? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InputContact.inputPhoneContact(clientId: _1!, phone: _2!, firstName: _3!, lastName: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputDialogPeer: TypeConstructorDescription {
        case inputDialogPeer(peer: Api.InputPeer)
        case inputDialogPeerFolder(folderId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDialogPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-55902537)
                    }
                    peer.serialize(buffer, true)
                    break
                case .inputDialogPeerFolder(let folderId):
                    if boxed {
                        buffer.appendInt32(1684014375)
                    }
                    serializeInt32(folderId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDialogPeer(let peer):
                return ("inputDialogPeer", [("peer", String(describing: peer))])
                case .inputDialogPeerFolder(let folderId):
                return ("inputDialogPeerFolder", [("folderId", String(describing: folderId))])
    }
    }
    
        public static func parse_inputDialogPeer(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDialogPeerFolder(_ reader: BufferReader) -> InputDialogPeer? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InputDialogPeer.inputDialogPeerFolder(folderId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription {
        case inputDocument(id: Int64, accessHash: Int64, fileReference: Buffer)
        case inputDocumentEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputDocument(let id, let accessHash, let fileReference):
                    if boxed {
                        buffer.appendInt32(448771445)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeBytes(fileReference, buffer: buffer, boxed: false)
                    break
                case .inputDocumentEmpty:
                    if boxed {
                        buffer.appendInt32(1928391342)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputDocument(let id, let accessHash, let fileReference):
                return ("inputDocument", [("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("fileReference", String(describing: fileReference))])
                case .inputDocumentEmpty:
                return ("inputDocumentEmpty", [])
    }
    }
    
        public static func parse_inputDocument(_ reader: BufferReader) -> InputDocument? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InputDocument.inputDocument(id: _1!, accessHash: _2!, fileReference: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputDocumentEmpty(_ reader: BufferReader) -> InputDocument? {
            return Api.InputDocument.inputDocumentEmpty
        }
    
    }
}
