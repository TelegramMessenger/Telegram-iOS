public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        public class Cons_joinAsPeers {
            public var peers: [Api.Peer]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
                self.peers = peers
                self.chats = chats
                self.users = users
            }
        }
        case joinAsPeers(Cons_joinAsPeers)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .joinAsPeers(let _data):
                if boxed {
                    buffer.appendInt32(-1343921601)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peers.count))
                for item in _data.peers {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .joinAsPeers(let _data):
                return ("joinAsPeers", [("peers", _data.peers as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_joinAsPeers(_ reader: BufferReader) -> JoinAsPeers? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.phone.JoinAsPeers.joinAsPeers(Cons_joinAsPeers(peers: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        public class Cons_phoneCall {
            public var phoneCall: Api.PhoneCall
            public var users: [Api.User]
            public init(phoneCall: Api.PhoneCall, users: [Api.User]) {
                self.phoneCall = phoneCall
                self.users = users
            }
        }
        case phoneCall(Cons_phoneCall)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .phoneCall(let _data):
                if boxed {
                    buffer.appendInt32(-326966976)
                }
                _data.phoneCall.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .phoneCall(let _data):
                return ("phoneCall", [("phoneCall", _data.phoneCall as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_phoneCall(_ reader: BufferReader) -> PhoneCall? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.PhoneCall.phoneCall(Cons_phoneCall(phoneCall: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        public class Cons_photo {
            public var photo: Api.Photo
            public var users: [Api.User]
            public init(photo: Api.Photo, users: [Api.User]) {
                self.photo = photo
                self.users = users
            }
        }
        case photo(Cons_photo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .photo(let _data):
                if boxed {
                    buffer.appendInt32(539045032)
                }
                _data.photo.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .photo(let _data):
                return ("photo", [("photo", _data.photo as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_photo(_ reader: BufferReader) -> Photo? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photo.photo(Cons_photo(photo: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        public class Cons_photos {
            public var photos: [Api.Photo]
            public var users: [Api.User]
            public init(photos: [Api.Photo], users: [Api.User]) {
                self.photos = photos
                self.users = users
            }
        }
        public class Cons_photosSlice {
            public var count: Int32
            public var photos: [Api.Photo]
            public var users: [Api.User]
            public init(count: Int32, photos: [Api.Photo], users: [Api.User]) {
                self.count = count
                self.photos = photos
                self.users = users
            }
        }
        case photos(Cons_photos)
        case photosSlice(Cons_photosSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .photos(let _data):
                if boxed {
                    buffer.appendInt32(-1916114267)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.photos.count))
                for item in _data.photos {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .photosSlice(let _data):
                if boxed {
                    buffer.appendInt32(352657236)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.photos.count))
                for item in _data.photos {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .photos(let _data):
                return ("photos", [("photos", _data.photos as Any), ("users", _data.users as Any)])
            case .photosSlice(let _data):
                return ("photosSlice", [("count", _data.count as Any), ("photos", _data.photos as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_photos(_ reader: BufferReader) -> Photos? {
            var _1: [Api.Photo]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.photos.Photos.photos(Cons_photos(photos: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_photosSlice(_ reader: BufferReader) -> Photos? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Photo]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.photos.Photos.photosSlice(Cons_photosSlice(count: _1!, photos: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.premium {
    enum BoostsList: TypeConstructorDescription {
        public class Cons_boostsList {
            public var flags: Int32
            public var count: Int32
            public var boosts: [Api.Boost]
            public var nextOffset: String?
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, boosts: [Api.Boost], nextOffset: String?, users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.boosts = boosts
                self.nextOffset = nextOffset
                self.users = users
            }
        }
        case boostsList(Cons_boostsList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .boostsList(let _data):
                if boxed {
                    buffer.appendInt32(-2030542532)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.boosts.count))
                for item in _data.boosts {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .boostsList(let _data):
                return ("boostsList", [("flags", _data.flags as Any), ("count", _data.count as Any), ("boosts", _data.boosts as Any), ("nextOffset", _data.nextOffset as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_boostsList(_ reader: BufferReader) -> BoostsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.Boost]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Boost.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.premium.BoostsList.boostsList(Cons_boostsList(flags: _1!, count: _2!, boosts: _3!, nextOffset: _4, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.premium {
    enum BoostsStatus: TypeConstructorDescription {
        public class Cons_boostsStatus {
            public var flags: Int32
            public var level: Int32
            public var currentLevelBoosts: Int32
            public var boosts: Int32
            public var giftBoosts: Int32?
            public var nextLevelBoosts: Int32?
            public var premiumAudience: Api.StatsPercentValue?
            public var boostUrl: String
            public var prepaidGiveaways: [Api.PrepaidGiveaway]?
            public var myBoostSlots: [Int32]?
            public init(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, giftBoosts: Int32?, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?, boostUrl: String, prepaidGiveaways: [Api.PrepaidGiveaway]?, myBoostSlots: [Int32]?) {
                self.flags = flags
                self.level = level
                self.currentLevelBoosts = currentLevelBoosts
                self.boosts = boosts
                self.giftBoosts = giftBoosts
                self.nextLevelBoosts = nextLevelBoosts
                self.premiumAudience = premiumAudience
                self.boostUrl = boostUrl
                self.prepaidGiveaways = prepaidGiveaways
                self.myBoostSlots = myBoostSlots
            }
        }
        case boostsStatus(Cons_boostsStatus)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .boostsStatus(let _data):
                if boxed {
                    buffer.appendInt32(1230586490)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.level, buffer: buffer, boxed: false)
                serializeInt32(_data.currentLevelBoosts, buffer: buffer, boxed: false)
                serializeInt32(_data.boosts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.giftBoosts!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.nextLevelBoosts!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.premiumAudience!.serialize(buffer, true)
                }
                serializeString(_data.boostUrl, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.prepaidGiveaways!.count))
                    for item in _data.prepaidGiveaways! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.myBoostSlots!.count))
                    for item in _data.myBoostSlots! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .boostsStatus(let _data):
                return ("boostsStatus", [("flags", _data.flags as Any), ("level", _data.level as Any), ("currentLevelBoosts", _data.currentLevelBoosts as Any), ("boosts", _data.boosts as Any), ("giftBoosts", _data.giftBoosts as Any), ("nextLevelBoosts", _data.nextLevelBoosts as Any), ("premiumAudience", _data.premiumAudience as Any), ("boostUrl", _data.boostUrl as Any), ("prepaidGiveaways", _data.prepaidGiveaways as Any), ("myBoostSlots", _data.myBoostSlots as Any)])
            }
        }

        public static func parse_boostsStatus(_ reader: BufferReader) -> BoostsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Api.StatsPercentValue?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
                }
            }
            var _8: String?
            _8 = parseString(reader)
            var _9: [Api.PrepaidGiveaway]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrepaidGiveaway.self)
                }
            }
            var _10: [Int32]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _10 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 2) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.premium.BoostsStatus.boostsStatus(Cons_boostsStatus(flags: _1!, level: _2!, currentLevelBoosts: _3!, boosts: _4!, giftBoosts: _5, nextLevelBoosts: _6, premiumAudience: _7, boostUrl: _8!, prepaidGiveaways: _9, myBoostSlots: _10))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.premium {
    enum MyBoosts: TypeConstructorDescription {
        public class Cons_myBoosts {
            public var myBoosts: [Api.MyBoost]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(myBoosts: [Api.MyBoost], chats: [Api.Chat], users: [Api.User]) {
                self.myBoosts = myBoosts
                self.chats = chats
                self.users = users
            }
        }
        case myBoosts(Cons_myBoosts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .myBoosts(let _data):
                if boxed {
                    buffer.appendInt32(-1696454430)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.myBoosts.count))
                for item in _data.myBoosts {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .myBoosts(let _data):
                return ("myBoosts", [("myBoosts", _data.myBoosts as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_myBoosts(_ reader: BufferReader) -> MyBoosts? {
            var _1: [Api.MyBoost]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MyBoost.self)
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.premium.MyBoosts.myBoosts(Cons_myBoosts(myBoosts: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.smsjobs {
    enum EligibilityToJoin: TypeConstructorDescription {
        public class Cons_eligibleToJoin {
            public var termsUrl: String
            public var monthlySentSms: Int32
            public init(termsUrl: String, monthlySentSms: Int32) {
                self.termsUrl = termsUrl
                self.monthlySentSms = monthlySentSms
            }
        }
        case eligibleToJoin(Cons_eligibleToJoin)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .eligibleToJoin(let _data):
                if boxed {
                    buffer.appendInt32(-594852657)
                }
                serializeString(_data.termsUrl, buffer: buffer, boxed: false)
                serializeInt32(_data.monthlySentSms, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .eligibleToJoin(let _data):
                return ("eligibleToJoin", [("termsUrl", _data.termsUrl as Any), ("monthlySentSms", _data.monthlySentSms as Any)])
            }
        }

        public static func parse_eligibleToJoin(_ reader: BufferReader) -> EligibilityToJoin? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.smsjobs.EligibilityToJoin.eligibleToJoin(Cons_eligibleToJoin(termsUrl: _1!, monthlySentSms: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.smsjobs {
    enum Status: TypeConstructorDescription {
        public class Cons_status {
            public var flags: Int32
            public var recentSent: Int32
            public var recentSince: Int32
            public var recentRemains: Int32
            public var totalSent: Int32
            public var totalSince: Int32
            public var lastGiftSlug: String?
            public var termsUrl: String
            public init(flags: Int32, recentSent: Int32, recentSince: Int32, recentRemains: Int32, totalSent: Int32, totalSince: Int32, lastGiftSlug: String?, termsUrl: String) {
                self.flags = flags
                self.recentSent = recentSent
                self.recentSince = recentSince
                self.recentRemains = recentRemains
                self.totalSent = totalSent
                self.totalSince = totalSince
                self.lastGiftSlug = lastGiftSlug
                self.termsUrl = termsUrl
            }
        }
        case status(Cons_status)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .status(let _data):
                if boxed {
                    buffer.appendInt32(720277905)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.recentSent, buffer: buffer, boxed: false)
                serializeInt32(_data.recentSince, buffer: buffer, boxed: false)
                serializeInt32(_data.recentRemains, buffer: buffer, boxed: false)
                serializeInt32(_data.totalSent, buffer: buffer, boxed: false)
                serializeInt32(_data.totalSince, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.lastGiftSlug!, buffer: buffer, boxed: false)
                }
                serializeString(_data.termsUrl, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .status(let _data):
                return ("status", [("flags", _data.flags as Any), ("recentSent", _data.recentSent as Any), ("recentSince", _data.recentSince as Any), ("recentRemains", _data.recentRemains as Any), ("totalSent", _data.totalSent as Any), ("totalSince", _data.totalSince as Any), ("lastGiftSlug", _data.lastGiftSlug as Any), ("termsUrl", _data.termsUrl as Any)])
            }
        }

        public static func parse_status(_ reader: BufferReader) -> Status? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _7 = parseString(reader)
            }
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.smsjobs.Status.status(Cons_status(flags: _1!, recentSent: _2!, recentSince: _3!, recentRemains: _4!, totalSent: _5!, totalSince: _6!, lastGiftSlug: _7, termsUrl: _8!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
        public class Cons_broadcastStats {
            public var period: Api.StatsDateRangeDays
            public var followers: Api.StatsAbsValueAndPrev
            public var viewsPerPost: Api.StatsAbsValueAndPrev
            public var sharesPerPost: Api.StatsAbsValueAndPrev
            public var reactionsPerPost: Api.StatsAbsValueAndPrev
            public var viewsPerStory: Api.StatsAbsValueAndPrev
            public var sharesPerStory: Api.StatsAbsValueAndPrev
            public var reactionsPerStory: Api.StatsAbsValueAndPrev
            public var enabledNotifications: Api.StatsPercentValue
            public var growthGraph: Api.StatsGraph
            public var followersGraph: Api.StatsGraph
            public var muteGraph: Api.StatsGraph
            public var topHoursGraph: Api.StatsGraph
            public var interactionsGraph: Api.StatsGraph
            public var ivInteractionsGraph: Api.StatsGraph
            public var viewsBySourceGraph: Api.StatsGraph
            public var newFollowersBySourceGraph: Api.StatsGraph
            public var languagesGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public var storyInteractionsGraph: Api.StatsGraph
            public var storyReactionsByEmotionGraph: Api.StatsGraph
            public var recentPostsInteractions: [Api.PostInteractionCounters]
            public init(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, reactionsPerPost: Api.StatsAbsValueAndPrev, viewsPerStory: Api.StatsAbsValueAndPrev, sharesPerStory: Api.StatsAbsValueAndPrev, reactionsPerStory: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph, storyInteractionsGraph: Api.StatsGraph, storyReactionsByEmotionGraph: Api.StatsGraph, recentPostsInteractions: [Api.PostInteractionCounters]) {
                self.period = period
                self.followers = followers
                self.viewsPerPost = viewsPerPost
                self.sharesPerPost = sharesPerPost
                self.reactionsPerPost = reactionsPerPost
                self.viewsPerStory = viewsPerStory
                self.sharesPerStory = sharesPerStory
                self.reactionsPerStory = reactionsPerStory
                self.enabledNotifications = enabledNotifications
                self.growthGraph = growthGraph
                self.followersGraph = followersGraph
                self.muteGraph = muteGraph
                self.topHoursGraph = topHoursGraph
                self.interactionsGraph = interactionsGraph
                self.ivInteractionsGraph = ivInteractionsGraph
                self.viewsBySourceGraph = viewsBySourceGraph
                self.newFollowersBySourceGraph = newFollowersBySourceGraph
                self.languagesGraph = languagesGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
                self.storyInteractionsGraph = storyInteractionsGraph
                self.storyReactionsByEmotionGraph = storyReactionsByEmotionGraph
                self.recentPostsInteractions = recentPostsInteractions
            }
        }
        case broadcastStats(Cons_broadcastStats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .broadcastStats(let _data):
                if boxed {
                    buffer.appendInt32(963421692)
                }
                _data.period.serialize(buffer, true)
                _data.followers.serialize(buffer, true)
                _data.viewsPerPost.serialize(buffer, true)
                _data.sharesPerPost.serialize(buffer, true)
                _data.reactionsPerPost.serialize(buffer, true)
                _data.viewsPerStory.serialize(buffer, true)
                _data.sharesPerStory.serialize(buffer, true)
                _data.reactionsPerStory.serialize(buffer, true)
                _data.enabledNotifications.serialize(buffer, true)
                _data.growthGraph.serialize(buffer, true)
                _data.followersGraph.serialize(buffer, true)
                _data.muteGraph.serialize(buffer, true)
                _data.topHoursGraph.serialize(buffer, true)
                _data.interactionsGraph.serialize(buffer, true)
                _data.ivInteractionsGraph.serialize(buffer, true)
                _data.viewsBySourceGraph.serialize(buffer, true)
                _data.newFollowersBySourceGraph.serialize(buffer, true)
                _data.languagesGraph.serialize(buffer, true)
                _data.reactionsByEmotionGraph.serialize(buffer, true)
                _data.storyInteractionsGraph.serialize(buffer, true)
                _data.storyReactionsByEmotionGraph.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.recentPostsInteractions.count))
                for item in _data.recentPostsInteractions {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .broadcastStats(let _data):
                return ("broadcastStats", [("period", _data.period as Any), ("followers", _data.followers as Any), ("viewsPerPost", _data.viewsPerPost as Any), ("sharesPerPost", _data.sharesPerPost as Any), ("reactionsPerPost", _data.reactionsPerPost as Any), ("viewsPerStory", _data.viewsPerStory as Any), ("sharesPerStory", _data.sharesPerStory as Any), ("reactionsPerStory", _data.reactionsPerStory as Any), ("enabledNotifications", _data.enabledNotifications as Any), ("growthGraph", _data.growthGraph as Any), ("followersGraph", _data.followersGraph as Any), ("muteGraph", _data.muteGraph as Any), ("topHoursGraph", _data.topHoursGraph as Any), ("interactionsGraph", _data.interactionsGraph as Any), ("ivInteractionsGraph", _data.ivInteractionsGraph as Any), ("viewsBySourceGraph", _data.viewsBySourceGraph as Any), ("newFollowersBySourceGraph", _data.newFollowersBySourceGraph as Any), ("languagesGraph", _data.languagesGraph as Any), ("reactionsByEmotionGraph", _data.reactionsByEmotionGraph as Any), ("storyInteractionsGraph", _data.storyInteractionsGraph as Any), ("storyReactionsByEmotionGraph", _data.storyReactionsByEmotionGraph as Any), ("recentPostsInteractions", _data.recentPostsInteractions as Any)])
            }
        }

        public static func parse_broadcastStats(_ reader: BufferReader) -> BroadcastStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _7: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _8: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _9: Api.StatsPercentValue?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _15: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _16: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _16 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _17: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _18: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _19: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _20: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _20 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _21: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _21 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _22: [Api.PostInteractionCounters]?
            if let _ = reader.readInt32() {
                _22 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PostInteractionCounters.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            let _c18 = _18 != nil
            let _c19 = _19 != nil
            let _c20 = _20 != nil
            let _c21 = _21 != nil
            let _c22 = _22 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 && _c22 {
                return Api.stats.BroadcastStats.broadcastStats(Cons_broadcastStats(period: _1!, followers: _2!, viewsPerPost: _3!, sharesPerPost: _4!, reactionsPerPost: _5!, viewsPerStory: _6!, sharesPerStory: _7!, reactionsPerStory: _8!, enabledNotifications: _9!, growthGraph: _10!, followersGraph: _11!, muteGraph: _12!, topHoursGraph: _13!, interactionsGraph: _14!, ivInteractionsGraph: _15!, viewsBySourceGraph: _16!, newFollowersBySourceGraph: _17!, languagesGraph: _18!, reactionsByEmotionGraph: _19!, storyInteractionsGraph: _20!, storyReactionsByEmotionGraph: _21!, recentPostsInteractions: _22!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
        public class Cons_megagroupStats {
            public var period: Api.StatsDateRangeDays
            public var members: Api.StatsAbsValueAndPrev
            public var messages: Api.StatsAbsValueAndPrev
            public var viewers: Api.StatsAbsValueAndPrev
            public var posters: Api.StatsAbsValueAndPrev
            public var growthGraph: Api.StatsGraph
            public var membersGraph: Api.StatsGraph
            public var newMembersBySourceGraph: Api.StatsGraph
            public var languagesGraph: Api.StatsGraph
            public var messagesGraph: Api.StatsGraph
            public var actionsGraph: Api.StatsGraph
            public var topHoursGraph: Api.StatsGraph
            public var weekdaysGraph: Api.StatsGraph
            public var topPosters: [Api.StatsGroupTopPoster]
            public var topAdmins: [Api.StatsGroupTopAdmin]
            public var topInviters: [Api.StatsGroupTopInviter]
            public var users: [Api.User]
            public init(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User]) {
                self.period = period
                self.members = members
                self.messages = messages
                self.viewers = viewers
                self.posters = posters
                self.growthGraph = growthGraph
                self.membersGraph = membersGraph
                self.newMembersBySourceGraph = newMembersBySourceGraph
                self.languagesGraph = languagesGraph
                self.messagesGraph = messagesGraph
                self.actionsGraph = actionsGraph
                self.topHoursGraph = topHoursGraph
                self.weekdaysGraph = weekdaysGraph
                self.topPosters = topPosters
                self.topAdmins = topAdmins
                self.topInviters = topInviters
                self.users = users
            }
        }
        case megagroupStats(Cons_megagroupStats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .megagroupStats(let _data):
                if boxed {
                    buffer.appendInt32(-276825834)
                }
                _data.period.serialize(buffer, true)
                _data.members.serialize(buffer, true)
                _data.messages.serialize(buffer, true)
                _data.viewers.serialize(buffer, true)
                _data.posters.serialize(buffer, true)
                _data.growthGraph.serialize(buffer, true)
                _data.membersGraph.serialize(buffer, true)
                _data.newMembersBySourceGraph.serialize(buffer, true)
                _data.languagesGraph.serialize(buffer, true)
                _data.messagesGraph.serialize(buffer, true)
                _data.actionsGraph.serialize(buffer, true)
                _data.topHoursGraph.serialize(buffer, true)
                _data.weekdaysGraph.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topPosters.count))
                for item in _data.topPosters {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topAdmins.count))
                for item in _data.topAdmins {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topInviters.count))
                for item in _data.topInviters {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .megagroupStats(let _data):
                return ("megagroupStats", [("period", _data.period as Any), ("members", _data.members as Any), ("messages", _data.messages as Any), ("viewers", _data.viewers as Any), ("posters", _data.posters as Any), ("growthGraph", _data.growthGraph as Any), ("membersGraph", _data.membersGraph as Any), ("newMembersBySourceGraph", _data.newMembersBySourceGraph as Any), ("languagesGraph", _data.languagesGraph as Any), ("messagesGraph", _data.messagesGraph as Any), ("actionsGraph", _data.actionsGraph as Any), ("topHoursGraph", _data.topHoursGraph as Any), ("weekdaysGraph", _data.weekdaysGraph as Any), ("topPosters", _data.topPosters as Any), ("topAdmins", _data.topAdmins as Any), ("topInviters", _data.topInviters as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_megagroupStats(_ reader: BufferReader) -> MegagroupStats? {
            var _1: Api.StatsDateRangeDays?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsDateRangeDays
            }
            var _2: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _3: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _4: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _5: Api.StatsAbsValueAndPrev?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsAbsValueAndPrev
            }
            var _6: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _7: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _8: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _9: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _10: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _11: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _12: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _13: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _14: [Api.StatsGroupTopPoster]?
            if let _ = reader.readInt32() {
                _14 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopPoster.self)
            }
            var _15: [Api.StatsGroupTopAdmin]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopAdmin.self)
            }
            var _16: [Api.StatsGroupTopInviter]?
            if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StatsGroupTopInviter.self)
            }
            var _17: [Api.User]?
            if let _ = reader.readInt32() {
                _17 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            let _c16 = _16 != nil
            let _c17 = _17 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 {
                return Api.stats.MegagroupStats.megagroupStats(Cons_megagroupStats(period: _1!, members: _2!, messages: _3!, viewers: _4!, posters: _5!, growthGraph: _6!, membersGraph: _7!, newMembersBySourceGraph: _8!, languagesGraph: _9!, messagesGraph: _10!, actionsGraph: _11!, topHoursGraph: _12!, weekdaysGraph: _13!, topPosters: _14!, topAdmins: _15!, topInviters: _16!, users: _17!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
        public class Cons_messageStats {
            public var viewsGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
                self.viewsGraph = viewsGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
            }
        }
        case messageStats(Cons_messageStats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageStats(let _data):
                if boxed {
                    buffer.appendInt32(2145983508)
                }
                _data.viewsGraph.serialize(buffer, true)
                _data.reactionsByEmotionGraph.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageStats(let _data):
                return ("messageStats", [("viewsGraph", _data.viewsGraph as Any), ("reactionsByEmotionGraph", _data.reactionsByEmotionGraph as Any)])
            }
        }

        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.MessageStats.messageStats(Cons_messageStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stats {
    enum PublicForwards: TypeConstructorDescription {
        public class Cons_publicForwards {
            public var flags: Int32
            public var count: Int32
            public var forwards: [Api.PublicForward]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, forwards: [Api.PublicForward], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.forwards = forwards
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case publicForwards(Cons_publicForwards)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .publicForwards(let _data):
                if boxed {
                    buffer.appendInt32(-1828487648)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.forwards.count))
                for item in _data.forwards {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .publicForwards(let _data):
                return ("publicForwards", [("flags", _data.flags as Any), ("count", _data.count as Any), ("forwards", _data.forwards as Any), ("nextOffset", _data.nextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_publicForwards(_ reader: BufferReader) -> PublicForwards? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.PublicForward]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PublicForward.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stats.PublicForwards.publicForwards(Cons_publicForwards(flags: _1!, count: _2!, forwards: _3!, nextOffset: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stats {
    enum StoryStats: TypeConstructorDescription {
        public class Cons_storyStats {
            public var viewsGraph: Api.StatsGraph
            public var reactionsByEmotionGraph: Api.StatsGraph
            public init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
                self.viewsGraph = viewsGraph
                self.reactionsByEmotionGraph = reactionsByEmotionGraph
            }
        }
        case storyStats(Cons_storyStats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyStats(let _data):
                if boxed {
                    buffer.appendInt32(1355613820)
                }
                _data.viewsGraph.serialize(buffer, true)
                _data.reactionsByEmotionGraph.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyStats(let _data):
                return ("storyStats", [("viewsGraph", _data.viewsGraph as Any), ("reactionsByEmotionGraph", _data.reactionsByEmotionGraph as Any)])
            }
        }

        public static func parse_storyStats(_ reader: BufferReader) -> StoryStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _2: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stats.StoryStats.storyStats(Cons_storyStats(viewsGraph: _1!, reactionsByEmotionGraph: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        public class Cons_suggestedShortName {
            public var shortName: String
            public init(shortName: String) {
                self.shortName = shortName
            }
        }
        case suggestedShortName(Cons_suggestedShortName)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .suggestedShortName(let _data):
                if boxed {
                    buffer.appendInt32(-2046910401)
                }
                serializeString(_data.shortName, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .suggestedShortName(let _data):
                return ("suggestedShortName", [("shortName", _data.shortName as Any)])
            }
        }

        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.stickers.SuggestedShortName.suggestedShortName(Cons_suggestedShortName(shortName: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .fileGif:
                if boxed {
                    buffer.appendInt32(-891180321)
                }
                break
            case .fileJpeg:
                if boxed {
                    buffer.appendInt32(8322574)
                }
                break
            case .fileMov:
                if boxed {
                    buffer.appendInt32(1258941372)
                }
                break
            case .fileMp3:
                if boxed {
                    buffer.appendInt32(1384777335)
                }
                break
            case .fileMp4:
                if boxed {
                    buffer.appendInt32(-1278304028)
                }
                break
            case .filePartial:
                if boxed {
                    buffer.appendInt32(1086091090)
                }
                break
            case .filePdf:
                if boxed {
                    buffer.appendInt32(-1373745011)
                }
                break
            case .filePng:
                if boxed {
                    buffer.appendInt32(172975040)
                }
                break
            case .fileUnknown:
                if boxed {
                    buffer.appendInt32(-1432995067)
                }
                break
            case .fileWebp:
                if boxed {
                    buffer.appendInt32(276907596)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .fileGif:
                return ("fileGif", [])
            case .fileJpeg:
                return ("fileJpeg", [])
            case .fileMov:
                return ("fileMov", [])
            case .fileMp3:
                return ("fileMp3", [])
            case .fileMp4:
                return ("fileMp4", [])
            case .filePartial:
                return ("filePartial", [])
            case .filePdf:
                return ("filePdf", [])
            case .filePng:
                return ("filePng", [])
            case .fileUnknown:
                return ("fileUnknown", [])
            case .fileWebp:
                return ("fileWebp", [])
            }
        }

        public static func parse_fileGif(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileGif
        }
        public static func parse_fileJpeg(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileJpeg
        }
        public static func parse_fileMov(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMov
        }
        public static func parse_fileMp3(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp3
        }
        public static func parse_fileMp4(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileMp4
        }
        public static func parse_filePartial(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePartial
        }
        public static func parse_filePdf(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePdf
        }
        public static func parse_filePng(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.filePng
        }
        public static func parse_fileUnknown(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileUnknown
        }
        public static func parse_fileWebp(_ reader: BufferReader) -> FileType? {
            return Api.storage.FileType.fileWebp
        }
    }
}
public extension Api.stories {
    enum Albums: TypeConstructorDescription {
        public class Cons_albums {
            public var hash: Int64
            public var albums: [Api.StoryAlbum]
            public init(hash: Int64, albums: [Api.StoryAlbum]) {
                self.hash = hash
                self.albums = albums
            }
        }
        case albums(Cons_albums)
        case albumsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .albums(let _data):
                if boxed {
                    buffer.appendInt32(-1013417414)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.albums.count))
                for item in _data.albums {
                    item.serialize(buffer, true)
                }
                break
            case .albumsNotModified:
                if boxed {
                    buffer.appendInt32(1448008427)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .albums(let _data):
                return ("albums", [("hash", _data.hash as Any), ("albums", _data.albums as Any)])
            case .albumsNotModified:
                return ("albumsNotModified", [])
            }
        }

        public static func parse_albums(_ reader: BufferReader) -> Albums? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.StoryAlbum]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryAlbum.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.Albums.albums(Cons_albums(hash: _1!, albums: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_albumsNotModified(_ reader: BufferReader) -> Albums? {
            return Api.stories.Albums.albumsNotModified
        }
    }
}
public extension Api.stories {
    enum AllStories: TypeConstructorDescription {
        public class Cons_allStories {
            public var flags: Int32
            public var count: Int32
            public var state: String
            public var peerStories: [Api.PeerStories]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var stealthMode: Api.StoriesStealthMode
            public init(flags: Int32, count: Int32, state: String, peerStories: [Api.PeerStories], chats: [Api.Chat], users: [Api.User], stealthMode: Api.StoriesStealthMode) {
                self.flags = flags
                self.count = count
                self.state = state
                self.peerStories = peerStories
                self.chats = chats
                self.users = users
                self.stealthMode = stealthMode
            }
        }
        public class Cons_allStoriesNotModified {
            public var flags: Int32
            public var state: String
            public var stealthMode: Api.StoriesStealthMode
            public init(flags: Int32, state: String, stealthMode: Api.StoriesStealthMode) {
                self.flags = flags
                self.state = state
                self.stealthMode = stealthMode
            }
        }
        case allStories(Cons_allStories)
        case allStoriesNotModified(Cons_allStoriesNotModified)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .allStories(let _data):
                if boxed {
                    buffer.appendInt32(1862033025)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                serializeString(_data.state, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.peerStories.count))
                for item in _data.peerStories {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                _data.stealthMode.serialize(buffer, true)
                break
            case .allStoriesNotModified(let _data):
                if boxed {
                    buffer.appendInt32(291044926)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.state, buffer: buffer, boxed: false)
                _data.stealthMode.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .allStories(let _data):
                return ("allStories", [("flags", _data.flags as Any), ("count", _data.count as Any), ("state", _data.state as Any), ("peerStories", _data.peerStories as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("stealthMode", _data.stealthMode as Any)])
            case .allStoriesNotModified(let _data):
                return ("allStoriesNotModified", [("flags", _data.flags as Any), ("state", _data.state as Any), ("stealthMode", _data.stealthMode as Any)])
            }
        }

        public static func parse_allStories(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.PeerStories]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerStories.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _7: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.stories.AllStories.allStories(Cons_allStories(flags: _1!, count: _2!, state: _3!, peerStories: _4!, chats: _5!, users: _6!, stealthMode: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_allStoriesNotModified(_ reader: BufferReader) -> AllStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.AllStories.allStoriesNotModified(Cons_allStoriesNotModified(flags: _1!, state: _2!, stealthMode: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum CanSendStoryCount: TypeConstructorDescription {
        public class Cons_canSendStoryCount {
            public var countRemains: Int32
            public init(countRemains: Int32) {
                self.countRemains = countRemains
            }
        }
        case canSendStoryCount(Cons_canSendStoryCount)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .canSendStoryCount(let _data):
                if boxed {
                    buffer.appendInt32(-1014513586)
                }
                serializeInt32(_data.countRemains, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .canSendStoryCount(let _data):
                return ("canSendStoryCount", [("countRemains", _data.countRemains as Any)])
            }
        }

        public static func parse_canSendStoryCount(_ reader: BufferReader) -> CanSendStoryCount? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.stories.CanSendStoryCount.canSendStoryCount(Cons_canSendStoryCount(countRemains: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum FoundStories: TypeConstructorDescription {
        public class Cons_foundStories {
            public var flags: Int32
            public var count: Int32
            public var stories: [Api.FoundStory]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, stories: [Api.FoundStory], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.stories = stories
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case foundStories(Cons_foundStories)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .foundStories(let _data):
                if boxed {
                    buffer.appendInt32(-488736969)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stories.count))
                for item in _data.stories {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .foundStories(let _data):
                return ("foundStories", [("flags", _data.flags as Any), ("count", _data.count as Any), ("stories", _data.stories as Any), ("nextOffset", _data.nextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_foundStories(_ reader: BufferReader) -> FoundStories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.FoundStory]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FoundStory.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.FoundStories.foundStories(Cons_foundStories(flags: _1!, count: _2!, stories: _3!, nextOffset: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
