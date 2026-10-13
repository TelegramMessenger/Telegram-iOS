public extension Api {
    enum GeoPoint: TypeConstructorDescription {
        public class Cons_geoPoint: TypeConstructorDescription {
            public var flags: Int32
            public var long: Double
            public var lat: Double
            public var accessHash: Int64
            public var accuracyRadius: Int32?
            public init(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?) {
                self.flags = flags
                self.long = long
                self.lat = lat
                self.accessHash = accessHash
                self.accuracyRadius = accuracyRadius
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("geoPoint", [("flags", ConstructorParameterDescription(self.flags)), ("long", ConstructorParameterDescription(self.long)), ("lat", ConstructorParameterDescription(self.lat)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("accuracyRadius", ConstructorParameterDescription(self.accuracyRadius))])
            }
        }
        case geoPoint(Cons_geoPoint)
        case geoPointEmpty

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .geoPoint(let _data):
                if boxed {
                    buffer.appendInt32(-1297942941)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeDouble(_data.long, buffer: buffer, boxed: false)
                serializeDouble(_data.lat, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.accuracyRadius!, buffer: buffer, boxed: false)
                }
                break
            case .geoPointEmpty:
                if boxed {
                    buffer.appendInt32(286776671)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .geoPoint(let _data):
                return ("geoPoint", [("flags", ConstructorParameterDescription(_data.flags)), ("long", ConstructorParameterDescription(_data.long)), ("lat", ConstructorParameterDescription(_data.lat)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("accuracyRadius", ConstructorParameterDescription(_data.accuracyRadius))])
            case .geoPointEmpty:
                return ("geoPointEmpty", [])
            }
        }

        public static func parse_geoPoint(_ reader: BufferReader) -> GeoPoint? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPoint.geoPoint(Cons_geoPoint(flags: _1!, long: _2!, lat: _3!, accessHash: _4!, accuracyRadius: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_geoPointEmpty(_ reader: BufferReader) -> GeoPoint? {
            return Api.GeoPoint.geoPointEmpty
        }
    }
}
public extension Api {
    enum GeoPointAddress: TypeConstructorDescription {
        public class Cons_geoPointAddress: TypeConstructorDescription {
            public var flags: Int32
            public var countryIso2: String
            public var state: String?
            public var city: String?
            public var street: String?
            public init(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?) {
                self.flags = flags
                self.countryIso2 = countryIso2
                self.state = state
                self.city = city
                self.street = street
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("geoPointAddress", [("flags", ConstructorParameterDescription(self.flags)), ("countryIso2", ConstructorParameterDescription(self.countryIso2)), ("state", ConstructorParameterDescription(self.state)), ("city", ConstructorParameterDescription(self.city)), ("street", ConstructorParameterDescription(self.street))])
            }
        }
        case geoPointAddress(Cons_geoPointAddress)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .geoPointAddress(let _data):
                if boxed {
                    buffer.appendInt32(-565420653)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.countryIso2, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.state!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.city!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.street!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .geoPointAddress(let _data):
                return ("geoPointAddress", [("flags", ConstructorParameterDescription(_data.flags)), ("countryIso2", ConstructorParameterDescription(_data.countryIso2)), ("state", ConstructorParameterDescription(_data.state)), ("city", ConstructorParameterDescription(_data.city)), ("street", ConstructorParameterDescription(_data.street))])
            }
        }

        public static func parse_geoPointAddress(_ reader: BufferReader) -> GeoPointAddress? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseString(reader)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.GeoPointAddress.geoPointAddress(Cons_geoPointAddress(flags: _1!, countryIso2: _2!, state: _3, city: _4, street: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription {
        public class Cons_globalPrivacySettings: TypeConstructorDescription {
            public var flags: Int32
            public var noncontactPeersPaidStars: Int64?
            public var disallowedGifts: Api.DisallowedGiftsSettings?
            public init(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?) {
                self.flags = flags
                self.noncontactPeersPaidStars = noncontactPeersPaidStars
                self.disallowedGifts = disallowedGifts
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("globalPrivacySettings", [("flags", ConstructorParameterDescription(self.flags)), ("noncontactPeersPaidStars", ConstructorParameterDescription(self.noncontactPeersPaidStars)), ("disallowedGifts", ConstructorParameterDescription(self.disallowedGifts))])
            }
        }
        case globalPrivacySettings(Cons_globalPrivacySettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .globalPrivacySettings(let _data):
                if boxed {
                    buffer.appendInt32(-29248689)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt64(_data.noncontactPeersPaidStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.disallowedGifts!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .globalPrivacySettings(let _data):
                return ("globalPrivacySettings", [("flags", ConstructorParameterDescription(_data.flags)), ("noncontactPeersPaidStars", ConstructorParameterDescription(_data.noncontactPeersPaidStars)), ("disallowedGifts", ConstructorParameterDescription(_data.disallowedGifts))])
            }
        }

        public static func parse_globalPrivacySettings(_ reader: BufferReader) -> GlobalPrivacySettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _2 = reader.readInt64()
            }
            var _3: Api.DisallowedGiftsSettings?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.DisallowedGiftsSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GlobalPrivacySettings.globalPrivacySettings(Cons_globalPrivacySettings(flags: _1!, noncontactPeersPaidStars: _2, disallowedGifts: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription {
        public class Cons_groupCall: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int64
            public var accessHash: Int64
            public var participantsCount: Int32
            public var title: String?
            public var streamDcId: Int32?
            public var recordStartDate: Int32?
            public var scheduleDate: Int32?
            public var unmutedVideoCount: Int32?
            public var unmutedVideoLimit: Int32
            public var version: Int32
            public var inviteLink: String?
            public var sendPaidMessagesStars: Int64?
            public var defaultSendAs: Api.Peer?
            public init(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?, sendPaidMessagesStars: Int64?, defaultSendAs: Api.Peer?) {
                self.flags = flags
                self.id = id
                self.accessHash = accessHash
                self.participantsCount = participantsCount
                self.title = title
                self.streamDcId = streamDcId
                self.recordStartDate = recordStartDate
                self.scheduleDate = scheduleDate
                self.unmutedVideoCount = unmutedVideoCount
                self.unmutedVideoLimit = unmutedVideoLimit
                self.version = version
                self.inviteLink = inviteLink
                self.sendPaidMessagesStars = sendPaidMessagesStars
                self.defaultSendAs = defaultSendAs
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCall", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("participantsCount", ConstructorParameterDescription(self.participantsCount)), ("title", ConstructorParameterDescription(self.title)), ("streamDcId", ConstructorParameterDescription(self.streamDcId)), ("recordStartDate", ConstructorParameterDescription(self.recordStartDate)), ("scheduleDate", ConstructorParameterDescription(self.scheduleDate)), ("unmutedVideoCount", ConstructorParameterDescription(self.unmutedVideoCount)), ("unmutedVideoLimit", ConstructorParameterDescription(self.unmutedVideoLimit)), ("version", ConstructorParameterDescription(self.version)), ("inviteLink", ConstructorParameterDescription(self.inviteLink)), ("sendPaidMessagesStars", ConstructorParameterDescription(self.sendPaidMessagesStars)), ("defaultSendAs", ConstructorParameterDescription(self.defaultSendAs))])
            }
        }
        public class Cons_groupCallDiscarded: TypeConstructorDescription {
            public var id: Int64
            public var accessHash: Int64
            public var duration: Int32
            public init(id: Int64, accessHash: Int64, duration: Int32) {
                self.id = id
                self.accessHash = accessHash
                self.duration = duration
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallDiscarded", [("id", ConstructorParameterDescription(self.id)), ("accessHash", ConstructorParameterDescription(self.accessHash)), ("duration", ConstructorParameterDescription(self.duration))])
            }
        }
        case groupCall(Cons_groupCall)
        case groupCallDiscarded(Cons_groupCallDiscarded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCall(let _data):
                if boxed {
                    buffer.appendInt32(-273500649)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.participantsCount, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.title!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.streamDcId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.recordStartDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.scheduleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.unmutedVideoCount!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.unmutedVideoLimit, buffer: buffer, boxed: false)
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeString(_data.inviteLink!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 20) != 0 {
                    serializeInt64(_data.sendPaidMessagesStars!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 21) != 0 {
                    _data.defaultSendAs!.serialize(buffer, true)
                }
                break
            case .groupCallDiscarded(let _data):
                if boxed {
                    buffer.appendInt32(2004925620)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeInt64(_data.accessHash, buffer: buffer, boxed: false)
                serializeInt32(_data.duration, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCall(let _data):
                return ("groupCall", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("participantsCount", ConstructorParameterDescription(_data.participantsCount)), ("title", ConstructorParameterDescription(_data.title)), ("streamDcId", ConstructorParameterDescription(_data.streamDcId)), ("recordStartDate", ConstructorParameterDescription(_data.recordStartDate)), ("scheduleDate", ConstructorParameterDescription(_data.scheduleDate)), ("unmutedVideoCount", ConstructorParameterDescription(_data.unmutedVideoCount)), ("unmutedVideoLimit", ConstructorParameterDescription(_data.unmutedVideoLimit)), ("version", ConstructorParameterDescription(_data.version)), ("inviteLink", ConstructorParameterDescription(_data.inviteLink)), ("sendPaidMessagesStars", ConstructorParameterDescription(_data.sendPaidMessagesStars)), ("defaultSendAs", ConstructorParameterDescription(_data.defaultSendAs))])
            case .groupCallDiscarded(let _data):
                return ("groupCallDiscarded", [("id", ConstructorParameterDescription(_data.id)), ("accessHash", ConstructorParameterDescription(_data.accessHash)), ("duration", ConstructorParameterDescription(_data.duration))])
            }
        }

        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int32?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _8 = reader.readInt32()
            }
            var _9: Int32?
            if Int(_1 ?? 0) & Int(1 << 10) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            _10 = reader.readInt32()
            var _11: Int32?
            _11 = reader.readInt32()
            var _12: String?
            if Int(_1 ?? 0) & Int(1 << 16) != 0 {
                _12 = parseString(reader)
            }
            var _13: Int64?
            if Int(_1 ?? 0) & Int(1 << 20) != 0 {
                _13 = reader.readInt64()
            }
            var _14: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 21) != 0 {
                if let signature = reader.readInt32() {
                    _14 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = (Int(_1 ?? 0) & Int(1 << 16) == 0) || _12 != nil
            let _c13 = (Int(_1 ?? 0) & Int(1 << 20) == 0) || _13 != nil
            let _c14 = (Int(_1 ?? 0) & Int(1 << 21) == 0) || _14 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 {
                return Api.GroupCall.groupCall(Cons_groupCall(flags: _1!, id: _2!, accessHash: _3!, participantsCount: _4!, title: _5, streamDcId: _6, recordStartDate: _7, scheduleDate: _8, unmutedVideoCount: _9, unmutedVideoLimit: _10!, version: _11!, inviteLink: _12, sendPaidMessagesStars: _13, defaultSendAs: _14))
            }
            else {
                return nil
            }
        }
        public static func parse_groupCallDiscarded(_ reader: BufferReader) -> GroupCall? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCall.groupCallDiscarded(Cons_groupCallDiscarded(id: _1!, accessHash: _2!, duration: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallDonor: TypeConstructorDescription {
        public class Cons_groupCallDonor: TypeConstructorDescription {
            public var flags: Int32
            public var peerId: Api.Peer?
            public var stars: Int64
            public init(flags: Int32, peerId: Api.Peer?, stars: Int64) {
                self.flags = flags
                self.peerId = peerId
                self.stars = stars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallDonor", [("flags", ConstructorParameterDescription(self.flags)), ("peerId", ConstructorParameterDescription(self.peerId)), ("stars", ConstructorParameterDescription(self.stars))])
            }
        }
        case groupCallDonor(Cons_groupCallDonor)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallDonor(let _data):
                if boxed {
                    buffer.appendInt32(-297595771)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.peerId!.serialize(buffer, true)
                }
                serializeInt64(_data.stars, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallDonor(let _data):
                return ("groupCallDonor", [("flags", ConstructorParameterDescription(_data.flags)), ("peerId", ConstructorParameterDescription(_data.peerId)), ("stars", ConstructorParameterDescription(_data.stars))])
            }
        }

        public static func parse_groupCallDonor(_ reader: BufferReader) -> GroupCallDonor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int64?
            _3 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.GroupCallDonor.groupCallDonor(Cons_groupCallDonor(flags: _1!, peerId: _2, stars: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallMessage: TypeConstructorDescription {
        public class Cons_groupCallMessage: TypeConstructorDescription {
            public var flags: Int32
            public var id: Int32
            public var fromId: Api.Peer
            public var date: Int32
            public var message: Api.TextWithEntities
            public var paidMessageStars: Int64?
            public init(flags: Int32, id: Int32, fromId: Api.Peer, date: Int32, message: Api.TextWithEntities, paidMessageStars: Int64?) {
                self.flags = flags
                self.id = id
                self.fromId = fromId
                self.date = date
                self.message = message
                self.paidMessageStars = paidMessageStars
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallMessage", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("fromId", ConstructorParameterDescription(self.fromId)), ("date", ConstructorParameterDescription(self.date)), ("message", ConstructorParameterDescription(self.message)), ("paidMessageStars", ConstructorParameterDescription(self.paidMessageStars))])
            }
        }
        case groupCallMessage(Cons_groupCallMessage)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallMessage(let _data):
                if boxed {
                    buffer.appendInt32(445316222)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.id, buffer: buffer, boxed: false)
                _data.fromId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.message.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.paidMessageStars!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallMessage(let _data):
                return ("groupCallMessage", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("fromId", ConstructorParameterDescription(_data.fromId)), ("date", ConstructorParameterDescription(_data.date)), ("message", ConstructorParameterDescription(_data.message)), ("paidMessageStars", ConstructorParameterDescription(_data.paidMessageStars))])
            }
        }

        public static func parse_groupCallMessage(_ reader: BufferReader) -> GroupCallMessage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _6: Int64?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _6 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.GroupCallMessage.groupCallMessage(Cons_groupCallMessage(flags: _1!, id: _2!, fromId: _3!, date: _4!, message: _5!, paidMessageStars: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription {
        public class Cons_groupCallParticipant: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var date: Int32
            public var activeDate: Int32?
            public var source: Int32
            public var volume: Int32?
            public var about: String?
            public var raiseHandRating: Int64?
            public var video: Api.GroupCallParticipantVideo?
            public var presentation: Api.GroupCallParticipantVideo?
            public var paidStarsTotal: Int64?
            public init(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?, paidStarsTotal: Int64?) {
                self.flags = flags
                self.peer = peer
                self.date = date
                self.activeDate = activeDate
                self.source = source
                self.volume = volume
                self.about = about
                self.raiseHandRating = raiseHandRating
                self.video = video
                self.presentation = presentation
                self.paidStarsTotal = paidStarsTotal
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallParticipant", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("date", ConstructorParameterDescription(self.date)), ("activeDate", ConstructorParameterDescription(self.activeDate)), ("source", ConstructorParameterDescription(self.source)), ("volume", ConstructorParameterDescription(self.volume)), ("about", ConstructorParameterDescription(self.about)), ("raiseHandRating", ConstructorParameterDescription(self.raiseHandRating)), ("video", ConstructorParameterDescription(self.video)), ("presentation", ConstructorParameterDescription(self.presentation)), ("paidStarsTotal", ConstructorParameterDescription(self.paidStarsTotal))])
            }
        }
        case groupCallParticipant(Cons_groupCallParticipant)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipant(let _data):
                if boxed {
                    buffer.appendInt32(708691884)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.activeDate!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.source, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    serializeInt32(_data.volume!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeString(_data.about!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 13) != 0 {
                    serializeInt64(_data.raiseHandRating!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    _data.video!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 14) != 0 {
                    _data.presentation!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 16) != 0 {
                    serializeInt64(_data.paidStarsTotal!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallParticipant(let _data):
                return ("groupCallParticipant", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("date", ConstructorParameterDescription(_data.date)), ("activeDate", ConstructorParameterDescription(_data.activeDate)), ("source", ConstructorParameterDescription(_data.source)), ("volume", ConstructorParameterDescription(_data.volume)), ("about", ConstructorParameterDescription(_data.about)), ("raiseHandRating", ConstructorParameterDescription(_data.raiseHandRating)), ("video", ConstructorParameterDescription(_data.video)), ("presentation", ConstructorParameterDescription(_data.presentation)), ("paidStarsTotal", ConstructorParameterDescription(_data.paidStarsTotal))])
            }
        }

        public static func parse_groupCallParticipant(_ reader: BufferReader) -> GroupCallParticipant? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 7) != 0 {
                _6 = reader.readInt32()
            }
            var _7: String?
            if Int(_1 ?? 0) & Int(1 << 11) != 0 {
                _7 = parseString(reader)
            }
            var _8: Int64?
            if Int(_1 ?? 0) & Int(1 << 13) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Api.GroupCallParticipantVideo?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
                }
            }
            var _10: Api.GroupCallParticipantVideo?
            if Int(_1 ?? 0) & Int(1 << 14) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.GroupCallParticipantVideo
                }
            }
            var _11: Int64?
            if Int(_1 ?? 0) & Int(1 << 16) != 0 {
                _11 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 7) == 0) || _6 != nil
            let _c7 = (Int(_1 ?? 0) & Int(1 << 11) == 0) || _7 != nil
            let _c8 = (Int(_1 ?? 0) & Int(1 << 13) == 0) || _8 != nil
            let _c9 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 16) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.GroupCallParticipant.groupCallParticipant(Cons_groupCallParticipant(flags: _1!, peer: _2!, date: _3!, activeDate: _4, source: _5!, volume: _6, about: _7, raiseHandRating: _8, video: _9, presentation: _10, paidStarsTotal: _11))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideo: TypeConstructorDescription {
            public var flags: Int32
            public var endpoint: String
            public var sourceGroups: [Api.GroupCallParticipantVideoSourceGroup]
            public var audioSource: Int32?
            public init(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?) {
                self.flags = flags
                self.endpoint = endpoint
                self.sourceGroups = sourceGroups
                self.audioSource = audioSource
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallParticipantVideo", [("flags", ConstructorParameterDescription(self.flags)), ("endpoint", ConstructorParameterDescription(self.endpoint)), ("sourceGroups", ConstructorParameterDescription(self.sourceGroups)), ("audioSource", ConstructorParameterDescription(self.audioSource))])
            }
        }
        case groupCallParticipantVideo(Cons_groupCallParticipantVideo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipantVideo(let _data):
                if boxed {
                    buffer.appendInt32(1735736008)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.endpoint, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sourceGroups.count))
                for item in _data.sourceGroups {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.audioSource!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallParticipantVideo(let _data):
                return ("groupCallParticipantVideo", [("flags", ConstructorParameterDescription(_data.flags)), ("endpoint", ConstructorParameterDescription(_data.endpoint)), ("sourceGroups", ConstructorParameterDescription(_data.sourceGroups)), ("audioSource", ConstructorParameterDescription(_data.audioSource))])
            }
        }

        public static func parse_groupCallParticipantVideo(_ reader: BufferReader) -> GroupCallParticipantVideo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.GroupCallParticipantVideoSourceGroup]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipantVideoSourceGroup.self)
            }
            var _4: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _4 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.GroupCallParticipantVideo.groupCallParticipantVideo(Cons_groupCallParticipantVideo(flags: _1!, endpoint: _2!, sourceGroups: _3!, audioSource: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription {
        public class Cons_groupCallParticipantVideoSourceGroup: TypeConstructorDescription {
            public var semantics: String
            public var sources: [Int32]
            public init(semantics: String, sources: [Int32]) {
                self.semantics = semantics
                self.sources = sources
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallParticipantVideoSourceGroup", [("semantics", ConstructorParameterDescription(self.semantics)), ("sources", ConstructorParameterDescription(self.sources))])
            }
        }
        case groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallParticipantVideoSourceGroup(let _data):
                if boxed {
                    buffer.appendInt32(-592373577)
                }
                serializeString(_data.semantics, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sources.count))
                for item in _data.sources {
                    serializeInt32(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallParticipantVideoSourceGroup(let _data):
                return ("groupCallParticipantVideoSourceGroup", [("semantics", ConstructorParameterDescription(_data.semantics)), ("sources", ConstructorParameterDescription(_data.sources))])
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
                return Api.GroupCallParticipantVideoSourceGroup.groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup(semantics: _1!, sources: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription {
        public class Cons_groupCallStreamChannel: TypeConstructorDescription {
            public var channel: Int32
            public var scale: Int32
            public var lastTimestampMs: Int64
            public init(channel: Int32, scale: Int32, lastTimestampMs: Int64) {
                self.channel = channel
                self.scale = scale
                self.lastTimestampMs = lastTimestampMs
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("groupCallStreamChannel", [("channel", ConstructorParameterDescription(self.channel)), ("scale", ConstructorParameterDescription(self.scale)), ("lastTimestampMs", ConstructorParameterDescription(self.lastTimestampMs))])
            }
        }
        case groupCallStreamChannel(Cons_groupCallStreamChannel)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallStreamChannel(let _data):
                if boxed {
                    buffer.appendInt32(-2132064081)
                }
                serializeInt32(_data.channel, buffer: buffer, boxed: false)
                serializeInt32(_data.scale, buffer: buffer, boxed: false)
                serializeInt64(_data.lastTimestampMs, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .groupCallStreamChannel(let _data):
                return ("groupCallStreamChannel", [("channel", ConstructorParameterDescription(_data.channel)), ("scale", ConstructorParameterDescription(_data.scale)), ("lastTimestampMs", ConstructorParameterDescription(_data.lastTimestampMs))])
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
                return Api.GroupCallStreamChannel.groupCallStreamChannel(Cons_groupCallStreamChannel(channel: _1!, scale: _2!, lastTimestampMs: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription {
        public class Cons_highScore: TypeConstructorDescription {
            public var pos: Int32
            public var userId: Int64
            public var score: Int32
            public init(pos: Int32, userId: Int64, score: Int32) {
                self.pos = pos
                self.userId = userId
                self.score = score
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("highScore", [("pos", ConstructorParameterDescription(self.pos)), ("userId", ConstructorParameterDescription(self.userId)), ("score", ConstructorParameterDescription(self.score))])
            }
        }
        case highScore(Cons_highScore)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .highScore(let _data):
                if boxed {
                    buffer.appendInt32(1940093419)
                }
                serializeInt32(_data.pos, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt32(_data.score, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .highScore(let _data):
                return ("highScore", [("pos", ConstructorParameterDescription(_data.pos)), ("userId", ConstructorParameterDescription(_data.userId)), ("score", ConstructorParameterDescription(_data.score))])
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
                return Api.HighScore.highScore(Cons_highScore(pos: _1!, userId: _2!, score: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription {
        public class Cons_importedContact: TypeConstructorDescription {
            public var userId: Int64
            public var clientId: Int64
            public init(userId: Int64, clientId: Int64) {
                self.userId = userId
                self.clientId = clientId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("importedContact", [("userId", ConstructorParameterDescription(self.userId)), ("clientId", ConstructorParameterDescription(self.clientId))])
            }
        }
        case importedContact(Cons_importedContact)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .importedContact(let _data):
                if boxed {
                    buffer.appendInt32(-1052885936)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                serializeInt64(_data.clientId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .importedContact(let _data):
                return ("importedContact", [("userId", ConstructorParameterDescription(_data.userId)), ("clientId", ConstructorParameterDescription(_data.clientId))])
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
                return Api.ImportedContact.importedContact(Cons_importedContact(userId: _1!, clientId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription {
        public class Cons_inlineBotSwitchPM: TypeConstructorDescription {
            public var text: String
            public var startParam: String
            public init(text: String, startParam: String) {
                self.text = text
                self.startParam = startParam
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineBotSwitchPM", [("text", ConstructorParameterDescription(self.text)), ("startParam", ConstructorParameterDescription(self.startParam))])
            }
        }
        case inlineBotSwitchPM(Cons_inlineBotSwitchPM)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineBotSwitchPM(let _data):
                if boxed {
                    buffer.appendInt32(1008755359)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.startParam, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inlineBotSwitchPM(let _data):
                return ("inlineBotSwitchPM", [("text", ConstructorParameterDescription(_data.text)), ("startParam", ConstructorParameterDescription(_data.startParam))])
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
                return Api.InlineBotSwitchPM.inlineBotSwitchPM(Cons_inlineBotSwitchPM(text: _1!, startParam: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription {
        public class Cons_inlineBotWebView: TypeConstructorDescription {
            public var text: String
            public var url: String
            public init(text: String, url: String) {
                self.text = text
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineBotWebView", [("text", ConstructorParameterDescription(self.text)), ("url", ConstructorParameterDescription(self.url))])
            }
        }
        case inlineBotWebView(Cons_inlineBotWebView)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineBotWebView(let _data):
                if boxed {
                    buffer.appendInt32(-1250781739)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inlineBotWebView(let _data):
                return ("inlineBotWebView", [("text", ConstructorParameterDescription(_data.text)), ("url", ConstructorParameterDescription(_data.url))])
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
                return Api.InlineBotWebView.inlineBotWebView(Cons_inlineBotWebView(text: _1!, url: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum InlineButtonType: TypeConstructorDescription {
        public class Cons_inlineButtonTypeCallback: TypeConstructorDescription {
            public var flags: Int32
            public var data: Buffer
            public init(flags: Int32, data: Buffer) {
                self.flags = flags
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeCallback", [("flags", ConstructorParameterDescription(self.flags)), ("data", ConstructorParameterDescription(self.data))])
            }
        }
        public class Cons_inlineButtonTypeCopy: TypeConstructorDescription {
            public var copyText: String
            public init(copyText: String) {
                self.copyText = copyText
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeCopy", [("copyText", ConstructorParameterDescription(self.copyText))])
            }
        }
        public class Cons_inlineButtonTypeSwitchInline: TypeConstructorDescription {
            public var flags: Int32
            public var query: String
            public var peerTypes: [Api.InlineQueryPeerType]?
            public init(flags: Int32, query: String, peerTypes: [Api.InlineQueryPeerType]?) {
                self.flags = flags
                self.query = query
                self.peerTypes = peerTypes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeSwitchInline", [("flags", ConstructorParameterDescription(self.flags)), ("query", ConstructorParameterDescription(self.query)), ("peerTypes", ConstructorParameterDescription(self.peerTypes))])
            }
        }
        public class Cons_inlineButtonTypeUrl: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeUrl", [("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_inlineButtonTypeUrlAuth: TypeConstructorDescription {
            public var flags: Int32
            public var fwdText: String?
            public var url: String
            public var buttonId: Int32
            public init(flags: Int32, fwdText: String?, url: String, buttonId: Int32) {
                self.flags = flags
                self.fwdText = fwdText
                self.url = url
                self.buttonId = buttonId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeUrlAuth", [("flags", ConstructorParameterDescription(self.flags)), ("fwdText", ConstructorParameterDescription(self.fwdText)), ("url", ConstructorParameterDescription(self.url)), ("buttonId", ConstructorParameterDescription(self.buttonId))])
            }
        }
        public class Cons_inlineButtonTypeUserProfile: TypeConstructorDescription {
            public var userId: Int64
            public init(userId: Int64) {
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeUserProfile", [("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        public class Cons_inlineButtonTypeWebView: TypeConstructorDescription {
            public var url: String
            public init(url: String) {
                self.url = url
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inlineButtonTypeWebView", [("url", ConstructorParameterDescription(self.url))])
            }
        }
        public class Cons_inputInlineButtonTypeUrlAuth: TypeConstructorDescription {
            public var flags: Int32
            public var fwdText: String?
            public var url: String
            public var bot: Api.InputUser?
            public init(flags: Int32, fwdText: String?, url: String, bot: Api.InputUser?) {
                self.flags = flags
                self.fwdText = fwdText
                self.url = url
                self.bot = bot
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInlineButtonTypeUrlAuth", [("flags", ConstructorParameterDescription(self.flags)), ("fwdText", ConstructorParameterDescription(self.fwdText)), ("url", ConstructorParameterDescription(self.url)), ("bot", ConstructorParameterDescription(self.bot))])
            }
        }
        public class Cons_inputInlineButtonTypeUserProfile: TypeConstructorDescription {
            public var userId: Api.InputUser
            public init(userId: Api.InputUser) {
                self.userId = userId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputInlineButtonTypeUserProfile", [("userId", ConstructorParameterDescription(self.userId))])
            }
        }
        case inlineButtonTypeBuy
        case inlineButtonTypeCallback(Cons_inlineButtonTypeCallback)
        case inlineButtonTypeCopy(Cons_inlineButtonTypeCopy)
        case inlineButtonTypeDisabled
        case inlineButtonTypeGame
        case inlineButtonTypeSwitchInline(Cons_inlineButtonTypeSwitchInline)
        case inlineButtonTypeUrl(Cons_inlineButtonTypeUrl)
        case inlineButtonTypeUrlAuth(Cons_inlineButtonTypeUrlAuth)
        case inlineButtonTypeUserProfile(Cons_inlineButtonTypeUserProfile)
        case inlineButtonTypeWebView(Cons_inlineButtonTypeWebView)
        case inputInlineButtonTypeUrlAuth(Cons_inputInlineButtonTypeUrlAuth)
        case inputInlineButtonTypeUserProfile(Cons_inputInlineButtonTypeUserProfile)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inlineButtonTypeBuy:
                if boxed {
                    buffer.appendInt32(1220204453)
                }
                break
            case .inlineButtonTypeCallback(let _data):
                if boxed {
                    buffer.appendInt32(693484600)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeBytes(_data.data, buffer: buffer, boxed: false)
                break
            case .inlineButtonTypeCopy(let _data):
                if boxed {
                    buffer.appendInt32(-1273154958)
                }
                serializeString(_data.copyText, buffer: buffer, boxed: false)
                break
            case .inlineButtonTypeDisabled:
                if boxed {
                    buffer.appendInt32(-1539808867)
                }
                break
            case .inlineButtonTypeGame:
                if boxed {
                    buffer.appendInt32(1557360797)
                }
                break
            case .inlineButtonTypeSwitchInline(let _data):
                if boxed {
                    buffer.appendInt32(-1820901387)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.query, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.peerTypes!.count))
                    for item in _data.peerTypes! {
                        item.serialize(buffer, true)
                    }
                }
                break
            case .inlineButtonTypeUrl(let _data):
                if boxed {
                    buffer.appendInt32(-324732716)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .inlineButtonTypeUrlAuth(let _data):
                if boxed {
                    buffer.appendInt32(-1076875870)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.fwdText!, buffer: buffer, boxed: false)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.buttonId, buffer: buffer, boxed: false)
                break
            case .inlineButtonTypeUserProfile(let _data):
                if boxed {
                    buffer.appendInt32(1067663311)
                }
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            case .inlineButtonTypeWebView(let _data):
                if boxed {
                    buffer.appendInt32(1003140532)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            case .inputInlineButtonTypeUrlAuth(let _data):
                if boxed {
                    buffer.appendInt32(-1721647948)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.fwdText!, buffer: buffer, boxed: false)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.bot!.serialize(buffer, true)
                }
                break
            case .inputInlineButtonTypeUserProfile(let _data):
                if boxed {
                    buffer.appendInt32(1408487002)
                }
                _data.userId.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inlineButtonTypeBuy:
                return ("inlineButtonTypeBuy", [])
            case .inlineButtonTypeCallback(let _data):
                return ("inlineButtonTypeCallback", [("flags", ConstructorParameterDescription(_data.flags)), ("data", ConstructorParameterDescription(_data.data))])
            case .inlineButtonTypeCopy(let _data):
                return ("inlineButtonTypeCopy", [("copyText", ConstructorParameterDescription(_data.copyText))])
            case .inlineButtonTypeDisabled:
                return ("inlineButtonTypeDisabled", [])
            case .inlineButtonTypeGame:
                return ("inlineButtonTypeGame", [])
            case .inlineButtonTypeSwitchInline(let _data):
                return ("inlineButtonTypeSwitchInline", [("flags", ConstructorParameterDescription(_data.flags)), ("query", ConstructorParameterDescription(_data.query)), ("peerTypes", ConstructorParameterDescription(_data.peerTypes))])
            case .inlineButtonTypeUrl(let _data):
                return ("inlineButtonTypeUrl", [("url", ConstructorParameterDescription(_data.url))])
            case .inlineButtonTypeUrlAuth(let _data):
                return ("inlineButtonTypeUrlAuth", [("flags", ConstructorParameterDescription(_data.flags)), ("fwdText", ConstructorParameterDescription(_data.fwdText)), ("url", ConstructorParameterDescription(_data.url)), ("buttonId", ConstructorParameterDescription(_data.buttonId))])
            case .inlineButtonTypeUserProfile(let _data):
                return ("inlineButtonTypeUserProfile", [("userId", ConstructorParameterDescription(_data.userId))])
            case .inlineButtonTypeWebView(let _data):
                return ("inlineButtonTypeWebView", [("url", ConstructorParameterDescription(_data.url))])
            case .inputInlineButtonTypeUrlAuth(let _data):
                return ("inputInlineButtonTypeUrlAuth", [("flags", ConstructorParameterDescription(_data.flags)), ("fwdText", ConstructorParameterDescription(_data.fwdText)), ("url", ConstructorParameterDescription(_data.url)), ("bot", ConstructorParameterDescription(_data.bot))])
            case .inputInlineButtonTypeUserProfile(let _data):
                return ("inputInlineButtonTypeUserProfile", [("userId", ConstructorParameterDescription(_data.userId))])
            }
        }

        public static func parse_inlineButtonTypeBuy(_ reader: BufferReader) -> InlineButtonType? {
            return Api.InlineButtonType.inlineButtonTypeBuy
        }
        public static func parse_inlineButtonTypeCallback(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.InlineButtonType.inlineButtonTypeCallback(Cons_inlineButtonTypeCallback(flags: _1!, data: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeCopy(_ reader: BufferReader) -> InlineButtonType? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InlineButtonType.inlineButtonTypeCopy(Cons_inlineButtonTypeCopy(copyText: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeDisabled(_ reader: BufferReader) -> InlineButtonType? {
            return Api.InlineButtonType.inlineButtonTypeDisabled
        }
        public static func parse_inlineButtonTypeGame(_ reader: BufferReader) -> InlineButtonType? {
            return Api.InlineButtonType.inlineButtonTypeGame
        }
        public static func parse_inlineButtonTypeSwitchInline(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.InlineQueryPeerType]?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InlineQueryPeerType.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.InlineButtonType.inlineButtonTypeSwitchInline(Cons_inlineButtonTypeSwitchInline(flags: _1!, query: _2!, peerTypes: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeUrl(_ reader: BufferReader) -> InlineButtonType? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InlineButtonType.inlineButtonTypeUrl(Cons_inlineButtonTypeUrl(url: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeUrlAuth(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InlineButtonType.inlineButtonTypeUrlAuth(Cons_inlineButtonTypeUrlAuth(flags: _1!, fwdText: _2, url: _3!, buttonId: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeUserProfile(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.InlineButtonType.inlineButtonTypeUserProfile(Cons_inlineButtonTypeUserProfile(userId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inlineButtonTypeWebView(_ reader: BufferReader) -> InlineButtonType? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.InlineButtonType.inlineButtonTypeWebView(Cons_inlineButtonTypeWebView(url: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInlineButtonTypeUrlAuth(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.InputUser?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.InputUser
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.InlineButtonType.inputInlineButtonTypeUrlAuth(Cons_inputInlineButtonTypeUrlAuth(flags: _1!, fwdText: _2, url: _3!, bot: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_inputInlineButtonTypeUserProfile(_ reader: BufferReader) -> InlineButtonType? {
            var _1: Api.InputUser?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.InlineButtonType.inputInlineButtonTypeUserProfile(Cons_inputInlineButtonTypeUserProfile(userId: _1!))
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
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
