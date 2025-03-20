public extension Api {
    enum ChannelAdminLogEventsFilter: TypeConstructorDescription {
        case channelAdminLogEventsFilter(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelAdminLogEventsFilter(let flags):
                    if boxed {
                        buffer.appendInt32(-368018716)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelAdminLogEventsFilter(let flags):
                return ("channelAdminLogEventsFilter", [("flags", flags as Any)])
    }
    }
    
        public static func parse_channelAdminLogEventsFilter(_ reader: BufferReader) -> ChannelAdminLogEventsFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChannelAdminLogEventsFilter.channelAdminLogEventsFilter(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChannelLocation: TypeConstructorDescription {
        case channelLocation(geoPoint: Api.GeoPoint, address: String)
        case channelLocationEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelLocation(let geoPoint, let address):
                    if boxed {
                        buffer.appendInt32(547062491)
                    }
                    geoPoint.serialize(buffer, true)
                    serializeString(address, buffer: buffer, boxed: false)
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
                case .channelLocation(let geoPoint, let address):
                return ("channelLocation", [("geoPoint", geoPoint as Any), ("address", address as Any)])
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
                return Api.ChannelLocation.channelLocation(geoPoint: _1!, address: _2!)
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
        case channelMessagesFilter(flags: Int32, ranges: [Api.MessageRange])
        case channelMessagesFilterEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelMessagesFilter(let flags, let ranges):
                    if boxed {
                        buffer.appendInt32(-847783593)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ranges.count))
                    for item in ranges {
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
                case .channelMessagesFilter(let flags, let ranges):
                return ("channelMessagesFilter", [("flags", flags as Any), ("ranges", ranges as Any)])
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
                return Api.ChannelMessagesFilter.channelMessagesFilter(flags: _1!, ranges: _2!)
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
        case channelParticipant(flags: Int32, userId: Int64, date: Int32, subscriptionUntilDate: Int32?)
        case channelParticipantAdmin(flags: Int32, userId: Int64, inviterId: Int64?, promotedBy: Int64, date: Int32, adminRights: Api.ChatAdminRights, rank: String?)
        case channelParticipantBanned(flags: Int32, peer: Api.Peer, kickedBy: Int64, date: Int32, bannedRights: Api.ChatBannedRights)
        case channelParticipantCreator(flags: Int32, userId: Int64, adminRights: Api.ChatAdminRights, rank: String?)
        case channelParticipantLeft(peer: Api.Peer)
        case channelParticipantSelf(flags: Int32, userId: Int64, inviterId: Int64, date: Int32, subscriptionUntilDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipant(let flags, let userId, let date, let subscriptionUntilDate):
                    if boxed {
                        buffer.appendInt32(-885426663)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(subscriptionUntilDate!, buffer: buffer, boxed: false)}
                    break
                case .channelParticipantAdmin(let flags, let userId, let inviterId, let promotedBy, let date, let adminRights, let rank):
                    if boxed {
                        buffer.appendInt32(885242707)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(inviterId!, buffer: buffer, boxed: false)}
                    serializeInt64(promotedBy, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    adminRights.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(rank!, buffer: buffer, boxed: false)}
                    break
                case .channelParticipantBanned(let flags, let peer, let kickedBy, let date, let bannedRights):
                    if boxed {
                        buffer.appendInt32(1844969806)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt64(kickedBy, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    bannedRights.serialize(buffer, true)
                    break
                case .channelParticipantCreator(let flags, let userId, let adminRights, let rank):
                    if boxed {
                        buffer.appendInt32(803602899)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    adminRights.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(rank!, buffer: buffer, boxed: false)}
                    break
                case .channelParticipantLeft(let peer):
                    if boxed {
                        buffer.appendInt32(453242886)
                    }
                    peer.serialize(buffer, true)
                    break
                case .channelParticipantSelf(let flags, let userId, let inviterId, let date, let subscriptionUntilDate):
                    if boxed {
                        buffer.appendInt32(1331723247)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(subscriptionUntilDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipant(let flags, let userId, let date, let subscriptionUntilDate):
                return ("channelParticipant", [("flags", flags as Any), ("userId", userId as Any), ("date", date as Any), ("subscriptionUntilDate", subscriptionUntilDate as Any)])
                case .channelParticipantAdmin(let flags, let userId, let inviterId, let promotedBy, let date, let adminRights, let rank):
                return ("channelParticipantAdmin", [("flags", flags as Any), ("userId", userId as Any), ("inviterId", inviterId as Any), ("promotedBy", promotedBy as Any), ("date", date as Any), ("adminRights", adminRights as Any), ("rank", rank as Any)])
                case .channelParticipantBanned(let flags, let peer, let kickedBy, let date, let bannedRights):
                return ("channelParticipantBanned", [("flags", flags as Any), ("peer", peer as Any), ("kickedBy", kickedBy as Any), ("date", date as Any), ("bannedRights", bannedRights as Any)])
                case .channelParticipantCreator(let flags, let userId, let adminRights, let rank):
                return ("channelParticipantCreator", [("flags", flags as Any), ("userId", userId as Any), ("adminRights", adminRights as Any), ("rank", rank as Any)])
                case .channelParticipantLeft(let peer):
                return ("channelParticipantLeft", [("peer", peer as Any)])
                case .channelParticipantSelf(let flags, let userId, let inviterId, let date, let subscriptionUntilDate):
                return ("channelParticipantSelf", [("flags", flags as Any), ("userId", userId as Any), ("inviterId", inviterId as Any), ("date", date as Any), ("subscriptionUntilDate", subscriptionUntilDate as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelParticipant.channelParticipant(flags: _1!, userId: _2!, date: _3!, subscriptionUntilDate: _4)
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
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt64() }
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.ChatAdminRights?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.ChannelParticipant.channelParticipantAdmin(flags: _1!, userId: _2!, inviterId: _3, promotedBy: _4!, date: _5!, adminRights: _6!, rank: _7)
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
                return Api.ChannelParticipant.channelParticipantBanned(flags: _1!, peer: _2!, kickedBy: _3!, date: _4!, bannedRights: _5!)
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.ChannelParticipant.channelParticipantCreator(flags: _1!, userId: _2!, adminRights: _3!, rank: _4)
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
                return Api.ChannelParticipant.channelParticipantLeft(peer: _1!)
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
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.ChannelParticipant.channelParticipantSelf(flags: _1!, userId: _2!, inviterId: _3!, date: _4!, subscriptionUntilDate: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChannelParticipantsFilter: TypeConstructorDescription {
        case channelParticipantsAdmins
        case channelParticipantsBanned(q: String)
        case channelParticipantsBots
        case channelParticipantsContacts(q: String)
        case channelParticipantsKicked(q: String)
        case channelParticipantsMentions(flags: Int32, q: String?, topMsgId: Int32?)
        case channelParticipantsRecent
        case channelParticipantsSearch(q: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipantsAdmins:
                    if boxed {
                        buffer.appendInt32(-1268741783)
                    }
                    
                    break
                case .channelParticipantsBanned(let q):
                    if boxed {
                        buffer.appendInt32(338142689)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsBots:
                    if boxed {
                        buffer.appendInt32(-1328445861)
                    }
                    
                    break
                case .channelParticipantsContacts(let q):
                    if boxed {
                        buffer.appendInt32(-1150621555)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsKicked(let q):
                    if boxed {
                        buffer.appendInt32(-1548400251)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
                case .channelParticipantsMentions(let flags, let q, let topMsgId):
                    if boxed {
                        buffer.appendInt32(-531931925)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(q!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    break
                case .channelParticipantsRecent:
                    if boxed {
                        buffer.appendInt32(-566281095)
                    }
                    
                    break
                case .channelParticipantsSearch(let q):
                    if boxed {
                        buffer.appendInt32(106343499)
                    }
                    serializeString(q, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipantsAdmins:
                return ("channelParticipantsAdmins", [])
                case .channelParticipantsBanned(let q):
                return ("channelParticipantsBanned", [("q", q as Any)])
                case .channelParticipantsBots:
                return ("channelParticipantsBots", [])
                case .channelParticipantsContacts(let q):
                return ("channelParticipantsContacts", [("q", q as Any)])
                case .channelParticipantsKicked(let q):
                return ("channelParticipantsKicked", [("q", q as Any)])
                case .channelParticipantsMentions(let flags, let q, let topMsgId):
                return ("channelParticipantsMentions", [("flags", flags as Any), ("q", q as Any), ("topMsgId", topMsgId as Any)])
                case .channelParticipantsRecent:
                return ("channelParticipantsRecent", [])
                case .channelParticipantsSearch(let q):
                return ("channelParticipantsSearch", [("q", q as Any)])
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
                return Api.ChannelParticipantsFilter.channelParticipantsBanned(q: _1!)
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
                return Api.ChannelParticipantsFilter.channelParticipantsContacts(q: _1!)
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
                return Api.ChannelParticipantsFilter.channelParticipantsKicked(q: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsMentions(_ reader: BufferReader) -> ChannelParticipantsFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.ChannelParticipantsFilter.channelParticipantsMentions(flags: _1!, q: _2, topMsgId: _3)
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
                return Api.ChannelParticipantsFilter.channelParticipantsSearch(q: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum Chat: TypeConstructorDescription {
        case channel(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, title: String, username: String?, photo: Api.ChatPhoto, date: Int32, restrictionReason: [Api.RestrictionReason]?, adminRights: Api.ChatAdminRights?, bannedRights: Api.ChatBannedRights?, defaultBannedRights: Api.ChatBannedRights?, participantsCount: Int32?, usernames: [Api.Username]?, storiesMaxId: Int32?, color: Api.PeerColor?, profileColor: Api.PeerColor?, emojiStatus: Api.EmojiStatus?, level: Int32?, subscriptionUntilDate: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?)
        case channelForbidden(flags: Int32, id: Int64, accessHash: Int64, title: String, untilDate: Int32?)
        case chat(flags: Int32, id: Int64, title: String, photo: Api.ChatPhoto, participantsCount: Int32, date: Int32, version: Int32, migratedTo: Api.InputChannel?, adminRights: Api.ChatAdminRights?, defaultBannedRights: Api.ChatBannedRights?)
        case chatEmpty(id: Int64)
        case chatForbidden(id: Int64, title: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channel(let flags, let flags2, let id, let accessHash, let title, let username, let photo, let date, let restrictionReason, let adminRights, let bannedRights, let defaultBannedRights, let participantsCount, let usernames, let storiesMaxId, let color, let profileColor, let emojiStatus, let level, let subscriptionUntilDate, let botVerificationIcon, let sendPaidMessagesStars):
                    if boxed {
                        buffer.appendInt32(1954681982)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(flags2, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt64(accessHash!, buffer: buffer, boxed: false)}
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    photo.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 14) != 0 {adminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {bannedRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {defaultBannedRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(participantsCount!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(usernames!.count))
                    for item in usernames! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags2) & Int(1 << 4) != 0 {serializeInt32(storiesMaxId!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 7) != 0 {color!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 8) != 0 {profileColor!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 9) != 0 {emojiStatus!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 10) != 0 {serializeInt32(level!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 11) != 0 {serializeInt32(subscriptionUntilDate!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 13) != 0 {serializeInt64(botVerificationIcon!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 14) != 0 {serializeInt64(sendPaidMessagesStars!, buffer: buffer, boxed: false)}
                    break
                case .channelForbidden(let flags, let id, let accessHash, let title, let untilDate):
                    if boxed {
                        buffer.appendInt32(399807445)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 16) != 0 {serializeInt32(untilDate!, buffer: buffer, boxed: false)}
                    break
                case .chat(let flags, let id, let title, let photo, let participantsCount, let date, let version, let migratedTo, let adminRights, let defaultBannedRights):
                    if boxed {
                        buffer.appendInt32(1103884886)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    photo.serialize(buffer, true)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 6) != 0 {migratedTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {adminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {defaultBannedRights!.serialize(buffer, true)}
                    break
                case .chatEmpty(let id):
                    if boxed {
                        buffer.appendInt32(693512293)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .chatForbidden(let id, let title):
                    if boxed {
                        buffer.appendInt32(1704108455)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channel(let flags, let flags2, let id, let accessHash, let title, let username, let photo, let date, let restrictionReason, let adminRights, let bannedRights, let defaultBannedRights, let participantsCount, let usernames, let storiesMaxId, let color, let profileColor, let emojiStatus, let level, let subscriptionUntilDate, let botVerificationIcon, let sendPaidMessagesStars):
                return ("channel", [("flags", flags as Any), ("flags2", flags2 as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("title", title as Any), ("username", username as Any), ("photo", photo as Any), ("date", date as Any), ("restrictionReason", restrictionReason as Any), ("adminRights", adminRights as Any), ("bannedRights", bannedRights as Any), ("defaultBannedRights", defaultBannedRights as Any), ("participantsCount", participantsCount as Any), ("usernames", usernames as Any), ("storiesMaxId", storiesMaxId as Any), ("color", color as Any), ("profileColor", profileColor as Any), ("emojiStatus", emojiStatus as Any), ("level", level as Any), ("subscriptionUntilDate", subscriptionUntilDate as Any), ("botVerificationIcon", botVerificationIcon as Any), ("sendPaidMessagesStars", sendPaidMessagesStars as Any)])
                case .channelForbidden(let flags, let id, let accessHash, let title, let untilDate):
                return ("channelForbidden", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("title", title as Any), ("untilDate", untilDate as Any)])
                case .chat(let flags, let id, let title, let photo, let participantsCount, let date, let version, let migratedTo, let adminRights, let defaultBannedRights):
                return ("chat", [("flags", flags as Any), ("id", id as Any), ("title", title as Any), ("photo", photo as Any), ("participantsCount", participantsCount as Any), ("date", date as Any), ("version", version as Any), ("migratedTo", migratedTo as Any), ("adminRights", adminRights as Any), ("defaultBannedRights", defaultBannedRights as Any)])
                case .chatEmpty(let id):
                return ("chatEmpty", [("id", id as Any)])
                case .chatForbidden(let id, let title):
                return ("chatForbidden", [("id", id as Any), ("title", title as Any)])
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
            if Int(_1!) & Int(1 << 13) != 0 {_4 = reader.readInt64() }
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1!) & Int(1 << 6) != 0 {_6 = parseString(reader) }
            var _7: Api.ChatPhoto?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChatPhoto
            }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 9) != 0 {if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _10: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _11: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
            var _12: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {_13 = reader.readInt32() }
            var _14: [Api.Username]?
            if Int(_2!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
            } }
            var _15: Int32?
            if Int(_2!) & Int(1 << 4) != 0 {_15 = reader.readInt32() }
            var _16: Api.PeerColor?
            if Int(_2!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.PeerColor
            } }
            var _17: Api.PeerColor?
            if Int(_2!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.PeerColor
            } }
            var _18: Api.EmojiStatus?
            if Int(_2!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            } }
            var _19: Int32?
            if Int(_2!) & Int(1 << 10) != 0 {_19 = reader.readInt32() }
            var _20: Int32?
            if Int(_2!) & Int(1 << 11) != 0 {_20 = reader.readInt32() }
            var _21: Int64?
            if Int(_2!) & Int(1 << 13) != 0 {_21 = reader.readInt64() }
            var _22: Int64?
            if Int(_2!) & Int(1 << 14) != 0 {_22 = reader.readInt64() }
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.Chat.channel(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, title: _5!, username: _6, photo: _7!, date: _8!, restrictionReason: _9, adminRights: _10, bannedRights: _11, defaultBannedRights: _12, participantsCount: _13, usernames: _14, storiesMaxId: _15, color: _16, profileColor: _17, emojiStatus: _18, level: _19, subscriptionUntilDate: _20, botVerificationIcon: _21, sendPaidMessagesStars: _22)
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
            if Int(_1!) & Int(1 << 16) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 16) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Chat.channelForbidden(flags: _1!, id: _2!, accessHash: _3!, title: _4!, untilDate: _5)
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
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.InputChannel
            } }
            var _9: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 14) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _10: Api.ChatBannedRights?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            } }
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
                return Api.Chat.chat(flags: _1!, id: _2!, title: _3!, photo: _4!, participantsCount: _5!, date: _6!, version: _7!, migratedTo: _8, adminRights: _9, defaultBannedRights: _10)
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
                return Api.Chat.chatEmpty(id: _1!)
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
                return Api.Chat.chatForbidden(id: _1!, title: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatAdminRights: TypeConstructorDescription {
        case chatAdminRights(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatAdminRights(let flags):
                    if boxed {
                        buffer.appendInt32(1605510357)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatAdminRights(let flags):
                return ("chatAdminRights", [("flags", flags as Any)])
    }
    }
    
        public static func parse_chatAdminRights(_ reader: BufferReader) -> ChatAdminRights? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.ChatAdminRights.chatAdminRights(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatAdminWithInvites: TypeConstructorDescription {
        case chatAdminWithInvites(adminId: Int64, invitesCount: Int32, revokedInvitesCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatAdminWithInvites(let adminId, let invitesCount, let revokedInvitesCount):
                    if boxed {
                        buffer.appendInt32(-219353309)
                    }
                    serializeInt64(adminId, buffer: buffer, boxed: false)
                    serializeInt32(invitesCount, buffer: buffer, boxed: false)
                    serializeInt32(revokedInvitesCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatAdminWithInvites(let adminId, let invitesCount, let revokedInvitesCount):
                return ("chatAdminWithInvites", [("adminId", adminId as Any), ("invitesCount", invitesCount as Any), ("revokedInvitesCount", revokedInvitesCount as Any)])
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
                return Api.ChatAdminWithInvites.chatAdminWithInvites(adminId: _1!, invitesCount: _2!, revokedInvitesCount: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatBannedRights: TypeConstructorDescription {
        case chatBannedRights(flags: Int32, untilDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatBannedRights(let flags, let untilDate):
                    if boxed {
                        buffer.appendInt32(-1626209256)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatBannedRights(let flags, let untilDate):
                return ("chatBannedRights", [("flags", flags as Any), ("untilDate", untilDate as Any)])
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
                return Api.ChatBannedRights.chatBannedRights(flags: _1!, untilDate: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ChatFull: TypeConstructorDescription {
        case channelFull(flags: Int32, flags2: Int32, id: Int64, about: String, participantsCount: Int32?, adminsCount: Int32?, kickedCount: Int32?, bannedCount: Int32?, onlineCount: Int32?, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, chatPhoto: Api.Photo, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo], migratedFromChatId: Int64?, migratedFromMaxId: Int32?, pinnedMsgId: Int32?, stickerset: Api.StickerSet?, availableMinId: Int32?, folderId: Int32?, linkedChatId: Int64?, location: Api.ChannelLocation?, slowmodeSeconds: Int32?, slowmodeNextSendDate: Int32?, statsDc: Int32?, pts: Int32, call: Api.InputGroupCall?, ttlPeriod: Int32?, pendingSuggestions: [String]?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, defaultSendAs: Api.Peer?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?, stories: Api.PeerStories?, wallpaper: Api.WallPaper?, boostsApplied: Int32?, boostsUnrestrict: Int32?, emojiset: Api.StickerSet?, botVerification: Api.BotVerification?, stargiftsCount: Int32?)
        case chatFull(flags: Int32, id: Int64, about: String, participants: Api.ChatParticipants, chatPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, exportedInvite: Api.ExportedChatInvite?, botInfo: [Api.BotInfo]?, pinnedMsgId: Int32?, folderId: Int32?, call: Api.InputGroupCall?, ttlPeriod: Int32?, groupcallDefaultJoinAs: Api.Peer?, themeEmoticon: String?, requestsPending: Int32?, recentRequesters: [Int64]?, availableReactions: Api.ChatReactions?, reactionsLimit: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelFull(let flags, let flags2, let id, let about, let participantsCount, let adminsCount, let kickedCount, let bannedCount, let onlineCount, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let migratedFromChatId, let migratedFromMaxId, let pinnedMsgId, let stickerset, let availableMinId, let folderId, let linkedChatId, let location, let slowmodeSeconds, let slowmodeNextSendDate, let statsDc, let pts, let call, let ttlPeriod, let pendingSuggestions, let groupcallDefaultJoinAs, let themeEmoticon, let requestsPending, let recentRequesters, let defaultSendAs, let availableReactions, let reactionsLimit, let stories, let wallpaper, let boostsApplied, let boostsUnrestrict, let emojiset, let botVerification, let stargiftsCount):
                    if boxed {
                        buffer.appendInt32(1389789291)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(flags2, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(participantsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(adminsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(kickedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(bannedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {serializeInt32(onlineCount!, buffer: buffer, boxed: false)}
                    serializeInt32(readInboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(readOutboxMaxId, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    chatPhoto.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 23) != 0 {exportedInvite!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(botInfo.count))
                    for item in botInfo {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(migratedFromChatId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(migratedFromMaxId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {stickerset!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 9) != 0 {serializeInt32(availableMinId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt64(linkedChatId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {location!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(slowmodeSeconds!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 18) != 0 {serializeInt32(slowmodeNextSendDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 12) != 0 {serializeInt32(statsDc!, buffer: buffer, boxed: false)}
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 21) != 0 {call!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 24) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 25) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(pendingSuggestions!.count))
                    for item in pendingSuggestions! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 26) != 0 {groupcallDefaultJoinAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 27) != 0 {serializeString(themeEmoticon!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 28) != 0 {serializeInt32(requestsPending!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 28) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentRequesters!.count))
                    for item in recentRequesters! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 29) != 0 {defaultSendAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 30) != 0 {availableReactions!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 13) != 0 {serializeInt32(reactionsLimit!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 4) != 0 {stories!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 7) != 0 {wallpaper!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 8) != 0 {serializeInt32(boostsApplied!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 9) != 0 {serializeInt32(boostsUnrestrict!, buffer: buffer, boxed: false)}
                    if Int(flags2) & Int(1 << 10) != 0 {emojiset!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 17) != 0 {botVerification!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 18) != 0 {serializeInt32(stargiftsCount!, buffer: buffer, boxed: false)}
                    break
                case .chatFull(let flags, let id, let about, let participants, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let pinnedMsgId, let folderId, let call, let ttlPeriod, let groupcallDefaultJoinAs, let themeEmoticon, let requestsPending, let recentRequesters, let availableReactions, let reactionsLimit):
                    if boxed {
                        buffer.appendInt32(640893467)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    participants.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {chatPhoto!.serialize(buffer, true)}
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 13) != 0 {exportedInvite!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(botInfo!.count))
                    for item in botInfo! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 12) != 0 {call!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {groupcallDefaultJoinAs!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(themeEmoticon!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt32(requestsPending!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentRequesters!.count))
                    for item in recentRequesters! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 18) != 0 {availableReactions!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 20) != 0 {serializeInt32(reactionsLimit!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelFull(let flags, let flags2, let id, let about, let participantsCount, let adminsCount, let kickedCount, let bannedCount, let onlineCount, let readInboxMaxId, let readOutboxMaxId, let unreadCount, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let migratedFromChatId, let migratedFromMaxId, let pinnedMsgId, let stickerset, let availableMinId, let folderId, let linkedChatId, let location, let slowmodeSeconds, let slowmodeNextSendDate, let statsDc, let pts, let call, let ttlPeriod, let pendingSuggestions, let groupcallDefaultJoinAs, let themeEmoticon, let requestsPending, let recentRequesters, let defaultSendAs, let availableReactions, let reactionsLimit, let stories, let wallpaper, let boostsApplied, let boostsUnrestrict, let emojiset, let botVerification, let stargiftsCount):
                return ("channelFull", [("flags", flags as Any), ("flags2", flags2 as Any), ("id", id as Any), ("about", about as Any), ("participantsCount", participantsCount as Any), ("adminsCount", adminsCount as Any), ("kickedCount", kickedCount as Any), ("bannedCount", bannedCount as Any), ("onlineCount", onlineCount as Any), ("readInboxMaxId", readInboxMaxId as Any), ("readOutboxMaxId", readOutboxMaxId as Any), ("unreadCount", unreadCount as Any), ("chatPhoto", chatPhoto as Any), ("notifySettings", notifySettings as Any), ("exportedInvite", exportedInvite as Any), ("botInfo", botInfo as Any), ("migratedFromChatId", migratedFromChatId as Any), ("migratedFromMaxId", migratedFromMaxId as Any), ("pinnedMsgId", pinnedMsgId as Any), ("stickerset", stickerset as Any), ("availableMinId", availableMinId as Any), ("folderId", folderId as Any), ("linkedChatId", linkedChatId as Any), ("location", location as Any), ("slowmodeSeconds", slowmodeSeconds as Any), ("slowmodeNextSendDate", slowmodeNextSendDate as Any), ("statsDc", statsDc as Any), ("pts", pts as Any), ("call", call as Any), ("ttlPeriod", ttlPeriod as Any), ("pendingSuggestions", pendingSuggestions as Any), ("groupcallDefaultJoinAs", groupcallDefaultJoinAs as Any), ("themeEmoticon", themeEmoticon as Any), ("requestsPending", requestsPending as Any), ("recentRequesters", recentRequesters as Any), ("defaultSendAs", defaultSendAs as Any), ("availableReactions", availableReactions as Any), ("reactionsLimit", reactionsLimit as Any), ("stories", stories as Any), ("wallpaper", wallpaper as Any), ("boostsApplied", boostsApplied as Any), ("boostsUnrestrict", boostsUnrestrict as Any), ("emojiset", emojiset as Any), ("botVerification", botVerification as Any), ("stargiftsCount", stargiftsCount as Any)])
                case .chatFull(let flags, let id, let about, let participants, let chatPhoto, let notifySettings, let exportedInvite, let botInfo, let pinnedMsgId, let folderId, let call, let ttlPeriod, let groupcallDefaultJoinAs, let themeEmoticon, let requestsPending, let recentRequesters, let availableReactions, let reactionsLimit):
                return ("chatFull", [("flags", flags as Any), ("id", id as Any), ("about", about as Any), ("participants", participants as Any), ("chatPhoto", chatPhoto as Any), ("notifySettings", notifySettings as Any), ("exportedInvite", exportedInvite as Any), ("botInfo", botInfo as Any), ("pinnedMsgId", pinnedMsgId as Any), ("folderId", folderId as Any), ("call", call as Any), ("ttlPeriod", ttlPeriod as Any), ("groupcallDefaultJoinAs", groupcallDefaultJoinAs as Any), ("themeEmoticon", themeEmoticon as Any), ("requestsPending", requestsPending as Any), ("recentRequesters", recentRequesters as Any), ("availableReactions", availableReactions as Any), ("reactionsLimit", reactionsLimit as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = reader.readInt32() }
            var _8: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            if Int(_1!) & Int(1 << 13) != 0 {_9 = reader.readInt32() }
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
            if Int(_1!) & Int(1 << 23) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _16: [Api.BotInfo]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
            }
            var _17: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_17 = reader.readInt64() }
            var _18: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_18 = reader.readInt32() }
            var _19: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_19 = reader.readInt32() }
            var _20: Api.StickerSet?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.StickerSet
            } }
            var _21: Int32?
            if Int(_1!) & Int(1 << 9) != 0 {_21 = reader.readInt32() }
            var _22: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_22 = reader.readInt32() }
            var _23: Int64?
            if Int(_1!) & Int(1 << 14) != 0 {_23 = reader.readInt64() }
            var _24: Api.ChannelLocation?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _24 = Api.parse(reader, signature: signature) as? Api.ChannelLocation
            } }
            var _25: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {_25 = reader.readInt32() }
            var _26: Int32?
            if Int(_1!) & Int(1 << 18) != 0 {_26 = reader.readInt32() }
            var _27: Int32?
            if Int(_1!) & Int(1 << 12) != 0 {_27 = reader.readInt32() }
            var _28: Int32?
            _28 = reader.readInt32()
            var _29: Api.InputGroupCall?
            if Int(_1!) & Int(1 << 21) != 0 {if let signature = reader.readInt32() {
                _29 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            } }
            var _30: Int32?
            if Int(_1!) & Int(1 << 24) != 0 {_30 = reader.readInt32() }
            var _31: [String]?
            if Int(_1!) & Int(1 << 25) != 0 {if let _ = reader.readInt32() {
                _31 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _32: Api.Peer?
            if Int(_1!) & Int(1 << 26) != 0 {if let signature = reader.readInt32() {
                _32 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _33: String?
            if Int(_1!) & Int(1 << 27) != 0 {_33 = parseString(reader) }
            var _34: Int32?
            if Int(_1!) & Int(1 << 28) != 0 {_34 = reader.readInt32() }
            var _35: [Int64]?
            if Int(_1!) & Int(1 << 28) != 0 {if let _ = reader.readInt32() {
                _35 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            var _36: Api.Peer?
            if Int(_1!) & Int(1 << 29) != 0 {if let signature = reader.readInt32() {
                _36 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _37: Api.ChatReactions?
            if Int(_1!) & Int(1 << 30) != 0 {if let signature = reader.readInt32() {
                _37 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            } }
            var _38: Int32?
            if Int(_2!) & Int(1 << 13) != 0 {_38 = reader.readInt32() }
            var _39: Api.PeerStories?
            if Int(_2!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _39 = Api.parse(reader, signature: signature) as? Api.PeerStories
            } }
            var _40: Api.WallPaper?
            if Int(_2!) & Int(1 << 7) != 0 {if let signature = reader.readInt32() {
                _40 = Api.parse(reader, signature: signature) as? Api.WallPaper
            } }
            var _41: Int32?
            if Int(_2!) & Int(1 << 8) != 0 {_41 = reader.readInt32() }
            var _42: Int32?
            if Int(_2!) & Int(1 << 9) != 0 {_42 = reader.readInt32() }
            var _43: Api.StickerSet?
            if Int(_2!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _43 = Api.parse(reader, signature: signature) as? Api.StickerSet
            } }
            var _44: Api.BotVerification?
            if Int(_2!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _44 = Api.parse(reader, signature: signature) as? Api.BotVerification
            } }
            var _45: Int32?
            if Int(_2!) & Int(1 << 18) != 0 {_45 = reader.readInt32() }
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 && _c23 && _c24 && _c25 && _c26 && _c27 && _c28 && _c29 && _c30 && _c31 && _c32 && _c33 && _c34 && _c35 && _c36 && _c37 && _c38 && _c39 && _c40 && _c41 && _c42 && _c43 && _c44 && _c45 {
                return Api.ChatFull.channelFull(flags: _1!, flags2: _2!, id: _3!, about: _4!, participantsCount: _5, adminsCount: _6, kickedCount: _7, bannedCount: _8, onlineCount: _9, readInboxMaxId: _10!, readOutboxMaxId: _11!, unreadCount: _12!, chatPhoto: _13!, notifySettings: _14!, exportedInvite: _15, botInfo: _16!, migratedFromChatId: _17, migratedFromMaxId: _18, pinnedMsgId: _19, stickerset: _20, availableMinId: _21, folderId: _22, linkedChatId: _23, location: _24, slowmodeSeconds: _25, slowmodeNextSendDate: _26, statsDc: _27, pts: _28!, call: _29, ttlPeriod: _30, pendingSuggestions: _31, groupcallDefaultJoinAs: _32, themeEmoticon: _33, requestsPending: _34, recentRequesters: _35, defaultSendAs: _36, availableReactions: _37, reactionsLimit: _38, stories: _39, wallpaper: _40, boostsApplied: _41, boostsUnrestrict: _42, emojiset: _43, botVerification: _44, stargiftsCount: _45)
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
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _6: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _7: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 13) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _8: [Api.BotInfo]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotInfo.self)
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_9 = reader.readInt32() }
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt32() }
            var _11: Api.InputGroupCall?
            if Int(_1!) & Int(1 << 12) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            } }
            var _12: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_12 = reader.readInt32() }
            var _13: Api.Peer?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _14: String?
            if Int(_1!) & Int(1 << 16) != 0 {_14 = parseString(reader) }
            var _15: Int32?
            if Int(_1!) & Int(1 << 17) != 0 {_15 = reader.readInt32() }
            var _16: [Int64]?
            if Int(_1!) & Int(1 << 17) != 0 {if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            var _17: Api.ChatReactions?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.ChatReactions
            } }
            var _18: Int32?
            if Int(_1!) & Int(1 << 20) != 0 {_18 = reader.readInt32() }
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
                return Api.ChatFull.chatFull(flags: _1!, id: _2!, about: _3!, participants: _4!, chatPhoto: _5, notifySettings: _6!, exportedInvite: _7, botInfo: _8, pinnedMsgId: _9, folderId: _10, call: _11, ttlPeriod: _12, groupcallDefaultJoinAs: _13, themeEmoticon: _14, requestsPending: _15, recentRequesters: _16, availableReactions: _17, reactionsLimit: _18)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum ChatInvite: TypeConstructorDescription {
        case chatInvite(flags: Int32, title: String, about: String?, photo: Api.Photo, participantsCount: Int32, participants: [Api.User]?, color: Int32, subscriptionPricing: Api.StarsSubscriptionPricing?, subscriptionFormId: Int64?, botVerification: Api.BotVerification?)
        case chatInviteAlready(chat: Api.Chat)
        case chatInvitePeek(chat: Api.Chat, expires: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .chatInvite(let flags, let title, let about, let photo, let participantsCount, let participants, let color, let subscriptionPricing, let subscriptionFormId, let botVerification):
                    if boxed {
                        buffer.appendInt32(1553807106)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    photo.serialize(buffer, true)
                    serializeInt32(participantsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants!.count))
                    for item in participants! {
                        item.serialize(buffer, true)
                    }}
                    serializeInt32(color, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 10) != 0 {subscriptionPricing!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 12) != 0 {serializeInt64(subscriptionFormId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 13) != 0 {botVerification!.serialize(buffer, true)}
                    break
                case .chatInviteAlready(let chat):
                    if boxed {
                        buffer.appendInt32(1516793212)
                    }
                    chat.serialize(buffer, true)
                    break
                case .chatInvitePeek(let chat, let expires):
                    if boxed {
                        buffer.appendInt32(1634294960)
                    }
                    chat.serialize(buffer, true)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .chatInvite(let flags, let title, let about, let photo, let participantsCount, let participants, let color, let subscriptionPricing, let subscriptionFormId, let botVerification):
                return ("chatInvite", [("flags", flags as Any), ("title", title as Any), ("about", about as Any), ("photo", photo as Any), ("participantsCount", participantsCount as Any), ("participants", participants as Any), ("color", color as Any), ("subscriptionPricing", subscriptionPricing as Any), ("subscriptionFormId", subscriptionFormId as Any), ("botVerification", botVerification as Any)])
                case .chatInviteAlready(let chat):
                return ("chatInviteAlready", [("chat", chat as Any)])
                case .chatInvitePeek(let chat, let expires):
                return ("chatInvitePeek", [("chat", chat as Any), ("expires", expires as Any)])
    }
    }
    
        public static func parse_chatInvite(_ reader: BufferReader) -> ChatInvite? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 5) != 0 {_3 = parseString(reader) }
            var _4: Api.Photo?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.User]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            } }
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.StarsSubscriptionPricing?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StarsSubscriptionPricing
            } }
            var _9: Int64?
            if Int(_1!) & Int(1 << 12) != 0 {_9 = reader.readInt64() }
            var _10: Api.BotVerification?
            if Int(_1!) & Int(1 << 13) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.BotVerification
            } }
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
                return Api.ChatInvite.chatInvite(flags: _1!, title: _2!, about: _3, photo: _4!, participantsCount: _5!, participants: _6, color: _7!, subscriptionPricing: _8, subscriptionFormId: _9, botVerification: _10)
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
                return Api.ChatInvite.chatInviteAlready(chat: _1!)
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
                return Api.ChatInvite.chatInvitePeek(chat: _1!, expires: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
