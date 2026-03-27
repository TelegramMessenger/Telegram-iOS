public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        public class Cons_channelAdminLogEventsFilter: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelAdminLogEventsFilter", [("flags", ConstructorParameterDescription(self.flags))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelAdminLogEventsFilter(let _data):
                return ("channelAdminLogEventsFilter", [("flags", ConstructorParameterDescription(_data.flags))])
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
        public class Cons_channelLocation: TypeConstructorDescription {
            public var geoPoint: Api.GeoPoint
            public var address: String
            public init(geoPoint: Api.GeoPoint, address: String) {
                self.geoPoint = geoPoint
                self.address = address
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelLocation", [("geoPoint", ConstructorParameterDescription(self.geoPoint)), ("address", ConstructorParameterDescription(self.address))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelLocation(let _data):
                return ("channelLocation", [("geoPoint", ConstructorParameterDescription(_data.geoPoint)), ("address", ConstructorParameterDescription(_data.address))])
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
        public class Cons_channelMessagesFilter: TypeConstructorDescription {
            public var flags: Int32
            public var ranges: [Api.MessageRange]
            public init(flags: Int32, ranges: [Api.MessageRange]) {
                self.flags = flags
                self.ranges = ranges
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelMessagesFilter", [("flags", ConstructorParameterDescription(self.flags)), ("ranges", ConstructorParameterDescription(self.ranges))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelMessagesFilter(let _data):
                return ("channelMessagesFilter", [("flags", ConstructorParameterDescription(_data.flags)), ("ranges", ConstructorParameterDescription(_data.ranges))])
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
        public class Cons_channelParticipant: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public var rank: String?
            public init(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
                self.rank = rank
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipant", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("date", ConstructorParameterDescription(self.date)), ("subscriptionUntilDate", ConstructorParameterDescription(self.subscriptionUntilDate)), ("rank", ConstructorParameterDescription(self.rank))])
            }
        }
        public class Cons_channelParticipantAdmin: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantAdmin", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("inviterId", ConstructorParameterDescription(self.inviterId)), ("promotedBy", ConstructorParameterDescription(self.promotedBy)), ("date", ConstructorParameterDescription(self.date)), ("adminRights", ConstructorParameterDescription(self.adminRights)), ("rank", ConstructorParameterDescription(self.rank))])
            }
        }
        public class Cons_channelParticipantBanned: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var kickedBy: Int64
            public var date: Int32
            public var bannedRights: Api.ChatBannedRights
            public var rank: String?
            public init(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights, rank: String?) {
                self.flags = flags
                self.peer = peer
                self.kickedBy = kickedBy
                self.date = date
                self.bannedRights = bannedRights
                self.rank = rank
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantBanned", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("kickedBy", ConstructorParameterDescription(self.kickedBy)), ("date", ConstructorParameterDescription(self.date)), ("bannedRights", ConstructorParameterDescription(self.bannedRights)), ("rank", ConstructorParameterDescription(self.rank))])
            }
        }
        public class Cons_channelParticipantCreator: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantCreator", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("adminRights", ConstructorParameterDescription(self.adminRights)), ("rank", ConstructorParameterDescription(self.rank))])
            }
        }
        public class Cons_channelParticipantLeft: TypeConstructorDescription {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantLeft", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        public class Cons_channelParticipantSelf: TypeConstructorDescription {
            public var flags: Int32
            public var userId: Int64
            public var inviterId: Int64
            public var date: Int32
            public var subscriptionUntilDate: Int32?
            public var rank: String?
            public init(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?, rank: String?) {
                self.flags = flags
                self.userId = userId
                self.inviterId = inviterId
                self.date = date
                self.subscriptionUntilDate = subscriptionUntilDate
                self.rank = rank
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantSelf", [("flags", ConstructorParameterDescription(self.flags)), ("userId", ConstructorParameterDescription(self.userId)), ("inviterId", ConstructorParameterDescription(self.inviterId)), ("date", ConstructorParameterDescription(self.date)), ("subscriptionUntilDate", ConstructorParameterDescription(self.subscriptionUntilDate)), ("rank", ConstructorParameterDescription(self.rank))])
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
                    buffer.appendInt32(466961494)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.rank!, buffer: buffer, boxed: false)
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
                    buffer.appendInt32(-705647215)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt64(_data.kickedBy, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.bannedRights.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.rank!, buffer: buffer, boxed: false)
                }
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
                    buffer.appendInt32(-1454929382)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.inviterId, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.subscriptionUntilDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.rank!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelParticipant(let _data):
                return ("channelParticipant", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("date", ConstructorParameterDescription(_data.date)), ("subscriptionUntilDate", ConstructorParameterDescription(_data.subscriptionUntilDate)), ("rank", ConstructorParameterDescription(_data.rank))])
            case .channelParticipantAdmin(let _data):
                return ("channelParticipantAdmin", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("inviterId", ConstructorParameterDescription(_data.inviterId)), ("promotedBy", ConstructorParameterDescription(_data.promotedBy)), ("date", ConstructorParameterDescription(_data.date)), ("adminRights", ConstructorParameterDescription(_data.adminRights)), ("rank", ConstructorParameterDescription(_data.rank))])
            case .channelParticipantBanned(let _data):
                return ("channelParticipantBanned", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("kickedBy", ConstructorParameterDescription(_data.kickedBy)), ("date", ConstructorParameterDescription(_data.date)), ("bannedRights", ConstructorParameterDescription(_data.bannedRights)), ("rank", ConstructorParameterDescription(_data.rank))])
            case .channelParticipantCreator(let _data):
                return ("channelParticipantCreator", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("adminRights", ConstructorParameterDescription(_data.adminRights)), ("rank", ConstructorParameterDescription(_data.rank))])
            case .channelParticipantLeft(let _data):
                return ("channelParticipantLeft", [("peer", ConstructorParameterDescription(_data.peer))])
            case .channelParticipantSelf(let _data):
                return ("channelParticipantSelf", [("flags", ConstructorParameterDescription(_data.flags)), ("userId", ConstructorParameterDescription(_data.userId)), ("inviterId", ConstructorParameterDescription(_data.inviterId)), ("date", ConstructorParameterDescription(_data.date)), ("subscriptionUntilDate", ConstructorParameterDescription(_data.subscriptionUntilDate)), ("rank", ConstructorParameterDescription(_data.rank))])
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
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChannelParticipant.channelParticipant(Cons_channelParticipant(flags: _1!, userId: _2!, date: _3!, subscriptionUntilDate: _4, rank: _5))
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
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ChannelParticipant.channelParticipantBanned(Cons_channelParticipantBanned(flags: _1!, peer: _2!, kickedBy: _3!, date: _4!, bannedRights: _5!, rank: _6))
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
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ChannelParticipant.channelParticipantSelf(Cons_channelParticipantSelf(flags: _1!, userId: _2!, inviterId: _3!, date: _4!, subscriptionUntilDate: _5, rank: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ChannelParticipantsFilter: TypeConstructorDescription {
        public class Cons_channelParticipantsBanned: TypeConstructorDescription {
            public var q: String
            public init(q: String) {
                self.q = q
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantsBanned", [("q", ConstructorParameterDescription(self.q))])
            }
        }
        public class Cons_channelParticipantsContacts: TypeConstructorDescription {
            public var q: String
            public init(q: String) {
                self.q = q
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantsContacts", [("q", ConstructorParameterDescription(self.q))])
            }
        }
        public class Cons_channelParticipantsKicked: TypeConstructorDescription {
            public var q: String
            public init(q: String) {
                self.q = q
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantsKicked", [("q", ConstructorParameterDescription(self.q))])
            }
        }
        public class Cons_channelParticipantsMentions: TypeConstructorDescription {
            public var flags: Int32
            public var q: String?
            public var topMsgId: Int32?
            public init(flags: Int32, q: String?, topMsgId: Int32?) {
                self.flags = flags
                self.q = q
                self.topMsgId = topMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantsMentions", [("flags", ConstructorParameterDescription(self.flags)), ("q", ConstructorParameterDescription(self.q)), ("topMsgId", ConstructorParameterDescription(self.topMsgId))])
            }
        }
        public class Cons_channelParticipantsSearch: TypeConstructorDescription {
            public var q: String
            public init(q: String) {
                self.q = q
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelParticipantsSearch", [("q", ConstructorParameterDescription(self.q))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelParticipantsAdmins:
                return ("channelParticipantsAdmins", [])
            case .channelParticipantsBanned(let _data):
                return ("channelParticipantsBanned", [("q", ConstructorParameterDescription(_data.q))])
            case .channelParticipantsBots:
                return ("channelParticipantsBots", [])
            case .channelParticipantsContacts(let _data):
                return ("channelParticipantsContacts", [("q", ConstructorParameterDescription(_data.q))])
            case .channelParticipantsKicked(let _data):
                return ("channelParticipantsKicked", [("q", ConstructorParameterDescription(_data.q))])
            case .channelParticipantsMentions(let _data):
                return ("channelParticipantsMentions", [("flags", ConstructorParameterDescription(_data.flags)), ("q", ConstructorParameterDescription(_data.q)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId))])
            case .channelParticipantsRecent:
                return ("channelParticipantsRecent", [])
            case .channelParticipantsSearch(let _data):
                return ("channelParticipantsSearch", [("q", ConstructorParameterDescription(_data.q))])
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
        public class Cons_channel: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channel", [("flags", ConstructorParameterDescription(self.flags)), ("flags2", ConstructorParameterDescription(self.flags2)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("title", ConstructorParameterDescription(self.title)), ("username", ConstructorParameterDescription(self.username)), ("photo", ConstructorParameterDescription(self.photo)), ("date", ConstructorParameterDescription(self.date)), ("restrictionReason", ConstructorParameterDescription(self.restrictionReason)), ("adminRights", ConstructorParameterDescription(self.adminRights)), ("bannedRights", ConstructorParameterDescription(self.bannedRights)), ("defaultBannedRights", ConstructorParameterDescription(self.defaultBannedRights)), ("participantsCount", ConstructorParameterDescription(self.participantsCount)), ("usernames", ConstructorParameterDescription(self.usernames)), ("storiesMaxId", ConstructorParameterDescription(self.storiesMaxId)), ("color", ConstructorParameterDescription(self.color)), ("profileColor", ConstructorParameterDescription(self.profileColor)), ("emojiStatus", ConstructorParameterDescription(self.emojiStatus)), ("level", ConstructorParameterDescription(self.level)), ("subscriptionUntilDate", ConstructorParameterDescription(self.subscriptionUntilDate)), ("botVerificationIcon", ConstructorParameterDescription(self.botVerificationIcon)), ("sendPaidMessagesStars", ConstructorParameterDescription(self.sendPaidMessagesStars)), ("linkedMonoforumId", ConstructorParameterDescription(self.linkedMonoforumId))])
            }
        }
        public class Cons_channelForbidden: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelForbidden", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("title", ConstructorParameterDescription(self.title)), ("untilDate", ConstructorParameterDescription(self.untilDate))])
            }
        }
        public class Cons_chat: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chat", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("title", ConstructorParameterDescription(self.title)), ("photo", ConstructorParameterDescription(self.photo)), ("participantsCount", ConstructorParameterDescription(self.participantsCount)), ("date", ConstructorParameterDescription(self.date)), ("version", ConstructorParameterDescription(self.version)), ("migratedTo", ConstructorParameterDescription(self.migratedTo)), ("adminRights", ConstructorParameterDescription(self.adminRights)), ("defaultBannedRights", ConstructorParameterDescription(self.defaultBannedRights))])
            }
        }
        public class Cons_chatEmpty: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatEmpty", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        public class Cons_chatForbidden: TypeConstructorDescription {
            public var id: Int64
            public var title: String
            public init(id: Int64, title: String) {
                self.id = id
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatForbidden", [("id", ConstructorParameterDescription(self.id)), ("title", ConstructorParameterDescription(self.title))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channel(let _data):
                return ("channel", [("flags", ConstructorParameterDescription(_data.flags)), ("flags2", ConstructorParameterDescription(_data.flags2)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("title", ConstructorParameterDescription(_data.title)), ("username", ConstructorParameterDescription(_data.username)), ("photo", ConstructorParameterDescription(_data.photo)), ("date", ConstructorParameterDescription(_data.date)), ("restrictionReason", ConstructorParameterDescription(_data.restrictionReason)), ("adminRights", ConstructorParameterDescription(_data.adminRights)), ("bannedRights", ConstructorParameterDescription(_data.bannedRights)), ("defaultBannedRights", ConstructorParameterDescription(_data.defaultBannedRights)), ("participantsCount", ConstructorParameterDescription(_data.participantsCount)), ("usernames", ConstructorParameterDescription(_data.usernames)), ("storiesMaxId", ConstructorParameterDescription(_data.storiesMaxId)), ("color", ConstructorParameterDescription(_data.color)), ("profileColor", ConstructorParameterDescription(_data.profileColor)), ("emojiStatus", ConstructorParameterDescription(_data.emojiStatus)), ("level", ConstructorParameterDescription(_data.level)), ("subscriptionUntilDate", ConstructorParameterDescription(_data.subscriptionUntilDate)), ("botVerificationIcon", ConstructorParameterDescription(_data.botVerificationIcon)), ("sendPaidMessagesStars", ConstructorParameterDescription(_data.sendPaidMessagesStars)), ("linkedMonoforumId", ConstructorParameterDescription(_data.linkedMonoforumId))])
            case .channelForbidden(let _data):
                return ("channelForbidden", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("title", ConstructorParameterDescription(_data.title)), ("untilDate", ConstructorParameterDescription(_data.untilDate))])
            case .chat(let _data):
                return ("chat", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("title", ConstructorParameterDescription(_data.title)), ("photo", ConstructorParameterDescription(_data.photo)), ("participantsCount", ConstructorParameterDescription(_data.participantsCount)), ("date", ConstructorParameterDescription(_data.date)), ("version", ConstructorParameterDescription(_data.version)), ("migratedTo", ConstructorParameterDescription(_data.migratedTo)), ("adminRights", ConstructorParameterDescription(_data.adminRights)), ("defaultBannedRights", ConstructorParameterDescription(_data.defaultBannedRights))])
            case .chatEmpty(let _data):
                return ("chatEmpty", [("id", ConstructorParameterDescription(_data.id))])
            case .chatForbidden(let _data):
                return ("chatForbidden", [("id", ConstructorParameterDescription(_data.id)), ("title", ConstructorParameterDescription(_data.title))])
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
        public class Cons_chatAdminRights: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatAdminRights", [("flags", ConstructorParameterDescription(self.flags))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatAdminRights(let _data):
                return ("chatAdminRights", [("flags", ConstructorParameterDescription(_data.flags))])
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
        public class Cons_chatAdminWithInvites: TypeConstructorDescription {
            public var adminId: Int64
            public var invitesCount: Int32
            public var revokedInvitesCount: Int32
            public init(adminId: Int64, invitesCount: Int32, revokedInvitesCount: Int32) {
                self.adminId = adminId
                self.invitesCount = invitesCount
                self.revokedInvitesCount = revokedInvitesCount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatAdminWithInvites", [("adminId", ConstructorParameterDescription(self.adminId)), ("invitesCount", ConstructorParameterDescription(self.invitesCount)), ("revokedInvitesCount", ConstructorParameterDescription(self.revokedInvitesCount))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatAdminWithInvites(let _data):
                return ("chatAdminWithInvites", [("adminId", ConstructorParameterDescription(_data.adminId)), ("invitesCount", ConstructorParameterDescription(_data.invitesCount)), ("revokedInvitesCount", ConstructorParameterDescription(_data.revokedInvitesCount))])
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
        public class Cons_chatBannedRights: TypeConstructorDescription {
            public var flags: Int32
            public var untilDate: Int32
            public init(flags: Int32, untilDate: Int32) {
                self.flags = flags
                self.untilDate = untilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatBannedRights", [("flags", ConstructorParameterDescription(self.flags)), ("untilDate", ConstructorParameterDescription(self.untilDate))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatBannedRights(let _data):
                return ("chatBannedRights", [("flags", ConstructorParameterDescription(_data.flags)), ("untilDate", ConstructorParameterDescription(_data.untilDate))])
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
        public class Cons_channelFull: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("channelFull", [("flags", ConstructorParameterDescription(self.flags)), ("flags2", ConstructorParameterDescription(self.flags2)), ("id", ConstructorParameterDescription(self.id)), ("about", ConstructorParameterDescription(self.about)), ("participantsCount", ConstructorParameterDescription(self.participantsCount)), ("adminsCount", ConstructorParameterDescription(self.adminsCount)), ("kickedCount", ConstructorParameterDescription(self.kickedCount)), ("bannedCount", ConstructorParameterDescription(self.bannedCount)), ("onlineCount", ConstructorParameterDescription(self.onlineCount)), ("readInboxMaxId", ConstructorParameterDescription(self.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(self.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(self.unreadCount)), ("chatPhoto", ConstructorParameterDescription(self.chatPhoto)), ("notifySettings", ConstructorParameterDescription(self.notifySettings)), ("exportedInvite", ConstructorParameterDescription(self.exportedInvite)), ("botInfo", ConstructorParameterDescription(self.botInfo)), ("migratedFromChatId", ConstructorParameterDescription(self.migratedFromChatId)), ("migratedFromMaxId", ConstructorParameterDescription(self.migratedFromMaxId)), ("pinnedMsgId", ConstructorParameterDescription(self.pinnedMsgId)), ("stickerset", ConstructorParameterDescription(self.stickerset)), ("availableMinId", ConstructorParameterDescription(self.availableMinId)), ("folderId", ConstructorParameterDescription(self.folderId)), ("linkedChatId", ConstructorParameterDescription(self.linkedChatId)), ("location", ConstructorParameterDescription(self.location)), ("slowmodeSeconds", ConstructorParameterDescription(self.slowmodeSeconds)), ("slowmodeNextSendDate", ConstructorParameterDescription(self.slowmodeNextSendDate)), ("statsDc", ConstructorParameterDescription(self.statsDc)), ("pts", ConstructorParameterDescription(self.pts)), ("call", ConstructorParameterDescription(self.call)), ("ttlPeriod", ConstructorParameterDescription(self.ttlPeriod)), ("pendingSuggestions", ConstructorParameterDescription(self.pendingSuggestions)), ("groupcallDefaultJoinAs", ConstructorParameterDescription(self.groupcallDefaultJoinAs)), ("themeEmoticon", ConstructorParameterDescription(self.themeEmoticon)), ("requestsPending", ConstructorParameterDescription(self.requestsPending)), ("recentRequesters", ConstructorParameterDescription(self.recentRequesters)), ("defaultSendAs", ConstructorParameterDescription(self.defaultSendAs)), ("availableReactions", ConstructorParameterDescription(self.availableReactions)), ("reactionsLimit", ConstructorParameterDescription(self.reactionsLimit)), ("stories", ConstructorParameterDescription(self.stories)), ("wallpaper", ConstructorParameterDescription(self.wallpaper)), ("boostsApplied", ConstructorParameterDescription(self.boostsApplied)), ("boostsUnrestrict", ConstructorParameterDescription(self.boostsUnrestrict)), ("emojiset", ConstructorParameterDescription(self.emojiset)), ("botVerification", ConstructorParameterDescription(self.botVerification)), ("stargiftsCount", ConstructorParameterDescription(self.stargiftsCount)), ("sendPaidMessagesStars", ConstructorParameterDescription(self.sendPaidMessagesStars)), ("mainTab", ConstructorParameterDescription(self.mainTab))])
            }
        }
        public class Cons_chatFull: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatFull", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("about", ConstructorParameterDescription(self.about)), ("participants", ConstructorParameterDescription(self.participants)), ("chatPhoto", ConstructorParameterDescription(self.chatPhoto)), ("notifySettings", ConstructorParameterDescription(self.notifySettings)), ("exportedInvite", ConstructorParameterDescription(self.exportedInvite)), ("botInfo", ConstructorParameterDescription(self.botInfo)), ("pinnedMsgId", ConstructorParameterDescription(self.pinnedMsgId)), ("folderId", ConstructorParameterDescription(self.folderId)), ("call", ConstructorParameterDescription(self.call)), ("ttlPeriod", ConstructorParameterDescription(self.ttlPeriod)), ("groupcallDefaultJoinAs", ConstructorParameterDescription(self.groupcallDefaultJoinAs)), ("themeEmoticon", ConstructorParameterDescription(self.themeEmoticon)), ("requestsPending", ConstructorParameterDescription(self.requestsPending)), ("recentRequesters", ConstructorParameterDescription(self.recentRequesters)), ("availableReactions", ConstructorParameterDescription(self.availableReactions)), ("reactionsLimit", ConstructorParameterDescription(self.reactionsLimit))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .channelFull(let _data):
                return ("channelFull", [("flags", ConstructorParameterDescription(_data.flags)), ("flags2", ConstructorParameterDescription(_data.flags2)), ("id", ConstructorParameterDescription(_data.id)), ("about", ConstructorParameterDescription(_data.about)), ("participantsCount", ConstructorParameterDescription(_data.participantsCount)), ("adminsCount", ConstructorParameterDescription(_data.adminsCount)), ("kickedCount", ConstructorParameterDescription(_data.kickedCount)), ("bannedCount", ConstructorParameterDescription(_data.bannedCount)), ("onlineCount", ConstructorParameterDescription(_data.onlineCount)), ("readInboxMaxId", ConstructorParameterDescription(_data.readInboxMaxId)), ("readOutboxMaxId", ConstructorParameterDescription(_data.readOutboxMaxId)), ("unreadCount", ConstructorParameterDescription(_data.unreadCount)), ("chatPhoto", ConstructorParameterDescription(_data.chatPhoto)), ("notifySettings", ConstructorParameterDescription(_data.notifySettings)), ("exportedInvite", ConstructorParameterDescription(_data.exportedInvite)), ("botInfo", ConstructorParameterDescription(_data.botInfo)), ("migratedFromChatId", ConstructorParameterDescription(_data.migratedFromChatId)), ("migratedFromMaxId", ConstructorParameterDescription(_data.migratedFromMaxId)), ("pinnedMsgId", ConstructorParameterDescription(_data.pinnedMsgId)), ("stickerset", ConstructorParameterDescription(_data.stickerset)), ("availableMinId", ConstructorParameterDescription(_data.availableMinId)), ("folderId", ConstructorParameterDescription(_data.folderId)), ("linkedChatId", ConstructorParameterDescription(_data.linkedChatId)), ("location", ConstructorParameterDescription(_data.location)), ("slowmodeSeconds", ConstructorParameterDescription(_data.slowmodeSeconds)), ("slowmodeNextSendDate", ConstructorParameterDescription(_data.slowmodeNextSendDate)), ("statsDc", ConstructorParameterDescription(_data.statsDc)), ("pts", ConstructorParameterDescription(_data.pts)), ("call", ConstructorParameterDescription(_data.call)), ("ttlPeriod", ConstructorParameterDescription(_data.ttlPeriod)), ("pendingSuggestions", ConstructorParameterDescription(_data.pendingSuggestions)), ("groupcallDefaultJoinAs", ConstructorParameterDescription(_data.groupcallDefaultJoinAs)), ("themeEmoticon", ConstructorParameterDescription(_data.themeEmoticon)), ("requestsPending", ConstructorParameterDescription(_data.requestsPending)), ("recentRequesters", ConstructorParameterDescription(_data.recentRequesters)), ("defaultSendAs", ConstructorParameterDescription(_data.defaultSendAs)), ("availableReactions", ConstructorParameterDescription(_data.availableReactions)), ("reactionsLimit", ConstructorParameterDescription(_data.reactionsLimit)), ("stories", ConstructorParameterDescription(_data.stories)), ("wallpaper", ConstructorParameterDescription(_data.wallpaper)), ("boostsApplied", ConstructorParameterDescription(_data.boostsApplied)), ("boostsUnrestrict", ConstructorParameterDescription(_data.boostsUnrestrict)), ("emojiset", ConstructorParameterDescription(_data.emojiset)), ("botVerification", ConstructorParameterDescription(_data.botVerification)), ("stargiftsCount", ConstructorParameterDescription(_data.stargiftsCount)), ("sendPaidMessagesStars", ConstructorParameterDescription(_data.sendPaidMessagesStars)), ("mainTab", ConstructorParameterDescription(_data.mainTab))])
            case .chatFull(let _data):
                return ("chatFull", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("about", ConstructorParameterDescription(_data.about)), ("participants", ConstructorParameterDescription(_data.participants)), ("chatPhoto", ConstructorParameterDescription(_data.chatPhoto)), ("notifySettings", ConstructorParameterDescription(_data.notifySettings)), ("exportedInvite", ConstructorParameterDescription(_data.exportedInvite)), ("botInfo", ConstructorParameterDescription(_data.botInfo)), ("pinnedMsgId", ConstructorParameterDescription(_data.pinnedMsgId)), ("folderId", ConstructorParameterDescription(_data.folderId)), ("call", ConstructorParameterDescription(_data.call)), ("ttlPeriod", ConstructorParameterDescription(_data.ttlPeriod)), ("groupcallDefaultJoinAs", ConstructorParameterDescription(_data.groupcallDefaultJoinAs)), ("themeEmoticon", ConstructorParameterDescription(_data.themeEmoticon)), ("requestsPending", ConstructorParameterDescription(_data.requestsPending)), ("recentRequesters", ConstructorParameterDescription(_data.recentRequesters)), ("availableReactions", ConstructorParameterDescription(_data.availableReactions)), ("reactionsLimit", ConstructorParameterDescription(_data.reactionsLimit))])
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
        public class Cons_chatInvite: TypeConstructorDescription {
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
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatInvite", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("about", ConstructorParameterDescription(self.about)), ("photo", ConstructorParameterDescription(self.photo)), ("participantsCount", ConstructorParameterDescription(self.participantsCount)), ("participants", ConstructorParameterDescription(self.participants)), ("color", ConstructorParameterDescription(self.color)), ("subscriptionPricing", ConstructorParameterDescription(self.subscriptionPricing)), ("subscriptionFormId", ConstructorParameterDescription(self.subscriptionFormId)), ("botVerification", ConstructorParameterDescription(self.botVerification))])
            }
        }
        public class Cons_chatInviteAlready: TypeConstructorDescription {
            public var chat: Api.Chat
            public init(chat: Api.Chat) {
                self.chat = chat
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatInviteAlready", [("chat", ConstructorParameterDescription(self.chat))])
            }
        }
        public class Cons_chatInvitePeek: TypeConstructorDescription {
            public var chat: Api.Chat
            public var expires: Int32
            public init(chat: Api.Chat, expires: Int32) {
                self.chat = chat
                self.expires = expires
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("chatInvitePeek", [("chat", ConstructorParameterDescription(self.chat)), ("expires", ConstructorParameterDescription(self.expires))])
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .chatInvite(let _data):
                return ("chatInvite", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("about", ConstructorParameterDescription(_data.about)), ("photo", ConstructorParameterDescription(_data.photo)), ("participantsCount", ConstructorParameterDescription(_data.participantsCount)), ("participants", ConstructorParameterDescription(_data.participants)), ("color", ConstructorParameterDescription(_data.color)), ("subscriptionPricing", ConstructorParameterDescription(_data.subscriptionPricing)), ("subscriptionFormId", ConstructorParameterDescription(_data.subscriptionFormId)), ("botVerification", ConstructorParameterDescription(_data.botVerification))])
            case .chatInviteAlready(let _data):
                return ("chatInviteAlready", [("chat", ConstructorParameterDescription(_data.chat))])
            case .chatInvitePeek(let _data):
                return ("chatInvitePeek", [("chat", ConstructorParameterDescription(_data.chat)), ("expires", ConstructorParameterDescription(_data.expires))])
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
