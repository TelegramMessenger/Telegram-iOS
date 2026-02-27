public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription {
        public class Cons_paymentReceipt {
            public var flags: Int32
            public var date: Int32
            public var botId: Int64
            public var providerId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var info: Api.PaymentRequestedInfo?
            public var shipping: Api.ShippingOption?
            public var tipAmount: Int64?
            public var currency: String
            public var totalAmount: Int64
            public var credentialsTitle: String
            public var users: [Api.User]
            public init(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User]) {
                self.flags = flags
                self.date = date
                self.botId = botId
                self.providerId = providerId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.info = info
                self.shipping = shipping
                self.tipAmount = tipAmount
                self.currency = currency
                self.totalAmount = totalAmount
                self.credentialsTitle = credentialsTitle
                self.users = users
            }
        }
        public class Cons_paymentReceiptStars {
            public var flags: Int32
            public var date: Int32
            public var botId: Int64
            public var title: String
            public var description: String
            public var photo: Api.WebDocument?
            public var invoice: Api.Invoice
            public var currency: String
            public var totalAmount: Int64
            public var transactionId: String
            public var users: [Api.User]
            public init(flags: Int32, date: Int32, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, currency: String, totalAmount: Int64, transactionId: String, users: [Api.User]) {
                self.flags = flags
                self.date = date
                self.botId = botId
                self.title = title
                self.description = description
                self.photo = photo
                self.invoice = invoice
                self.currency = currency
                self.totalAmount = totalAmount
                self.transactionId = transactionId
                self.users = users
            }
        }
        case paymentReceipt(Cons_paymentReceipt)
        case paymentReceiptStars(Cons_paymentReceiptStars)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentReceipt(let _data):
                if boxed {
                    buffer.appendInt32(1891958275)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeInt64(_data.providerId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                _data.invoice.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.info!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.shipping!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.tipAmount!, buffer: buffer, boxed: false)
                }
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                serializeString(_data.credentialsTitle, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .paymentReceiptStars(let _data):
                if boxed {
                    buffer.appendInt32(-625215430)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt64(_data.botId, buffer: buffer, boxed: false)
                serializeString(_data.title, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.photo!.serialize(buffer, true)
                }
                _data.invoice.serialize(buffer, true)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.totalAmount, buffer: buffer, boxed: false)
                serializeString(_data.transactionId, buffer: buffer, boxed: false)
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
            case .paymentReceipt(let _data):
                return ("paymentReceipt", [("flags", _data.flags as Any), ("date", _data.date as Any), ("botId", _data.botId as Any), ("providerId", _data.providerId as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("invoice", _data.invoice as Any), ("info", _data.info as Any), ("shipping", _data.shipping as Any), ("tipAmount", _data.tipAmount as Any), ("currency", _data.currency as Any), ("totalAmount", _data.totalAmount as Any), ("credentialsTitle", _data.credentialsTitle as Any), ("users", _data.users as Any)])
            case .paymentReceiptStars(let _data):
                return ("paymentReceiptStars", [("flags", _data.flags as Any), ("date", _data.date as Any), ("botId", _data.botId as Any), ("title", _data.title as Any), ("description", _data.description as Any), ("photo", _data.photo as Any), ("invoice", _data.invoice as Any), ("currency", _data.currency as Any), ("totalAmount", _data.totalAmount as Any), ("transactionId", _data.transactionId as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_paymentReceipt(_ reader: BufferReader) -> PaymentReceipt? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            _6 = parseString(reader)
            var _7: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _8: Api.Invoice?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _9: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _9 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
                }
            }
            var _10: Api.ShippingOption?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _10 = Api.parse(reader, signature: signature) as? Api.ShippingOption
                }
            }
            var _11: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {
                _11 = reader.readInt64()
            }
            var _12: String?
            _12 = parseString(reader)
            var _13: Int64?
            _13 = reader.readInt64()
            var _14: String?
            _14 = parseString(reader)
            var _15: [Api.User]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = _12 != nil
            let _c13 = _13 != nil
            let _c14 = _14 != nil
            let _c15 = _15 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.payments.PaymentReceipt.paymentReceipt(Cons_paymentReceipt(flags: _1!, date: _2!, botId: _3!, providerId: _4!, title: _5!, description: _6!, photo: _7, invoice: _8!, info: _9, shipping: _10, tipAmount: _11, currency: _12!, totalAmount: _13!, credentialsTitle: _14!, users: _15!))
            }
            else {
                return nil
            }
        }
        public static func parse_paymentReceiptStars(_ reader: BufferReader) -> PaymentReceipt? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.WebDocument?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.WebDocument
                }
            }
            var _7: Api.Invoice?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _8: String?
            _8 = parseString(reader)
            var _9: Int64?
            _9 = reader.readInt64()
            var _10: String?
            _10 = parseString(reader)
            var _11: [Api.User]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.payments.PaymentReceipt.paymentReceiptStars(Cons_paymentReceiptStars(flags: _1!, date: _2!, botId: _3!, title: _4!, description: _5!, photo: _6, invoice: _7!, currency: _8!, totalAmount: _9!, transactionId: _10!, users: _11!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription {
        public class Cons_paymentResult {
            public var updates: Api.Updates
            public init(updates: Api.Updates) {
                self.updates = updates
            }
        }
        public class Cons_paymentVerificationNeeded {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case paymentResult(Cons_paymentResult)
        case paymentVerificationNeeded(Cons_paymentVerificationNeeded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paymentResult(let _data):
                if boxed {
                    buffer.appendInt32(1314881805)
                }
                _data.updates.serialize(buffer, true)
                break
            case .paymentVerificationNeeded(let _data):
                if boxed {
                    buffer.appendInt32(-666824391)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .paymentResult(let _data):
                return ("paymentResult", [("updates", _data.updates as Any)])
            case .paymentVerificationNeeded(let _data):
                return ("paymentVerificationNeeded", [("url", _data.url as Any)])
            }
        }

        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentResult(Cons_paymentResult(updates: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_paymentVerificationNeeded(_ reader: BufferReader) -> PaymentResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentVerificationNeeded(Cons_paymentVerificationNeeded(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum ResaleStarGifts: TypeConstructorDescription {
        public class Cons_resaleStarGifts {
            public var flags: Int32
            public var count: Int32
            public var gifts: [Api.StarGift]
            public var nextOffset: String?
            public var attributes: [Api.StarGiftAttribute]?
            public var attributesHash: Int64?
            public var chats: [Api.Chat]
            public var counters: [Api.StarGiftAttributeCounter]?
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, gifts: [Api.StarGift], nextOffset: String?, attributes: [Api.StarGiftAttribute]?, attributesHash: Int64?, chats: [Api.Chat], counters: [Api.StarGiftAttributeCounter]?, users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.gifts = gifts
                self.nextOffset = nextOffset
                self.attributes = attributes
                self.attributesHash = attributesHash
                self.chats = chats
                self.counters = counters
                self.users = users
            }
        }
        case resaleStarGifts(Cons_resaleStarGifts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resaleStarGifts(let _data):
                if boxed {
                    buffer.appendInt32(-1803939105)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.gifts.count))
                for item in _data.gifts {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.attributes!.count))
                    for item in _data.attributes! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt64(_data.attributesHash!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.counters!.count))
                    for item in _data.counters! {
                        item.serialize(buffer, true)
                    }
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
            case .resaleStarGifts(let _data):
                return ("resaleStarGifts", [("flags", _data.flags as Any), ("count", _data.count as Any), ("gifts", _data.gifts as Any), ("nextOffset", _data.nextOffset as Any), ("attributes", _data.attributes as Any), ("attributesHash", _data.attributesHash as Any), ("chats", _data.chats as Any), ("counters", _data.counters as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_resaleStarGifts(_ reader: BufferReader) -> ResaleStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StarGift]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGift.self)
            }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: [Api.StarGiftAttribute]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
                }
            }
            var _6: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt64()
            }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.StarGiftAttributeCounter]?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttributeCounter.self)
                }
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.ResaleStarGifts.resaleStarGifts(Cons_resaleStarGifts(flags: _1!, count: _2!, gifts: _3!, nextOffset: _4, attributes: _5, attributesHash: _6, chats: _7!, counters: _8, users: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription {
        public class Cons_savedInfo {
            public var flags: Int32
            public var savedInfo: Api.PaymentRequestedInfo?
            public init(flags: Int32, savedInfo: Api.PaymentRequestedInfo?) {
                self.flags = flags
                self.savedInfo = savedInfo
            }
        }
        case savedInfo(Cons_savedInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedInfo(let _data):
                if boxed {
                    buffer.appendInt32(-74456004)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.savedInfo!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedInfo(let _data):
                return ("savedInfo", [("flags", _data.flags as Any), ("savedInfo", _data.savedInfo as Any)])
            }
        }

        public static func parse_savedInfo(_ reader: BufferReader) -> SavedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.payments.SavedInfo.savedInfo(Cons_savedInfo(flags: _1!, savedInfo: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum SavedStarGifts: TypeConstructorDescription {
        public class Cons_savedStarGifts {
            public var flags: Int32
            public var count: Int32
            public var chatNotificationsEnabled: Api.Bool?
            public var gifts: [Api.SavedStarGift]
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, chatNotificationsEnabled: Api.Bool?, gifts: [Api.SavedStarGift], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.chatNotificationsEnabled = chatNotificationsEnabled
                self.gifts = gifts
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case savedStarGifts(Cons_savedStarGifts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedStarGifts(let _data):
                if boxed {
                    buffer.appendInt32(-1779201615)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.chatNotificationsEnabled!.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.gifts.count))
                for item in _data.gifts {
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
            case .savedStarGifts(let _data):
                return ("savedStarGifts", [("flags", _data.flags as Any), ("count", _data.count as Any), ("chatNotificationsEnabled", _data.chatNotificationsEnabled as Any), ("gifts", _data.gifts as Any), ("nextOffset", _data.nextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_savedStarGifts(_ reader: BufferReader) -> SavedStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Bool
                }
            }
            var _4: [Api.SavedStarGift]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedStarGift.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseString(reader)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.payments.SavedStarGifts.savedStarGifts(Cons_savedStarGifts(flags: _1!, count: _2!, chatNotificationsEnabled: _3, gifts: _4!, nextOffset: _5, chats: _6!, users: _7!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGiftActiveAuctions: TypeConstructorDescription {
        public class Cons_starGiftActiveAuctions {
            public var auctions: [Api.StarGiftActiveAuctionState]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(auctions: [Api.StarGiftActiveAuctionState], users: [Api.User], chats: [Api.Chat]) {
                self.auctions = auctions
                self.users = users
                self.chats = chats
            }
        }
        case starGiftActiveAuctions(Cons_starGiftActiveAuctions)
        case starGiftActiveAuctionsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftActiveAuctions(let _data):
                if boxed {
                    buffer.appendInt32(-1359565892)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.auctions.count))
                for item in _data.auctions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                break
            case .starGiftActiveAuctionsNotModified:
                if boxed {
                    buffer.appendInt32(-617358640)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftActiveAuctions(let _data):
                return ("starGiftActiveAuctions", [("auctions", _data.auctions as Any), ("users", _data.users as Any), ("chats", _data.chats as Any)])
            case .starGiftActiveAuctionsNotModified:
                return ("starGiftActiveAuctionsNotModified", [])
            }
        }

        public static func parse_starGiftActiveAuctions(_ reader: BufferReader) -> StarGiftActiveAuctions? {
            var _1: [Api.StarGiftActiveAuctionState]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftActiveAuctionState.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.StarGiftActiveAuctions.starGiftActiveAuctions(Cons_starGiftActiveAuctions(auctions: _1!, users: _2!, chats: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftActiveAuctionsNotModified(_ reader: BufferReader) -> StarGiftActiveAuctions? {
            return Api.payments.StarGiftActiveAuctions.starGiftActiveAuctionsNotModified
        }
    }
}
public extension Api.payments {
    enum StarGiftAuctionAcquiredGifts: TypeConstructorDescription {
        public class Cons_starGiftAuctionAcquiredGifts {
            public var gifts: [Api.StarGiftAuctionAcquiredGift]
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(gifts: [Api.StarGiftAuctionAcquiredGift], users: [Api.User], chats: [Api.Chat]) {
                self.gifts = gifts
                self.users = users
                self.chats = chats
            }
        }
        case starGiftAuctionAcquiredGifts(Cons_starGiftAuctionAcquiredGifts)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionAcquiredGifts(let _data):
                if boxed {
                    buffer.appendInt32(2103169520)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.gifts.count))
                for item in _data.gifts {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionAcquiredGifts(let _data):
                return ("starGiftAuctionAcquiredGifts", [("gifts", _data.gifts as Any), ("users", _data.users as Any), ("chats", _data.chats as Any)])
            }
        }

        public static func parse_starGiftAuctionAcquiredGifts(_ reader: BufferReader) -> StarGiftAuctionAcquiredGifts? {
            var _1: [Api.StarGiftAuctionAcquiredGift]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAuctionAcquiredGift.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.StarGiftAuctionAcquiredGifts.starGiftAuctionAcquiredGifts(Cons_starGiftAuctionAcquiredGifts(gifts: _1!, users: _2!, chats: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGiftAuctionState: TypeConstructorDescription {
        public class Cons_starGiftAuctionState {
            public var gift: Api.StarGift
            public var state: Api.StarGiftAuctionState
            public var userState: Api.StarGiftAuctionUserState
            public var timeout: Int32
            public var users: [Api.User]
            public var chats: [Api.Chat]
            public init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState, timeout: Int32, users: [Api.User], chats: [Api.Chat]) {
                self.gift = gift
                self.state = state
                self.userState = userState
                self.timeout = timeout
                self.users = users
                self.chats = chats
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftAuctionState(let _data):
                if boxed {
                    buffer.appendInt32(1798960364)
                }
                _data.gift.serialize(buffer, true)
                _data.state.serialize(buffer, true)
                _data.userState.serialize(buffer, true)
                serializeInt32(_data.timeout, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftAuctionState(let _data):
                return ("starGiftAuctionState", [("gift", _data.gift as Any), ("state", _data.state as Any), ("userState", _data.userState as Any), ("timeout", _data.timeout as Any), ("users", _data.users as Any), ("chats", _data.chats as Any)])
            }
        }

        public static func parse_starGiftAuctionState(_ reader: BufferReader) -> StarGiftAuctionState? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
            }
            var _2: Api.StarGiftAuctionState?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionState
            }
            var _3: Api.StarGiftAuctionUserState?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StarGiftAuctionUserState
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.payments.StarGiftAuctionState.starGiftAuctionState(Cons_starGiftAuctionState(gift: _1!, state: _2!, userState: _3!, timeout: _4!, users: _5!, chats: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGiftCollections: TypeConstructorDescription {
        public class Cons_starGiftCollections {
            public var collections: [Api.StarGiftCollection]
            public init(collections: [Api.StarGiftCollection]) {
                self.collections = collections
            }
        }
        case starGiftCollections(Cons_starGiftCollections)
        case starGiftCollectionsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftCollections(let _data):
                if boxed {
                    buffer.appendInt32(-1977011469)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.collections.count))
                for item in _data.collections {
                    item.serialize(buffer, true)
                }
                break
            case .starGiftCollectionsNotModified:
                if boxed {
                    buffer.appendInt32(-1598402793)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftCollections(let _data):
                return ("starGiftCollections", [("collections", _data.collections as Any)])
            case .starGiftCollectionsNotModified:
                return ("starGiftCollectionsNotModified", [])
            }
        }

        public static func parse_starGiftCollections(_ reader: BufferReader) -> StarGiftCollections? {
            var _1: [Api.StarGiftCollection]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftCollection.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarGiftCollections.starGiftCollections(Cons_starGiftCollections(collections: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftCollectionsNotModified(_ reader: BufferReader) -> StarGiftCollections? {
            return Api.payments.StarGiftCollections.starGiftCollectionsNotModified
        }
    }
}
public extension Api.payments {
    enum StarGiftUpgradeAttributes: TypeConstructorDescription {
        public class Cons_starGiftUpgradeAttributes {
            public var attributes: [Api.StarGiftAttribute]
            public init(attributes: [Api.StarGiftAttribute]) {
                self.attributes = attributes
            }
        }
        case starGiftUpgradeAttributes(Cons_starGiftUpgradeAttributes)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftUpgradeAttributes(let _data):
                if boxed {
                    buffer.appendInt32(1187439471)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.attributes.count))
                for item in _data.attributes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftUpgradeAttributes(let _data):
                return ("starGiftUpgradeAttributes", [("attributes", _data.attributes as Any)])
            }
        }

        public static func parse_starGiftUpgradeAttributes(_ reader: BufferReader) -> StarGiftUpgradeAttributes? {
            var _1: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarGiftUpgradeAttributes.starGiftUpgradeAttributes(Cons_starGiftUpgradeAttributes(attributes: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGiftUpgradePreview: TypeConstructorDescription {
        public class Cons_starGiftUpgradePreview {
            public var sampleAttributes: [Api.StarGiftAttribute]
            public var prices: [Api.StarGiftUpgradePrice]
            public var nextPrices: [Api.StarGiftUpgradePrice]
            public init(sampleAttributes: [Api.StarGiftAttribute], prices: [Api.StarGiftUpgradePrice], nextPrices: [Api.StarGiftUpgradePrice]) {
                self.sampleAttributes = sampleAttributes
                self.prices = prices
                self.nextPrices = nextPrices
            }
        }
        case starGiftUpgradePreview(Cons_starGiftUpgradePreview)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftUpgradePreview(let _data):
                if boxed {
                    buffer.appendInt32(1038213101)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.sampleAttributes.count))
                for item in _data.sampleAttributes {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.prices.count))
                for item in _data.prices {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.nextPrices.count))
                for item in _data.nextPrices {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftUpgradePreview(let _data):
                return ("starGiftUpgradePreview", [("sampleAttributes", _data.sampleAttributes as Any), ("prices", _data.prices as Any), ("nextPrices", _data.nextPrices as Any)])
            }
        }

        public static func parse_starGiftUpgradePreview(_ reader: BufferReader) -> StarGiftUpgradePreview? {
            var _1: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            var _2: [Api.StarGiftUpgradePrice]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftUpgradePrice.self)
            }
            var _3: [Api.StarGiftUpgradePrice]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftUpgradePrice.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.StarGiftUpgradePreview.starGiftUpgradePreview(Cons_starGiftUpgradePreview(sampleAttributes: _1!, prices: _2!, nextPrices: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGiftWithdrawalUrl: TypeConstructorDescription {
        public class Cons_starGiftWithdrawalUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starGiftWithdrawalUrl(Cons_starGiftWithdrawalUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGiftWithdrawalUrl(let _data):
                if boxed {
                    buffer.appendInt32(-2069218660)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGiftWithdrawalUrl(let _data):
                return ("starGiftWithdrawalUrl", [("url", _data.url as Any)])
            }
        }

        public static func parse_starGiftWithdrawalUrl(_ reader: BufferReader) -> StarGiftWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarGiftWithdrawalUrl.starGiftWithdrawalUrl(Cons_starGiftWithdrawalUrl(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription {
        public class Cons_starGifts {
            public var hash: Int32
            public var gifts: [Api.StarGift]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(hash: Int32, gifts: [Api.StarGift], chats: [Api.Chat], users: [Api.User]) {
                self.hash = hash
                self.gifts = gifts
                self.chats = chats
                self.users = users
            }
        }
        case starGifts(Cons_starGifts)
        case starGiftsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starGifts(let _data):
                if boxed {
                    buffer.appendInt32(785918357)
                }
                serializeInt32(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.gifts.count))
                for item in _data.gifts {
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
            case .starGiftsNotModified:
                if boxed {
                    buffer.appendInt32(-1551326360)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starGifts(let _data):
                return ("starGifts", [("hash", _data.hash as Any), ("gifts", _data.gifts as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .starGiftsNotModified:
                return ("starGiftsNotModified", [])
            }
        }

        public static func parse_starGifts(_ reader: BufferReader) -> StarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.StarGift]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGift.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.payments.StarGifts.starGifts(Cons_starGifts(hash: _1!, gifts: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_starGiftsNotModified(_ reader: BufferReader) -> StarGifts? {
            return Api.payments.StarGifts.starGiftsNotModified
        }
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription {
        public class Cons_starsRevenueAdsAccountUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starsRevenueAdsAccountUrl(Cons_starsRevenueAdsAccountUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsRevenueAdsAccountUrl(let _data):
                if boxed {
                    buffer.appendInt32(961445665)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsRevenueAdsAccountUrl(let _data):
                return ("starsRevenueAdsAccountUrl", [("url", _data.url as Any)])
            }
        }

        public static func parse_starsRevenueAdsAccountUrl(_ reader: BufferReader) -> StarsRevenueAdsAccountUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueAdsAccountUrl.starsRevenueAdsAccountUrl(Cons_starsRevenueAdsAccountUrl(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription {
        public class Cons_starsRevenueStats {
            public var flags: Int32
            public var topHoursGraph: Api.StatsGraph?
            public var revenueGraph: Api.StatsGraph
            public var status: Api.StarsRevenueStatus
            public var usdRate: Double
            public init(flags: Int32, topHoursGraph: Api.StatsGraph?, revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double) {
                self.flags = flags
                self.topHoursGraph = topHoursGraph
                self.revenueGraph = revenueGraph
                self.status = status
                self.usdRate = usdRate
            }
        }
        case starsRevenueStats(Cons_starsRevenueStats)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsRevenueStats(let _data):
                if boxed {
                    buffer.appendInt32(1814066038)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.topHoursGraph!.serialize(buffer, true)
                }
                _data.revenueGraph.serialize(buffer, true)
                _data.status.serialize(buffer, true)
                serializeDouble(_data.usdRate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsRevenueStats(let _data):
                return ("starsRevenueStats", [("flags", _data.flags as Any), ("topHoursGraph", _data.topHoursGraph as Any), ("revenueGraph", _data.revenueGraph as Any), ("status", _data.status as Any), ("usdRate", _data.usdRate as Any)])
            }
        }

        public static func parse_starsRevenueStats(_ reader: BufferReader) -> StarsRevenueStats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StatsGraph?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
                }
            }
            var _3: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _4: Api.StarsRevenueStatus?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.StarsRevenueStatus
            }
            var _5: Double?
            _5 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.StarsRevenueStats.starsRevenueStats(Cons_starsRevenueStats(flags: _1!, topHoursGraph: _2, revenueGraph: _3!, status: _4!, usdRate: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription {
        public class Cons_starsRevenueWithdrawalUrl {
            public var url: String
            public init(url: String) {
                self.url = url
            }
        }
        case starsRevenueWithdrawalUrl(Cons_starsRevenueWithdrawalUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsRevenueWithdrawalUrl(let _data):
                if boxed {
                    buffer.appendInt32(497778871)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .starsRevenueWithdrawalUrl(let _data):
                return ("starsRevenueWithdrawalUrl", [("url", _data.url as Any)])
            }
        }

        public static func parse_starsRevenueWithdrawalUrl(_ reader: BufferReader) -> StarsRevenueWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.StarsRevenueWithdrawalUrl.starsRevenueWithdrawalUrl(Cons_starsRevenueWithdrawalUrl(url: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription {
        public class Cons_starsStatus {
            public var flags: Int32
            public var balance: Api.StarsAmount
            public var subscriptions: [Api.StarsSubscription]?
            public var subscriptionsNextOffset: String?
            public var subscriptionsMissingBalance: Int64?
            public var history: [Api.StarsTransaction]?
            public var nextOffset: String?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, balance: Api.StarsAmount, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.balance = balance
                self.subscriptions = subscriptions
                self.subscriptionsNextOffset = subscriptionsNextOffset
                self.subscriptionsMissingBalance = subscriptionsMissingBalance
                self.history = history
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
            }
        }
        case starsStatus(Cons_starsStatus)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .starsStatus(let _data):
                if boxed {
                    buffer.appendInt32(1822222573)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.balance.serialize(buffer, true)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.subscriptions!.count))
                    for item in _data.subscriptions! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeString(_data.subscriptionsNextOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt64(_data.subscriptionsMissingBalance!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.history!.count))
                    for item in _data.history! {
                        item.serialize(buffer, true)
                    }
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
            case .starsStatus(let _data):
                return ("starsStatus", [("flags", _data.flags as Any), ("balance", _data.balance as Any), ("subscriptions", _data.subscriptions as Any), ("subscriptionsNextOffset", _data.subscriptionsNextOffset as Any), ("subscriptionsMissingBalance", _data.subscriptionsMissingBalance as Any), ("history", _data.history as Any), ("nextOffset", _data.nextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_starsStatus(_ reader: BufferReader) -> StarsStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            var _3: [Api.StarsSubscription]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsSubscription.self)
                }
            }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseString(reader)
            }
            var _5: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt64()
            }
            var _6: [Api.StarsTransaction]?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let _ = reader.readInt32() {
                    _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsTransaction.self)
                }
            }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = parseString(reader)
            }
            var _8: [Api.Chat]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _9: [Api.User]?
            if let _ = reader.readInt32() {
                _9 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.payments.StarsStatus.starsStatus(Cons_starsStatus(flags: _1!, balance: _2!, subscriptions: _3, subscriptionsNextOffset: _4, subscriptionsMissingBalance: _5, history: _6, nextOffset: _7, chats: _8!, users: _9!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum SuggestedStarRefBots: TypeConstructorDescription {
        public class Cons_suggestedStarRefBots {
            public var flags: Int32
            public var count: Int32
            public var suggestedBots: [Api.StarRefProgram]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, suggestedBots: [Api.StarRefProgram], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.suggestedBots = suggestedBots
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case suggestedStarRefBots(Cons_suggestedStarRefBots)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .suggestedStarRefBots(let _data):
                if boxed {
                    buffer.appendInt32(-1261053863)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.suggestedBots.count))
                for item in _data.suggestedBots {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .suggestedStarRefBots(let _data):
                return ("suggestedStarRefBots", [("flags", _data.flags as Any), ("count", _data.count as Any), ("suggestedBots", _data.suggestedBots as Any), ("users", _data.users as Any), ("nextOffset", _data.nextOffset as Any)])
            }
        }

        public static func parse_suggestedStarRefBots(_ reader: BufferReader) -> SuggestedStarRefBots? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StarRefProgram]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarRefProgram.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.payments.SuggestedStarRefBots.suggestedStarRefBots(Cons_suggestedStarRefBots(flags: _1!, count: _2!, suggestedBots: _3!, users: _4!, nextOffset: _5))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum UniqueStarGift: TypeConstructorDescription {
        public class Cons_uniqueStarGift {
            public var gift: Api.StarGift
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(gift: Api.StarGift, chats: [Api.Chat], users: [Api.User]) {
                self.gift = gift
                self.chats = chats
                self.users = users
            }
        }
        case uniqueStarGift(Cons_uniqueStarGift)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .uniqueStarGift(let _data):
                if boxed {
                    buffer.appendInt32(1097619176)
                }
                _data.gift.serialize(buffer, true)
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
            case .uniqueStarGift(let _data):
                return ("uniqueStarGift", [("gift", _data.gift as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_uniqueStarGift(_ reader: BufferReader) -> UniqueStarGift? {
            var _1: Api.StarGift?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarGift
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
                return Api.payments.UniqueStarGift.uniqueStarGift(Cons_uniqueStarGift(gift: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum UniqueStarGiftValueInfo: TypeConstructorDescription {
        public class Cons_uniqueStarGiftValueInfo {
            public var flags: Int32
            public var currency: String
            public var value: Int64
            public var initialSaleDate: Int32
            public var initialSaleStars: Int64
            public var initialSalePrice: Int64
            public var lastSaleDate: Int32?
            public var lastSalePrice: Int64?
            public var floorPrice: Int64?
            public var averagePrice: Int64?
            public var listedCount: Int32?
            public var fragmentListedCount: Int32?
            public var fragmentListedUrl: String?
            public init(flags: Int32, currency: String, value: Int64, initialSaleDate: Int32, initialSaleStars: Int64, initialSalePrice: Int64, lastSaleDate: Int32?, lastSalePrice: Int64?, floorPrice: Int64?, averagePrice: Int64?, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
                self.flags = flags
                self.currency = currency
                self.value = value
                self.initialSaleDate = initialSaleDate
                self.initialSaleStars = initialSaleStars
                self.initialSalePrice = initialSalePrice
                self.lastSaleDate = lastSaleDate
                self.lastSalePrice = lastSalePrice
                self.floorPrice = floorPrice
                self.averagePrice = averagePrice
                self.listedCount = listedCount
                self.fragmentListedCount = fragmentListedCount
                self.fragmentListedUrl = fragmentListedUrl
            }
        }
        case uniqueStarGiftValueInfo(Cons_uniqueStarGiftValueInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .uniqueStarGiftValueInfo(let _data):
                if boxed {
                    buffer.appendInt32(1362093126)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.value, buffer: buffer, boxed: false)
                serializeInt32(_data.initialSaleDate, buffer: buffer, boxed: false)
                serializeInt64(_data.initialSaleStars, buffer: buffer, boxed: false)
                serializeInt64(_data.initialSalePrice, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.lastSaleDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.lastSalePrice!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.floorPrice!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt64(_data.averagePrice!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.listedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.fragmentListedCount!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeString(_data.fragmentListedUrl!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .uniqueStarGiftValueInfo(let _data):
                return ("uniqueStarGiftValueInfo", [("flags", _data.flags as Any), ("currency", _data.currency as Any), ("value", _data.value as Any), ("initialSaleDate", _data.initialSaleDate as Any), ("initialSaleStars", _data.initialSaleStars as Any), ("initialSalePrice", _data.initialSalePrice as Any), ("lastSaleDate", _data.lastSaleDate as Any), ("lastSalePrice", _data.lastSalePrice as Any), ("floorPrice", _data.floorPrice as Any), ("averagePrice", _data.averagePrice as Any), ("listedCount", _data.listedCount as Any), ("fragmentListedCount", _data.fragmentListedCount as Any), ("fragmentListedUrl", _data.fragmentListedUrl as Any)])
            }
        }

        public static func parse_uniqueStarGiftValueInfo(_ reader: BufferReader) -> UniqueStarGiftValueInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _7 = reader.readInt32()
            }
            var _8: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _8 = reader.readInt64()
            }
            var _9: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {
                _9 = reader.readInt64()
            }
            var _10: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {
                _10 = reader.readInt64()
            }
            var _11: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _11 = reader.readInt32()
            }
            var _12: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {
                _12 = reader.readInt32()
            }
            var _13: String?
            if Int(_1!) & Int(1 << 5) != 0 {
                _13 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 4) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 5) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.payments.UniqueStarGiftValueInfo.uniqueStarGiftValueInfo(Cons_uniqueStarGiftValueInfo(flags: _1!, currency: _2!, value: _3!, initialSaleDate: _4!, initialSaleStars: _5!, initialSalePrice: _6!, lastSaleDate: _7, lastSalePrice: _8, floorPrice: _9, averagePrice: _10, listedCount: _11, fragmentListedCount: _12, fragmentListedUrl: _13))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription {
        public class Cons_validatedRequestedInfo {
            public var flags: Int32
            public var id: String?
            public var shippingOptions: [Api.ShippingOption]?
            public init(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?) {
                self.flags = flags
                self.id = id
                self.shippingOptions = shippingOptions
            }
        }
        case validatedRequestedInfo(Cons_validatedRequestedInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .validatedRequestedInfo(let _data):
                if boxed {
                    buffer.appendInt32(-784000893)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.id!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.shippingOptions!.count))
                    for item in _data.shippingOptions! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .validatedRequestedInfo(let _data):
                return ("validatedRequestedInfo", [("flags", _data.flags as Any), ("id", _data.id as Any), ("shippingOptions", _data.shippingOptions as Any)])
            }
        }

        public static func parse_validatedRequestedInfo(_ reader: BufferReader) -> ValidatedRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: [Api.ShippingOption]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ShippingOption.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.payments.ValidatedRequestedInfo.validatedRequestedInfo(Cons_validatedRequestedInfo(flags: _1!, id: _2, shippingOptions: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription {
        public class Cons_exportedGroupCallInvite {
            public var link: String
            public init(link: String) {
                self.link = link
            }
        }
        case exportedGroupCallInvite(Cons_exportedGroupCallInvite)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedGroupCallInvite(let _data):
                if boxed {
                    buffer.appendInt32(541839704)
                }
                serializeString(_data.link, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedGroupCallInvite(let _data):
                return ("exportedGroupCallInvite", [("link", _data.link as Any)])
            }
        }

        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.ExportedGroupCallInvite.exportedGroupCallInvite(Cons_exportedGroupCallInvite(link: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription {
        public class Cons_groupCall {
            public var call: Api.GroupCall
            public var participants: [Api.GroupCallParticipant]
            public var participantsNextOffset: String
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User]) {
                self.call = call
                self.participants = participants
                self.participantsNextOffset = participantsNextOffset
                self.chats = chats
                self.users = users
            }
        }
        case groupCall(Cons_groupCall)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCall(let _data):
                if boxed {
                    buffer.appendInt32(-1636664659)
                }
                _data.call.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.participants.count))
                for item in _data.participants {
                    item.serialize(buffer, true)
                }
                serializeString(_data.participantsNextOffset, buffer: buffer, boxed: false)
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
            case .groupCall(let _data):
                return ("groupCall", [("call", _data.call as Any), ("participants", _data.participants as Any), ("participantsNextOffset", _data.participantsNextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_groupCall(_ reader: BufferReader) -> GroupCall? {
            var _1: Api.GroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.phone.GroupCall.groupCall(Cons_groupCall(call: _1!, participants: _2!, participantsNextOffset: _3!, chats: _4!, users: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum GroupCallStars: TypeConstructorDescription {
        public class Cons_groupCallStars {
            public var totalStars: Int64
            public var topDonors: [Api.GroupCallDonor]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(totalStars: Int64, topDonors: [Api.GroupCallDonor], chats: [Api.Chat], users: [Api.User]) {
                self.totalStars = totalStars
                self.topDonors = topDonors
                self.chats = chats
                self.users = users
            }
        }
        case groupCallStars(Cons_groupCallStars)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallStars(let _data):
                if boxed {
                    buffer.appendInt32(-1658995418)
                }
                serializeInt64(_data.totalStars, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.topDonors.count))
                for item in _data.topDonors {
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
            case .groupCallStars(let _data):
                return ("groupCallStars", [("totalStars", _data.totalStars as Any), ("topDonors", _data.topDonors as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_groupCallStars(_ reader: BufferReader) -> GroupCallStars? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.GroupCallDonor]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallDonor.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: [Api.User]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.phone.GroupCallStars.groupCallStars(Cons_groupCallStars(totalStars: _1!, topDonors: _2!, chats: _3!, users: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription {
        public class Cons_groupCallStreamChannels {
            public var channels: [Api.GroupCallStreamChannel]
            public init(channels: [Api.GroupCallStreamChannel]) {
                self.channels = channels
            }
        }
        case groupCallStreamChannels(Cons_groupCallStreamChannels)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallStreamChannels(let _data):
                if boxed {
                    buffer.appendInt32(-790330702)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.channels.count))
                for item in _data.channels {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallStreamChannels(let _data):
                return ("groupCallStreamChannels", [("channels", _data.channels as Any)])
            }
        }

        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            var _1: [Api.GroupCallStreamChannel]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallStreamChannel.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.GroupCallStreamChannels.groupCallStreamChannels(Cons_groupCallStreamChannels(channels: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription {
        public class Cons_groupCallStreamRtmpUrl {
            public var url: String
            public var key: String
            public init(url: String, key: String) {
                self.url = url
                self.key = key
            }
        }
        case groupCallStreamRtmpUrl(Cons_groupCallStreamRtmpUrl)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupCallStreamRtmpUrl(let _data):
                if boxed {
                    buffer.appendInt32(767505458)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeString(_data.key, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupCallStreamRtmpUrl(let _data):
                return ("groupCallStreamRtmpUrl", [("url", _data.url as Any), ("key", _data.key as Any)])
            }
        }

        public static func parse_groupCallStreamRtmpUrl(_ reader: BufferReader) -> GroupCallStreamRtmpUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.phone.GroupCallStreamRtmpUrl.groupCallStreamRtmpUrl(Cons_groupCallStreamRtmpUrl(url: _1!, key: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        public class Cons_groupParticipants {
            public var count: Int32
            public var participants: [Api.GroupCallParticipant]
            public var nextOffset: String
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var version: Int32
            public init(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32) {
                self.count = count
                self.participants = participants
                self.nextOffset = nextOffset
                self.chats = chats
                self.users = users
                self.version = version
            }
        }
        case groupParticipants(Cons_groupParticipants)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .groupParticipants(let _data):
                if boxed {
                    buffer.appendInt32(-193506890)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.participants.count))
                for item in _data.participants {
                    item.serialize(buffer, true)
                }
                serializeString(_data.nextOffset, buffer: buffer, boxed: false)
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
                serializeInt32(_data.version, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .groupParticipants(let _data):
                return ("groupParticipants", [("count", _data.count as Any), ("participants", _data.participants as Any), ("nextOffset", _data.nextOffset as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("version", _data.version as Any)])
            }
        }

        public static func parse_groupParticipants(_ reader: BufferReader) -> GroupParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.phone.GroupParticipants.groupParticipants(Cons_groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!))
            }
            else {
                return nil
            }
        }
    }
}
