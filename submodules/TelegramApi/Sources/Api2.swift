public extension Api {
    enum BotInfo: TypeConstructorDescription {
        case botInfo(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInfo(let flags, let userId, let description, let descriptionPhoto, let descriptionDocument, let commands, let menuButton):
                    if boxed {
                        buffer.appendInt32(-1892676777)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(userId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {descriptionPhoto!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {descriptionDocument!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(commands!.count))
                    for item in commands! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 3) != 0 {menuButton!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInfo(let flags, let userId, let description, let descriptionPhoto, let descriptionDocument, let commands, let menuButton):
                return ("botInfo", [("flags", flags as Any), ("userId", userId as Any), ("description", description as Any), ("descriptionPhoto", descriptionPhoto as Any), ("descriptionDocument", descriptionDocument as Any), ("commands", commands as Any), ("menuButton", menuButton as Any)])
    }
    }
    
        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _6: [Api.BotCommand]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
            } }
            var _7: Api.BotMenuButton?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.BotMenuButton
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.BotInfo.botInfo(flags: _1!, userId: _2, description: _3, descriptionPhoto: _4, descriptionDocument: _5, commands: _6, menuButton: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BotInlineMessage: TypeConstructorDescription {
        case botInlineMessageMediaAuto(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaContact(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaGeo(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaInvoice(flags: Int32, title: String, description: String, photo: Api.WebDocument?, currency: String, totalAmount: Int64, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageMediaVenue(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?)
        case botInlineMessageText(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(1984755728)
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
                case .botInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(416402882)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    serializeString(vcard, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaGeo(let flags, let geo, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(85477117)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(heading!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(period!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(proximityNotificationRadius!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaInvoice(let flags, let title, let description, let photo, let currency, let totalAmount, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(894081801)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageMediaVenue(let flags, let geo, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1970903652)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    geo.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {replyMarkup!.serialize(buffer, true)}
                    break
                case .botInlineMessageText(let flags, let message, let entities, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-1937807902)
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
                case .botInlineMessageMediaAuto(let flags, let message, let entities, let replyMarkup):
                return ("botInlineMessageMediaAuto", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
                case .botInlineMessageMediaContact(let flags, let phoneNumber, let firstName, let lastName, let vcard, let replyMarkup):
                return ("botInlineMessageMediaContact", [("flags", flags as Any), ("phoneNumber", phoneNumber as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("vcard", vcard as Any), ("replyMarkup", replyMarkup as Any)])
                case .botInlineMessageMediaGeo(let flags, let geo, let heading, let period, let proximityNotificationRadius, let replyMarkup):
                return ("botInlineMessageMediaGeo", [("flags", flags as Any), ("geo", geo as Any), ("heading", heading as Any), ("period", period as Any), ("proximityNotificationRadius", proximityNotificationRadius as Any), ("replyMarkup", replyMarkup as Any)])
                case .botInlineMessageMediaInvoice(let flags, let title, let description, let photo, let currency, let totalAmount, let replyMarkup):
                return ("botInlineMessageMediaInvoice", [("flags", flags as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("replyMarkup", replyMarkup as Any)])
                case .botInlineMessageMediaVenue(let flags, let geo, let title, let address, let provider, let venueId, let venueType, let replyMarkup):
                return ("botInlineMessageMediaVenue", [("flags", flags as Any), ("geo", geo as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any), ("replyMarkup", replyMarkup as Any)])
                case .botInlineMessageText(let flags, let message, let entities, let replyMarkup):
                return ("botInlineMessageText", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("replyMarkup", replyMarkup as Any)])
    }
    }
    
        public static func parse_botInlineMessageMediaAuto(_ reader: BufferReader) -> BotInlineMessage? {
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
                return Api.BotInlineMessage.botInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaContact(_ reader: BufferReader) -> BotInlineMessage? {
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
                return Api.BotInlineMessage.botInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaGeo(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
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
                return Api.BotInlineMessage.botInlineMessageMediaGeo(flags: _1!, geo: _2!, heading: _3, period: _4, proximityNotificationRadius: _5, replyMarkup: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaInvoice(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.WebDocument?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.BotInlineMessage.botInlineMessageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, currency: _5!, totalAmount: _6!, replyMarkup: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageMediaVenue(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
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
                return Api.BotInlineMessage.botInlineMessageMediaVenue(flags: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineMessageText(_ reader: BufferReader) -> BotInlineMessage? {
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
                return Api.BotInlineMessage.botInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BotInlineResult: TypeConstructorDescription {
        case botInlineMediaResult(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage)
        case botInlineResult(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInlineMediaResult(let flags, let id, let type, let photo, let document, let title, let description, let sendMessage):
                    if boxed {
                        buffer.appendInt32(400266251)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    sendMessage.serialize(buffer, true)
                    break
                case .botInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                    if boxed {
                        buffer.appendInt32(295067450)
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInlineMediaResult(let flags, let id, let type, let photo, let document, let title, let description, let sendMessage):
                return ("botInlineMediaResult", [("flags", flags as Any), ("id", id as Any), ("type", type as Any), ("photo", photo as Any), ("document", document as Any), ("title", title as Any), ("description", description as Any), ("sendMessage", sendMessage as Any)])
                case .botInlineResult(let flags, let id, let type, let title, let description, let url, let thumb, let content, let sendMessage):
                return ("botInlineResult", [("flags", flags as Any), ("id", id as Any), ("type", type as Any), ("title", title as Any), ("description", description as Any), ("url", url as Any), ("thumb", thumb as Any), ("content", content as Any), ("sendMessage", sendMessage as Any)])
    }
    }
    
        public static func parse_botInlineMediaResult(_ reader: BufferReader) -> BotInlineResult? {
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
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: Api.BotInlineMessage?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.BotInlineMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.BotInlineResult.botInlineMediaResult(flags: _1!, id: _2!, type: _3!, photo: _4, document: _5, title: _6, description: _7, sendMessage: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_botInlineResult(_ reader: BufferReader) -> BotInlineResult? {
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
            var _7: Api.WebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _9: Api.BotInlineMessage?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.BotInlineMessage
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
                return Api.BotInlineResult.botInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BotMenuButton: TypeConstructorDescription {
        case botMenuButton(text: String, url: String)
        case botMenuButtonCommands
        case botMenuButtonDefault
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botMenuButton(let text, let url):
                    if boxed {
                        buffer.appendInt32(-944407322)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .botMenuButtonCommands:
                    if boxed {
                        buffer.appendInt32(1113113093)
                    }
                    
                    break
                case .botMenuButtonDefault:
                    if boxed {
                        buffer.appendInt32(1966318984)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botMenuButton(let text, let url):
                return ("botMenuButton", [("text", text as Any), ("url", url as Any)])
                case .botMenuButtonCommands:
                return ("botMenuButtonCommands", [])
                case .botMenuButtonDefault:
                return ("botMenuButtonDefault", [])
    }
    }
    
        public static func parse_botMenuButton(_ reader: BufferReader) -> BotMenuButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotMenuButton.botMenuButton(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_botMenuButtonCommands(_ reader: BufferReader) -> BotMenuButton? {
            return Api.BotMenuButton.botMenuButtonCommands
        }
        public static func parse_botMenuButtonDefault(_ reader: BufferReader) -> BotMenuButton? {
            return Api.BotMenuButton.botMenuButtonDefault
        }
    
    }
}
public extension Api {
    enum CdnConfig: TypeConstructorDescription {
        case cdnConfig(publicKeys: [Api.CdnPublicKey])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnConfig(let publicKeys):
                    if boxed {
                        buffer.appendInt32(1462101002)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(publicKeys.count))
                    for item in publicKeys {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnConfig(let publicKeys):
                return ("cdnConfig", [("publicKeys", publicKeys as Any)])
    }
    }
    
        public static func parse_cdnConfig(_ reader: BufferReader) -> CdnConfig? {
            var _1: [Api.CdnPublicKey]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.CdnPublicKey.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.CdnConfig.cdnConfig(publicKeys: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum CdnPublicKey: TypeConstructorDescription {
        case cdnPublicKey(dcId: Int32, publicKey: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .cdnPublicKey(let dcId, let publicKey):
                    if boxed {
                        buffer.appendInt32(-914167110)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeString(publicKey, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .cdnPublicKey(let dcId, let publicKey):
                return ("cdnPublicKey", [("dcId", dcId as Any), ("publicKey", publicKey as Any)])
    }
    }
    
        public static func parse_cdnPublicKey(_ reader: BufferReader) -> CdnPublicKey? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.CdnPublicKey.cdnPublicKey(dcId: _1!, publicKey: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum ChannelAdminLogEvent: TypeConstructorDescription {
        case channelAdminLogEvent(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                    if boxed {
                        buffer.appendInt32(531458253)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEvent(let id, let date, let userId, let action):
                return ("channelAdminLogEvent", [("id", id as Any), ("date", date as Any), ("userId", userId as Any), ("action", action as Any)])
    }
    }
    
        public static func parse_channelAdminLogEvent(_ reader: BufferReader) -> ChannelAdminLogEvent? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.ChannelAdminLogEventAction?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChannelAdminLogEventAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelAdminLogEvent.channelAdminLogEvent(id: _1!, date: _2!, userId: _3!, action: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum ChannelAdminLogEventAction: TypeConstructorDescription {
        case channelAdminLogEventActionChangeAbout(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeAvailableReactions(prevValue: Api.ChatReactions, newValue: Api.ChatReactions)
        case channelAdminLogEventActionChangeHistoryTTL(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionChangeLinkedChat(prevValue: Int64, newValue: Int64)
        case channelAdminLogEventActionChangeLocation(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation)
        case channelAdminLogEventActionChangePhoto(prevPhoto: Api.Photo, newPhoto: Api.Photo)
        case channelAdminLogEventActionChangeStickerSet(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet)
        case channelAdminLogEventActionChangeTitle(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsername(prevValue: String, newValue: String)
        case channelAdminLogEventActionChangeUsernames(prevValue: [String], newValue: [String])
        case channelAdminLogEventActionCreateTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDefaultBannedRights(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights)
        case channelAdminLogEventActionDeleteMessage(message: Api.Message)
        case channelAdminLogEventActionDeleteTopic(topic: Api.ForumTopic)
        case channelAdminLogEventActionDiscardGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionEditMessage(prevMessage: Api.Message, newMessage: Api.Message)
        case channelAdminLogEventActionEditTopic(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic)
        case channelAdminLogEventActionExportedInviteDelete(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteEdit(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite)
        case channelAdminLogEventActionExportedInviteRevoke(invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantInvite(participant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(flags: Int32, invite: Api.ExportedChatInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(invite: Api.ExportedChatInvite, approvedBy: Int64)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantToggleBan(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant)
        case channelAdminLogEventActionParticipantUnmute(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionParticipantVolume(participant: Api.GroupCallParticipant)
        case channelAdminLogEventActionPinTopic(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?)
        case channelAdminLogEventActionSendMessage(message: Api.Message)
        case channelAdminLogEventActionStartGroupCall(call: Api.InputGroupCall)
        case channelAdminLogEventActionStopPoll(message: Api.Message)
        case channelAdminLogEventActionToggleAntiSpam(newValue: Api.Bool)
        case channelAdminLogEventActionToggleForum(newValue: Api.Bool)
        case channelAdminLogEventActionToggleGroupCallSetting(joinMuted: Api.Bool)
        case channelAdminLogEventActionToggleInvites(newValue: Api.Bool)
        case channelAdminLogEventActionToggleNoForwards(newValue: Api.Bool)
        case channelAdminLogEventActionTogglePreHistoryHidden(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSignatures(newValue: Api.Bool)
        case channelAdminLogEventActionToggleSlowMode(prevValue: Int32, newValue: Int32)
        case channelAdminLogEventActionUpdatePinned(message: Api.Message)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1427671598)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeAvailableReactions(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-1102180616)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeHistoryTTL(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1855199800)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(84703944)
                    }
                    serializeInt64(prevValue, buffer: buffer, boxed: false)
                    serializeInt64(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(241923758)
                    }
                    prevValue.serialize(buffer, true)
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                    if boxed {
                        buffer.appendInt32(1129042607)
                    }
                    prevPhoto.serialize(buffer, true)
                    newPhoto.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                    if boxed {
                        buffer.appendInt32(-1312568665)
                    }
                    prevStickerset.serialize(buffer, true)
                    newStickerset.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-421545947)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeUsername(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1783299128)
                    }
                    serializeString(prevValue, buffer: buffer, boxed: false)
                    serializeString(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionChangeUsernames(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(-263212119)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prevValue.count))
                    for item in prevValue {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newValue.count))
                    for item in newValue {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                    break
                case .channelAdminLogEventActionCreateTopic(let topic):
                    if boxed {
                        buffer.appendInt32(1483767080)
                    }
                    topic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                    if boxed {
                        buffer.appendInt32(771095562)
                    }
                    prevBannedRights.serialize(buffer, true)
                    newBannedRights.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDeleteMessage(let message):
                    if boxed {
                        buffer.appendInt32(1121994683)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDeleteTopic(let topic):
                    if boxed {
                        buffer.appendInt32(-1374254839)
                    }
                    topic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionDiscardGroupCall(let call):
                    if boxed {
                        buffer.appendInt32(-610299584)
                    }
                    call.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                    if boxed {
                        buffer.appendInt32(1889215493)
                    }
                    prevMessage.serialize(buffer, true)
                    newMessage.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionEditTopic(let prevTopic, let newTopic):
                    if boxed {
                        buffer.appendInt32(-261103096)
                    }
                    prevTopic.serialize(buffer, true)
                    newTopic.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteDelete(let invite):
                    if boxed {
                        buffer.appendInt32(1515256996)
                    }
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteEdit(let prevInvite, let newInvite):
                    if boxed {
                        buffer.appendInt32(-384910503)
                    }
                    prevInvite.serialize(buffer, true)
                    newInvite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionExportedInviteRevoke(let invite):
                    if boxed {
                        buffer.appendInt32(1091179342)
                    }
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantInvite(let participant):
                    if boxed {
                        buffer.appendInt32(-484690728)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantJoin:
                    if boxed {
                        buffer.appendInt32(405815507)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantJoinByInvite(let flags, let invite):
                    if boxed {
                        buffer.appendInt32(-23084712)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    invite.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantJoinByRequest(let invite, let approvedBy):
                    if boxed {
                        buffer.appendInt32(-1347021750)
                    }
                    invite.serialize(buffer, true)
                    serializeInt64(approvedBy, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionParticipantLeave:
                    if boxed {
                        buffer.appendInt32(-124291086)
                    }
                    
                    break
                case .channelAdminLogEventActionParticipantMute(let participant):
                    if boxed {
                        buffer.appendInt32(-115071790)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantToggleAdmin(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(-714643696)
                    }
                    prevParticipant.serialize(buffer, true)
                    newParticipant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                    if boxed {
                        buffer.appendInt32(-422036098)
                    }
                    prevParticipant.serialize(buffer, true)
                    newParticipant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantUnmute(let participant):
                    if boxed {
                        buffer.appendInt32(-431740480)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionParticipantVolume(let participant):
                    if boxed {
                        buffer.appendInt32(1048537159)
                    }
                    participant.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionPinTopic(let flags, let prevTopic, let newTopic):
                    if boxed {
                        buffer.appendInt32(1569535291)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevTopic!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newTopic!.serialize(buffer, true)}
                    break
                case .channelAdminLogEventActionSendMessage(let message):
                    if boxed {
                        buffer.appendInt32(663693416)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionStartGroupCall(let call):
                    if boxed {
                        buffer.appendInt32(589338437)
                    }
                    call.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionStopPoll(let message):
                    if boxed {
                        buffer.appendInt32(-1895328189)
                    }
                    message.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleAntiSpam(let newValue):
                    if boxed {
                        buffer.appendInt32(1693675004)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleForum(let newValue):
                    if boxed {
                        buffer.appendInt32(46949251)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleGroupCallSetting(let joinMuted):
                    if boxed {
                        buffer.appendInt32(1456906823)
                    }
                    joinMuted.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleInvites(let newValue):
                    if boxed {
                        buffer.appendInt32(460916654)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleNoForwards(let newValue):
                    if boxed {
                        buffer.appendInt32(-886388890)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                    if boxed {
                        buffer.appendInt32(1599903217)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                    if boxed {
                        buffer.appendInt32(648939889)
                    }
                    newValue.serialize(buffer, true)
                    break
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                    if boxed {
                        buffer.appendInt32(1401984889)
                    }
                    serializeInt32(prevValue, buffer: buffer, boxed: false)
                    serializeInt32(newValue, buffer: buffer, boxed: false)
                    break
                case .channelAdminLogEventActionUpdatePinned(let message):
                    if boxed {
                        buffer.appendInt32(-370660328)
                    }
                    message.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEventActionChangeAbout(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeAbout", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeAvailableReactions(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeAvailableReactions", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeHistoryTTL(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeHistoryTTL", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeLinkedChat(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLinkedChat", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeLocation(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeLocation", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangePhoto(let prevPhoto, let newPhoto):
                return ("channelAdminLogEventActionChangePhoto", [("prevPhoto", prevPhoto as Any), ("newPhoto", newPhoto as Any)])
                case .channelAdminLogEventActionChangeStickerSet(let prevStickerset, let newStickerset):
                return ("channelAdminLogEventActionChangeStickerSet", [("prevStickerset", prevStickerset as Any), ("newStickerset", newStickerset as Any)])
                case .channelAdminLogEventActionChangeTitle(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeTitle", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeUsername(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeUsername", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionChangeUsernames(let prevValue, let newValue):
                return ("channelAdminLogEventActionChangeUsernames", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionCreateTopic(let topic):
                return ("channelAdminLogEventActionCreateTopic", [("topic", topic as Any)])
                case .channelAdminLogEventActionDefaultBannedRights(let prevBannedRights, let newBannedRights):
                return ("channelAdminLogEventActionDefaultBannedRights", [("prevBannedRights", prevBannedRights as Any), ("newBannedRights", newBannedRights as Any)])
                case .channelAdminLogEventActionDeleteMessage(let message):
                return ("channelAdminLogEventActionDeleteMessage", [("message", message as Any)])
                case .channelAdminLogEventActionDeleteTopic(let topic):
                return ("channelAdminLogEventActionDeleteTopic", [("topic", topic as Any)])
                case .channelAdminLogEventActionDiscardGroupCall(let call):
                return ("channelAdminLogEventActionDiscardGroupCall", [("call", call as Any)])
                case .channelAdminLogEventActionEditMessage(let prevMessage, let newMessage):
                return ("channelAdminLogEventActionEditMessage", [("prevMessage", prevMessage as Any), ("newMessage", newMessage as Any)])
                case .channelAdminLogEventActionEditTopic(let prevTopic, let newTopic):
                return ("channelAdminLogEventActionEditTopic", [("prevTopic", prevTopic as Any), ("newTopic", newTopic as Any)])
                case .channelAdminLogEventActionExportedInviteDelete(let invite):
                return ("channelAdminLogEventActionExportedInviteDelete", [("invite", invite as Any)])
                case .channelAdminLogEventActionExportedInviteEdit(let prevInvite, let newInvite):
                return ("channelAdminLogEventActionExportedInviteEdit", [("prevInvite", prevInvite as Any), ("newInvite", newInvite as Any)])
                case .channelAdminLogEventActionExportedInviteRevoke(let invite):
                return ("channelAdminLogEventActionExportedInviteRevoke", [("invite", invite as Any)])
                case .channelAdminLogEventActionParticipantInvite(let participant):
                return ("channelAdminLogEventActionParticipantInvite", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantJoin:
                return ("channelAdminLogEventActionParticipantJoin", [])
                case .channelAdminLogEventActionParticipantJoinByInvite(let flags, let invite):
                return ("channelAdminLogEventActionParticipantJoinByInvite", [("flags", flags as Any), ("invite", invite as Any)])
                case .channelAdminLogEventActionParticipantJoinByRequest(let invite, let approvedBy):
                return ("channelAdminLogEventActionParticipantJoinByRequest", [("invite", invite as Any), ("approvedBy", approvedBy as Any)])
                case .channelAdminLogEventActionParticipantLeave:
                return ("channelAdminLogEventActionParticipantLeave", [])
                case .channelAdminLogEventActionParticipantMute(let participant):
                return ("channelAdminLogEventActionParticipantMute", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantToggleAdmin(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleAdmin", [("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any)])
                case .channelAdminLogEventActionParticipantToggleBan(let prevParticipant, let newParticipant):
                return ("channelAdminLogEventActionParticipantToggleBan", [("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any)])
                case .channelAdminLogEventActionParticipantUnmute(let participant):
                return ("channelAdminLogEventActionParticipantUnmute", [("participant", participant as Any)])
                case .channelAdminLogEventActionParticipantVolume(let participant):
                return ("channelAdminLogEventActionParticipantVolume", [("participant", participant as Any)])
                case .channelAdminLogEventActionPinTopic(let flags, let prevTopic, let newTopic):
                return ("channelAdminLogEventActionPinTopic", [("flags", flags as Any), ("prevTopic", prevTopic as Any), ("newTopic", newTopic as Any)])
                case .channelAdminLogEventActionSendMessage(let message):
                return ("channelAdminLogEventActionSendMessage", [("message", message as Any)])
                case .channelAdminLogEventActionStartGroupCall(let call):
                return ("channelAdminLogEventActionStartGroupCall", [("call", call as Any)])
                case .channelAdminLogEventActionStopPoll(let message):
                return ("channelAdminLogEventActionStopPoll", [("message", message as Any)])
                case .channelAdminLogEventActionToggleAntiSpam(let newValue):
                return ("channelAdminLogEventActionToggleAntiSpam", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleForum(let newValue):
                return ("channelAdminLogEventActionToggleForum", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleGroupCallSetting(let joinMuted):
                return ("channelAdminLogEventActionToggleGroupCallSetting", [("joinMuted", joinMuted as Any)])
                case .channelAdminLogEventActionToggleInvites(let newValue):
                return ("channelAdminLogEventActionToggleInvites", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleNoForwards(let newValue):
                return ("channelAdminLogEventActionToggleNoForwards", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionTogglePreHistoryHidden(let newValue):
                return ("channelAdminLogEventActionTogglePreHistoryHidden", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleSignatures(let newValue):
                return ("channelAdminLogEventActionToggleSignatures", [("newValue", newValue as Any)])
                case .channelAdminLogEventActionToggleSlowMode(let prevValue, let newValue):
                return ("channelAdminLogEventActionToggleSlowMode", [("prevValue", prevValue as Any), ("newValue", newValue as Any)])
                case .channelAdminLogEventActionUpdatePinned(let message):
                return ("channelAdminLogEventActionUpdatePinned", [("message", message as Any)])
    }
    }
    
        public static func parse_channelAdminLogEventActionChangeAbout(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAbout(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeAvailableReactions(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChatReactions?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            }
            var _2: Api.ChatReactions?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAvailableReactions(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeHistoryTTL(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeHistoryTTL(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeLinkedChat(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLinkedChat(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeLocation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelLocation?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            }
            var _2: Api.ChannelLocation?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLocation(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangePhoto(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: Api.Photo?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangePhoto(prevPhoto: _1!, newPhoto: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            var _2: Api.InputStickerSet?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputStickerSet
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeStickerSet(prevStickerset: _1!, newStickerset: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeTitle(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeTitle(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeUsername(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsername(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeUsernames(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: [String]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsernames(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionCreateTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionCreateTopic(topic: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDefaultBannedRights(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            var _2: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDefaultBannedRights(prevBannedRights: _1!, newBannedRights: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDeleteMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDeleteTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteTopic(topic: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionDiscardGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDiscardGroupCall(call: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionEditMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Api.Message?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditMessage(prevMessage: _1!, newMessage: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionEditTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            var _2: Api.ForumTopic?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditTopic(prevTopic: _1!, newTopic: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteDelete(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteDelete(invite: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteEdit(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteEdit(prevInvite: _1!, newInvite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionExportedInviteRevoke(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteRevoke(invite: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantInvite(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantJoin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoin
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByInvite(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByInvite(flags: _1!, invite: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantJoinByRequest(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByRequest(invite: _1!, approvedBy: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantLeave(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantLeave
        }
        public static func parse_channelAdminLogEventActionParticipantMute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantMute(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantToggleAdmin(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            var _2: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: _1!, newParticipant: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantToggleBan(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            var _2: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleBan(prevParticipant: _1!, newParticipant: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantUnmute(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantUnmute(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantVolume(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.GroupCallParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipant
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantVolume(participant: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionPinTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ForumTopic?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            } }
            var _3: Api.ForumTopic?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ForumTopic
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionPinTopic(flags: _1!, prevTopic: _2, newTopic: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionSendMessage(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionSendMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionStartGroupCall(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStartGroupCall(call: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionStopPoll(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStopPoll(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleAntiSpam(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleAntiSpam(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleForum(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleForum(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleGroupCallSetting(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleGroupCallSetting(joinMuted: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleInvites(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleInvites(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleNoForwards(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleNoForwards(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionTogglePreHistoryHidden(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionTogglePreHistoryHidden(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleSignatures(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSignatures(newValue: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleSlowMode(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSlowMode(prevValue: _1!, newValue: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionUpdatePinned(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionUpdatePinned(message: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
