public extension Api {
    enum BotBusinessConnection: TypeConstructorDescription {
        public class Cons_botBusinessConnection {
            public var flags: Int32
            public var connectionId: String
            public var userId: Int64
            public var dcId: Int32
            public var date: Int32
            public var rights: Api.BusinessBotRights?
            public init(flags: Int32, connectionId: String, userId: Int64, dcId: Int32, date: Int32, rights: Api.BusinessBotRights?) {
                self.flags = flags
                self.connectionId = connectionId
                self.userId = userId
                self.dcId = dcId
                self.date = date
                self.rights = rights
            }
        }
        case botBusinessConnection(Cons_botBusinessConnection)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botBusinessConnection(let _data):
                if boxed {
                    buffer.appendInt32(-1892371723)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.connectionId, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.rights!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botBusinessConnection(let _data):
                return ("botBusinessConnection", [("flags", _data.flags as Any), ("connectionId", _data.connectionId as Any), ("userId", _data.userId as Any), ("dcId", _data.dcId as Any), ("date", _data.date as Any), ("rights", _data.rights as Any)])
            }
        }

        public static func parse_botBusinessConnection(_ reader: BufferReader) -> BotBusinessConnection? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.BusinessBotRights?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.BusinessBotRights
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BotBusinessConnection.botBusinessConnection(Cons_botBusinessConnection(flags: _1!, connectionId: _2!, userId: _3!, dcId: _4!, date: _5!, rights: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotCommand: TypeConstructorDescription {
        public class Cons_botCommand {
            public var command: String
            public var description: String
            public init(command: String, description: String) {
                self.command = command
                self.description = description
            }
        }
        case botCommand(Cons_botCommand)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botCommand(let _data):
                if boxed {
                    buffer.appendInt32(-1032140601)
                }
                serializeString(_data.command, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botCommand(let _data):
                return ("botCommand", [("command", _data.command as Any), ("description", _data.description as Any)])
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
                return Api.BotCommand.botCommand(Cons_botCommand(command: _1!, description: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum BotCommandScope: TypeConstructorDescription {
        public class Cons_botCommandScopePeer {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_botCommandScopePeerAdmins {
            public var peer: Api.InputPeer
            public init(peer: Api.InputPeer) {
                self.peer = peer
            }
        }
        public class Cons_botCommandScopePeerUser {
            public var peer: Api.InputPeer
            public var userId: Api.InputUser
            public init(peer: Api.InputPeer, userId: Api.InputUser) {
                self.peer = peer
                self.userId = userId
            }
        }
        case botCommandScopeChatAdmins
        case botCommandScopeChats
        case botCommandScopeDefault
        case botCommandScopePeer(Cons_botCommandScopePeer)
        case botCommandScopePeerAdmins(Cons_botCommandScopePeerAdmins)
        case botCommandScopePeerUser(Cons_botCommandScopePeerUser)
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
            case .botCommandScopePeer(let _data):
                if boxed {
                    buffer.appendInt32(-610432643)
                }
                _data.peer.serialize(buffer, true)
                break
            case .botCommandScopePeerAdmins(let _data):
                if boxed {
                    buffer.appendInt32(1071145937)
                }
                _data.peer.serialize(buffer, true)
                break
            case .botCommandScopePeerUser(let _data):
                if boxed {
                    buffer.appendInt32(169026035)
                }
                _data.peer.serialize(buffer, true)
                _data.userId.serialize(buffer, true)
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
            case .botCommandScopePeer(let _data):
                return ("botCommandScopePeer", [("peer", _data.peer as Any)])
            case .botCommandScopePeerAdmins(let _data):
                return ("botCommandScopePeerAdmins", [("peer", _data.peer as Any)])
            case .botCommandScopePeerUser(let _data):
                return ("botCommandScopePeerUser", [("peer", _data.peer as Any), ("userId", _data.userId as Any)])
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
                return Api.BotCommandScope.botCommandScopePeer(Cons_botCommandScopePeer(peer: _1!))
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
                return Api.BotCommandScope.botCommandScopePeerAdmins(Cons_botCommandScopePeerAdmins(peer: _1!))
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
                return Api.BotCommandScope.botCommandScopePeerUser(Cons_botCommandScopePeerUser(peer: _1!, userId: _2!))
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
        public class Cons_botInfo {
            public var flags: Int32
            public var userId: Int64?
            public var description: String?
            public var descriptionPhoto: Api.Photo?
            public var descriptionDocument: Api.Document?
            public var commands: [Api.BotCommand]?
            public var menuButton: Api.BotMenuButton?
            public var privacyPolicyUrl: String?
            public var appSettings: Api.BotAppSettings?
            public var verifierSettings: Api.BotVerifierSettings?
            public init(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?, privacyPolicyUrl: String?, appSettings: Api.BotAppSettings?, verifierSettings: Api.BotVerifierSettings?) {
                self.flags = flags
                self.userId = userId
                self.description = description
                self.descriptionPhoto = descriptionPhoto
                self.descriptionDocument = descriptionDocument
                self.commands = commands
                self.menuButton = menuButton
                self.privacyPolicyUrl = privacyPolicyUrl
                self.appSettings = appSettings
                self.verifierSettings = verifierSettings
            }
        }
        case botInfo(Cons_botInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botInfo(let _data):
                if boxed {
                    buffer.appendInt32(1300890265)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.userId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.descriptionPhoto!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.descriptionDocument!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.commands!.count))
                    for item in _data.commands! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.menuButton!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeString(_data.privacyPolicyUrl!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.appSettings!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    _data.verifierSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botInfo(let _data):
                return ("botInfo", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("description", _data.description as Any), ("descriptionPhoto", _data.descriptionPhoto as Any), ("descriptionDocument", _data.descriptionDocument as Any), ("commands", _data.commands as Any), ("menuButton", _data.menuButton as Any), ("privacyPolicyUrl", _data.privacyPolicyUrl as Any), ("appSettings", _data.appSettings as Any), ("verifierSettings", _data.verifierSettings as Any)])
            }
        }

        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt64()
            }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = parseString(reader)
            }
            var _4: Api.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _6: [Api.BotCommand]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
                }
            }
            var _7: Api.BotMenuButton?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.BotMenuButton
                }
            }
            var _8: String?
            if Int(_1!) & Int(1 << 7) != 0 {
                _8 = parseString(reader)
            }
            var _9: Api.BotAppSettings?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.BotAppSettings
                }
            }
            var _10: Api.BotVerifierSettings?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.BotVerifierSettings
                }
            }
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
                return Api.BotInfo.botInfo(Cons_botInfo(flags: _1!, userId: _2, description: _3, descriptionPhoto: _4, descriptionDocument: _5, commands: _6, menuButton: _7, privacyPolicyUrl: _8, appSettings: _9, verifierSettings: _10))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotInlineMessage: TypeConstructorDescription {
        public class Cons_botInlineMessageMediaAuto {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaContact {
            public var flags: Int32
            public var phoneNumber: String
            public var firstName: String
            public var lastName: String
            public var vcard: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.phoneNumber = phoneNumber
                self.firstName = firstName
                self.lastName = lastName
                self.vcard = vcard
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaGeo {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var heading: Int32?
            public var period: Int32?
            public var proximityNotificationRadius: Int32?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geo = geo
                self.heading = heading
                self.period = period
                self.proximityNotificationRadius = proximityNotificationRadius
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaInvoice {
            public var flags: Int32
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var currency: String
            public var totalAmount: Int64
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, currency: String, totalAmount: Int64, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.photo = photo
                self.currency = currency
                self.totalAmount = totalAmount
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaVenue {
            public var flags: Int32
            public var geo: Api.GeoPoint
            public var title: String
            public var address: String
            public var provider: String
            public var venueId: String
            public var venueType: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.geo = geo
                self.title = title
                self.address = address
                self.provider = provider
                self.venueId = venueId
                self.venueType = venueType
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageMediaWebPage {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var url: String
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.url = url
                self.replyMarkup = replyMarkup
            }
        }
        public class Cons_botInlineMessageText {
            public var flags: Int32
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var replyMarkup: Api.ReplyMarkup?
            public init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
                self.flags = flags
                self.message = message
                self.entities = entities
                self.replyMarkup = replyMarkup
            }
        }
        case botInlineMessageMediaAuto(Cons_botInlineMessageMediaAuto)
        case botInlineMessageMediaContact(Cons_botInlineMessageMediaContact)
        case botInlineMessageMediaGeo(Cons_botInlineMessageMediaGeo)
        case botInlineMessageMediaInvoice(Cons_botInlineMessageMediaInvoice)
        case botInlineMessageMediaVenue(Cons_botInlineMessageMediaVenue)
        case botInlineMessageMediaWebPage(Cons_botInlineMessageMediaWebPage)
        case botInlineMessageText(Cons_botInlineMessageText)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botInlineMessageMediaAuto(let _data):
                if boxed {
                    buffer.appendInt32(1984755728)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageMediaContact(let _data):
                if boxed {
                    buffer.appendInt32(416402882)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.phoneNumber, buffer: buffer, boxed: false)
                serializeString(_data.firstName, buffer: buffer, boxed: false)
                serializeString(_data.lastName, buffer: buffer, boxed: false)
                serializeString(_data.vcard, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageMediaGeo(let _data):
                if boxed {
                    buffer.appendInt32(85477117)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geo.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.heading!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.period!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.proximityNotificationRadius!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageMediaInvoice(let _data):
                if boxed {
                    buffer.appendInt32(894081801)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageMediaVenue(let _data):
                if boxed {
                    buffer.appendInt32(-1970903652)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.geo.serialize(buffer, true)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.address, buffer: buffer, boxed: false)
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.venueId, buffer: buffer, boxed: false)
                serializeString(_data.venueType, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageMediaWebPage(let _data):
                if boxed {
                    buffer.appendInt32(-2137335386)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            case .botInlineMessageText(let _data):
                if boxed {
                    buffer.appendInt32(-1937807902)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replyMarkup!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botInlineMessageMediaAuto(let _data):
                return ("botInlineMessageMediaAuto", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageMediaContact(let _data):
                return ("botInlineMessageMediaContact", [("flags", _data.flags as Any), ("phoneNumber", _data.phoneNumber as Any), ("firstName", _data.firstName as Any), ("lastName", _data.lastName as Any), ("vcard", _data.vcard as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageMediaGeo(let _data):
                return ("botInlineMessageMediaGeo", [("flags", _data.flags as Any), ("geo", _data.geo as Any), ("heading", _data.heading as Any), ("period", _data.period as Any), ("proximityNotificationRadius", _data.proximityNotificationRadius as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageMediaInvoice(let _data):
                return ("botInlineMessageMediaInvoice", [("flags", _data.flags as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("currency", _data.currency as Any), ("totalAmount", _data.totalAmount as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageMediaVenue(let _data):
                return ("botInlineMessageMediaVenue", [("flags", _data.flags as Any), ("geo", _data.geo as Any), ("title", _data.title as Any), ("address", _data.address as Any), ("provider", _data.provider as Any), ("venueId", _data.venueId as Any), ("venueType", _data.venueType as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageMediaWebPage(let _data):
                return ("botInlineMessageMediaWebPage", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("url", _data.url as Any), ("replyMarkup", _data.replyMarkup as Any)])
            case .botInlineMessageText(let _data):
                return ("botInlineMessageText", [("flags", _data.flags as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("replyMarkup", _data.replyMarkup as Any)])
            }
        }

        public static func parse_botInlineMessageMediaAuto(_ reader: BufferReader) -> BotInlineMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotInlineMessage.botInlineMessageMediaAuto(Cons_botInlineMessageMediaAuto(flags: _1!, message: _2!, entities: _3, replyMarkup: _4))
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
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BotInlineMessage.botInlineMessageMediaContact(Cons_botInlineMessageMediaContact(flags: _1!, phoneNumber: _2!, firstName: _3!, lastName: _4!, vcard: _5!, replyMarkup: _6))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BotInlineMessage.botInlineMessageMediaGeo(Cons_botInlineMessageMediaGeo(flags: _1!, geo: _2!, heading: _3, period: _4, proximityNotificationRadius: _5, replyMarkup: _6))
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.BotInlineMessage.botInlineMessageMediaInvoice(Cons_botInlineMessageMediaInvoice(flags: _1!, title: _2!, description: _3!, photo: _4, currency: _5!, totalAmount: _6!, replyMarkup: _7))
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
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.BotInlineMessage.botInlineMessageMediaVenue(Cons_botInlineMessageMediaVenue(flags: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!, replyMarkup: _8))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.BotInlineMessage.botInlineMessageMediaWebPage(Cons_botInlineMessageMediaWebPage(flags: _1!, message: _2!, entities: _3, url: _4!, replyMarkup: _5))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _4: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotInlineMessage.botInlineMessageText(Cons_botInlineMessageText(flags: _1!, message: _2!, entities: _3, replyMarkup: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotInlineResult: TypeConstructorDescription {
        public class Cons_botInlineMediaResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var photo: Api.Photo?
            public var document: Api.Document?
            public var title: String?
            public var description: String?
            public var sendMessage: Api.BotInlineMessage
            public init(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.photo = photo
                self.document = document
                self.title = title
                self.description = description
                self.sendMessage = sendMessage
            }
        }
        public class Cons_botInlineResult {
            public var flags: Int32
            public var id: String
            public var type: String
            public var title: String?
            public var description: String?
            public var url: String?
            public var thumb: Api.WebDocument?
            public var content: Api.WebDocument?
            public var sendMessage: Api.BotInlineMessage
            public init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage) {
                self.flags = flags
                self.id = id
                self.type = type
                self.title = title
                self.description = description
                self.url = url
                self.thumb = thumb
                self.content = content
                self.sendMessage = sendMessage
            }
        }
        case botInlineMediaResult(Cons_botInlineMediaResult)
        case botInlineResult(Cons_botInlineResult)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botInlineMediaResult(let _data):
                if boxed {
                    buffer.appendInt32(400266251)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.document!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                _data.sendMessage.serialize(buffer, true)
                break
            case .botInlineResult(let _data):
                if boxed {
                    buffer.appendInt32(295067450)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.type, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.description!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    _data.thumb!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.content!.serialize(buffer, true)
                }
                _data.sendMessage.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botInlineMediaResult(let _data):
                return ("botInlineMediaResult", [("flags", _data.flags as Any), ("id", _data.id as Any), ("type", _data.type as Any), ("photo", _data.photo as Any), ("document", _data.document as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("sendMessage", _data.sendMessage as Any)])
            case .botInlineResult(let _data):
                return ("botInlineResult", [("flags", _data.flags as Any), ("id", _data.id as Any), ("type", _data.type as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("url", _data.url as Any), ("thumb", _data.thumb as Any), ("content", _data.content as Any), ("sendMessage", _data.sendMessage as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _5: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = parseString(reader)
            }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _7 = parseString(reader)
            }
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
                return Api.BotInlineResult.botInlineMediaResult(Cons_botInlineMediaResult(flags: _1!, id: _2!, type: _3!, photo: _4, document: _5, title: _6, description: _7, sendMessage: _8!))
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
            if Int(_1!) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.WebDocument?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _8: Api.WebDocument?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
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
                return Api.BotInlineResult.botInlineResult(Cons_botInlineResult(flags: _1!, id: _2!, type: _3!, title: _4, description: _5, url: _6, thumb: _7, content: _8, sendMessage: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotMenuButton: TypeConstructorDescription {
        public class Cons_botMenuButton {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
        }
        case botMenuButton(Cons_botMenuButton)
        case botMenuButtonCommands
        case botMenuButtonDefault

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botMenuButton(let _data):
                if boxed {
                    buffer.appendInt32(-944407322)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
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
            case .botMenuButton(let _data):
                return ("botMenuButton", [("text", _data.text as Any), ("url", _data.url as Any)])
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
                return Api.BotMenuButton.botMenuButton(Cons_botMenuButton(text: _1!, url: _2!))
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
        public class Cons_botPreviewMedia {
            public var date: Int32
            public var media: Api.MessageMedia
            public init(date: Int32, media: Api.MessageMedia) {
                self.date = date
                self.media = media
            }
        }
        case botPreviewMedia(Cons_botPreviewMedia)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botPreviewMedia(let _data):
                if boxed {
                    buffer.appendInt32(602479523)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.media.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botPreviewMedia(let _data):
                return ("botPreviewMedia", [("date", _data.date as Any), ("media", _data.media as Any)])
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
                return Api.BotPreviewMedia.botPreviewMedia(Cons_botPreviewMedia(date: _1!, media: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotVerification: TypeConstructorDescription {
        public class Cons_botVerification {
            public var botId: Int64
            public var icon: Int64
            public var description: String
            public init(botId: Int64, icon: Int64, description: String) {
                self.botId = botId
                self.icon = icon
                self.description = description
            }
        }
        case botVerification(Cons_botVerification)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botVerification(let _data):
                if boxed {
                    buffer.appendInt32(-113453988)
                }
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeInt64(_data.icon, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botVerification(let _data):
                return ("botVerification", [("botId", _data.botId as Any), ("icon", _data.icon as Any), ("description", _data.description as Any)])
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
                return Api.BotVerification.botVerification(Cons_botVerification(botId: _1!, icon: _2!, description: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BotVerifierSettings: TypeConstructorDescription {
        public class Cons_botVerifierSettings {
            public var flags: Int32
            public var icon: Int64
            public var company: String
            public var customDescription: String?
            public init(flags: Int32, icon: Int64, company: String, customDescription: String?) {
                self.flags = flags
                self.icon = icon
                self.company = company
                self.customDescription = customDescription
            }
        }
        case botVerifierSettings(Cons_botVerifierSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botVerifierSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1328716265)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.icon, buffer: buffer, boxed: false)
                serializeString(_data.company, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.customDescription!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .botVerifierSettings(let _data):
                return ("botVerifierSettings", [("flags", _data.flags as Any), ("icon", _data.icon as Any), ("company", _data.company as Any), ("customDescription", _data.customDescription as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BotVerifierSettings.botVerifierSettings(Cons_botVerifierSettings(flags: _1!, icon: _2!, company: _3!, customDescription: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessAwayMessage: TypeConstructorDescription {
        public class Cons_businessAwayMessage {
            public var flags: Int32
            public var shortcutId: Int32
            public var schedule: Api.BusinessAwayMessageSchedule
            public var recipients: Api.BusinessRecipients
            public init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.BusinessRecipients) {
                self.flags = flags
                self.shortcutId = shortcutId
                self.schedule = schedule
                self.recipients = recipients
            }
        }
        case businessAwayMessage(Cons_businessAwayMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessAwayMessage(let _data):
                if boxed {
                    buffer.appendInt32(-283809188)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                _data.schedule.serialize(buffer, true)
                _data.recipients.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessAwayMessage(let _data):
                return ("businessAwayMessage", [("flags", _data.flags as Any), ("shortcutId", _data.shortcutId as Any), ("schedule", _data.schedule as Any), ("recipients", _data.recipients as Any)])
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
                return Api.BusinessAwayMessage.businessAwayMessage(Cons_businessAwayMessage(flags: _1!, shortcutId: _2!, schedule: _3!, recipients: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessAwayMessageSchedule: TypeConstructorDescription {
        public class Cons_businessAwayMessageScheduleCustom {
            public var startDate: Int32
            public var endDate: Int32
            public init(startDate: Int32, endDate: Int32) {
                self.startDate = startDate
                self.endDate = endDate
            }
        }
        case businessAwayMessageScheduleAlways
        case businessAwayMessageScheduleCustom(Cons_businessAwayMessageScheduleCustom)
        case businessAwayMessageScheduleOutsideWorkHours

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessAwayMessageScheduleAlways:
                if boxed {
                    buffer.appendInt32(-910564679)
                }
                break
            case .businessAwayMessageScheduleCustom(let _data):
                if boxed {
                    buffer.appendInt32(-867328308)
                }
                serializeInt32(_data.startDate, buffer: buffer, boxed: false)
                serializeInt32(_data.endDate, buffer: buffer, boxed: false)
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
            case .businessAwayMessageScheduleCustom(let _data):
                return ("businessAwayMessageScheduleCustom", [("startDate", _data.startDate as Any), ("endDate", _data.endDate as Any)])
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
                return Api.BusinessAwayMessageSchedule.businessAwayMessageScheduleCustom(Cons_businessAwayMessageScheduleCustom(startDate: _1!, endDate: _2!))
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
        public class Cons_businessBotRecipients {
            public var flags: Int32
            public var users: [Int64]?
            public var excludeUsers: [Int64]?
            public init(flags: Int32, users: [Int64]?, excludeUsers: [Int64]?) {
                self.flags = flags
                self.users = users
                self.excludeUsers = excludeUsers
            }
        }
        case businessBotRecipients(Cons_businessBotRecipients)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessBotRecipients(let _data):
                if boxed {
                    buffer.appendInt32(-1198722189)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.users!.count))
                    for item in _data.users! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.excludeUsers!.count))
                    for item in _data.excludeUsers! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessBotRecipients(let _data):
                return ("businessBotRecipients", [("flags", _data.flags as Any), ("users", _data.users as Any), ("excludeUsers", _data.excludeUsers as Any)])
            }
        }

        public static func parse_businessBotRecipients(_ reader: BufferReader) -> BusinessBotRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            var _3: [Int64]?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessBotRecipients.businessBotRecipients(Cons_businessBotRecipients(flags: _1!, users: _2, excludeUsers: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessBotRights: TypeConstructorDescription {
        public class Cons_businessBotRights {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case businessBotRights(Cons_businessBotRights)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessBotRights(let _data):
                if boxed {
                    buffer.appendInt32(-1604170505)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessBotRights(let _data):
                return ("businessBotRights", [("flags", _data.flags as Any)])
            }
        }

        public static func parse_businessBotRights(_ reader: BufferReader) -> BusinessBotRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.BusinessBotRights.businessBotRights(Cons_businessBotRights(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessChatLink: TypeConstructorDescription {
        public class Cons_businessChatLink {
            public var flags: Int32
            public var link: String
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var title: String?
            public var views: Int32
            public init(flags: Int32, link: String, message: String, entities: [Api.MessageEntity]?, title: String?, views: Int32) {
                self.flags = flags
                self.link = link
                self.message = message
                self.entities = entities
                self.title = title
                self.views = views
            }
        }
        case businessChatLink(Cons_businessChatLink)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessChatLink(let _data):
                if boxed {
                    buffer.appendInt32(-1263638929)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.link, buffer: buffer, boxed: false)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.views, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessChatLink(let _data):
                return ("businessChatLink", [("flags", _data.flags as Any), ("link", _data.link as Any), ("message", _data.message as Any), ("entities", _data.entities as Any), ("title", _data.title as Any), ("views", _data.views as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.BusinessChatLink.businessChatLink(Cons_businessChatLink(flags: _1!, link: _2!, message: _3!, entities: _4, title: _5, views: _6!))
            }
            else {
                return nil
            }
        }
    }
}
