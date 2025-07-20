public extension Api {
    enum BotCommand: TypeConstructorDescription {
        case botCommand(command: String, description: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botCommand(let command, let description):
                    if boxed {
                        buffer.appendInt32(-1032140601)
                    }
                    serializeString(command, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botCommand(let command, let description):
                return ("botCommand", [("command", command as Any), ("description", description as Any)])
    }
    }
    
        public static func parse_botCommand(_ reader: BufferReader) -> BotCommand? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotCommand.botCommand(command: _1!, description: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum BotCommandScope: TypeConstructorDescription {
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(peer: Api.InputPeer)
        case botCommandScopePeerAdmins(peer: Api.InputPeer)
        case botCommandScopePeerUser(peer: Api.InputPeer, userId: Api.InputUser)
        case botCommandScopeUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botCommandScopeChatAdmins:
                    if boxed {
                        buffer.appendInt32(-1180016534)
                    }
                    
                    break
                case .botCommandScopeChats:
                    if boxed {
                        buffer.appendInt32(1877059713)
                    }
                    
                    break
                case .botCommandScopeDefault:
                    if boxed {
                        buffer.appendInt32(795652779)
                    }
                    
                    break
                case .botCommandScopePeer(let peer):
                    if boxed {
                        buffer.appendInt32(-610432643)
                    }
                    peer.serialize(buffer, true)
                    break
                case .botCommandScopePeerAdmins(let peer):
                    if boxed {
                        buffer.appendInt32(1071145937)
                    }
                    peer.serialize(buffer, true)
                    break
                case .botCommandScopePeerUser(let peer, let userId):
                    if boxed {
                        buffer.appendInt32(169026035)
                    }
                    peer.serialize(buffer, true)
                    userId.serialize(buffer, true)
                    break
                case .botCommandScopeUsers:
                    if boxed {
                        buffer.appendInt32(1011811544)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botCommandScopeChatAdmins:
                return ("botCommandScopeChatAdmins", [])
                case .botCommandScopeChats:
                return ("botCommandScopeChats", [])
                case .botCommandScopeDefault:
                return ("botCommandScopeDefault", [])
                case .botCommandScopePeer(let peer):
                return ("botCommandScopePeer", [("peer", peer as Any)])
                case .botCommandScopePeerAdmins(let peer):
                return ("botCommandScopePeerAdmins", [("peer", peer as Any)])
                case .botCommandScopePeerUser(let peer, let userId):
                return ("botCommandScopePeerUser", [("peer", peer as Any), ("userId", userId as Any)])
                case .botCommandScopeUsers:
                return ("botCommandScopeUsers", [])
    }
    }
    
        public static func parse_botCommandScopeChatAdmins(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeChatAdmins
        }
        public static func parse_botCommandScopeChats(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeChats
        }
        public static func parse_botCommandScopeDefault(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeDefault
        }
        public static func parse_botCommandScopePeer(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.BotCommandScope.botCommandScopePeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopePeerAdmins(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.BotCommandScope.botCommandScopePeerAdmins(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopePeerUser(_ reader: BufferReader) -> BotCommandScope? {
            var _1: Api.InputPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputPeer
            }
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotCommandScope.botCommandScopePeerUser(peer: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_botCommandScopeUsers(_ reader: BufferReader) -> BotCommandScope? {
            return Api.BotCommandScope.botCommandScopeUsers
        }
    
    }
}
public extension Api {
    enum BotInfo: TypeConstructorDescription {
        case botInfo(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?, privacyPolicyUrl: String?, appSettings: Api.BotAppSettings?, verifierSettings: Api.BotVerifierSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botInfo(let flags, let userId, let description, let descriptionPhoto, let descriptionDocument, let commands, let menuButton, let privacyPolicyUrl, let appSettings, let verifierSettings):
                    if boxed {
                        buffer.appendInt32(1300890265)
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
                    if Int(flags) & Int(1 << 7) != 0 {serializeString(privacyPolicyUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {appSettings!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 9) != 0 {verifierSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botInfo(let flags, let userId, let description, let descriptionPhoto, let descriptionDocument, let commands, let menuButton, let privacyPolicyUrl, let appSettings, let verifierSettings):
                return ("botInfo", [("flags", flags as Any), ("userId", userId as Any), ("description", description as Any), ("descriptionPhoto", descriptionPhoto as Any), ("descriptionDocument", descriptionDocument as Any), ("commands", commands as Any), ("menuButton", menuButton as Any), ("privacyPolicyUrl", privacyPolicyUrl as Any), ("appSettings", appSettings as Any), ("verifierSettings", verifierSettings as Any)])
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
            var _8: String?
            if Int(_1!) & Int(1 << 7) != 0 {_8 = parseString(reader) }
            var _9: Api.BotAppSettings?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.BotAppSettings
            } }
            var _10: Api.BotVerifierSettings?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.BotVerifierSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 8) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 9) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.BotInfo.botInfo(flags: _1!, userId: _2, description: _3, descriptionPhoto: _4, descriptionDocument: _5, commands: _6, menuButton: _7, privacyPolicyUrl: _8, appSettings: _9, verifierSettings: _10)
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
        case botInlineMessageMediaWebPage(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?)
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
                case .botInlineMessageMediaWebPage(let flags, let message, let entities, let url, let replyMarkup):
                    if boxed {
                        buffer.appendInt32(-2137335386)
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
                case .botInlineMessageMediaWebPage(let flags, let message, let entities, let url, let replyMarkup):
                return ("botInlineMessageMediaWebPage", [("flags", flags as Any), ("message", message as Any), ("entities", entities as Any), ("url", url as Any), ("replyMarkup", replyMarkup as Any)])
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
        public static func parse_botInlineMessageMediaWebPage(_ reader: BufferReader) -> BotInlineMessage? {
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
                return Api.BotInlineMessage.botInlineMessageMediaWebPage(flags: _1!, message: _2!, entities: _3, url: _4!, replyMarkup: _5)
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
    indirect enum BotPreviewMedia: TypeConstructorDescription {
        case botPreviewMedia(date: Int32, media: Api.MessageMedia)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botPreviewMedia(let date, let media):
                    if boxed {
                        buffer.appendInt32(602479523)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botPreviewMedia(let date, let media):
                return ("botPreviewMedia", [("date", date as Any), ("media", media as Any)])
    }
    }
    
        public static func parse_botPreviewMedia(_ reader: BufferReader) -> BotPreviewMedia? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BotPreviewMedia.botPreviewMedia(date: _1!, media: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BotVerification: TypeConstructorDescription {
        case botVerification(botId: Int64, icon: Int64, description: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botVerification(let botId, let icon, let description):
                    if boxed {
                        buffer.appendInt32(-113453988)
                    }
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt64(icon, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botVerification(let botId, let icon, let description):
                return ("botVerification", [("botId", botId as Any), ("icon", icon as Any), ("description", description as Any)])
    }
    }
    
        public static func parse_botVerification(_ reader: BufferReader) -> BotVerification? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BotVerification.botVerification(botId: _1!, icon: _2!, description: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BotVerifierSettings: TypeConstructorDescription {
        case botVerifierSettings(flags: Int32, icon: Int64, company: String, customDescription: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .botVerifierSettings(let flags, let icon, let company, let customDescription):
                    if boxed {
                        buffer.appendInt32(-1328716265)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(icon, buffer: buffer, boxed: false)
                    serializeString(company, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(customDescription!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .botVerifierSettings(let flags, let icon, let company, let customDescription):
                return ("botVerifierSettings", [("flags", flags as Any), ("icon", icon as Any), ("company", company as Any), ("customDescription", customDescription as Any)])
    }
    }
    
        public static func parse_botVerifierSettings(_ reader: BufferReader) -> BotVerifierSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotVerifierSettings.botVerifierSettings(flags: _1!, icon: _2!, company: _3!, customDescription: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessAwayMessage: TypeConstructorDescription {
        case businessAwayMessage(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.BusinessRecipients)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessAwayMessage(let flags, let shortcutId, let schedule, let recipients):
                    if boxed {
                        buffer.appendInt32(-283809188)
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
                case .businessAwayMessage(let flags, let shortcutId, let schedule, let recipients):
                return ("businessAwayMessage", [("flags", flags as Any), ("shortcutId", shortcutId as Any), ("schedule", schedule as Any), ("recipients", recipients as Any)])
    }
    }
    
        public static func parse_businessAwayMessage(_ reader: BufferReader) -> BusinessAwayMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.BusinessAwayMessageSchedule?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.BusinessAwayMessageSchedule
            }
            var _4: Api.BusinessRecipients?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.BusinessRecipients
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BusinessAwayMessage.businessAwayMessage(flags: _1!, shortcutId: _2!, schedule: _3!, recipients: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessAwayMessageSchedule: TypeConstructorDescription {
        case businessAwayMessageScheduleAlways
        case businessAwayMessageScheduleCustom(startDate: Int32, endDate: Int32)
        case businessAwayMessageScheduleOutsideWorkHours
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessAwayMessageScheduleAlways:
                    if boxed {
                        buffer.appendInt32(-910564679)
                    }
                    
                    break
                case .businessAwayMessageScheduleCustom(let startDate, let endDate):
                    if boxed {
                        buffer.appendInt32(-867328308)
                    }
                    serializeInt32(startDate, buffer: buffer, boxed: false)
                    serializeInt32(endDate, buffer: buffer, boxed: false)
                    break
                case .businessAwayMessageScheduleOutsideWorkHours:
                    if boxed {
                        buffer.appendInt32(-1007487743)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessAwayMessageScheduleAlways:
                return ("businessAwayMessageScheduleAlways", [])
                case .businessAwayMessageScheduleCustom(let startDate, let endDate):
                return ("businessAwayMessageScheduleCustom", [("startDate", startDate as Any), ("endDate", endDate as Any)])
                case .businessAwayMessageScheduleOutsideWorkHours:
                return ("businessAwayMessageScheduleOutsideWorkHours", [])
    }
    }
    
        public static func parse_businessAwayMessageScheduleAlways(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            return Api.BusinessAwayMessageSchedule.businessAwayMessageScheduleAlways
        }
        public static func parse_businessAwayMessageScheduleCustom(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BusinessAwayMessageSchedule.businessAwayMessageScheduleCustom(startDate: _1!, endDate: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_businessAwayMessageScheduleOutsideWorkHours(_ reader: BufferReader) -> BusinessAwayMessageSchedule? {
            return Api.BusinessAwayMessageSchedule.businessAwayMessageScheduleOutsideWorkHours
        }
    
    }
}
public extension Api {
    enum BusinessBotRecipients: TypeConstructorDescription {
        case businessBotRecipients(flags: Int32, users: [Int64]?, excludeUsers: [Int64]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessBotRecipients(let flags, let users, let excludeUsers):
                    if boxed {
                        buffer.appendInt32(-1198722189)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users!.count))
                    for item in users! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(excludeUsers!.count))
                    for item in excludeUsers! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessBotRecipients(let flags, let users, let excludeUsers):
                return ("businessBotRecipients", [("flags", flags as Any), ("users", users as Any), ("excludeUsers", excludeUsers as Any)])
    }
    }
    
        public static func parse_businessBotRecipients(_ reader: BufferReader) -> BusinessBotRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            var _3: [Int64]?
            if Int(_1!) & Int(1 << 6) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessBotRecipients.businessBotRecipients(flags: _1!, users: _2, excludeUsers: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessBotRights: TypeConstructorDescription {
        case businessBotRights(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessBotRights(let flags):
                    if boxed {
                        buffer.appendInt32(-1604170505)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessBotRights(let flags):
                return ("businessBotRights", [("flags", flags as Any)])
    }
    }
    
        public static func parse_businessBotRights(_ reader: BufferReader) -> BusinessBotRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.BusinessBotRights.businessBotRights(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessChatLink: TypeConstructorDescription {
        case businessChatLink(flags: Int32, link: String, message: String, entities: [Api.MessageEntity]?, title: String?, views: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessChatLink(let flags, let link, let message, let entities, let title, let views):
                    if boxed {
                        buffer.appendInt32(-1263638929)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(link, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    serializeInt32(views, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessChatLink(let flags, let link, let message, let entities, let title, let views):
                return ("businessChatLink", [("flags", flags as Any), ("link", link as Any), ("message", message as Any), ("entities", entities as Any), ("title", title as Any), ("views", views as Any)])
    }
    }
    
        public static func parse_businessChatLink(_ reader: BufferReader) -> BusinessChatLink? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BusinessChatLink.businessChatLink(flags: _1!, link: _2!, message: _3!, entities: _4, title: _5, views: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum BusinessGreetingMessage: TypeConstructorDescription {
        case businessGreetingMessage(shortcutId: Int32, recipients: Api.BusinessRecipients, noActivityDays: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .businessGreetingMessage(let shortcutId, let recipients, let noActivityDays):
                    if boxed {
                        buffer.appendInt32(-451302485)
                    }
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    recipients.serialize(buffer, true)
                    serializeInt32(noActivityDays, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .businessGreetingMessage(let shortcutId, let recipients, let noActivityDays):
                return ("businessGreetingMessage", [("shortcutId", shortcutId as Any), ("recipients", recipients as Any), ("noActivityDays", noActivityDays as Any)])
    }
    }
    
        public static func parse_businessGreetingMessage(_ reader: BufferReader) -> BusinessGreetingMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BusinessRecipients?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BusinessRecipients
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessGreetingMessage.businessGreetingMessage(shortcutId: _1!, recipients: _2!, noActivityDays: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
