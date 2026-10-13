public extension Api {
    enum NearestDc: TypeConstructorDescription {
        public class Cons_nearestDc: TypeConstructorDescription {
            public var country: String
            public var thisDc: Int32
            public var nearestDc: Int32
            public init(country: String, thisDc: Int32, nearestDc: Int32) {
                self.country = country
                self.thisDc = thisDc
                self.nearestDc = nearestDc
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("nearestDc", [("country", ConstructorParameterDescription(self.country)), ("thisDc", ConstructorParameterDescription(self.thisDc)), ("nearestDc", ConstructorParameterDescription(self.nearestDc))])
            }
        }
        case nearestDc(Cons_nearestDc)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nearestDc(let _data):
                if boxed {
                    buffer.appendInt32(-1910892683)
                }
                serializeString(_data.country, buffer: buffer, boxed: false)
                serializeInt32(_data.thisDc, buffer: buffer, boxed: false)
                serializeInt32(_data.nearestDc, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .nearestDc(let _data):
                return ("nearestDc", [("country", ConstructorParameterDescription(_data.country)), ("thisDc", ConstructorParameterDescription(_data.thisDc)), ("nearestDc", ConstructorParameterDescription(_data.nearestDc))])
            }
        }

        public static func parse_nearestDc(_ reader: BufferReader) -> NearestDc? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.NearestDc.nearestDc(Cons_nearestDc(country: _1!, thisDc: _2!, nearestDc: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        public class Cons_notificationSoundLocal: TypeConstructorDescription {
            public var title: String
            public var data: String
            public init(title: String, data: String) {
                self.title = title
                self.data = data
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notificationSoundLocal", [("title", ConstructorParameterDescription(self.title)), ("data", ConstructorParameterDescription(self.data))])
            }
        }
        public class Cons_notificationSoundRingtone: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notificationSoundRingtone", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case notificationSoundDefault
        case notificationSoundLocal(Cons_notificationSoundLocal)
        case notificationSoundNone
        case notificationSoundRingtone(Cons_notificationSoundRingtone)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .notificationSoundDefault:
                if boxed {
                    buffer.appendInt32(-1746354498)
                }
                break
            case .notificationSoundLocal(let _data):
                if boxed {
                    buffer.appendInt32(-2096391452)
                }
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.data, buffer: buffer, boxed: false)
                break
            case .notificationSoundNone:
                if boxed {
                    buffer.appendInt32(1863070943)
                }
                break
            case .notificationSoundRingtone(let _data):
                if boxed {
                    buffer.appendInt32(-9666487)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .notificationSoundDefault:
                return ("notificationSoundDefault", [])
            case .notificationSoundLocal(let _data):
                return ("notificationSoundLocal", [("title", ConstructorParameterDescription(_data.title)), ("data", ConstructorParameterDescription(_data.data))])
            case .notificationSoundNone:
                return ("notificationSoundNone", [])
            case .notificationSoundRingtone(let _data):
                return ("notificationSoundRingtone", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_notificationSoundDefault(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundDefault
        }
        public static func parse_notificationSoundLocal(_ reader: BufferReader) -> NotificationSound? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotificationSound.notificationSoundLocal(Cons_notificationSoundLocal(title: _1!, data: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_notificationSoundNone(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundNone
        }
        public static func parse_notificationSoundRingtone(_ reader: BufferReader) -> NotificationSound? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotificationSound.notificationSoundRingtone(Cons_notificationSoundRingtone(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription {
        public class Cons_notifyCommunity: TypeConstructorDescription {
            public var communityId: Int64
            public init(communityId: Int64) {
                self.communityId = communityId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notifyCommunity", [("communityId", ConstructorParameterDescription(self.communityId))])
            }
        }
        public class Cons_notifyForumTopic: TypeConstructorDescription {
            public var peer: Api.Peer
            public var topMsgId: Int32
            public init(peer: Api.Peer, topMsgId: Int32) {
                self.peer = peer
                self.topMsgId = topMsgId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notifyForumTopic", [("peer", ConstructorParameterDescription(self.peer)), ("topMsgId", ConstructorParameterDescription(self.topMsgId))])
            }
        }
        public class Cons_notifyPeer: TypeConstructorDescription {
            public var peer: Api.Peer
            public init(peer: Api.Peer) {
                self.peer = peer
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("notifyPeer", [("peer", ConstructorParameterDescription(self.peer))])
            }
        }
        case notifyBroadcasts
        case notifyChats
        case notifyCommunity(Cons_notifyCommunity)
        case notifyForumTopic(Cons_notifyForumTopic)
        case notifyPeer(Cons_notifyPeer)
        case notifyUsers

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .notifyBroadcasts:
                if boxed {
                    buffer.appendInt32(-703403793)
                }
                break
            case .notifyChats:
                if boxed {
                    buffer.appendInt32(-1073230141)
                }
                break
            case .notifyCommunity(let _data):
                if boxed {
                    buffer.appendInt32(-1103664743)
                }
                serializeInt64(_data.communityId, buffer: buffer, boxed: false)
                break
            case .notifyForumTopic(let _data):
                if boxed {
                    buffer.appendInt32(577659656)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.topMsgId, buffer: buffer, boxed: false)
                break
            case .notifyPeer(let _data):
                if boxed {
                    buffer.appendInt32(-1613493288)
                }
                _data.peer.serialize(buffer, true)
                break
            case .notifyUsers:
                if boxed {
                    buffer.appendInt32(-1261946036)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .notifyBroadcasts:
                return ("notifyBroadcasts", [])
            case .notifyChats:
                return ("notifyChats", [])
            case .notifyCommunity(let _data):
                return ("notifyCommunity", [("communityId", ConstructorParameterDescription(_data.communityId))])
            case .notifyForumTopic(let _data):
                return ("notifyForumTopic", [("peer", ConstructorParameterDescription(_data.peer)), ("topMsgId", ConstructorParameterDescription(_data.topMsgId))])
            case .notifyPeer(let _data):
                return ("notifyPeer", [("peer", ConstructorParameterDescription(_data.peer))])
            case .notifyUsers:
                return ("notifyUsers", [])
            }
        }

        public static func parse_notifyBroadcasts(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyBroadcasts
        }
        public static func parse_notifyChats(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyChats
        }
        public static func parse_notifyCommunity(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotifyPeer.notifyCommunity(Cons_notifyCommunity(communityId: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_notifyForumTopic(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotifyPeer.notifyForumTopic(Cons_notifyForumTopic(peer: _1!, topMsgId: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_notifyPeer(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotifyPeer.notifyPeer(Cons_notifyPeer(peer: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_notifyUsers(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyUsers
        }
    }
}
public extension Api {
    enum OnrampAvailability: TypeConstructorDescription {
        public class Cons_onrampAvailability: TypeConstructorDescription {
            public var flags: Int32
            public var countryCode: String
            public var state: String?
            public var methods: [Api.OnrampMethodAvailability]
            public init(flags: Int32, countryCode: String, state: String?, methods: [Api.OnrampMethodAvailability]) {
                self.flags = flags
                self.countryCode = countryCode
                self.state = state
                self.methods = methods
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampAvailability", [("flags", ConstructorParameterDescription(self.flags)), ("countryCode", ConstructorParameterDescription(self.countryCode)), ("state", ConstructorParameterDescription(self.state)), ("methods", ConstructorParameterDescription(self.methods))])
            }
        }
        case onrampAvailability(Cons_onrampAvailability)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampAvailability(let _data):
                if boxed {
                    buffer.appendInt32(-104314509)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.countryCode, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.state!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.methods.count))
                for item in _data.methods {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampAvailability(let _data):
                return ("onrampAvailability", [("flags", ConstructorParameterDescription(_data.flags)), ("countryCode", ConstructorParameterDescription(_data.countryCode)), ("state", ConstructorParameterDescription(_data.state)), ("methods", ConstructorParameterDescription(_data.methods))])
            }
        }

        public static func parse_onrampAvailability(_ reader: BufferReader) -> OnrampAvailability? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _3 = parseString(reader)
            }
            var _4: [Api.OnrampMethodAvailability]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.OnrampMethodAvailability.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.OnrampAvailability.onrampAvailability(Cons_onrampAvailability(flags: _1!, countryCode: _2!, state: _3, methods: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OnrampLimits: TypeConstructorDescription {
        public class Cons_onrampLimits: TypeConstructorDescription {
            public var baseCurrency: String
            public var baseMinAmount: String
            public var baseMaxAmount: String
            public var cryptoMinAmount: String
            public var cryptoMaxAmount: String
            public var paymentMethod: String
            public init(baseCurrency: String, baseMinAmount: String, baseMaxAmount: String, cryptoMinAmount: String, cryptoMaxAmount: String, paymentMethod: String) {
                self.baseCurrency = baseCurrency
                self.baseMinAmount = baseMinAmount
                self.baseMaxAmount = baseMaxAmount
                self.cryptoMinAmount = cryptoMinAmount
                self.cryptoMaxAmount = cryptoMaxAmount
                self.paymentMethod = paymentMethod
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampLimits", [("baseCurrency", ConstructorParameterDescription(self.baseCurrency)), ("baseMinAmount", ConstructorParameterDescription(self.baseMinAmount)), ("baseMaxAmount", ConstructorParameterDescription(self.baseMaxAmount)), ("cryptoMinAmount", ConstructorParameterDescription(self.cryptoMinAmount)), ("cryptoMaxAmount", ConstructorParameterDescription(self.cryptoMaxAmount)), ("paymentMethod", ConstructorParameterDescription(self.paymentMethod))])
            }
        }
        case onrampLimits(Cons_onrampLimits)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampLimits(let _data):
                if boxed {
                    buffer.appendInt32(2078435198)
                }
                serializeString(_data.baseCurrency, buffer: buffer, boxed: false)
                serializeString(_data.baseMinAmount, buffer: buffer, boxed: false)
                serializeString(_data.baseMaxAmount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoMinAmount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoMaxAmount, buffer: buffer, boxed: false)
                serializeString(_data.paymentMethod, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampLimits(let _data):
                return ("onrampLimits", [("baseCurrency", ConstructorParameterDescription(_data.baseCurrency)), ("baseMinAmount", ConstructorParameterDescription(_data.baseMinAmount)), ("baseMaxAmount", ConstructorParameterDescription(_data.baseMaxAmount)), ("cryptoMinAmount", ConstructorParameterDescription(_data.cryptoMinAmount)), ("cryptoMaxAmount", ConstructorParameterDescription(_data.cryptoMaxAmount)), ("paymentMethod", ConstructorParameterDescription(_data.paymentMethod))])
            }
        }

        public static func parse_onrampLimits(_ reader: BufferReader) -> OnrampLimits? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.OnrampLimits.onrampLimits(Cons_onrampLimits(baseCurrency: _1!, baseMinAmount: _2!, baseMaxAmount: _3!, cryptoMinAmount: _4!, cryptoMaxAmount: _5!, paymentMethod: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OnrampMethodAvailability: TypeConstructorDescription {
        public class Cons_onrampMethodAvailability: TypeConstructorDescription {
            public var flags: Int32
            public var paymentMethod: String
            public init(flags: Int32, paymentMethod: String) {
                self.flags = flags
                self.paymentMethod = paymentMethod
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampMethodAvailability", [("flags", ConstructorParameterDescription(self.flags)), ("paymentMethod", ConstructorParameterDescription(self.paymentMethod))])
            }
        }
        case onrampMethodAvailability(Cons_onrampMethodAvailability)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampMethodAvailability(let _data):
                if boxed {
                    buffer.appendInt32(-1631009112)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.paymentMethod, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampMethodAvailability(let _data):
                return ("onrampMethodAvailability", [("flags", ConstructorParameterDescription(_data.flags)), ("paymentMethod", ConstructorParameterDescription(_data.paymentMethod))])
            }
        }

        public static func parse_onrampMethodAvailability(_ reader: BufferReader) -> OnrampMethodAvailability? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.OnrampMethodAvailability.onrampMethodAvailability(Cons_onrampMethodAvailability(flags: _1!, paymentMethod: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OnrampProviderInfo: TypeConstructorDescription {
        public class Cons_onrampProviderInfo: TypeConstructorDescription {
            public var flags: Int32
            public var id: String
            public var name: String
            public var cryptoCurrencies: [String]
            public init(flags: Int32, id: String, name: String, cryptoCurrencies: [String]) {
                self.flags = flags
                self.id = id
                self.name = name
                self.cryptoCurrencies = cryptoCurrencies
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampProviderInfo", [("flags", ConstructorParameterDescription(self.flags)), ("id", ConstructorParameterDescription(self.id)), ("name", ConstructorParameterDescription(self.name)), ("cryptoCurrencies", ConstructorParameterDescription(self.cryptoCurrencies))])
            }
        }
        case onrampProviderInfo(Cons_onrampProviderInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampProviderInfo(let _data):
                if boxed {
                    buffer.appendInt32(230847874)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.id, buffer: buffer, boxed: false)
                serializeString(_data.name, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.cryptoCurrencies.count))
                for item in _data.cryptoCurrencies {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampProviderInfo(let _data):
                return ("onrampProviderInfo", [("flags", ConstructorParameterDescription(_data.flags)), ("id", ConstructorParameterDescription(_data.id)), ("name", ConstructorParameterDescription(_data.name)), ("cryptoCurrencies", ConstructorParameterDescription(_data.cryptoCurrencies))])
            }
        }

        public static func parse_onrampProviderInfo(_ reader: BufferReader) -> OnrampProviderInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [String]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.OnrampProviderInfo.onrampProviderInfo(Cons_onrampProviderInfo(flags: _1!, id: _2!, name: _3!, cryptoCurrencies: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OnrampQuote: TypeConstructorDescription {
        public class Cons_onrampQuote: TypeConstructorDescription {
            public var baseCurrency: String
            public var baseAmount: String
            public var cryptoCurrency: String
            public var cryptoAmount: String
            public var cryptoPrice: String
            public var feeAmount: String
            public var extraFeeAmount: String
            public var networkFeeAmount: String
            public var totalAmount: String
            public var paymentMethod: String
            public var expiresDate: Int32
            public init(baseCurrency: String, baseAmount: String, cryptoCurrency: String, cryptoAmount: String, cryptoPrice: String, feeAmount: String, extraFeeAmount: String, networkFeeAmount: String, totalAmount: String, paymentMethod: String, expiresDate: Int32) {
                self.baseCurrency = baseCurrency
                self.baseAmount = baseAmount
                self.cryptoCurrency = cryptoCurrency
                self.cryptoAmount = cryptoAmount
                self.cryptoPrice = cryptoPrice
                self.feeAmount = feeAmount
                self.extraFeeAmount = extraFeeAmount
                self.networkFeeAmount = networkFeeAmount
                self.totalAmount = totalAmount
                self.paymentMethod = paymentMethod
                self.expiresDate = expiresDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampQuote", [("baseCurrency", ConstructorParameterDescription(self.baseCurrency)), ("baseAmount", ConstructorParameterDescription(self.baseAmount)), ("cryptoCurrency", ConstructorParameterDescription(self.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(self.cryptoAmount)), ("cryptoPrice", ConstructorParameterDescription(self.cryptoPrice)), ("feeAmount", ConstructorParameterDescription(self.feeAmount)), ("extraFeeAmount", ConstructorParameterDescription(self.extraFeeAmount)), ("networkFeeAmount", ConstructorParameterDescription(self.networkFeeAmount)), ("totalAmount", ConstructorParameterDescription(self.totalAmount)), ("paymentMethod", ConstructorParameterDescription(self.paymentMethod)), ("expiresDate", ConstructorParameterDescription(self.expiresDate))])
            }
        }
        case onrampQuote(Cons_onrampQuote)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampQuote(let _data):
                if boxed {
                    buffer.appendInt32(2055213545)
                }
                serializeString(_data.baseCurrency, buffer: buffer, boxed: false)
                serializeString(_data.baseAmount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoCurrency, buffer: buffer, boxed: false)
                serializeString(_data.cryptoAmount, buffer: buffer, boxed: false)
                serializeString(_data.cryptoPrice, buffer: buffer, boxed: false)
                serializeString(_data.feeAmount, buffer: buffer, boxed: false)
                serializeString(_data.extraFeeAmount, buffer: buffer, boxed: false)
                serializeString(_data.networkFeeAmount, buffer: buffer, boxed: false)
                serializeString(_data.totalAmount, buffer: buffer, boxed: false)
                serializeString(_data.paymentMethod, buffer: buffer, boxed: false)
                serializeInt32(_data.expiresDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampQuote(let _data):
                return ("onrampQuote", [("baseCurrency", ConstructorParameterDescription(_data.baseCurrency)), ("baseAmount", ConstructorParameterDescription(_data.baseAmount)), ("cryptoCurrency", ConstructorParameterDescription(_data.cryptoCurrency)), ("cryptoAmount", ConstructorParameterDescription(_data.cryptoAmount)), ("cryptoPrice", ConstructorParameterDescription(_data.cryptoPrice)), ("feeAmount", ConstructorParameterDescription(_data.feeAmount)), ("extraFeeAmount", ConstructorParameterDescription(_data.extraFeeAmount)), ("networkFeeAmount", ConstructorParameterDescription(_data.networkFeeAmount)), ("totalAmount", ConstructorParameterDescription(_data.totalAmount)), ("paymentMethod", ConstructorParameterDescription(_data.paymentMethod)), ("expiresDate", ConstructorParameterDescription(_data.expiresDate))])
            }
        }

        public static func parse_onrampQuote(_ reader: BufferReader) -> OnrampQuote? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
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
            var _8: String?
            _8 = parseString(reader)
            var _9: String?
            _9 = parseString(reader)
            var _10: String?
            _10 = parseString(reader)
            var _11: Int32?
            _11 = reader.readInt32()
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.OnrampQuote.onrampQuote(Cons_onrampQuote(baseCurrency: _1!, baseAmount: _2!, cryptoCurrency: _3!, cryptoAmount: _4!, cryptoPrice: _5!, feeAmount: _6!, extraFeeAmount: _7!, networkFeeAmount: _8!, totalAmount: _9!, paymentMethod: _10!, expiresDate: _11!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OnrampSession: TypeConstructorDescription {
        public class Cons_onrampSession: TypeConstructorDescription {
            public var provider: String
            public var sessionId: String
            public var url: String
            public var expiresDate: Int32
            public init(provider: String, sessionId: String, url: String, expiresDate: Int32) {
                self.provider = provider
                self.sessionId = sessionId
                self.url = url
                self.expiresDate = expiresDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("onrampSession", [("provider", ConstructorParameterDescription(self.provider)), ("sessionId", ConstructorParameterDescription(self.sessionId)), ("url", ConstructorParameterDescription(self.url)), ("expiresDate", ConstructorParameterDescription(self.expiresDate))])
            }
        }
        case onrampSession(Cons_onrampSession)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .onrampSession(let _data):
                if boxed {
                    buffer.appendInt32(-773575132)
                }
                serializeString(_data.provider, buffer: buffer, boxed: false)
                serializeString(_data.sessionId, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.expiresDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .onrampSession(let _data):
                return ("onrampSession", [("provider", ConstructorParameterDescription(_data.provider)), ("sessionId", ConstructorParameterDescription(_data.sessionId)), ("url", ConstructorParameterDescription(_data.url)), ("expiresDate", ConstructorParameterDescription(_data.expiresDate))])
            }
        }

        public static func parse_onrampSession(_ reader: BufferReader) -> OnrampSession? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.OnrampSession.onrampSession(Cons_onrampSession(provider: _1!, sessionId: _2!, url: _3!, expiresDate: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum OutboxReadDate: TypeConstructorDescription {
        public class Cons_outboxReadDate: TypeConstructorDescription {
            public var date: Int32
            public init(date: Int32) {
                self.date = date
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("outboxReadDate", [("date", ConstructorParameterDescription(self.date))])
            }
        }
        case outboxReadDate(Cons_outboxReadDate)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .outboxReadDate(let _data):
                if boxed {
                    buffer.appendInt32(1001931436)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .outboxReadDate(let _data):
                return ("outboxReadDate", [("date", ConstructorParameterDescription(_data.date))])
            }
        }

        public static func parse_outboxReadDate(_ reader: BufferReader) -> OutboxReadDate? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.OutboxReadDate.outboxReadDate(Cons_outboxReadDate(date: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum Page: TypeConstructorDescription {
        public class Cons_page: TypeConstructorDescription {
            public var flags: Int32
            public var url: String
            public var blocks: [Api.PageBlock]
            public var photos: [Api.Photo]
            public var documents: [Api.Document]
            public var views: Int32?
            public init(flags: Int32, url: String, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document], views: Int32?) {
                self.flags = flags
                self.url = url
                self.blocks = blocks
                self.photos = photos
                self.documents = documents
                self.views = views
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("page", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("blocks", ConstructorParameterDescription(self.blocks)), ("photos", ConstructorParameterDescription(self.photos)), ("documents", ConstructorParameterDescription(self.documents)), ("views", ConstructorParameterDescription(self.views))])
            }
        }
        case page(Cons_page)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .page(let _data):
                if boxed {
                    buffer.appendInt32(-1738178803)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.url, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.photos.count))
                for item in _data.photos {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.views!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .page(let _data):
                return ("page", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("photos", ConstructorParameterDescription(_data.photos)), ("documents", ConstructorParameterDescription(_data.documents)), ("views", ConstructorParameterDescription(_data.views))])
            }
        }

        public static func parse_page(_ reader: BufferReader) -> Page? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _4: [Api.Photo]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Photo.self)
            }
            var _5: [Api.Document]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Page.page(Cons_page(flags: _1!, url: _2!, blocks: _3!, photos: _4!, documents: _5!, views: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum PageBlock: TypeConstructorDescription {
        public class Cons_inputPageBlockMap: TypeConstructorDescription {
            public var geo: Api.InputGeoPoint
            public var zoom: Int32
            public var w: Int32
            public var h: Int32
            public var caption: Api.PageCaption
            public init(geo: Api.InputGeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
                self.geo = geo
                self.zoom = zoom
                self.w = w
                self.h = h
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("inputPageBlockMap", [("geo", ConstructorParameterDescription(self.geo)), ("zoom", ConstructorParameterDescription(self.zoom)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockAnchor: TypeConstructorDescription {
            public var name: String
            public init(name: String) {
                self.name = name
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAnchor", [("name", ConstructorParameterDescription(self.name))])
            }
        }
        public class Cons_pageBlockAudio: TypeConstructorDescription {
            public var audioId: Int64
            public var caption: Api.PageCaption
            public init(audioId: Int64, caption: Api.PageCaption) {
                self.audioId = audioId
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAudio", [("audioId", ConstructorParameterDescription(self.audioId)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockAuthorDate: TypeConstructorDescription {
            public var author: Api.RichText
            public var publishedDate: Int32
            public init(author: Api.RichText, publishedDate: Int32) {
                self.author = author
                self.publishedDate = publishedDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockAuthorDate", [("author", ConstructorParameterDescription(self.author)), ("publishedDate", ConstructorParameterDescription(self.publishedDate))])
            }
        }
        public class Cons_pageBlockBlockquote: TypeConstructorDescription {
            public var flags: Int32
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(flags: Int32, text: Api.RichText, caption: Api.RichText) {
                self.flags = flags
                self.text = text
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockBlockquote", [("flags", ConstructorParameterDescription(self.flags)), ("text", ConstructorParameterDescription(self.text)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockBlockquoteBlocks: TypeConstructorDescription {
            public var blocks: [Api.PageBlock]
            public var caption: Api.RichText
            public init(blocks: [Api.PageBlock], caption: Api.RichText) {
                self.blocks = blocks
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockBlockquoteBlocks", [("blocks", ConstructorParameterDescription(self.blocks)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockButtonRow: TypeConstructorDescription {
            public var flags: Int32
            public var buttons: [Api.PageButton]
            public init(flags: Int32, buttons: [Api.PageButton]) {
                self.flags = flags
                self.buttons = buttons
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockButtonRow", [("flags", ConstructorParameterDescription(self.flags)), ("buttons", ConstructorParameterDescription(self.buttons))])
            }
        }
        public class Cons_pageBlockChannel: TypeConstructorDescription {
            public var channel: Api.Chat
            public init(channel: Api.Chat) {
                self.channel = channel
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockChannel", [("channel", ConstructorParameterDescription(self.channel))])
            }
        }
        public class Cons_pageBlockCollage: TypeConstructorDescription {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockCollage", [("items", ConstructorParameterDescription(self.items)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockCover: TypeConstructorDescription {
            public var cover: Api.PageBlock
            public init(cover: Api.PageBlock) {
                self.cover = cover
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockCover", [("cover", ConstructorParameterDescription(self.cover))])
            }
        }
        public class Cons_pageBlockDetails: TypeConstructorDescription {
            public var flags: Int32
            public var blocks: [Api.PageBlock]
            public var title: Api.RichText
            public init(flags: Int32, blocks: [Api.PageBlock], title: Api.RichText) {
                self.flags = flags
                self.blocks = blocks
                self.title = title
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockDetails", [("flags", ConstructorParameterDescription(self.flags)), ("blocks", ConstructorParameterDescription(self.blocks)), ("title", ConstructorParameterDescription(self.title))])
            }
        }
        public class Cons_pageBlockDocument: TypeConstructorDescription {
            public var documentId: Int64
            public var caption: Api.PageCaption
            public init(documentId: Int64, caption: Api.PageCaption) {
                self.documentId = documentId
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockDocument", [("documentId", ConstructorParameterDescription(self.documentId)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockEmbed: TypeConstructorDescription {
            public var flags: Int32
            public var url: String?
            public var html: String?
            public var posterPhotoId: Int64?
            public var w: Int32?
            public var h: Int32?
            public var caption: Api.PageCaption
            public init(flags: Int32, url: String?, html: String?, posterPhotoId: Int64?, w: Int32?, h: Int32?, caption: Api.PageCaption) {
                self.flags = flags
                self.url = url
                self.html = html
                self.posterPhotoId = posterPhotoId
                self.w = w
                self.h = h
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockEmbed", [("flags", ConstructorParameterDescription(self.flags)), ("url", ConstructorParameterDescription(self.url)), ("html", ConstructorParameterDescription(self.html)), ("posterPhotoId", ConstructorParameterDescription(self.posterPhotoId)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockEmbedPost: TypeConstructorDescription {
            public var url: String
            public var webpageId: Int64
            public var authorPhotoId: Int64
            public var author: String
            public var date: Int32
            public var blocks: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(url: String, webpageId: Int64, authorPhotoId: Int64, author: String, date: Int32, blocks: [Api.PageBlock], caption: Api.PageCaption) {
                self.url = url
                self.webpageId = webpageId
                self.authorPhotoId = authorPhotoId
                self.author = author
                self.date = date
                self.blocks = blocks
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockEmbedPost", [("url", ConstructorParameterDescription(self.url)), ("webpageId", ConstructorParameterDescription(self.webpageId)), ("authorPhotoId", ConstructorParameterDescription(self.authorPhotoId)), ("author", ConstructorParameterDescription(self.author)), ("date", ConstructorParameterDescription(self.date)), ("blocks", ConstructorParameterDescription(self.blocks)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockFooter: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockFooter", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeader: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeader", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading1: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading1", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading2: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading2", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading3: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading3", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading4: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading4", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading5: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading5", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockHeading6: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockHeading6", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockKicker: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockKicker", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockList: TypeConstructorDescription {
            public var items: [Api.PageListItem]
            public init(items: [Api.PageListItem]) {
                self.items = items
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockList", [("items", ConstructorParameterDescription(self.items))])
            }
        }
        public class Cons_pageBlockMap: TypeConstructorDescription {
            public var geo: Api.GeoPoint
            public var zoom: Int32
            public var w: Int32
            public var h: Int32
            public var caption: Api.PageCaption
            public init(geo: Api.GeoPoint, zoom: Int32, w: Int32, h: Int32, caption: Api.PageCaption) {
                self.geo = geo
                self.zoom = zoom
                self.w = w
                self.h = h
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockMap", [("geo", ConstructorParameterDescription(self.geo)), ("zoom", ConstructorParameterDescription(self.zoom)), ("w", ConstructorParameterDescription(self.w)), ("h", ConstructorParameterDescription(self.h)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockMath: TypeConstructorDescription {
            public var source: String
            public init(source: String) {
                self.source = source
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockMath", [("source", ConstructorParameterDescription(self.source))])
            }
        }
        public class Cons_pageBlockOrderedList: TypeConstructorDescription {
            public var flags: Int32
            public var items: [Api.PageListOrderedItem]
            public var start: Int32?
            public var type: String?
            public init(flags: Int32, items: [Api.PageListOrderedItem], start: Int32?, type: String?) {
                self.flags = flags
                self.items = items
                self.start = start
                self.type = type
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockOrderedList", [("flags", ConstructorParameterDescription(self.flags)), ("items", ConstructorParameterDescription(self.items)), ("start", ConstructorParameterDescription(self.start)), ("type", ConstructorParameterDescription(self.type))])
            }
        }
        public class Cons_pageBlockParagraph: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockParagraph", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockPhoto: TypeConstructorDescription {
            public var flags: Int32
            public var photoId: Int64
            public var caption: Api.PageCaption
            public var url: String?
            public var webpageId: Int64?
            public init(flags: Int32, photoId: Int64, caption: Api.PageCaption, url: String?, webpageId: Int64?) {
                self.flags = flags
                self.photoId = photoId
                self.caption = caption
                self.url = url
                self.webpageId = webpageId
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPhoto", [("flags", ConstructorParameterDescription(self.flags)), ("photoId", ConstructorParameterDescription(self.photoId)), ("caption", ConstructorParameterDescription(self.caption)), ("url", ConstructorParameterDescription(self.url)), ("webpageId", ConstructorParameterDescription(self.webpageId))])
            }
        }
        public class Cons_pageBlockPreformatted: TypeConstructorDescription {
            public var text: Api.RichText
            public var language: String
            public init(text: Api.RichText, language: String) {
                self.text = text
                self.language = language
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPreformatted", [("text", ConstructorParameterDescription(self.text)), ("language", ConstructorParameterDescription(self.language))])
            }
        }
        public class Cons_pageBlockPullquote: TypeConstructorDescription {
            public var text: Api.RichText
            public var caption: Api.RichText
            public init(text: Api.RichText, caption: Api.RichText) {
                self.text = text
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockPullquote", [("text", ConstructorParameterDescription(self.text)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockRelatedArticles: TypeConstructorDescription {
            public var title: Api.RichText
            public var articles: [Api.PageRelatedArticle]
            public init(title: Api.RichText, articles: [Api.PageRelatedArticle]) {
                self.title = title
                self.articles = articles
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockRelatedArticles", [("title", ConstructorParameterDescription(self.title)), ("articles", ConstructorParameterDescription(self.articles))])
            }
        }
        public class Cons_pageBlockSlideshow: TypeConstructorDescription {
            public var items: [Api.PageBlock]
            public var caption: Api.PageCaption
            public init(items: [Api.PageBlock], caption: Api.PageCaption) {
                self.items = items
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSlideshow", [("items", ConstructorParameterDescription(self.items)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        public class Cons_pageBlockSubheader: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSubheader", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockSubtitle: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockSubtitle", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockTable: TypeConstructorDescription {
            public var flags: Int32
            public var title: Api.RichText
            public var rows: [Api.PageTableRow]
            public init(flags: Int32, title: Api.RichText, rows: [Api.PageTableRow]) {
                self.flags = flags
                self.title = title
                self.rows = rows
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockTable", [("flags", ConstructorParameterDescription(self.flags)), ("title", ConstructorParameterDescription(self.title)), ("rows", ConstructorParameterDescription(self.rows))])
            }
        }
        public class Cons_pageBlockThinking: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockThinking", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockTitle: TypeConstructorDescription {
            public var text: Api.RichText
            public init(text: Api.RichText) {
                self.text = text
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockTitle", [("text", ConstructorParameterDescription(self.text))])
            }
        }
        public class Cons_pageBlockVideo: TypeConstructorDescription {
            public var flags: Int32
            public var videoId: Int64
            public var caption: Api.PageCaption
            public init(flags: Int32, videoId: Int64, caption: Api.PageCaption) {
                self.flags = flags
                self.videoId = videoId
                self.caption = caption
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("pageBlockVideo", [("flags", ConstructorParameterDescription(self.flags)), ("videoId", ConstructorParameterDescription(self.videoId)), ("caption", ConstructorParameterDescription(self.caption))])
            }
        }
        case inputPageBlockMap(Cons_inputPageBlockMap)
        case pageBlockAnchor(Cons_pageBlockAnchor)
        case pageBlockAudio(Cons_pageBlockAudio)
        case pageBlockAuthorDate(Cons_pageBlockAuthorDate)
        case pageBlockBlockquote(Cons_pageBlockBlockquote)
        case pageBlockBlockquoteBlocks(Cons_pageBlockBlockquoteBlocks)
        case pageBlockButtonRow(Cons_pageBlockButtonRow)
        case pageBlockChannel(Cons_pageBlockChannel)
        case pageBlockCollage(Cons_pageBlockCollage)
        case pageBlockCover(Cons_pageBlockCover)
        case pageBlockDetails(Cons_pageBlockDetails)
        case pageBlockDivider
        case pageBlockDocument(Cons_pageBlockDocument)
        case pageBlockEmbed(Cons_pageBlockEmbed)
        case pageBlockEmbedPost(Cons_pageBlockEmbedPost)
        case pageBlockFooter(Cons_pageBlockFooter)
        case pageBlockHeader(Cons_pageBlockHeader)
        case pageBlockHeading1(Cons_pageBlockHeading1)
        case pageBlockHeading2(Cons_pageBlockHeading2)
        case pageBlockHeading3(Cons_pageBlockHeading3)
        case pageBlockHeading4(Cons_pageBlockHeading4)
        case pageBlockHeading5(Cons_pageBlockHeading5)
        case pageBlockHeading6(Cons_pageBlockHeading6)
        case pageBlockKicker(Cons_pageBlockKicker)
        case pageBlockList(Cons_pageBlockList)
        case pageBlockMap(Cons_pageBlockMap)
        case pageBlockMath(Cons_pageBlockMath)
        case pageBlockOrderedList(Cons_pageBlockOrderedList)
        case pageBlockParagraph(Cons_pageBlockParagraph)
        case pageBlockPhoto(Cons_pageBlockPhoto)
        case pageBlockPreformatted(Cons_pageBlockPreformatted)
        case pageBlockPullquote(Cons_pageBlockPullquote)
        case pageBlockRelatedArticles(Cons_pageBlockRelatedArticles)
        case pageBlockSlideshow(Cons_pageBlockSlideshow)
        case pageBlockSubheader(Cons_pageBlockSubheader)
        case pageBlockSubtitle(Cons_pageBlockSubtitle)
        case pageBlockTable(Cons_pageBlockTable)
        case pageBlockThinking(Cons_pageBlockThinking)
        case pageBlockTitle(Cons_pageBlockTitle)
        case pageBlockUnsupported
        case pageBlockVideo(Cons_pageBlockVideo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputPageBlockMap(let _data):
                if boxed {
                    buffer.appendInt32(1464557951)
                }
                _data.geo.serialize(buffer, true)
                serializeInt32(_data.zoom, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockAnchor(let _data):
                if boxed {
                    buffer.appendInt32(-837994576)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                break
            case .pageBlockAudio(let _data):
                if boxed {
                    buffer.appendInt32(-2143067670)
                }
                serializeInt64(_data.audioId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockAuthorDate(let _data):
                if boxed {
                    buffer.appendInt32(-1162877472)
                }
                _data.author.serialize(buffer, true)
                serializeInt32(_data.publishedDate, buffer: buffer, boxed: false)
                break
            case .pageBlockBlockquote(let _data):
                if boxed {
                    buffer.appendInt32(1724999435)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.text.serialize(buffer, true)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockBlockquoteBlocks(let _data):
                if boxed {
                    buffer.appendInt32(242108356)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockButtonRow(let _data):
                if boxed {
                    buffer.appendInt32(1835270936)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.buttons.count))
                for item in _data.buttons {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockChannel(let _data):
                if boxed {
                    buffer.appendInt32(-283684427)
                }
                _data.channel.serialize(buffer, true)
                break
            case .pageBlockCollage(let _data):
                if boxed {
                    buffer.appendInt32(1705048653)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockCover(let _data):
                if boxed {
                    buffer.appendInt32(972174080)
                }
                _data.cover.serialize(buffer, true)
                break
            case .pageBlockDetails(let _data):
                if boxed {
                    buffer.appendInt32(1987480557)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                _data.title.serialize(buffer, true)
                break
            case .pageBlockDivider:
                if boxed {
                    buffer.appendInt32(-618614392)
                }
                break
            case .pageBlockDocument(let _data):
                if boxed {
                    buffer.appendInt32(955923363)
                }
                serializeInt64(_data.documentId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockEmbed(let _data):
                if boxed {
                    buffer.appendInt32(-1468953147)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.html!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.posterPhotoId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.w!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.h!, buffer: buffer, boxed: false)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockEmbedPost(let _data):
                if boxed {
                    buffer.appendInt32(-229005301)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt64(_data.webpageId, buffer: buffer, boxed: false)
                serializeInt64(_data.authorPhotoId, buffer: buffer, boxed: false)
                serializeString(_data.author, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.blocks.count))
                for item in _data.blocks {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockFooter(let _data):
                if boxed {
                    buffer.appendInt32(1216809369)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeader(let _data):
                if boxed {
                    buffer.appendInt32(-1076861716)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading1(let _data):
                if boxed {
                    buffer.appendInt32(-1157691601)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading2(let _data):
                if boxed {
                    buffer.appendInt32(158018284)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading3(let _data):
                if boxed {
                    buffer.appendInt32(1743204781)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading4(let _data):
                if boxed {
                    buffer.appendInt32(-1254983893)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading5(let _data):
                if boxed {
                    buffer.appendInt32(-608277398)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockHeading6(let _data):
                if boxed {
                    buffer.appendInt32(1747599785)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockKicker(let _data):
                if boxed {
                    buffer.appendInt32(504660880)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockList(let _data):
                if boxed {
                    buffer.appendInt32(-454524911)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockMap(let _data):
                if boxed {
                    buffer.appendInt32(-1538310410)
                }
                _data.geo.serialize(buffer, true)
                serializeInt32(_data.zoom, buffer: buffer, boxed: false)
                serializeInt32(_data.w, buffer: buffer, boxed: false)
                serializeInt32(_data.h, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockMath(let _data):
                if boxed {
                    buffer.appendInt32(1493699616)
                }
                serializeString(_data.source, buffer: buffer, boxed: false)
                break
            case .pageBlockOrderedList(let _data):
                if boxed {
                    buffer.appendInt32(534181569)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.start!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.type!, buffer: buffer, boxed: false)
                }
                break
            case .pageBlockParagraph(let _data):
                if boxed {
                    buffer.appendInt32(1182402406)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockPhoto(let _data):
                if boxed {
                    buffer.appendInt32(391759200)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.photoId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.url!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.webpageId!, buffer: buffer, boxed: false)
                }
                break
            case .pageBlockPreformatted(let _data):
                if boxed {
                    buffer.appendInt32(-1066346178)
                }
                _data.text.serialize(buffer, true)
                serializeString(_data.language, buffer: buffer, boxed: false)
                break
            case .pageBlockPullquote(let _data):
                if boxed {
                    buffer.appendInt32(1329878739)
                }
                _data.text.serialize(buffer, true)
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockRelatedArticles(let _data):
                if boxed {
                    buffer.appendInt32(370236054)
                }
                _data.title.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.articles.count))
                for item in _data.articles {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockSlideshow(let _data):
                if boxed {
                    buffer.appendInt32(52401552)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.items.count))
                for item in _data.items {
                    item.serialize(buffer, true)
                }
                _data.caption.serialize(buffer, true)
                break
            case .pageBlockSubheader(let _data):
                if boxed {
                    buffer.appendInt32(-248793375)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockSubtitle(let _data):
                if boxed {
                    buffer.appendInt32(-1879401953)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockTable(let _data):
                if boxed {
                    buffer.appendInt32(-1085412734)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.title.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rows.count))
                for item in _data.rows {
                    item.serialize(buffer, true)
                }
                break
            case .pageBlockThinking(let _data):
                if boxed {
                    buffer.appendInt32(1009361890)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockTitle(let _data):
                if boxed {
                    buffer.appendInt32(1890305021)
                }
                _data.text.serialize(buffer, true)
                break
            case .pageBlockUnsupported:
                if boxed {
                    buffer.appendInt32(324435594)
                }
                break
            case .pageBlockVideo(let _data):
                if boxed {
                    buffer.appendInt32(2089805750)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.videoId, buffer: buffer, boxed: false)
                _data.caption.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .inputPageBlockMap(let _data):
                return ("inputPageBlockMap", [("geo", ConstructorParameterDescription(_data.geo)), ("zoom", ConstructorParameterDescription(_data.zoom)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockAnchor(let _data):
                return ("pageBlockAnchor", [("name", ConstructorParameterDescription(_data.name))])
            case .pageBlockAudio(let _data):
                return ("pageBlockAudio", [("audioId", ConstructorParameterDescription(_data.audioId)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockAuthorDate(let _data):
                return ("pageBlockAuthorDate", [("author", ConstructorParameterDescription(_data.author)), ("publishedDate", ConstructorParameterDescription(_data.publishedDate))])
            case .pageBlockBlockquote(let _data):
                return ("pageBlockBlockquote", [("flags", ConstructorParameterDescription(_data.flags)), ("text", ConstructorParameterDescription(_data.text)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockBlockquoteBlocks(let _data):
                return ("pageBlockBlockquoteBlocks", [("blocks", ConstructorParameterDescription(_data.blocks)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockButtonRow(let _data):
                return ("pageBlockButtonRow", [("flags", ConstructorParameterDescription(_data.flags)), ("buttons", ConstructorParameterDescription(_data.buttons))])
            case .pageBlockChannel(let _data):
                return ("pageBlockChannel", [("channel", ConstructorParameterDescription(_data.channel))])
            case .pageBlockCollage(let _data):
                return ("pageBlockCollage", [("items", ConstructorParameterDescription(_data.items)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockCover(let _data):
                return ("pageBlockCover", [("cover", ConstructorParameterDescription(_data.cover))])
            case .pageBlockDetails(let _data):
                return ("pageBlockDetails", [("flags", ConstructorParameterDescription(_data.flags)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("title", ConstructorParameterDescription(_data.title))])
            case .pageBlockDivider:
                return ("pageBlockDivider", [])
            case .pageBlockDocument(let _data):
                return ("pageBlockDocument", [("documentId", ConstructorParameterDescription(_data.documentId)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockEmbed(let _data):
                return ("pageBlockEmbed", [("flags", ConstructorParameterDescription(_data.flags)), ("url", ConstructorParameterDescription(_data.url)), ("html", ConstructorParameterDescription(_data.html)), ("posterPhotoId", ConstructorParameterDescription(_data.posterPhotoId)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockEmbedPost(let _data):
                return ("pageBlockEmbedPost", [("url", ConstructorParameterDescription(_data.url)), ("webpageId", ConstructorParameterDescription(_data.webpageId)), ("authorPhotoId", ConstructorParameterDescription(_data.authorPhotoId)), ("author", ConstructorParameterDescription(_data.author)), ("date", ConstructorParameterDescription(_data.date)), ("blocks", ConstructorParameterDescription(_data.blocks)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockFooter(let _data):
                return ("pageBlockFooter", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeader(let _data):
                return ("pageBlockHeader", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading1(let _data):
                return ("pageBlockHeading1", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading2(let _data):
                return ("pageBlockHeading2", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading3(let _data):
                return ("pageBlockHeading3", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading4(let _data):
                return ("pageBlockHeading4", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading5(let _data):
                return ("pageBlockHeading5", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockHeading6(let _data):
                return ("pageBlockHeading6", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockKicker(let _data):
                return ("pageBlockKicker", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockList(let _data):
                return ("pageBlockList", [("items", ConstructorParameterDescription(_data.items))])
            case .pageBlockMap(let _data):
                return ("pageBlockMap", [("geo", ConstructorParameterDescription(_data.geo)), ("zoom", ConstructorParameterDescription(_data.zoom)), ("w", ConstructorParameterDescription(_data.w)), ("h", ConstructorParameterDescription(_data.h)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockMath(let _data):
                return ("pageBlockMath", [("source", ConstructorParameterDescription(_data.source))])
            case .pageBlockOrderedList(let _data):
                return ("pageBlockOrderedList", [("flags", ConstructorParameterDescription(_data.flags)), ("items", ConstructorParameterDescription(_data.items)), ("start", ConstructorParameterDescription(_data.start)), ("type", ConstructorParameterDescription(_data.type))])
            case .pageBlockParagraph(let _data):
                return ("pageBlockParagraph", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockPhoto(let _data):
                return ("pageBlockPhoto", [("flags", ConstructorParameterDescription(_data.flags)), ("photoId", ConstructorParameterDescription(_data.photoId)), ("caption", ConstructorParameterDescription(_data.caption)), ("url", ConstructorParameterDescription(_data.url)), ("webpageId", ConstructorParameterDescription(_data.webpageId))])
            case .pageBlockPreformatted(let _data):
                return ("pageBlockPreformatted", [("text", ConstructorParameterDescription(_data.text)), ("language", ConstructorParameterDescription(_data.language))])
            case .pageBlockPullquote(let _data):
                return ("pageBlockPullquote", [("text", ConstructorParameterDescription(_data.text)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockRelatedArticles(let _data):
                return ("pageBlockRelatedArticles", [("title", ConstructorParameterDescription(_data.title)), ("articles", ConstructorParameterDescription(_data.articles))])
            case .pageBlockSlideshow(let _data):
                return ("pageBlockSlideshow", [("items", ConstructorParameterDescription(_data.items)), ("caption", ConstructorParameterDescription(_data.caption))])
            case .pageBlockSubheader(let _data):
                return ("pageBlockSubheader", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockSubtitle(let _data):
                return ("pageBlockSubtitle", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockTable(let _data):
                return ("pageBlockTable", [("flags", ConstructorParameterDescription(_data.flags)), ("title", ConstructorParameterDescription(_data.title)), ("rows", ConstructorParameterDescription(_data.rows))])
            case .pageBlockThinking(let _data):
                return ("pageBlockThinking", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockTitle(let _data):
                return ("pageBlockTitle", [("text", ConstructorParameterDescription(_data.text))])
            case .pageBlockUnsupported:
                return ("pageBlockUnsupported", [])
            case .pageBlockVideo(let _data):
                return ("pageBlockVideo", [("flags", ConstructorParameterDescription(_data.flags)), ("videoId", ConstructorParameterDescription(_data.videoId)), ("caption", ConstructorParameterDescription(_data.caption))])
            }
        }

        public static func parse_inputPageBlockMap(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.InputGeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGeoPoint
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.PageCaption?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.inputPageBlockMap(Cons_inputPageBlockMap(geo: _1!, zoom: _2!, w: _3!, h: _4!, caption: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockAnchor(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockAnchor(Cons_pageBlockAnchor(name: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockAudio(_ reader: BufferReader) -> PageBlock? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockAudio(Cons_pageBlockAudio(audioId: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockAuthorDate(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockAuthorDate(Cons_pageBlockAuthorDate(author: _1!, publishedDate: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockBlockquote(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _3: Api.RichText?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockBlockquote(Cons_pageBlockBlockquote(flags: _1!, text: _2!, caption: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockBlockquoteBlocks(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockBlockquoteBlocks(Cons_pageBlockBlockquoteBlocks(blocks: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockButtonRow(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PageButton]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageButton.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockButtonRow(Cons_pageBlockButtonRow(flags: _1!, buttons: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockChannel(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.Chat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Chat
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockChannel(Cons_pageBlockChannel(channel: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockCollage(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockCollage(Cons_pageBlockCollage(items: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockCover(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.PageBlock?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PageBlock
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockCover(Cons_pageBlockCover(cover: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockDetails(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _3: Api.RichText?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockDetails(Cons_pageBlockDetails(flags: _1!, blocks: _2!, title: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockDivider(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockDivider
        }
        public static func parse_pageBlockDocument(_ reader: BufferReader) -> PageBlock? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockDocument(Cons_pageBlockDocument(documentId: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockEmbed(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _2 = parseString(reader)
            }
            var _3: String?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _3 = parseString(reader)
            }
            var _4: Int64?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _4 = reader.readInt64()
            }
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _5 = reader.readInt32()
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Api.PageCaption?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PageBlock.pageBlockEmbed(Cons_pageBlockEmbed(flags: _1!, url: _2, html: _3, posterPhotoId: _4, w: _5, h: _6, caption: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockEmbedPost(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _7: Api.PageCaption?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.PageBlock.pageBlockEmbedPost(Cons_pageBlockEmbedPost(url: _1!, webpageId: _2!, authorPhotoId: _3!, author: _4!, date: _5!, blocks: _6!, caption: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockFooter(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockFooter(Cons_pageBlockFooter(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeader(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeader(Cons_pageBlockHeader(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading1(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading1(Cons_pageBlockHeading1(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading2(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading2(Cons_pageBlockHeading2(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading3(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading3(Cons_pageBlockHeading3(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading4(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading4(Cons_pageBlockHeading4(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading5(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading5(Cons_pageBlockHeading5(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockHeading6(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockHeading6(Cons_pageBlockHeading6(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockKicker(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockKicker(Cons_pageBlockKicker(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockList(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageListItem]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageListItem.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockList(Cons_pageBlockList(items: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockMap(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Api.PageCaption?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.pageBlockMap(Cons_pageBlockMap(geo: _1!, zoom: _2!, w: _3!, h: _4!, caption: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockMath(_ reader: BufferReader) -> PageBlock? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockMath(Cons_pageBlockMath(source: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockOrderedList(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PageListOrderedItem]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageListOrderedItem.self)
            }
            var _3: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _4 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.PageBlock.pageBlockOrderedList(Cons_pageBlockOrderedList(flags: _1!, items: _2!, start: _3, type: _4))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockParagraph(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockParagraph(Cons_pageBlockParagraph(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPhoto(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PageCaption?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int64?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.PageBlock.pageBlockPhoto(Cons_pageBlockPhoto(flags: _1!, photoId: _2!, caption: _3!, url: _4, webpageId: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPreformatted(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockPreformatted(Cons_pageBlockPreformatted(text: _1!, language: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockPullquote(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockPullquote(Cons_pageBlockPullquote(text: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockRelatedArticles(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _2: [Api.PageRelatedArticle]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageRelatedArticle.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockRelatedArticles(Cons_pageBlockRelatedArticles(title: _1!, articles: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSlideshow(_ reader: BufferReader) -> PageBlock? {
            var _1: [Api.PageBlock]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageBlock.self)
            }
            var _2: Api.PageCaption?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.PageBlock.pageBlockSlideshow(Cons_pageBlockSlideshow(items: _1!, caption: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSubheader(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockSubheader(Cons_pageBlockSubheader(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockSubtitle(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockSubtitle(Cons_pageBlockSubtitle(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockTable(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.RichText?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            var _3: [Api.PageTableRow]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PageTableRow.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockTable(Cons_pageBlockTable(flags: _1!, title: _2!, rows: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockThinking(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockThinking(Cons_pageBlockThinking(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockTitle(_ reader: BufferReader) -> PageBlock? {
            var _1: Api.RichText?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.RichText
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.PageBlock.pageBlockTitle(Cons_pageBlockTitle(text: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_pageBlockUnsupported(_ reader: BufferReader) -> PageBlock? {
            return Api.PageBlock.pageBlockUnsupported
        }
        public static func parse_pageBlockVideo(_ reader: BufferReader) -> PageBlock? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PageCaption?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PageCaption
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.PageBlock.pageBlockVideo(Cons_pageBlockVideo(flags: _1!, videoId: _2!, caption: _3!))
            }
            else {
                return nil
            }
        }
    }
}
