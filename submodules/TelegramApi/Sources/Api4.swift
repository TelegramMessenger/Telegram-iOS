public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        public class Cons_channelAdminLogEventsFilter {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case channelAdminLogEventsFilter(Cons_channelAdminLogEventsFilter)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelAdminLogEventsFilter(let _data):
                if boxed {
                    buffer.appendInt32(-368018716)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelAdminLogEventsFilter(let _data):
                return ("channelAdminLogEventsFilter", [("flags", _data.flags as Any)])
            }
        }

        public static func parse_channelAdminLogEventsFilter(_ reader: BufferReader) -> ChannelAdminLogEventsFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventsFilter.channelAdminLogEventsFilter(Cons_channelAdminLogEventsFilter(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChannelLocation: TypeConstructorDescription {
        public class Cons_channelLocation {
            public var geoPoint: Api.GeoPoint
            public var address: String
            public init(geoPoint: Api.GeoPoint, address: String) {
                self.geoPoint = geoPoint
                self.address = address
            }
        }
        case channelLocation(Cons_channelLocation)
        case channelLocationEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelLocation(let _data):
                if boxed {
                    buffer.appendInt32(547062491)
                }
                _data.geoPoint.serialize(buffer, true)
                serializeString(_data.address, buffer: buffer, boxed: false)
                break
            case .channelLocationEmpty:
                if boxed {
                    buffer.appendInt32(-1078612597)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelLocation(let _data):
                return ("channelLocation", [("geoPoint", _data.geoPoint as Any), ("address", _data.address as Any)])
            case .channelLocationEmpty:
                return ("channelLocationEmpty", [])
            }
        }

        public static func parse_channelLocation(_ reader: BufferReader) -> ChannelLocation? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelLocation.channelLocation(Cons_channelLocation(geoPoint: _1!, address: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelLocationEmpty(_ reader: BufferReader) -> ChannelLocation? {
            return Api.ChannelLocation.channelLocationEmpty
        }
    }
}
public extension Api {
    enum ChannelMessagesFilter: TypeConstructorDescription {
        public class Cons_channelMessagesFilter {
            public var flags: Int32
            public var ranges: [Api.MessageRange]
            public init(flags: Int32, ranges: [Api.MessageRange]) {
                self.flags = flags
                self.ranges = ranges
            }
        }
        case channelMessagesFilter(Cons_channelMessagesFilter)
        case channelMessagesFilterEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelMessagesFilter(let _data):
                if boxed {
                    buffer.appendInt32(-847783593)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.ranges.count))
                for item in _data.ranges {
                    item.serialize(buffer, true)
                }
                break
            case .channelMessagesFilterEmpty:
                if boxed {
                    buffer.appendInt32(-1798033689)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelMessagesFilter(let _data):
                return ("channelMessagesFilter", [("flags", _data.flags as Any), ("ranges", _data.ranges as Any)])
            case .channelMessagesFilterEmpty:
                return ("channelMessagesFilterEmpty", [])
            }
        }

        public static func parse_channelMessagesFilter(_ reader: BufferReader) -> ChannelMessagesFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.MessageRange]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageRange.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChannelMessagesFilter.channelMessagesFilter(Cons_channelMessagesFilter(flags: _1!, ranges: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelMessagesFilterEmpty(_ reader: BufferReader) -> ChannelMessagesFilter? {
            return Api.ChannelMessagesFilter.channelMessagesFilterEmpty
        }
    }
}
public extension Api {
    enum ChannelParticipant: TypeConstructorDescription {
        public class Cons_channelParticipant {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        public class Cons_channelParticipantAdmin {
            public var flags: Int32
            public var userId: Int64
            public var inviterId: Int64?
            public var promotedBy: Int64
            public var date: Int32
            public var adminRights: Api.ChatAdminRights
            public var rank: String?
            public init(flags: Int32, userId: Int64, inviterId: Int64?, promotedBy: Int64, date: Int32, adminRights: Api.ChatAdminRights, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.inviterId = inviterId
                self.promotedBy = promotedBy
                self.date = date
                self.adminRights = adminRights
                self.rank = rank
            }
        }
        public class Cons_channelParticipantBanned {
            public var flags: Int32
            public var peer: Api.Peer
            public var kickedBy: Int64
            public var date: Int32
            public var bannedRights: Api.ChatBannedRights
            public init(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights) {
                self.flags = flags
                self.peer = peer
                self.kickedBy = kickedBy
                self.date = date
                self.bannedRights = bannedRights
            }
        }
        public class Cons_channelParticipantCreator {
            public var flags: Int32
            public var userId: Int64
            public var adminRights: Api.ChatAdminRights
            public var rank: String?
            public init(flags: Int32, userId: Int64, adminRights: Api.ChatAdminRights, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.adminRights = adminRights
                self.rank = rank
            }
        }
        public class Cons_channelParticipantLeft {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
        }
        public class Cons_channelParticipantSelf {
            public var flags: Int32
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?) {
                self.flags = flags
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
            }
        }
        case channelParticipant(Cons_channelParticipant)
        case channelParticipantAdmin(Cons_channelParticipantAdmin)
        case channelParticipantBanned(Cons_channelParticipantBanned)
        case channelParticipantCreator(Cons_channelParticipantCreator)
        case channelParticipantLeft(Cons_channelParticipantLeft)
        case channelParticipantSelf(Cons_channelParticipantSelf)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelParticipant(let _data):
                if boxed {
                    buffer.appendInt32(-885426663)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                break
            case .channelParticipantAdmin(let _data):
                if boxed {
                    buffer.appendInt32(885242707)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.inviterId!, buffer: buffer, boxed: false)
                }
                serializeInt64(_data.promotedBy, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.adminRights.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.rank!, buffer: buffer, boxed: false)
                }
                break
            case .channelParticipantBanned(let _data):
                if boxed {
                    buffer.appendInt32(1844969806)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.kickedBy, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.bannedRights.serialize(buffer, true)
                break
            case .channelParticipantCreator(let _data):
                if boxed {
                    buffer.appendInt32(803602899)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                _data.adminRights.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.rank!, buffer: buffer, boxed: false)
                }
                break
            case .channelParticipantLeft(let _data):
                if boxed {
                    buffer.appendInt32(453242886)
                }
                _data.peer.serialize(buffer, true)
                break
            case .channelParticipantSelf(let _data):
                if boxed {
                    buffer.appendInt32(1331723247)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelParticipant(let _data):
                return ("channelParticipant", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("date", _data.date as Any), ("subscriptionUntilDate", _data.subscriptionUntilDate as Any)])
            case .channelParticipantAdmin(let _data):
                return ("channelParticipantAdmin", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("inviterId", _data.inviterId as Any), ("promotedBy", _data.promotedBy as Any), ("date", _data.date as Any), ("adminRights", _data.adminRights as Any), ("rank", _data.rank as Any)])
            case .channelParticipantBanned(let _data):
                return ("channelParticipantBanned", [("flags", _data.flags as Any), ("peer", _data.peer as Any), ("kickedBy", _data.kickedBy as Any), ("date", _data.date as Any), ("bannedRights", _data.bannedRights as Any)])
            case .channelParticipantCreator(let _data):
                return ("channelParticipantCreator", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("adminRights", _data.adminRights as Any), ("rank", _data.rank as Any)])
            case .channelParticipantLeft(let _data):
                return ("channelParticipantLeft", [("peer", _data.peer as Any)])
            case .channelParticipantSelf(let _data):
                return ("channelParticipantSelf", [("flags", _data.flags as Any), ("userId", _data.userId as Any), ("inviterId", _data.inviterId as Any), ("date", _data.date as Any), ("subscriptionUntilDate", _data.subscriptionUntilDate as Any)])
            }
        }

        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelParticipant.channelParticipant(Cons_channelParticipant(flags: _1!, userId: _2!, date: _3!, subscriptionUntilDate: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantAdmin(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt64()
            }
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.ChatAdminRights?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _7 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.ChannelParticipant.channelParticipantAdmin(Cons_channelParticipantAdmin(flags: _1!, userId: _2!, inviterId: _3, promotedBy: _4!, date: _5!, adminRights: _6!, rank: _7))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantBanned(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChannelParticipant.channelParticipantBanned(Cons_channelParticipantBanned(flags: _1!, peer: _2!, kickedBy: _3!, date: _4!, bannedRights: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantCreator(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.ChatAdminRights?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelParticipant.channelParticipantCreator(Cons_channelParticipantCreator(flags: _1!, userId: _2!, adminRights: _3!, rank: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantLeft(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipant.channelParticipantLeft(Cons_channelParticipantLeft(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantSelf(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChannelParticipant.channelParticipantSelf(Cons_channelParticipantSelf(flags: _1!, userId: _2!, inviterId: _3!, date: _4!, subscriptionUntilDate: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChannelParticipantsFilter: TypeConstructorDescription {
        public class Cons_channelParticipantsBanned {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsContacts {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsKicked {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        public class Cons_channelParticipantsMentions {
            public var flags: Int32
            public var q: String?
            public var topMsgId: Int32?
            public init(flags: Int32, q: String?, topMsgId: Int32?) {
                self.flags = flags
                self.q = q
                self.topMsgId = topMsgId
            }
        }
        public class Cons_channelParticipantsSearch {
            public var q: String
            public init(q: String) {
                self.q = q
            }
        }
        case channelParticipantsAdmins
        case channelParticipantsBanned(Cons_channelParticipantsBanned)
        case channelParticipantsBots
        case channelParticipantsContacts(Cons_channelParticipantsContacts)
        case channelParticipantsKicked(Cons_channelParticipantsKicked)
        case channelParticipantsMentions(Cons_channelParticipantsMentions)
        case channelParticipantsRecent
        case channelParticipantsSearch(Cons_channelParticipantsSearch)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelParticipantsAdmins:
                if boxed {
                    buffer.appendInt32(-1268741783)
                }
                break
            case .channelParticipantsBanned(let _data):
                if boxed {
                    buffer.appendInt32(338142689)
                }
                serializeString(_data.q, buffer: buffer, boxed: false)
                break
            case .channelParticipantsBots:
                if boxed {
                    buffer.appendInt32(-1328445861)
                }
                break
            case .channelParticipantsContacts(let _data):
                if boxed {
                    buffer.appendInt32(-1150621555)
                }
                serializeString(_data.q, buffer: buffer, boxed: false)
                break
            case .channelParticipantsKicked(let _data):
                if boxed {
                    buffer.appendInt32(-1548400251)
                }
                serializeString(_data.q, buffer: buffer, boxed: false)
                break
            case .channelParticipantsMentions(let _data):
                if boxed {
                    buffer.appendInt32(-531931925)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.q!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.topMsgId!, buffer: buffer, boxed: false)
                }
                break
            case .channelParticipantsRecent:
                if boxed {
                    buffer.appendInt32(-566281095)
                }
                break
            case .channelParticipantsSearch(let _data):
                if boxed {
                    buffer.appendInt32(106343499)
                }
                serializeString(_data.q, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelParticipantsAdmins:
                return ("channelParticipantsAdmins", [])
            case .channelParticipantsBanned(let _data):
                return ("channelParticipantsBanned", [("q", _data.q as Any)])
            case .channelParticipantsBots:
                return ("channelParticipantsBots", [])
            case .channelParticipantsContacts(let _data):
                return ("channelParticipantsContacts", [("q", _data.q as Any)])
            case .channelParticipantsKicked(let _data):
                return ("channelParticipantsKicked", [("q", _data.q as Any)])
            case .channelParticipantsMentions(let _data):
                return ("channelParticipantsMentions", [("flags", _data.flags as Any), ("q", _data.q as Any), ("topMsgId", _data.topMsgId as Any)])
            case .channelParticipantsRecent:
                return ("channelParticipantsRecent", [])
            case .channelParticipantsSearch(let _data):
                return ("channelParticipantsSearch", [("q", _data.q as Any)])
            }
        }

        public static func parse_channelParticipantsAdmins(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsAdmins
        }
        public static func parse_channelParticipantsBanned(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsBanned(Cons_channelParticipantsBanned(q: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsBots(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsBots
        }
        public static func parse_channelParticipantsContacts(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsContacts(Cons_channelParticipantsContacts(q: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsKicked(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsKicked(Cons_channelParticipantsKicked(q: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsMentions(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelParticipantsFilter.channelParticipantsMentions(Cons_channelParticipantsMentions(flags: _1!, q: _2, topMsgId: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsRecent(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            return Api.ChannelParticipantsFilter.channelParticipantsRecent
        }
        public static func parse_channelParticipantsSearch(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelParticipantsFilter.channelParticipantsSearch(Cons_channelParticipantsSearch(q: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum Chat: TypeConstructorDescription {
        public class Cons_channel {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var accessHash: Int64?
            public var title: String
            public var username: String?
            public var photo: Api.ChatPhoto
            public var date: Int32
            public var restrictionReason: [Api.RestrictionReason]?
            public var adminRights: Api.ChatAdminRights?
            public var bannedRights: Api.ChatBannedRights?
            public var defaultBannedRights: Api.ChatBannedRights?
            public var participantsCount: Int32?
            public var usernames: [Api.Username]?
            public var storiesMaxId: Api.RecentStory?
            public var color: Api.PeerColor?
            public var profileColor: Api.PeerColor?
            public var emojiStatus: Api.EmojiStatus?
            public var level: Int32?
            public var subscriptionUntilDate: Int32?
            public var botVerificationIcon: Int64?
            public var sendPaidMessagesStars: Int64?
            public var linkedMonoforumId: Int64?
            public init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, emojiStatus: Api.EmojiStatus?, level: Int32?, subscriptionUntilDate: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?, linkedMonoforumId: Int64?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.username = username
                self.photo = photo
                self.date = date
                self.restrictionReason = restrictionReason
                self.adminRights = adminRights
                self.bannedRights = bannedRights
                self.defaultBannedRights = defaultBannedRights
                self.participantsCount = participantsCount
                self.usernames = usernames
                self.storiesMaxId = storiesMaxId
                self.color = color
                self.profileColor = profileColor
                self.emojiStatus = emojiStatus
                self.level = level
                self.subscriptionUntilDate = subscriptionUntilDate
                self.botVerificationIcon = botVerificationIcon
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.linkedMonoforumId = linkedMonoforumId
            }
        }
        public class Cons_channelForbidden {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var title: String
            public var untilDate: Int32?
            public init(flags: Int32, id: Int64, accessHash: Int64, title: String, untilDate: Int32?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.title = title
                self.untilDate = untilDate
            }
        }
        public class Cons_chat {
            public var flags: Int32
            public var id: Int64
            public var title: String
            public var photo: Api.ChatPhoto
            public var participantsCount: Int32
            public var date: Int32
            public var version: Int32
            public var migratedTo: Api.InputChannel?
            public var adminRights: Api.ChatAdminRights?
            public var defaultBannedRights: Api.ChatBannedRights?
            public init(flags: Int32, id: Int64, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?) {
                self.flags = flags
                self.id = id
                self.title = title
                self.photo = photo
                self.participantsCount = participantsCount
                self.date = date
                self.version = version
                self.migratedTo = migratedTo
                self.adminRights = adminRights
                self.defaultBannedRights = defaultBannedRights
            }
        }
        public class Cons_chatEmpty {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
        }
        public class Cons_chatForbidden {
            public var id: Int64
            public var title: String
            public init(id: Int64, title: String) {
                self.id = id
                self.title = title
            }
        }
        case channel(Cons_channel)
        case channelForbidden(Cons_channelForbidden)
        case chat(Cons_chat)
        case chatEmpty(Cons_chatEmpty)
        case chatForbidden(Cons_chatForbidden)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channel(let _data):
                if boxed {
                    buffer.appendInt32(473084188)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.flags2, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt64(_data.accessHash!, buffer: buffer, boxed: false)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.username!, buffer: buffer, boxed: false)
                }
                _data.photo.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.restrictionReason!.count))
                    for item in _data.restrictionReason! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.adminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.bannedRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.defaultBannedRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    serializeInt32(_data.participantsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.usernames!.count))
                    for item in _data.usernames! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags2) & Int(1 << 4) != 0 {
                    _data.storiesMaxId!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 7) != 0 {
                    _data.color!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 8) != 0 {
                    _data.profileColor!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 9) != 0 {
                    _data.emojiStatus!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 10) != 0 {
                    serializeInt32(_data.level!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 11) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 13) != 0 {
                    serializeInt64(_data.botVerificationIcon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 14) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 18) != 0 {
                    serializeInt64(_data.linkedMonoforumId!, buffer: buffer, boxed: false)
                }
                break
            case .channelForbidden(let _data):
                if boxed {
                    buffer.appendInt32(399807445)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt32(_data.untilDate!, buffer: buffer, boxed: false)
                }
                break
            case .chat(let _data):
                if boxed {
                    buffer.appendInt32(1103884886)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                _data.photo.serialize(buffer, true)
                serializeInt32(_data.participantsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.migratedTo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.adminRights!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.defaultBannedRights!.serialize(buffer, true)
                }
                break
            case .chatEmpty(let _data):
                if boxed {
                    buffer.appendInt32(693512293)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            case .chatForbidden(let _data):
                if boxed {
                    buffer.appendInt32(1704108455)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channel(let _data):
                return ("channel", [("flags", _data.flags as Any), ("flags2", _data.flags2 as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("title", _data.title as Any), ("username", _data.username as Any), ("photo", _data.photo as Any), ("date", _data.date as Any), ("restrictionReason", _data.restrictionReason as Any), ("adminRights", _data.adminRights as Any), ("bannedRights", _data.bannedRights as Any), ("defaultBannedRights", _data.defaultBannedRights as Any), ("participantsCount", _data.participantsCount as Any), ("usernames", _data.usernames as Any), ("storiesMaxId", _data.storiesMaxId as Any), ("color", _data.color as Any), ("profileColor", _data.profileColor as Any), ("emojiStatus", _data.emojiStatus as Any), ("level", _data.level as Any), ("subscriptionUntilDate", _data.subscriptionUntilDate as Any), ("botVerificationIcon", _data.botVerificationIcon as Any), ("sendPaidMessagesStars", _data.sendPaidMessagesStars as Any), ("linkedMonoforumId", _data.linkedMonoforumId as Any)])
            case .channelForbidden(let _data):
                return ("channelForbidden", [("flags", _data.flags as Any), ("id", _data.id as Any), ("accessHash", _data.accessHash as Any), ("title", _data.title as Any), ("untilDate", _data.untilDate as Any)])
            case .chat(let _data):
                return ("chat", [("flags", _data.flags as Any), ("id", _data.id as Any), ("title", _data.title as Any), ("photo", _data.photo as Any), ("participantsCount", _data.participantsCount as Any), ("date", _data.date as Any), ("version", _data.version as Any), ("migratedTo", _data.migratedTo as Any), ("adminRights", _data.adminRights as Any), ("defaultBannedRights", _data.defaultBannedRights as Any)])
            case .chatEmpty(let _data):
                return ("chatEmpty", [("id", _data.id as Any)])
            case .chatForbidden(let _data):
                return ("chatForbidden", [("id", _data.id as Any), ("title", _data.title as Any)])
            }
        }

        public static func parse_channel(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            if Int(_1!) & Int(1 << 13) != 0 {
                _4 = reader.readInt64()
            }
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _6 = parseString(reader)
            }
            var _7: Api.ChatPhoto?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 9) != 0 {
                if let _ = reader.readInt32() {
                    _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
                }
            }
            var _10: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _11: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
                }
            }
            var _12: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _12 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
                }
            }
            var _13: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {
                _13 = reader.readInt32()
            }
            var _14: [Api.Username]?
            if Int(_2!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
                }
            }
            var _15: Api.RecentStory?
            if Int(_2!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.RecentStory
                }
            }
            var _16: Api.PeerColor?
            if Int(_2!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _16 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _17: Api.PeerColor?
            if Int(_2!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.PeerColor
                }
            }
            var _18: Api.EmojiStatus?
            if Int(_2!) & Int(1 << 9) != 0 {
                if let signature = reader.readInt32() {
                    _18 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
                }
            }
            var _19: Int32?
            if Int(_2!) & Int(1 << 10) != 0 {
                _19 = reader.readInt32()
            }
            var _20: Int32?
            if Int(_2!) & Int(1 << 11) != 0 {
                _20 = reader.readInt32()
            }
            var _21: Int64?
            if Int(_2!) & Int(1 << 13) != 0 {
                _21 = reader.readInt64()
            }
            var _22: Int64?
            if Int(_2!) & Int(1 << 14) != 0 {
                _22 = reader.readInt64()
            }
            var _23: Int64?
            if Int(_2!) & Int(1 << 18) != 0 {
                _23 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 13) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 6) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 9) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 15) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 17) == 0) || _13 != nil
            let _c14 = (Int(_2!) & Int(1 << 0) == 0) || _14 != nil
            let _c15 = (Int(_2!) & Int(1 << 4) == 0) || _15 != nil
            let _c16 = (Int(_2!) & Int(1 << 7) == 0) || _16 != nil
            let _c17 = (Int(_2!) & Int(1 << 8) == 0) || _17 != nil
            let _c18 = (Int(_2!) & Int(1 << 9) == 0) || _18 != nil
            let _c19 = (Int(_2!) & Int(1 << 10) == 0) || _19 != nil
            let _c20 = (Int(_2!) & Int(1 << 11) == 0) || _20 != nil
            let _c21 = (Int(_2!) & Int(1 << 13) == 0) || _21 != nil
            let _c22 = (Int(_2!) & Int(1 << 14) == 0) || _22 != nil
            let _c23 = (Int(_2!) & Int(1 << 18) == 0) || _23 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 {
                return Api.Chat.channel(Cons_channel(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, title: _5!, username: _6, photo: _7!, date: _8!, restrictionReason: _9, adminRights: _10, bannedRights: _11, defaultBannedRights: _12, participantsCount: _13, usernames: _14, storiesMaxId: _15, color: _16, profileColor: _17, emojiStatus: _18, level: _19, subscriptionUntilDate: _20, botVerificationIcon: _21, sendPaidMessagesStars: _22, linkedMonoforumId: _23))
            }
            else {
                return nil
            }
        }
        public static func parse_channelForbidden(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            if Int(_1!) & Int(1 << 16) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 16) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Chat.channelForbidden(Cons_channelForbidden(flags: _1!, id: _2!, accessHash: _3!, title: _4!, untilDate: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_chat(_ reader: BufferReader) -> Chat? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatPhoto?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.InputChannel?
            if Int(_1!) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.InputChannel
                }
            }
            var _9: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
                }
            }
            var _10: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 14) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 18) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.Chat.chat(Cons_chat(flags: _1!, id: _2!, title: _3!, photo: _4!, participantsCount: _5!, date: _6!, version: _7!, migratedTo: _8, adminRights: _9, defaultBannedRights: _10))
            }
            else {
                return nil
            }
        }
        public static func parse_chatEmpty(_ reader: BufferReader) -> Chat? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Chat.chatEmpty(Cons_chatEmpty(id: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatForbidden(_ reader: BufferReader) -> Chat? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Chat.chatForbidden(Cons_chatForbidden(id: _1!, title: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatAdminRights: TypeConstructorDescription {
        public class Cons_chatAdminRights {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case chatAdminRights(Cons_chatAdminRights)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatAdminRights(let _data):
                if boxed {
                    buffer.appendInt32(1605510357)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatAdminRights(let _data):
                return ("chatAdminRights", [("flags", _data.flags as Any)])
            }
        }

        public static func parse_chatAdminRights(_ reader: BufferReader) -> ChatAdminRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatAdminRights.chatAdminRights(Cons_chatAdminRights(flags: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatAdminWithInvites: TypeConstructorDescription {
        public class Cons_chatAdminWithInvites {
            public var adminId: Int64
            public var invitesCount: Int32
            public var revokedInvitesCount: Int32
            public init(adminId: Int64, invitesCount: Int32, revokedInvitesCount: Int32) {
                self.adminId = adminId
                self.invitesCount = invitesCount
                self.revokedInvitesCount = revokedInvitesCount
            }
        }
        case chatAdminWithInvites(Cons_chatAdminWithInvites)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatAdminWithInvites(let _data):
                if boxed {
                    buffer.appendInt32(-219353309)
                }
                serializeInt64(_data.adminId, buffer: buffer, boxed: false)
                serializeInt32(_data.invitesCount, buffer: buffer, boxed: false)
                serializeInt32(_data.revokedInvitesCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatAdminWithInvites(let _data):
                return ("chatAdminWithInvites", [("adminId", _data.adminId as Any), ("invitesCount", _data.invitesCount as Any), ("revokedInvitesCount", _data.revokedInvitesCount as Any)])
            }
        }

        public static func parse_chatAdminWithInvites(_ reader: BufferReader) -> ChatAdminWithInvites? {
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
                return Api.ChatAdminWithInvites.chatAdminWithInvites(Cons_chatAdminWithInvites(adminId: _1!, invitesCount: _2!, revokedInvitesCount: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatBannedRights: TypeConstructorDescription {
        public class Cons_chatBannedRights {
            public var flags: Int32
            public var untilDate: Int32
            public init(flags: Int32, untilDate: Int32) {
                self.flags = flags
                self.untilDate = untilDate
            }
        }
        case chatBannedRights(Cons_chatBannedRights)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatBannedRights(let _data):
                if boxed {
                    buffer.appendInt32(-1626209256)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatBannedRights(let _data):
                return ("chatBannedRights", [("flags", _data.flags as Any), ("untilDate", _data.untilDate as Any)])
            }
        }

        public static func parse_chatBannedRights(_ reader: BufferReader) -> ChatBannedRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChatBannedRights.chatBannedRights(Cons_chatBannedRights(flags: _1!, untilDate: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChatFull: TypeConstructorDescription {
        public class Cons_channelFull {
            public var flags: Int32
            public var flags2: Int32
            public var id: Int64
            public var about: String
            public var participantsCount: Int32?
            public var adminsCount: Int32?
            public var kickedCount: Int32?
            public var bannedCount: Int32?
            public var onlineCount: Int32?
            public var readInboxMaxId: Int32
            public var readOutboxMaxId: Int32
            public var unreadCount: Int32
            public var chatPhoto: Api.Photo
            public var notifySettings: Api.PeerNotifySettings
            public var exportedInvite: Api.ExportedChatInvite?
            public var botInfo: [Api.BotInfo]
            public var migratedFromChatId: Int64?
            public var migratedFromMaxId: Int32?
            public var pinnedMsgId: Int32?
            public var stickerset: Api.StickerSet?
            public var availableMinId: Int32?
            public var folderId: Int32?
            public var linkedChatId: Int64?
            public var location: Api.ChannelLocation?
            public var slowmodeSeconds: Int32?
            public var slowmodeNextSendDate: Int32?
            public var statsDc: Int32?
            public var pts: Int32
            public var call: Api.InputGroupCall?
            public var ttlPeriod: Int32?
            public var pendingSuggestions: [String]?
            public var groupcallDefaultJoinAs: Api.Peer?
            public var themeEmoticon: String?
            public var requestsPending: Int32?
            public var recentRequesters: [Int64]?
            public var defaultSendAs: Api.Peer?
            public var availableReactions: Api.ChatReactions?
            public var reactionsLimit: Int32?
            public var stories: Api.PeerStories?
            public var wallpaper: Api.WallPaper?
            public var boostsApplied: Int32?
            public var boostsUnrestrict: Int32?
            public var emojiset: Api.StickerSet?
            public var botVerification: Api.BotVerification?
            public var stargiftsCount: Int32?
            public var sendPaidMessagesStars: Int64?
            public var mainTab: Api.ProfileTab?
            public init(flags: Int32, flags2: Int32, id: Int64, about: String, participantsCount: Int32?, adminsCount: Int32?, kickedCount: Int32?, bannedCount: Int32?, onlineCount: Int32?, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, chatPhoto: Api.Photo, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo], migratedFromChatId: Int64?, migratedFromMaxId: Int32?, pinnedMsgId: Int32?, stickerset: Api.StickerSet?, availableMinId: Int32?, folderId: Int32?, linkedChatId: Int64?, location: Api.ChannelLocation?, slowmodeSeconds: Int32?, slowmodeNextSendDate: Int32?, statsDc: Int32?, pts: Int32, call: Api.InputGroupCall?, ttlPeriod: Int32?, pendingSuggestions: [String]?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, defaultSendAs: Api.Peer?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?, stories: Api.PeerStories?, wallpaper: Api.WallPaper?, boostsApplied: Int32?, boostsUnrestrict: Int32?, emojiset: Api.StickerSet?, botVerification: Api.BotVerification?, stargiftsCount: Int32?, sendPaidMessagesStars: Int64?, mainTab: Api.ProfileTab?) {
                self.flags = flags
                self.flags2 = flags2
                self.id = id
                self.about = about
                self.participantsCount = participantsCount
                self.adminsCount = adminsCount
                self.kickedCount = kickedCount
                self.bannedCount = bannedCount
                self.onlineCount = onlineCount
                self.readInboxMaxId = readInboxMaxId
                self.readOutboxMaxId = readOutboxMaxId
                self.unreadCount = unreadCount
                self.chatPhoto = chatPhoto
                self.notifySettings = notifySettings
                self.exportedInvite = exportedInvite
                self.botInfo = botInfo
                self.migratedFromChatId = migratedFromChatId
                self.migratedFromMaxId = migratedFromMaxId
                self.pinnedMsgId = pinnedMsgId
                self.stickerset = stickerset
                self.availableMinId = availableMinId
                self.folderId = folderId
                self.linkedChatId = linkedChatId
                self.location = location
                self.slowmodeSeconds = slowmodeSeconds
                self.slowmodeNextSendDate = slowmodeNextSendDate
                self.statsDc = statsDc
                self.pts = pts
                self.call = call
                self.ttlPeriod = ttlPeriod
                self.pendingSuggestions = pendingSuggestions
                self.groupcallDefaultJoinAs = groupcallDefaultJoinAs
                self.themeEmoticon = themeEmoticon
                self.requestsPending = requestsPending
                self.recentRequesters = recentRequesters
                self.defaultSendAs = defaultSendAs
                self.availableReactions = availableReactions
                self.reactionsLimit = reactionsLimit
                self.stories = stories
                self.wallpaper = wallpaper
                self.boostsApplied = boostsApplied
                self.boostsUnrestrict = boostsUnrestrict
                self.emojiset = emojiset
                self.botVerification = botVerification
                self.stargiftsCount = stargiftsCount
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.mainTab = mainTab
            }
        }
        public class Cons_chatFull {
            public var flags: Int32
            public var id: Int64
            public var about: String
            public var participants: Api.ChatParticipants
            public var chatPhoto: Api.Photo?
            public var notifySettings: Api.PeerNotifySettings
            public var exportedInvite: Api.ExportedChatInvite?
            public var botInfo: [Api.BotInfo]?
            public var pinnedMsgId: Int32?
            public var folderId: Int32?
            public var call: Api.InputGroupCall?
            public var ttlPeriod: Int32?
            public var groupcallDefaultJoinAs: Api.Peer?
            public var themeEmoticon: String?
            public var requestsPending: Int32?
            public var recentRequesters: [Int64]?
            public var availableReactions: Api.ChatReactions?
            public var reactionsLimit: Int32?
            public init(flags: Int32, id: Int64, about: String, participants: Api.ChatParticipants, chatPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo]?, pinnedMsgId: Int32?, folderId: Int32?, call: Api.InputGroupCall?, ttlPeriod: Int32?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?) {
                self.flags = flags
                self.id = id
                self.about = about
                self.participants = participants
                self.chatPhoto = chatPhoto
                self.notifySettings = notifySettings
                self.exportedInvite = exportedInvite
                self.botInfo = botInfo
                self.pinnedMsgId = pinnedMsgId
                self.folderId = folderId
                self.call = call
                self.ttlPeriod = ttlPeriod
                self.groupcallDefaultJoinAs = groupcallDefaultJoinAs
                self.themeEmoticon = themeEmoticon
                self.requestsPending = requestsPending
                self.recentRequesters = recentRequesters
                self.availableReactions = availableReactions
                self.reactionsLimit = reactionsLimit
            }
        }
        case channelFull(Cons_channelFull)
        case chatFull(Cons_chatFull)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelFull(let _data):
                if boxed {
                    buffer.appendInt32(-455036259)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.flags2, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.about, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.participantsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.adminsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.kickedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.bannedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt32(_data.onlineCount!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.readInboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.readOutboxMaxId, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                _data.chatPhoto.serialize(buffer, true)
                _data.notifySettings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 23) != 0 {
                    _data.exportedInvite!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.botInfo.count))
                for item in _data.botInfo {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.migratedFromChatId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.migratedFromMaxId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.pinnedMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.stickerset!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 9) != 0 {
                    serializeInt32(_data.availableMinId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt64(_data.linkedChatId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.location!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    serializeInt32(_data.slowmodeSeconds!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    serializeInt32(_data.slowmodeNextSendDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt32(_data.statsDc!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 21) != 0 {
                    _data.call!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 24) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 25) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.pendingSuggestions!.count))
                    for item in _data.pendingSuggestions! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 26) != 0 {
                    _data.groupcallDefaultJoinAs!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 27) != 0 {
                    serializeString(_data.themeEmoticon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 28) != 0 {
                    serializeInt32(_data.requestsPending!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 28) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.recentRequesters!.count))
                    for item in _data.recentRequesters! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 29) != 0 {
                    _data.defaultSendAs!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 30) != 0 {
                    _data.availableReactions!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 13) != 0 {
                    serializeInt32(_data.reactionsLimit!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 4) != 0 {
                    _data.stories!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 7) != 0 {
                    _data.wallpaper!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 8) != 0 {
                    serializeInt32(_data.boostsApplied!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 9) != 0 {
                    serializeInt32(_data.boostsUnrestrict!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 10) != 0 {
                    _data.emojiset!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 17) != 0 {
                    _data.botVerification!.serialize(buffer, true)
                }
                if Int(_data.flags2) & Int(1 << 18) != 0 {
                    serializeInt32(_data.stargiftsCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 21) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags2) & Int(1 << 22) != 0 {
                    _data.mainTab!.serialize(buffer, true)
                }
                break
            case .chatFull(let _data):
                if boxed {
                    buffer.appendInt32(640893467)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.about, buffer: buffer, boxed: false)
                _data.participants.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.chatPhoto!.serialize(buffer, true)
                }
                _data.notifySettings.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.exportedInvite!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.botInfo!.count))
                    for item in _data.botInfo! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeInt32(_data.pinnedMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.folderId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    _data.call!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    serializeInt32(_data.ttlPeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 15) != 0 {
                    _data.groupcallDefaultJoinAs!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.themeEmoticon!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    serializeInt32(_data.requestsPending!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 17) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.recentRequesters!.count))
                    for item in _data.recentRequesters! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                }
                if Int(_data.flags) & Int(1 << 18) != 0 {
                    _data.availableReactions!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt32(_data.reactionsLimit!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelFull(let _data):
                return ("channelFull", [("flags", _data.flags as Any), ("flags2", _data.flags2 as Any), ("id", _data.id as Any), ("about", _data.about as Any), ("participantsCount", _data.participantsCount as Any), ("adminsCount", _data.adminsCount as Any), ("kickedCount", _data.kickedCount as Any), ("bannedCount", _data.bannedCount as Any), ("onlineCount", _data.onlineCount as Any), ("readInboxMaxId", _data.readInboxMaxId as Any), ("readOutboxMaxId", _data.readOutboxMaxId as Any), ("unreadCount", _data.unreadCount as Any), ("chatPhoto", _data.chatPhoto as Any), ("notifySettings", _data.notifySettings as Any), ("exportedInvite", _data.exportedInvite as Any), ("botInfo", _data.botInfo as Any), ("migratedFromChatId", _data.migratedFromChatId as Any), ("migratedFromMaxId", _data.migratedFromMaxId as Any), ("pinnedMsgId", _data.pinnedMsgId as Any), ("stickerset", _data.stickerset as Any), ("availableMinId", _data.availableMinId as Any), ("folderId", _data.folderId as Any), ("linkedChatId", _data.linkedChatId as Any), ("location", _data.location as Any), ("slowmodeSeconds", _data.slowmodeSeconds as Any), ("slowmodeNextSendDate", _data.slowmodeNextSendDate as Any), ("statsDc", _data.statsDc as Any), ("pts", _data.pts as Any), ("call", _data.call as Any), ("ttlPeriod", _data.ttlPeriod as Any), ("pendingSuggestions", _data.pendingSuggestions as Any), ("groupcallDefaultJoinAs", _data.groupcallDefaultJoinAs as Any), ("themeEmoticon", _data.themeEmoticon as Any), ("requestsPending", _data.requestsPending as Any), ("recentRequesters", _data.recentRequesters as Any), ("defaultSendAs", _data.defaultSendAs as Any), ("availableReactions", _data.availableReactions as Any), ("reactionsLimit", _data.reactionsLimit as Any), ("stories", _data.stories as Any), ("wallpaper", _data.wallpaper as Any), ("boostsApplied", _data.boostsApplied as Any), ("boostsUnrestrict", _data.boostsUnrestrict as Any), ("emojiset", _data.emojiset as Any), ("botVerification", _data.botVerification as Any), ("stargiftsCount", _data.stargiftsCount as Any), ("sendPaidMessagesStars", _data.sendPaidMessagesStars as Any), ("mainTab", _data.mainTab as Any)])
            case .chatFull(let _data):
                return ("chatFull", [("flags", _data.flags as Any), ("id", _data.id as Any), ("about", _data.about as Any), ("participants", _data.participants as Any), ("chatPhoto", _data.chatPhoto as Any), ("notifySettings", _data.notifySettings as Any), ("exportedInvite", _data.exportedInvite as Any), ("botInfo", _data.botInfo as Any), ("pinnedMsgId", _data.pinnedMsgId as Any), ("folderId", _data.folderId as Any), ("call", _data.call as Any), ("ttlPeriod", _data.ttlPeriod as Any), ("groupcallDefaultJoinAs", _data.groupcallDefaultJoinAs as Any), ("themeEmoticon", _data.themeEmoticon as Any), ("requestsPending", _data.requestsPending as Any), ("recentRequesters", _data.recentRequesters as Any), ("availableReactions", _data.availableReactions as Any), ("reactionsLimit", _data.reactionsLimit as Any)])
            }
        }

        public static func parse_channelFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: Int32?
            _12 = reader.readInt32()
            var _13: Api.Photo?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _14: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _15: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 23) != 0 {
                if let signature = reader.readInt32() {
                    _15 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                }
            }
            var _16: [Api.BotInfo]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
            }
            var _17: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _17 = reader.readInt64()
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _18 = reader.readInt32()
            }
            var _19: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _19 = reader.readInt32()
            }
            var _20: Api.StickerSet?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _20 = Api.parse(reader, signature: signature) as? Api.StickerSet
                }
            }
            var _21: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {
                _21 = reader.readInt32()
            }
            var _22: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _22 = reader.readInt32()
            }
            var _23: Int64?
            if Int(_1!) & Int(1 << 14) != 0 {
                _23 = reader.readInt64()
            }
            var _24: Api.ChannelLocation?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _24 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
                }
            }
            var _25: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {
                _25 = reader.readInt32()
            }
            var _26: Int32?
            if Int(_1!) & Int(1 << 18) != 0 {
                _26 = reader.readInt32()
            }
            var _27: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {
                _27 = reader.readInt32()
            }
            var _28: Int32?
            _28 = reader.readInt32()
            var _29: Api.InputGroupCall?
            if Int(_1!) & Int(1 << 21) != 0 {
                if let signature = reader.readInt32() {
                    _29 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
                }
            }
            var _30: Int32?
            if Int(_1!) & Int(1 << 24) != 0 {
                _30 = reader.readInt32()
            }
            var _31: [String]?
            if Int(_1!) & Int(1 << 25) != 0 {
                if let _ = reader.readInt32() {
                    _31 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
                }
            }
            var _32: Api.Peer?
            if Int(_1!) & Int(1 << 26) != 0 {
                if let signature = reader.readInt32() {
                    _32 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _33: String?
            if Int(_1!) & Int(1 << 27) != 0 {
                _33 = parseString(reader)
            }
            var _34: Int32?
            if Int(_1!) & Int(1 << 28) != 0 {
                _34 = reader.readInt32()
            }
            var _35: [Int64]?
            if Int(_1!) & Int(1 << 28) != 0 {
                if let _ = reader.readInt32() {
                    _35 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            var _36: Api.Peer?
            if Int(_1!) & Int(1 << 29) != 0 {
                if let signature = reader.readInt32() {
                    _36 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _37: Api.ChatReactions?
            if Int(_1!) & Int(1 << 30) != 0 {
                if let signature = reader.readInt32() {
                    _37 = Api.parse(reader, signature: signature) as? Api.ChatReactions
                }
            }
            var _38: Int32?
            if Int(_2!) & Int(1 << 13) != 0 {
                _38 = reader.readInt32()
            }
            var _39: Api.PeerStories?
            if Int(_2!) & Int(1 << 4) != 0 {
                if let signature = reader.readInt32() {
                    _39 = Api.parse(reader, signature: signature) as? Api.PeerStories
                }
            }
            var _40: Api.WallPaper?
            if Int(_2!) & Int(1 << 7) != 0 {
                if let signature = reader.readInt32() {
                    _40 = Api.parse(reader, signature: signature) as? Api.WallPaper
                }
            }
            var _41: Int32?
            if Int(_2!) & Int(1 << 8) != 0 {
                _41 = reader.readInt32()
            }
            var _42: Int32?
            if Int(_2!) & Int(1 << 9) != 0 {
                _42 = reader.readInt32()
            }
            var _43: Api.StickerSet?
            if Int(_2!) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _43 = Api.parse(reader, signature: signature) as? Api.StickerSet
                }
            }
            var _44: Api.BotVerification?
            if Int(_2!) & Int(1 << 17) != 0 {
                if let signature = reader.readInt32() {
                    _44 = Api.parse(reader, signature: signature) as? Api.BotVerification
                }
            }
            var _45: Int32?
            if Int(_2!) & Int(1 << 18) != 0 {
                _45 = reader.readInt32()
            }
            var _46: Int64?
            if Int(_2!) & Int(1 << 21) != 0 {
                _46 = reader.readInt64()
            }
            var _47: Api.ProfileTab?
            if Int(_2!) & Int(1 << 22) != 0 {
                if let signature = reader.readInt32() {
                    _47 = Api.parse(reader, signature: signature) as? Api.ProfileTab
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 13) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 23) == 0) || _15 != nil
            let _c16 = _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 4) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 4) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 5) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 8) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 9) == 0) || _21 != nil
            let _c22 = (Int(_1!) & Int(1 << 11) == 0) || _22 != nil
            let _c23 = (Int(_1!) & Int(1 << 14) == 0) || _23 != nil
            let _c24 = (Int(_1!) & Int(1 << 15) == 0) || _24 != nil
            let _c25 = (Int(_1!) & Int(1 << 17) == 0) || _25 != nil
            let _c26 = (Int(_1!) & Int(1 << 18) == 0) || _26 != nil
            let _c27 = (Int(_1!) & Int(1 << 12) == 0) || _27 != nil
            let _c28 = _28 != nil
            let _c29 = (Int(_1!) & Int(1 << 21) == 0) || _29 != nil
            let _c30 = (Int(_1!) & Int(1 << 24) == 0) || _30 != nil
            let _c31 = (Int(_1!) & Int(1 << 25) == 0) || _31 != nil
            let _c32 = (Int(_1!) & Int(1 << 26) == 0) || _32 != nil
            let _c33 = (Int(_1!) & Int(1 << 27) == 0) || _33 != nil
            let _c34 = (Int(_1!) & Int(1 << 28) == 0) || _34 != nil
            let _c35 = (Int(_1!) & Int(1 << 28) == 0) || _35 != nil
            let _c36 = (Int(_1!) & Int(1 << 29) == 0) || _36 != nil
            let _c37 = (Int(_1!) & Int(1 << 30) == 0) || _37 != nil
            let _c38 = (Int(_2!) & Int(1 << 13) == 0) || _38 != nil
            let _c39 = (Int(_2!) & Int(1 << 4) == 0) || _39 != nil
            let _c40 = (Int(_2!) & Int(1 << 7) == 0) || _40 != nil
            let _c41 = (Int(_2!) & Int(1 << 8) == 0) || _41 != nil
            let _c42 = (Int(_2!) & Int(1 << 9) == 0) || _42 != nil
            let _c43 = (Int(_2!) & Int(1 << 10) == 0) || _43 != nil
            let _c44 = (Int(_2!) & Int(1 << 17) == 0) || _44 != nil
            let _c45 = (Int(_2!) & Int(1 << 18) == 0) || _45 != nil
            let _c46 = (Int(_2!) & Int(1 << 21) == 0) || _46 != nil
            let _c47 = (Int(_2!) & Int(1 << 22) == 0) || _47 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 && _c40 && _c41 && _c42 && _c43 && _c44 && _c45 && _c46 && _c47 {
                return Api.ChatFull.channelFull(Cons_channelFull(flags: _1!, flags2: _2!, id: _3!, about: _4!, participantsCount: _5, adminsCount: _6, kickedCount: _7, bannedCount: _8, onlineCount: _9, readInboxMaxId: _10!, readOutboxMaxId: _11!, unreadCount: _12!, chatPhoto: _13!, notifySettings: _14!, exportedInvite: _15, botInfo: _16!, migratedFromChatId: _17, migratedFromMaxId: _18, pinnedMsgId: _19, stickerset: _20, availableMinId: _21, folderId: _22, linkedChatId: _23, location: _24, slowmodeSeconds: _25, slowmodeNextSendDate: _26, statsDc: _27, pts: _28!, call: _29, ttlPeriod: _30, pendingSuggestions: _31, groupcallDefaultJoinAs: _32, themeEmoticon: _33, requestsPending: _34, recentRequesters: _35, defaultSendAs: _36, availableReactions: _37, reactionsLimit: _38, stories: _39, wallpaper: _40, boostsApplied: _41, boostsUnrestrict: _42, emojiset: _43, botVerification: _44, stargiftsCount: _45, sendPaidMessagesStars: _46, mainTab: _47))
            }
            else {
                return nil
            }
        }
        public static func parse_chatFull(_ reader: BufferReader) -> ChatFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.ChatParticipants?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.ChatParticipants
            }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.Photo
                }
            }
            var _6: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _7: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
                }
            }
            var _8: [Api.BotInfo]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
                }
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _10 = reader.readInt32()
            }
            var _11: Api.InputGroupCall?
            if Int(_1!) & Int(1 << 12) != 0 {
                if let signature = reader.readInt32() {
                    _11 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
                }
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {
                _12 = reader.readInt32()
            }
            var _13: Api.Peer?
            if Int(_1!) & Int(1 << 15) != 0 {
                if let signature = reader.readInt32() {
                    _13 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _14: String?
            if Int(_1!) & Int(1 << 16) != 0 {
                _14 = parseString(reader)
            }
            var _15: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {
                _15 = reader.readInt32()
            }
            var _16: [Int64]?
            if Int(_1!) & Int(1 << 17) != 0 {
                if let _ = reader.readInt32() {
                    _16 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
                }
            }
            var _17: Api.ChatReactions?
            if Int(_1!) & Int(1 << 18) != 0 {
                if let signature = reader.readInt32() {
                    _17 = Api.parse(reader, signature: signature) as? Api.ChatReactions
                }
            }
            var _18: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {
                _18 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 13) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 12) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 14) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 15) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 16) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 17) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 17) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 18) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 20) == 0) || _18 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 {
                return Api.ChatFull.chatFull(Cons_chatFull(flags: _1!, id: _2!, about: _3!, participants: _4!, chatPhoto: _5, notifySettings: _6!, exportedInvite: _7, botInfo: _8, pinnedMsgId: _9, folderId: _10, call: _11, ttlPeriod: _12, groupcallDefaultJoinAs: _13, themeEmoticon: _14, requestsPending: _15, recentRequesters: _16, availableReactions: _17, reactionsLimit: _18))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum ChatInvite: TypeConstructorDescription {
        public class Cons_chatInvite {
            public var flags: Int32
            public var title: String
            public var about: String?
            public var photo: Api.Photo
            public var participantsCount: Int32
            public var participants: [Api.User]?
            public var color: Int32
            public var subscriptionPricing: Api.StarsSubscriptionPricing?
            public var subscriptionFormId: Int64?
            public var botVerification: Api.BotVerification?
            public init(flags: Int32, title: String, about: String?, photo: Api.Photo, participantsCount: Int32, participants: [Api.User]?, color: Int32, subscriptionPricing: Api.StarsSubscriptionPricing?, subscriptionFormId: Int64?, botVerification: Api.BotVerification?) {
                self.flags = flags
                self.title = title
                self.about = about
                self.photo = photo
                self.participantsCount = participantsCount
                self.participants = participants
                self.color = color
                self.subscriptionPricing = subscriptionPricing
                self.subscriptionFormId = subscriptionFormId
                self.botVerification = botVerification
            }
        }
        public class Cons_chatInviteAlready {
            public var chat: Api.Chat
            public init(chat: Api.Chat) {
                self.chat = chat
            }
        }
        public class Cons_chatInvitePeek {
            public var chat: Api.Chat
            public var expires: Int32
            public init(chat: Api.Chat, expires: Int32) {
                self.chat = chat
                self.expires = expires
            }
        }
        case chatInvite(Cons_chatInvite)
        case chatInviteAlready(Cons_chatInviteAlready)
        case chatInvitePeek(Cons_chatInvitePeek)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .chatInvite(let _data):
                if boxed {
                    buffer.appendInt32(1553807106)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.about!, buffer: buffer, boxed: false)
                }
                _data.photo.serialize(buffer, true)
                serializeInt32(_data.participantsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.participants!.count))
                    for item in _data.participants! {
                        item.serialize(buffer, true)
                    }
                }
                serializeInt32(_data.color, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    _data.subscriptionPricing!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 12) != 0 {
                    serializeInt64(_data.subscriptionFormId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    _data.botVerification!.serialize(buffer, true)
                }
                break
            case .chatInviteAlready(let _data):
                if boxed {
                    buffer.appendInt32(1516793212)
                }
                _data.chat.serialize(buffer, true)
                break
            case .chatInvitePeek(let _data):
                if boxed {
                    buffer.appendInt32(1634294960)
                }
                _data.chat.serialize(buffer, true)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .chatInvite(let _data):
                return ("chatInvite", [("flags", _data.flags as Any), ("title", _data.title as Any), ("about", _data.about as Any), ("photo", _data.photo as Any), ("participantsCount", _data.participantsCount as Any), ("participants", _data.participants as Any), ("color", _data.color as Any), ("subscriptionPricing", _data.subscriptionPricing as Any), ("subscriptionFormId", _data.subscriptionFormId as Any), ("botVerification", _data.botVerification as Any)])
            case .chatInviteAlready(let _data):
                return ("chatInviteAlready", [("chat", _data.chat as Any)])
            case .chatInvitePeek(let _data):
                return ("chatInvitePeek", [("chat", _data.chat as Any), ("expires", _data.expires as Any)])
            }
        }

        public static func parse_chatInvite(_ reader: BufferReader) -> ChatInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _3 = parseString(reader)
            }
            var _4: Api.Photo?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.User]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
                }
            }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.StarsSubscriptionPricing?
            if Int(_1!) & Int(1 << 10) != 0 {
                if let signature = reader.readInt32() {
                    _8 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
                }
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 12) != 0 {
                _9 = reader.readInt64()
            }
            var _10: Api.BotVerification?
            if Int(_1!) & Int(1 << 13) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.BotVerification
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 5) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 10) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 12) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 13) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.ChatInvite.chatInvite(Cons_chatInvite(flags: _1!, title: _2!, about: _3, photo: _4!, participantsCount: _5!, participants: _6, color: _7!, subscriptionPricing: _8, subscriptionFormId: _9, botVerification: _10))
            }
            else {
                return nil
            }
        }
        public static func parse_chatInviteAlready(_ reader: BufferReader) -> ChatInvite? {
            var _1: Api.Chat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Chat
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatInvite.chatInviteAlready(Cons_chatInviteAlready(chat: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_chatInvitePeek(_ reader: BufferReader) -> ChatInvite? {
            var _1: Api.Chat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Chat
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.ChatInvite.chatInvitePeek(Cons_chatInvitePeek(chat: _1!, expires: _2!))
            }
            else {
                return nil
            }
        }
    }
}
