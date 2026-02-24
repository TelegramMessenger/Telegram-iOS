public extension Api {
    enum BusinessGreetingMessage: TypeConstructorDescription {
        public class Cons_businessGreetingMessage: TypeConstructorDescription {
            public var shortcutId: Int32
            public var recipients: Api.BusinessRecipients
            public var noActivityDays: Int32
            public init(shortcutId: Int32, recipients: Api.BusinessRecipients, noActivityDays: Int32) {
                self.shortcutId = shortcutId
                self.recipients = recipients
                self.noActivityDays = noActivityDays
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessGreetingMessage", [("shortcutId", self.shortcutId as Any), ("recipients", self.recipients as Any), ("noActivityDays", self.noActivityDays as Any)])
            }
        }
        case businessGreetingMessage(Cons_businessGreetingMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessGreetingMessage(let _data):
                if boxed {
                    buffer.appendInt32(-451302485)
                }
                serializeInt32(_data.shortcutId, buffer: buffer, boxed: false)
                _data.recipients.serialize(buffer, true)
                serializeInt32(_data.noActivityDays, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessGreetingMessage(let _data):
                return ("businessGreetingMessage", [("shortcutId", _data.shortcutId as Any), ("recipients", _data.recipients as Any), ("noActivityDays", _data.noActivityDays as Any)])
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
                return Api.BusinessGreetingMessage.businessGreetingMessage(Cons_businessGreetingMessage(shortcutId: _1!, recipients: _2!, noActivityDays: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessIntro: TypeConstructorDescription {
        public class Cons_businessIntro: TypeConstructorDescription {
            public var flags: Int32
            public var title: String
            public var description: String
            public var sticker: Api.Document?
            public init(flags: Int32, title: String, description: String, sticker: Api.Document?) {
                self.flags = flags
                self.title = title
                self.description = description
                self.sticker = sticker
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessIntro", [("flags", self.flags as Any), ("title", self.title as Any), ("description", self.description as Any), ("sticker", self.sticker as Any)])
            }
        }
        case businessIntro(Cons_businessIntro)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessIntro(let _data):
                if boxed {
                    buffer.appendInt32(1510606445)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.sticker!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessIntro(let _data):
                return ("businessIntro", [("flags", _data.flags as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("sticker", _data.sticker as Any)])
            }
        }

        public static func parse_businessIntro(_ reader: BufferReader) -> BusinessIntro? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.Document?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.Document
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.BusinessIntro.businessIntro(Cons_businessIntro(flags: _1!, title: _2!, description: _3!, sticker: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessLocation: TypeConstructorDescription {
        public class Cons_businessLocation: TypeConstructorDescription {
            public var flags: Int32
            public var geoPoint: Api.GeoPoint?
            public var address: String
            public init(flags: Int32, geoPoint: Api.GeoPoint?, address: String) {
                self.flags = flags
                self.geoPoint = geoPoint
                self.address = address
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessLocation", [("flags", self.flags as Any), ("geoPoint", self.geoPoint as Any), ("address", self.address as Any)])
            }
        }
        case businessLocation(Cons_businessLocation)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessLocation(let _data):
                if boxed {
                    buffer.appendInt32(-1403249929)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.geoPoint!.serialize(buffer, true)
                }
                serializeString(_data.address, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessLocation(let _data):
                return ("businessLocation", [("flags", _data.flags as Any), ("geoPoint", _data.geoPoint as Any), ("address", _data.address as Any)])
            }
        }

        public static func parse_businessLocation(_ reader: BufferReader) -> BusinessLocation? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
                }
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessLocation.businessLocation(Cons_businessLocation(flags: _1!, geoPoint: _2, address: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessRecipients: TypeConstructorDescription {
        public class Cons_businessRecipients: TypeConstructorDescription {
            public var flags: Int32
            public var users: [Int64]?
            public init(flags: Int32, users: [Int64]?) {
                self.flags = flags
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessRecipients", [("flags", self.flags as Any), ("users", self.users as Any)])
            }
        }
        case businessRecipients(Cons_businessRecipients)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessRecipients(let _data):
                if boxed {
                    buffer.appendInt32(554733559)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.users!.count))
                    for item in _data.users! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessRecipients(let _data):
                return ("businessRecipients", [("flags", _data.flags as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_businessRecipients(_ reader: BufferReader) -> BusinessRecipients? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.BusinessRecipients.businessRecipients(Cons_businessRecipients(flags: _1!, users: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessWeeklyOpen: TypeConstructorDescription {
        public class Cons_businessWeeklyOpen: TypeConstructorDescription {
            public var startMinute: Int32
            public var endMinute: Int32
            public init(startMinute: Int32, endMinute: Int32) {
                self.startMinute = startMinute
                self.endMinute = endMinute
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessWeeklyOpen", [("startMinute", self.startMinute as Any), ("endMinute", self.endMinute as Any)])
            }
        }
        case businessWeeklyOpen(Cons_businessWeeklyOpen)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessWeeklyOpen(let _data):
                if boxed {
                    buffer.appendInt32(302717625)
                }
                serializeInt32(_data.startMinute, buffer: buffer, boxed: false)
                serializeInt32(_data.endMinute, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessWeeklyOpen(let _data):
                return ("businessWeeklyOpen", [("startMinute", _data.startMinute as Any), ("endMinute", _data.endMinute as Any)])
            }
        }

        public static func parse_businessWeeklyOpen(_ reader: BufferReader) -> BusinessWeeklyOpen? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.BusinessWeeklyOpen.businessWeeklyOpen(Cons_businessWeeklyOpen(startMinute: _1!, endMinute: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum BusinessWorkHours: TypeConstructorDescription {
        public class Cons_businessWorkHours: TypeConstructorDescription {
            public var flags: Int32
            public var timezoneId: String
            public var weeklyOpen: [Api.BusinessWeeklyOpen]
            public init(flags: Int32, timezoneId: String, weeklyOpen: [Api.BusinessWeeklyOpen]) {
                self.flags = flags
                self.timezoneId = timezoneId
                self.weeklyOpen = weeklyOpen
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("businessWorkHours", [("flags", self.flags as Any), ("timezoneId", self.timezoneId as Any), ("weeklyOpen", self.weeklyOpen as Any)])
            }
        }
        case businessWorkHours(Cons_businessWorkHours)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .businessWorkHours(let _data):
                if boxed {
                    buffer.appendInt32(-1936543592)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.timezoneId, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.weeklyOpen.count))
                for item in _data.weeklyOpen {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .businessWorkHours(let _data):
                return ("businessWorkHours", [("flags", _data.flags as Any), ("timezoneId", _data.timezoneId as Any), ("weeklyOpen", _data.weeklyOpen as Any)])
            }
        }

        public static func parse_businessWorkHours(_ reader: BufferReader) -> BusinessWorkHours? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.BusinessWeeklyOpen]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BusinessWeeklyOpen.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.BusinessWorkHours.businessWorkHours(Cons_businessWorkHours(flags: _1!, timezoneId: _2!, weeklyOpen: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum CdnConfig: TypeConstructorDescription {
        public class Cons_cdnConfig: TypeConstructorDescription {
            public var publicKeys: [Api.CdnPublicKey]
            public init(publicKeys: [Api.CdnPublicKey]) {
                self.publicKeys = publicKeys
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("cdnConfig", [("publicKeys", self.publicKeys as Any)])
            }
        }
        case cdnConfig(Cons_cdnConfig)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .cdnConfig(let _data):
                if boxed {
                    buffer.appendInt32(1462101002)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.publicKeys.count))
                for item in _data.publicKeys {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .cdnConfig(let _data):
                return ("cdnConfig", [("publicKeys", _data.publicKeys as Any)])
            }
        }

        public static func parse_cdnConfig(_ reader: BufferReader) -> CdnConfig? {
            var _1: [Api.CdnPublicKey]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.CdnPublicKey.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.CdnConfig.cdnConfig(Cons_cdnConfig(publicKeys: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum CdnPublicKey: TypeConstructorDescription {
        public class Cons_cdnPublicKey: TypeConstructorDescription {
            public var dcId: Int32
            public var publicKey: String
            public init(dcId: Int32, publicKey: String) {
                self.dcId = dcId
                self.publicKey = publicKey
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("cdnPublicKey", [("dcId", self.dcId as Any), ("publicKey", self.publicKey as Any)])
            }
        }
        case cdnPublicKey(Cons_cdnPublicKey)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .cdnPublicKey(let _data):
                if boxed {
                    buffer.appendInt32(-914167110)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeString(_data.publicKey, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .cdnPublicKey(let _data):
                return ("cdnPublicKey", [("dcId", _data.dcId as Any), ("publicKey", _data.publicKey as Any)])
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
                return Api.CdnPublicKey.cdnPublicKey(Cons_cdnPublicKey(dcId: _1!, publicKey: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum ChannelAdminLogEvent: TypeConstructorDescription {
        public class Cons_channelAdminLogEvent: TypeConstructorDescription {
            public var id: Int64
            public var date: Int32
            public var userId: Int64
            public var action: Api.ChannelAdminLogEventAction
            public init(id: Int64, date: Int32, userId: Int64, action: Api.ChannelAdminLogEventAction) {
                self.id = id
                self.date = date
                self.userId = userId
                self.action = action
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEvent", [("id", self.id as Any), ("date", self.date as Any), ("userId", self.userId as Any), ("action", self.action as Any)])
            }
        }
        case channelAdminLogEvent(Cons_channelAdminLogEvent)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelAdminLogEvent(let _data):
                if boxed {
                    buffer.appendInt32(531458253)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.action.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelAdminLogEvent(let _data):
                return ("channelAdminLogEvent", [("id", _data.id as Any), ("date", _data.date as Any), ("userId", _data.userId as Any), ("action", _data.action as Any)])
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
                return Api.ChannelAdminLogEvent.channelAdminLogEvent(Cons_channelAdminLogEvent(id: _1!, date: _2!, userId: _3!, action: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum ChannelAdminLogEventAction: TypeConstructorDescription {
        public class Cons_channelAdminLogEventActionChangeAbout: TypeConstructorDescription {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeAbout", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeAvailableReactions: TypeConstructorDescription {
            public var prevValue: Api.ChatReactions
            public var newValue: Api.ChatReactions
            public init(prevValue: Api.ChatReactions, newValue: Api.ChatReactions) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeAvailableReactions", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeEmojiStatus: TypeConstructorDescription {
            public var prevValue: Api.EmojiStatus
            public var newValue: Api.EmojiStatus
            public init(prevValue: Api.EmojiStatus, newValue: Api.EmojiStatus) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeEmojiStatus", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeEmojiStickerSet: TypeConstructorDescription {
            public var prevStickerset: Api.InputStickerSet
            public var newStickerset: Api.InputStickerSet
            public init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
                self.prevStickerset = prevStickerset
                self.newStickerset = newStickerset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeEmojiStickerSet", [("prevStickerset", self.prevStickerset as Any), ("newStickerset", self.newStickerset as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeHistoryTTL: TypeConstructorDescription {
            public var prevValue: Int32
            public var newValue: Int32
            public init(prevValue: Int32, newValue: Int32) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeHistoryTTL", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeLinkedChat: TypeConstructorDescription {
            public var prevValue: Int64
            public var newValue: Int64
            public init(prevValue: Int64, newValue: Int64) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeLinkedChat", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeLocation: TypeConstructorDescription {
            public var prevValue: Api.ChannelLocation
            public var newValue: Api.ChannelLocation
            public init(prevValue: Api.ChannelLocation, newValue: Api.ChannelLocation) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeLocation", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangePeerColor: TypeConstructorDescription {
            public var prevValue: Api.PeerColor
            public var newValue: Api.PeerColor
            public init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangePeerColor", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangePhoto: TypeConstructorDescription {
            public var prevPhoto: Api.Photo
            public var newPhoto: Api.Photo
            public init(prevPhoto: Api.Photo, newPhoto: Api.Photo) {
                self.prevPhoto = prevPhoto
                self.newPhoto = newPhoto
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangePhoto", [("prevPhoto", self.prevPhoto as Any), ("newPhoto", self.newPhoto as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeProfilePeerColor: TypeConstructorDescription {
            public var prevValue: Api.PeerColor
            public var newValue: Api.PeerColor
            public init(prevValue: Api.PeerColor, newValue: Api.PeerColor) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeProfilePeerColor", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeStickerSet: TypeConstructorDescription {
            public var prevStickerset: Api.InputStickerSet
            public var newStickerset: Api.InputStickerSet
            public init(prevStickerset: Api.InputStickerSet, newStickerset: Api.InputStickerSet) {
                self.prevStickerset = prevStickerset
                self.newStickerset = newStickerset
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeStickerSet", [("prevStickerset", self.prevStickerset as Any), ("newStickerset", self.newStickerset as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeTitle: TypeConstructorDescription {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeTitle", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeUsername: TypeConstructorDescription {
            public var prevValue: String
            public var newValue: String
            public init(prevValue: String, newValue: String) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeUsername", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeUsernames: TypeConstructorDescription {
            public var prevValue: [String]
            public var newValue: [String]
            public init(prevValue: [String], newValue: [String]) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeUsernames", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionChangeWallpaper: TypeConstructorDescription {
            public var prevValue: Api.WallPaper
            public var newValue: Api.WallPaper
            public init(prevValue: Api.WallPaper, newValue: Api.WallPaper) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionChangeWallpaper", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionCreateTopic: TypeConstructorDescription {
            public var topic: Api.ForumTopic
            public init(topic: Api.ForumTopic) {
                self.topic = topic
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionCreateTopic", [("topic", self.topic as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionDefaultBannedRights: TypeConstructorDescription {
            public var prevBannedRights: Api.ChatBannedRights
            public var newBannedRights: Api.ChatBannedRights
            public init(prevBannedRights: Api.ChatBannedRights, newBannedRights: Api.ChatBannedRights) {
                self.prevBannedRights = prevBannedRights
                self.newBannedRights = newBannedRights
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionDefaultBannedRights", [("prevBannedRights", self.prevBannedRights as Any), ("newBannedRights", self.newBannedRights as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionDeleteMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionDeleteMessage", [("message", self.message as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionDeleteTopic: TypeConstructorDescription {
            public var topic: Api.ForumTopic
            public init(topic: Api.ForumTopic) {
                self.topic = topic
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionDeleteTopic", [("topic", self.topic as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionDiscardGroupCall: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public init(call: Api.InputGroupCall) {
                self.call = call
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionDiscardGroupCall", [("call", self.call as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionEditMessage: TypeConstructorDescription {
            public var prevMessage: Api.Message
            public var newMessage: Api.Message
            public init(prevMessage: Api.Message, newMessage: Api.Message) {
                self.prevMessage = prevMessage
                self.newMessage = newMessage
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionEditMessage", [("prevMessage", self.prevMessage as Any), ("newMessage", self.newMessage as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionEditTopic: TypeConstructorDescription {
            public var prevTopic: Api.ForumTopic
            public var newTopic: Api.ForumTopic
            public init(prevTopic: Api.ForumTopic, newTopic: Api.ForumTopic) {
                self.prevTopic = prevTopic
                self.newTopic = newTopic
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionEditTopic", [("prevTopic", self.prevTopic as Any), ("newTopic", self.newTopic as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteDelete: TypeConstructorDescription {
            public var invite: Api.ExportedChatInvite
            public init(invite: Api.ExportedChatInvite) {
                self.invite = invite
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionExportedInviteDelete", [("invite", self.invite as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteEdit: TypeConstructorDescription {
            public var prevInvite: Api.ExportedChatInvite
            public var newInvite: Api.ExportedChatInvite
            public init(prevInvite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite) {
                self.prevInvite = prevInvite
                self.newInvite = newInvite
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionExportedInviteEdit", [("prevInvite", self.prevInvite as Any), ("newInvite", self.newInvite as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionExportedInviteRevoke: TypeConstructorDescription {
            public var invite: Api.ExportedChatInvite
            public init(invite: Api.ExportedChatInvite) {
                self.invite = invite
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionExportedInviteRevoke", [("invite", self.invite as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantEditRank: TypeConstructorDescription {
            public var userId: Int64
            public var prevRank: String
            public var newRank: String
            public init(userId: Int64, prevRank: String, newRank: String) {
                self.userId = userId
                self.prevRank = prevRank
                self.newRank = newRank
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantEditRank", [("userId", self.userId as Any), ("prevRank", self.prevRank as Any), ("newRank", self.newRank as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantInvite: TypeConstructorDescription {
            public var participant: Api.ChannelParticipant
            public init(participant: Api.ChannelParticipant) {
                self.participant = participant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantInvite", [("participant", self.participant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantJoinByInvite: TypeConstructorDescription {
            public var flags: Int32
            public var invite: Api.ExportedChatInvite
            public init(flags: Int32, invite: Api.ExportedChatInvite) {
                self.flags = flags
                self.invite = invite
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantJoinByInvite", [("flags", self.flags as Any), ("invite", self.invite as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantJoinByRequest: TypeConstructorDescription {
            public var invite: Api.ExportedChatInvite
            public var approvedBy: Int64
            public init(invite: Api.ExportedChatInvite, approvedBy: Int64) {
                self.invite = invite
                self.approvedBy = approvedBy
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantJoinByRequest", [("invite", self.invite as Any), ("approvedBy", self.approvedBy as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantMute: TypeConstructorDescription {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantMute", [("participant", self.participant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantSubExtend: TypeConstructorDescription {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantSubExtend", [("prevParticipant", self.prevParticipant as Any), ("newParticipant", self.newParticipant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantToggleAdmin: TypeConstructorDescription {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantToggleAdmin", [("prevParticipant", self.prevParticipant as Any), ("newParticipant", self.newParticipant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantToggleBan: TypeConstructorDescription {
            public var prevParticipant: Api.ChannelParticipant
            public var newParticipant: Api.ChannelParticipant
            public init(prevParticipant: Api.ChannelParticipant, newParticipant: Api.ChannelParticipant) {
                self.prevParticipant = prevParticipant
                self.newParticipant = newParticipant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantToggleBan", [("prevParticipant", self.prevParticipant as Any), ("newParticipant", self.newParticipant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantUnmute: TypeConstructorDescription {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantUnmute", [("participant", self.participant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionParticipantVolume: TypeConstructorDescription {
            public var participant: Api.GroupCallParticipant
            public init(participant: Api.GroupCallParticipant) {
                self.participant = participant
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionParticipantVolume", [("participant", self.participant as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionPinTopic: TypeConstructorDescription {
            public var flags: Int32
            public var prevTopic: Api.ForumTopic?
            public var newTopic: Api.ForumTopic?
            public init(flags: Int32, prevTopic: Api.ForumTopic?, newTopic: Api.ForumTopic?) {
                self.flags = flags
                self.prevTopic = prevTopic
                self.newTopic = newTopic
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionPinTopic", [("flags", self.flags as Any), ("prevTopic", self.prevTopic as Any), ("newTopic", self.newTopic as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionSendMessage: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionSendMessage", [("message", self.message as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionStartGroupCall: TypeConstructorDescription {
            public var call: Api.InputGroupCall
            public init(call: Api.InputGroupCall) {
                self.call = call
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionStartGroupCall", [("call", self.call as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionStopPoll: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionStopPoll", [("message", self.message as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleAntiSpam: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleAntiSpam", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleAutotranslation: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleAutotranslation", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleForum: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleForum", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleGroupCallSetting: TypeConstructorDescription {
            public var joinMuted: Api.Bool
            public init(joinMuted: Api.Bool) {
                self.joinMuted = joinMuted
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleGroupCallSetting", [("joinMuted", self.joinMuted as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleInvites: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleInvites", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleNoForwards: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleNoForwards", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionTogglePreHistoryHidden: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionTogglePreHistoryHidden", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleSignatureProfiles: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleSignatureProfiles", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleSignatures: TypeConstructorDescription {
            public var newValue: Api.Bool
            public init(newValue: Api.Bool) {
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleSignatures", [("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionToggleSlowMode: TypeConstructorDescription {
            public var prevValue: Int32
            public var newValue: Int32
            public init(prevValue: Int32, newValue: Int32) {
                self.prevValue = prevValue
                self.newValue = newValue
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionToggleSlowMode", [("prevValue", self.prevValue as Any), ("newValue", self.newValue as Any)])
            }
        }
        public class Cons_channelAdminLogEventActionUpdatePinned: TypeConstructorDescription {
            public var message: Api.Message
            public init(message: Api.Message) {
                self.message = message
            }
            public func descriptionFields() -> (String, [(String, Any)]) {
                return ("channelAdminLogEventActionUpdatePinned", [("message", self.message as Any)])
            }
        }
        case channelAdminLogEventActionChangeAbout(Cons_channelAdminLogEventActionChangeAbout)
        case channelAdminLogEventActionChangeAvailableReactions(Cons_channelAdminLogEventActionChangeAvailableReactions)
        case channelAdminLogEventActionChangeEmojiStatus(Cons_channelAdminLogEventActionChangeEmojiStatus)
        case channelAdminLogEventActionChangeEmojiStickerSet(Cons_channelAdminLogEventActionChangeEmojiStickerSet)
        case channelAdminLogEventActionChangeHistoryTTL(Cons_channelAdminLogEventActionChangeHistoryTTL)
        case channelAdminLogEventActionChangeLinkedChat(Cons_channelAdminLogEventActionChangeLinkedChat)
        case channelAdminLogEventActionChangeLocation(Cons_channelAdminLogEventActionChangeLocation)
        case channelAdminLogEventActionChangePeerColor(Cons_channelAdminLogEventActionChangePeerColor)
        case channelAdminLogEventActionChangePhoto(Cons_channelAdminLogEventActionChangePhoto)
        case channelAdminLogEventActionChangeProfilePeerColor(Cons_channelAdminLogEventActionChangeProfilePeerColor)
        case channelAdminLogEventActionChangeStickerSet(Cons_channelAdminLogEventActionChangeStickerSet)
        case channelAdminLogEventActionChangeTitle(Cons_channelAdminLogEventActionChangeTitle)
        case channelAdminLogEventActionChangeUsername(Cons_channelAdminLogEventActionChangeUsername)
        case channelAdminLogEventActionChangeUsernames(Cons_channelAdminLogEventActionChangeUsernames)
        case channelAdminLogEventActionChangeWallpaper(Cons_channelAdminLogEventActionChangeWallpaper)
        case channelAdminLogEventActionCreateTopic(Cons_channelAdminLogEventActionCreateTopic)
        case channelAdminLogEventActionDefaultBannedRights(Cons_channelAdminLogEventActionDefaultBannedRights)
        case channelAdminLogEventActionDeleteMessage(Cons_channelAdminLogEventActionDeleteMessage)
        case channelAdminLogEventActionDeleteTopic(Cons_channelAdminLogEventActionDeleteTopic)
        case channelAdminLogEventActionDiscardGroupCall(Cons_channelAdminLogEventActionDiscardGroupCall)
        case channelAdminLogEventActionEditMessage(Cons_channelAdminLogEventActionEditMessage)
        case channelAdminLogEventActionEditTopic(Cons_channelAdminLogEventActionEditTopic)
        case channelAdminLogEventActionExportedInviteDelete(Cons_channelAdminLogEventActionExportedInviteDelete)
        case channelAdminLogEventActionExportedInviteEdit(Cons_channelAdminLogEventActionExportedInviteEdit)
        case channelAdminLogEventActionExportedInviteRevoke(Cons_channelAdminLogEventActionExportedInviteRevoke)
        case channelAdminLogEventActionParticipantEditRank(Cons_channelAdminLogEventActionParticipantEditRank)
        case channelAdminLogEventActionParticipantInvite(Cons_channelAdminLogEventActionParticipantInvite)
        case channelAdminLogEventActionParticipantJoin
        case channelAdminLogEventActionParticipantJoinByInvite(Cons_channelAdminLogEventActionParticipantJoinByInvite)
        case channelAdminLogEventActionParticipantJoinByRequest(Cons_channelAdminLogEventActionParticipantJoinByRequest)
        case channelAdminLogEventActionParticipantLeave
        case channelAdminLogEventActionParticipantMute(Cons_channelAdminLogEventActionParticipantMute)
        case channelAdminLogEventActionParticipantSubExtend(Cons_channelAdminLogEventActionParticipantSubExtend)
        case channelAdminLogEventActionParticipantToggleAdmin(Cons_channelAdminLogEventActionParticipantToggleAdmin)
        case channelAdminLogEventActionParticipantToggleBan(Cons_channelAdminLogEventActionParticipantToggleBan)
        case channelAdminLogEventActionParticipantUnmute(Cons_channelAdminLogEventActionParticipantUnmute)
        case channelAdminLogEventActionParticipantVolume(Cons_channelAdminLogEventActionParticipantVolume)
        case channelAdminLogEventActionPinTopic(Cons_channelAdminLogEventActionPinTopic)
        case channelAdminLogEventActionSendMessage(Cons_channelAdminLogEventActionSendMessage)
        case channelAdminLogEventActionStartGroupCall(Cons_channelAdminLogEventActionStartGroupCall)
        case channelAdminLogEventActionStopPoll(Cons_channelAdminLogEventActionStopPoll)
        case channelAdminLogEventActionToggleAntiSpam(Cons_channelAdminLogEventActionToggleAntiSpam)
        case channelAdminLogEventActionToggleAutotranslation(Cons_channelAdminLogEventActionToggleAutotranslation)
        case channelAdminLogEventActionToggleForum(Cons_channelAdminLogEventActionToggleForum)
        case channelAdminLogEventActionToggleGroupCallSetting(Cons_channelAdminLogEventActionToggleGroupCallSetting)
        case channelAdminLogEventActionToggleInvites(Cons_channelAdminLogEventActionToggleInvites)
        case channelAdminLogEventActionToggleNoForwards(Cons_channelAdminLogEventActionToggleNoForwards)
        case channelAdminLogEventActionTogglePreHistoryHidden(Cons_channelAdminLogEventActionTogglePreHistoryHidden)
        case channelAdminLogEventActionToggleSignatureProfiles(Cons_channelAdminLogEventActionToggleSignatureProfiles)
        case channelAdminLogEventActionToggleSignatures(Cons_channelAdminLogEventActionToggleSignatures)
        case channelAdminLogEventActionToggleSlowMode(Cons_channelAdminLogEventActionToggleSlowMode)
        case channelAdminLogEventActionUpdatePinned(Cons_channelAdminLogEventActionUpdatePinned)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelAdminLogEventActionChangeAbout(let _data):
                if boxed {
                    buffer.appendInt32(1427671598)
                }
                serializeString(_data.prevValue, buffer: buffer, boxed: false)
                serializeString(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionChangeAvailableReactions(let _data):
                if boxed {
                    buffer.appendInt32(-1102180616)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeEmojiStatus(let _data):
                if boxed {
                    buffer.appendInt32(1051328177)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeEmojiStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(1188577451)
                }
                _data.prevStickerset.serialize(buffer, true)
                _data.newStickerset.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeHistoryTTL(let _data):
                if boxed {
                    buffer.appendInt32(1855199800)
                }
                serializeInt32(_data.prevValue, buffer: buffer, boxed: false)
                serializeInt32(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionChangeLinkedChat(let _data):
                if boxed {
                    buffer.appendInt32(84703944)
                }
                serializeInt64(_data.prevValue, buffer: buffer, boxed: false)
                serializeInt64(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionChangeLocation(let _data):
                if boxed {
                    buffer.appendInt32(241923758)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangePeerColor(let _data):
                if boxed {
                    buffer.appendInt32(1469507456)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangePhoto(let _data):
                if boxed {
                    buffer.appendInt32(1129042607)
                }
                _data.prevPhoto.serialize(buffer, true)
                _data.newPhoto.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeProfilePeerColor(let _data):
                if boxed {
                    buffer.appendInt32(1581742885)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeStickerSet(let _data):
                if boxed {
                    buffer.appendInt32(-1312568665)
                }
                _data.prevStickerset.serialize(buffer, true)
                _data.newStickerset.serialize(buffer, true)
                break
            case .channelAdminLogEventActionChangeTitle(let _data):
                if boxed {
                    buffer.appendInt32(-421545947)
                }
                serializeString(_data.prevValue, buffer: buffer, boxed: false)
                serializeString(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionChangeUsername(let _data):
                if boxed {
                    buffer.appendInt32(1783299128)
                }
                serializeString(_data.prevValue, buffer: buffer, boxed: false)
                serializeString(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionChangeUsernames(let _data):
                if boxed {
                    buffer.appendInt32(-263212119)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prevValue.count))
                for item in _data.prevValue {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newValue.count))
                for item in _data.newValue {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            case .channelAdminLogEventActionChangeWallpaper(let _data):
                if boxed {
                    buffer.appendInt32(834362706)
                }
                _data.prevValue.serialize(buffer, true)
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionCreateTopic(let _data):
                if boxed {
                    buffer.appendInt32(1483767080)
                }
                _data.topic.serialize(buffer, true)
                break
            case .channelAdminLogEventActionDefaultBannedRights(let _data):
                if boxed {
                    buffer.appendInt32(771095562)
                }
                _data.prevBannedRights.serialize(buffer, true)
                _data.newBannedRights.serialize(buffer, true)
                break
            case .channelAdminLogEventActionDeleteMessage(let _data):
                if boxed {
                    buffer.appendInt32(1121994683)
                }
                _data.message.serialize(buffer, true)
                break
            case .channelAdminLogEventActionDeleteTopic(let _data):
                if boxed {
                    buffer.appendInt32(-1374254839)
                }
                _data.topic.serialize(buffer, true)
                break
            case .channelAdminLogEventActionDiscardGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(-610299584)
                }
                _data.call.serialize(buffer, true)
                break
            case .channelAdminLogEventActionEditMessage(let _data):
                if boxed {
                    buffer.appendInt32(1889215493)
                }
                _data.prevMessage.serialize(buffer, true)
                _data.newMessage.serialize(buffer, true)
                break
            case .channelAdminLogEventActionEditTopic(let _data):
                if boxed {
                    buffer.appendInt32(-261103096)
                }
                _data.prevTopic.serialize(buffer, true)
                _data.newTopic.serialize(buffer, true)
                break
            case .channelAdminLogEventActionExportedInviteDelete(let _data):
                if boxed {
                    buffer.appendInt32(1515256996)
                }
                _data.invite.serialize(buffer, true)
                break
            case .channelAdminLogEventActionExportedInviteEdit(let _data):
                if boxed {
                    buffer.appendInt32(-384910503)
                }
                _data.prevInvite.serialize(buffer, true)
                _data.newInvite.serialize(buffer, true)
                break
            case .channelAdminLogEventActionExportedInviteRevoke(let _data):
                if boxed {
                    buffer.appendInt32(1091179342)
                }
                _data.invite.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantEditRank(let _data):
                if boxed {
                    buffer.appendInt32(1476834540)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeString(_data.prevRank, buffer: buffer, boxed: false)
                serializeString(_data.newRank, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionParticipantInvite(let _data):
                if boxed {
                    buffer.appendInt32(-484690728)
                }
                _data.participant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantJoin:
                if boxed {
                    buffer.appendInt32(405815507)
                }
                break
            case .channelAdminLogEventActionParticipantJoinByInvite(let _data):
                if boxed {
                    buffer.appendInt32(-23084712)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.invite.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantJoinByRequest(let _data):
                if boxed {
                    buffer.appendInt32(-1347021750)
                }
                _data.invite.serialize(buffer, true)
                serializeInt64(_data.approvedBy, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionParticipantLeave:
                if boxed {
                    buffer.appendInt32(-124291086)
                }
                break
            case .channelAdminLogEventActionParticipantMute(let _data):
                if boxed {
                    buffer.appendInt32(-115071790)
                }
                _data.participant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantSubExtend(let _data):
                if boxed {
                    buffer.appendInt32(1684286899)
                }
                _data.prevParticipant.serialize(buffer, true)
                _data.newParticipant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantToggleAdmin(let _data):
                if boxed {
                    buffer.appendInt32(-714643696)
                }
                _data.prevParticipant.serialize(buffer, true)
                _data.newParticipant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantToggleBan(let _data):
                if boxed {
                    buffer.appendInt32(-422036098)
                }
                _data.prevParticipant.serialize(buffer, true)
                _data.newParticipant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantUnmute(let _data):
                if boxed {
                    buffer.appendInt32(-431740480)
                }
                _data.participant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionParticipantVolume(let _data):
                if boxed {
                    buffer.appendInt32(1048537159)
                }
                _data.participant.serialize(buffer, true)
                break
            case .channelAdminLogEventActionPinTopic(let _data):
                if boxed {
                    buffer.appendInt32(1569535291)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.prevTopic!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.newTopic!.serialize(buffer, true)
                }
                break
            case .channelAdminLogEventActionSendMessage(let _data):
                if boxed {
                    buffer.appendInt32(663693416)
                }
                _data.message.serialize(buffer, true)
                break
            case .channelAdminLogEventActionStartGroupCall(let _data):
                if boxed {
                    buffer.appendInt32(589338437)
                }
                _data.call.serialize(buffer, true)
                break
            case .channelAdminLogEventActionStopPoll(let _data):
                if boxed {
                    buffer.appendInt32(-1895328189)
                }
                _data.message.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleAntiSpam(let _data):
                if boxed {
                    buffer.appendInt32(1693675004)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleAutotranslation(let _data):
                if boxed {
                    buffer.appendInt32(-988285058)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleForum(let _data):
                if boxed {
                    buffer.appendInt32(46949251)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleGroupCallSetting(let _data):
                if boxed {
                    buffer.appendInt32(1456906823)
                }
                _data.joinMuted.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleInvites(let _data):
                if boxed {
                    buffer.appendInt32(460916654)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleNoForwards(let _data):
                if boxed {
                    buffer.appendInt32(-886388890)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionTogglePreHistoryHidden(let _data):
                if boxed {
                    buffer.appendInt32(1599903217)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleSignatureProfiles(let _data):
                if boxed {
                    buffer.appendInt32(1621597305)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleSignatures(let _data):
                if boxed {
                    buffer.appendInt32(648939889)
                }
                _data.newValue.serialize(buffer, true)
                break
            case .channelAdminLogEventActionToggleSlowMode(let _data):
                if boxed {
                    buffer.appendInt32(1401984889)
                }
                serializeInt32(_data.prevValue, buffer: buffer, boxed: false)
                serializeInt32(_data.newValue, buffer: buffer, boxed: false)
                break
            case .channelAdminLogEventActionUpdatePinned(let _data):
                if boxed {
                    buffer.appendInt32(-370660328)
                }
                _data.message.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelAdminLogEventActionChangeAbout(let _data):
                return ("channelAdminLogEventActionChangeAbout", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeAvailableReactions(let _data):
                return ("channelAdminLogEventActionChangeAvailableReactions", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeEmojiStatus(let _data):
                return ("channelAdminLogEventActionChangeEmojiStatus", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeEmojiStickerSet(let _data):
                return ("channelAdminLogEventActionChangeEmojiStickerSet", [("prevStickerset", _data.prevStickerset as Any), ("newStickerset", _data.newStickerset as Any)])
            case .channelAdminLogEventActionChangeHistoryTTL(let _data):
                return ("channelAdminLogEventActionChangeHistoryTTL", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeLinkedChat(let _data):
                return ("channelAdminLogEventActionChangeLinkedChat", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeLocation(let _data):
                return ("channelAdminLogEventActionChangeLocation", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangePeerColor(let _data):
                return ("channelAdminLogEventActionChangePeerColor", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangePhoto(let _data):
                return ("channelAdminLogEventActionChangePhoto", [("prevPhoto", _data.prevPhoto as Any), ("newPhoto", _data.newPhoto as Any)])
            case .channelAdminLogEventActionChangeProfilePeerColor(let _data):
                return ("channelAdminLogEventActionChangeProfilePeerColor", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeStickerSet(let _data):
                return ("channelAdminLogEventActionChangeStickerSet", [("prevStickerset", _data.prevStickerset as Any), ("newStickerset", _data.newStickerset as Any)])
            case .channelAdminLogEventActionChangeTitle(let _data):
                return ("channelAdminLogEventActionChangeTitle", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeUsername(let _data):
                return ("channelAdminLogEventActionChangeUsername", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeUsernames(let _data):
                return ("channelAdminLogEventActionChangeUsernames", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionChangeWallpaper(let _data):
                return ("channelAdminLogEventActionChangeWallpaper", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionCreateTopic(let _data):
                return ("channelAdminLogEventActionCreateTopic", [("topic", _data.topic as Any)])
            case .channelAdminLogEventActionDefaultBannedRights(let _data):
                return ("channelAdminLogEventActionDefaultBannedRights", [("prevBannedRights", _data.prevBannedRights as Any), ("newBannedRights", _data.newBannedRights as Any)])
            case .channelAdminLogEventActionDeleteMessage(let _data):
                return ("channelAdminLogEventActionDeleteMessage", [("message", _data.message as Any)])
            case .channelAdminLogEventActionDeleteTopic(let _data):
                return ("channelAdminLogEventActionDeleteTopic", [("topic", _data.topic as Any)])
            case .channelAdminLogEventActionDiscardGroupCall(let _data):
                return ("channelAdminLogEventActionDiscardGroupCall", [("call", _data.call as Any)])
            case .channelAdminLogEventActionEditMessage(let _data):
                return ("channelAdminLogEventActionEditMessage", [("prevMessage", _data.prevMessage as Any), ("newMessage", _data.newMessage as Any)])
            case .channelAdminLogEventActionEditTopic(let _data):
                return ("channelAdminLogEventActionEditTopic", [("prevTopic", _data.prevTopic as Any), ("newTopic", _data.newTopic as Any)])
            case .channelAdminLogEventActionExportedInviteDelete(let _data):
                return ("channelAdminLogEventActionExportedInviteDelete", [("invite", _data.invite as Any)])
            case .channelAdminLogEventActionExportedInviteEdit(let _data):
                return ("channelAdminLogEventActionExportedInviteEdit", [("prevInvite", _data.prevInvite as Any), ("newInvite", _data.newInvite as Any)])
            case .channelAdminLogEventActionExportedInviteRevoke(let _data):
                return ("channelAdminLogEventActionExportedInviteRevoke", [("invite", _data.invite as Any)])
            case .channelAdminLogEventActionParticipantEditRank(let _data):
                return ("channelAdminLogEventActionParticipantEditRank", [("userId", _data.userId as Any), ("prevRank", _data.prevRank as Any), ("newRank", _data.newRank as Any)])
            case .channelAdminLogEventActionParticipantInvite(let _data):
                return ("channelAdminLogEventActionParticipantInvite", [("participant", _data.participant as Any)])
            case .channelAdminLogEventActionParticipantJoin:
                return ("channelAdminLogEventActionParticipantJoin", [])
            case .channelAdminLogEventActionParticipantJoinByInvite(let _data):
                return ("channelAdminLogEventActionParticipantJoinByInvite", [("flags", _data.flags as Any), ("invite", _data.invite as Any)])
            case .channelAdminLogEventActionParticipantJoinByRequest(let _data):
                return ("channelAdminLogEventActionParticipantJoinByRequest", [("invite", _data.invite as Any), ("approvedBy", _data.approvedBy as Any)])
            case .channelAdminLogEventActionParticipantLeave:
                return ("channelAdminLogEventActionParticipantLeave", [])
            case .channelAdminLogEventActionParticipantMute(let _data):
                return ("channelAdminLogEventActionParticipantMute", [("participant", _data.participant as Any)])
            case .channelAdminLogEventActionParticipantSubExtend(let _data):
                return ("channelAdminLogEventActionParticipantSubExtend", [("prevParticipant", _data.prevParticipant as Any), ("newParticipant", _data.newParticipant as Any)])
            case .channelAdminLogEventActionParticipantToggleAdmin(let _data):
                return ("channelAdminLogEventActionParticipantToggleAdmin", [("prevParticipant", _data.prevParticipant as Any), ("newParticipant", _data.newParticipant as Any)])
            case .channelAdminLogEventActionParticipantToggleBan(let _data):
                return ("channelAdminLogEventActionParticipantToggleBan", [("prevParticipant", _data.prevParticipant as Any), ("newParticipant", _data.newParticipant as Any)])
            case .channelAdminLogEventActionParticipantUnmute(let _data):
                return ("channelAdminLogEventActionParticipantUnmute", [("participant", _data.participant as Any)])
            case .channelAdminLogEventActionParticipantVolume(let _data):
                return ("channelAdminLogEventActionParticipantVolume", [("participant", _data.participant as Any)])
            case .channelAdminLogEventActionPinTopic(let _data):
                return ("channelAdminLogEventActionPinTopic", [("flags", _data.flags as Any), ("prevTopic", _data.prevTopic as Any), ("newTopic", _data.newTopic as Any)])
            case .channelAdminLogEventActionSendMessage(let _data):
                return ("channelAdminLogEventActionSendMessage", [("message", _data.message as Any)])
            case .channelAdminLogEventActionStartGroupCall(let _data):
                return ("channelAdminLogEventActionStartGroupCall", [("call", _data.call as Any)])
            case .channelAdminLogEventActionStopPoll(let _data):
                return ("channelAdminLogEventActionStopPoll", [("message", _data.message as Any)])
            case .channelAdminLogEventActionToggleAntiSpam(let _data):
                return ("channelAdminLogEventActionToggleAntiSpam", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleAutotranslation(let _data):
                return ("channelAdminLogEventActionToggleAutotranslation", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleForum(let _data):
                return ("channelAdminLogEventActionToggleForum", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleGroupCallSetting(let _data):
                return ("channelAdminLogEventActionToggleGroupCallSetting", [("joinMuted", _data.joinMuted as Any)])
            case .channelAdminLogEventActionToggleInvites(let _data):
                return ("channelAdminLogEventActionToggleInvites", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleNoForwards(let _data):
                return ("channelAdminLogEventActionToggleNoForwards", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionTogglePreHistoryHidden(let _data):
                return ("channelAdminLogEventActionTogglePreHistoryHidden", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleSignatureProfiles(let _data):
                return ("channelAdminLogEventActionToggleSignatureProfiles", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleSignatures(let _data):
                return ("channelAdminLogEventActionToggleSignatures", [("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionToggleSlowMode(let _data):
                return ("channelAdminLogEventActionToggleSlowMode", [("prevValue", _data.prevValue as Any), ("newValue", _data.newValue as Any)])
            case .channelAdminLogEventActionUpdatePinned(let _data):
                return ("channelAdminLogEventActionUpdatePinned", [("message", _data.message as Any)])
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAbout(Cons_channelAdminLogEventActionChangeAbout(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeAvailableReactions(Cons_channelAdminLogEventActionChangeAvailableReactions(prevValue: _1!, newValue: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStatus(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            var _2: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeEmojiStatus(Cons_channelAdminLogEventActionChangeEmojiStatus(prevValue: _1!, newValue: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeEmojiStickerSet(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeEmojiStickerSet(Cons_channelAdminLogEventActionChangeEmojiStickerSet(prevStickerset: _1!, newStickerset: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeHistoryTTL(Cons_channelAdminLogEventActionChangeHistoryTTL(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLinkedChat(Cons_channelAdminLogEventActionChangeLinkedChat(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeLocation(Cons_channelAdminLogEventActionChangeLocation(prevValue: _1!, newValue: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.PeerColor?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            var _2: Api.PeerColor?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangePeerColor(Cons_channelAdminLogEventActionChangePeerColor(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangePhoto(Cons_channelAdminLogEventActionChangePhoto(prevPhoto: _1!, newPhoto: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeProfilePeerColor(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.PeerColor?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            var _2: Api.PeerColor?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerColor
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeProfilePeerColor(Cons_channelAdminLogEventActionChangeProfilePeerColor(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeStickerSet(Cons_channelAdminLogEventActionChangeStickerSet(prevStickerset: _1!, newStickerset: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeTitle(Cons_channelAdminLogEventActionChangeTitle(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsername(Cons_channelAdminLogEventActionChangeUsername(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeUsernames(Cons_channelAdminLogEventActionChangeUsernames(prevValue: _1!, newValue: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionChangeWallpaper(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.WallPaper?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            var _2: Api.WallPaper?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionChangeWallpaper(Cons_channelAdminLogEventActionChangeWallpaper(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionCreateTopic(Cons_channelAdminLogEventActionCreateTopic(topic: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDefaultBannedRights(Cons_channelAdminLogEventActionDefaultBannedRights(prevBannedRights: _1!, newBannedRights: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteMessage(Cons_channelAdminLogEventActionDeleteMessage(message: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDeleteTopic(Cons_channelAdminLogEventActionDeleteTopic(topic: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionDiscardGroupCall(Cons_channelAdminLogEventActionDiscardGroupCall(call: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditMessage(Cons_channelAdminLogEventActionEditMessage(prevMessage: _1!, newMessage: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionEditTopic(Cons_channelAdminLogEventActionEditTopic(prevTopic: _1!, newTopic: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteDelete(Cons_channelAdminLogEventActionExportedInviteDelete(invite: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteEdit(Cons_channelAdminLogEventActionExportedInviteEdit(prevInvite: _1!, newInvite: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionExportedInviteRevoke(Cons_channelAdminLogEventActionExportedInviteRevoke(invite: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantEditRank(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantEditRank(Cons_channelAdminLogEventActionParticipantEditRank(userId: _1!, prevRank: _2!, newRank: _3!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantInvite(Cons_channelAdminLogEventActionParticipantInvite(participant: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByInvite(Cons_channelAdminLogEventActionParticipantJoinByInvite(flags: _1!, invite: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantJoinByRequest(Cons_channelAdminLogEventActionParticipantJoinByRequest(invite: _1!, approvedBy: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantMute(Cons_channelAdminLogEventActionParticipantMute(participant: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionParticipantSubExtend(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantSubExtend(Cons_channelAdminLogEventActionParticipantSubExtend(prevParticipant: _1!, newParticipant: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleAdmin(Cons_channelAdminLogEventActionParticipantToggleAdmin(prevParticipant: _1!, newParticipant: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantToggleBan(Cons_channelAdminLogEventActionParticipantToggleBan(prevParticipant: _1!, newParticipant: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantUnmute(Cons_channelAdminLogEventActionParticipantUnmute(participant: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionParticipantVolume(Cons_channelAdminLogEventActionParticipantVolume(participant: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionPinTopic(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.ForumTopic?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.ForumTopic
                }
            }
            var _3: Api.ForumTopic?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.ForumTopic
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionPinTopic(Cons_channelAdminLogEventActionPinTopic(flags: _1!, prevTopic: _2, newTopic: _3))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionSendMessage(Cons_channelAdminLogEventActionSendMessage(message: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStartGroupCall(Cons_channelAdminLogEventActionStartGroupCall(call: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionStopPoll(Cons_channelAdminLogEventActionStopPoll(message: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleAntiSpam(Cons_channelAdminLogEventActionToggleAntiSpam(newValue: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleAutotranslation(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleAutotranslation(Cons_channelAdminLogEventActionToggleAutotranslation(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleForum(Cons_channelAdminLogEventActionToggleForum(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleGroupCallSetting(Cons_channelAdminLogEventActionToggleGroupCallSetting(joinMuted: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleInvites(Cons_channelAdminLogEventActionToggleInvites(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleNoForwards(Cons_channelAdminLogEventActionToggleNoForwards(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionTogglePreHistoryHidden(Cons_channelAdminLogEventActionTogglePreHistoryHidden(newValue: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelAdminLogEventActionToggleSignatureProfiles(_ reader: BufferReader) -> ChannelAdminLogEventAction? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSignatureProfiles(Cons_channelAdminLogEventActionToggleSignatureProfiles(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSignatures(Cons_channelAdminLogEventActionToggleSignatures(newValue: _1!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionToggleSlowMode(Cons_channelAdminLogEventActionToggleSlowMode(prevValue: _1!, newValue: _2!))
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
                return Api.ChannelAdminLogEventAction.channelAdminLogEventActionUpdatePinned(Cons_channelAdminLogEventActionUpdatePinned(message: _1!))
            }
            else {
                return nil
            }
        }
    }
}
