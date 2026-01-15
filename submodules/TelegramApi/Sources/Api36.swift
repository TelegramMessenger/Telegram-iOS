public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription {
        case paymentReceipt(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User])
        case paymentReceiptStars(flags: Int32, date: Int32, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, currency: String, totalAmount: Int64, transactionId: String, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentReceipt(let flags, let date, let botId, let providerId, let title, let description, let photo, let invoice, let info, let shipping, let tipAmount, let currency, let totalAmount, let credentialsTitle, let users):
                    if boxed {
                        buffer.appendInt32(1891958275)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeInt64(providerId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {shipping!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(tipAmount!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(credentialsTitle, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .paymentReceiptStars(let flags, let date, let botId, let title, let description, let photo, let invoice, let currency, let totalAmount, let transactionId, let users):
                    if boxed {
                        buffer.appendInt32(-625215430)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(description, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {photo!.serialize(buffer, true)}
                    invoice.serialize(buffer, true)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeString(transactionId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentReceipt(let flags, let date, let botId, let providerId, let title, let description, let photo, let invoice, let info, let shipping, let tipAmount, let currency, let totalAmount, let credentialsTitle, let users):
                return ("paymentReceipt", [("flags", flags as Any), ("date", date as Any), ("botId", botId as Any), ("providerId", providerId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("info", info as Any), ("shipping", shipping as Any), ("tipAmount", tipAmount as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("credentialsTitle", credentialsTitle as Any), ("users", users as Any)])
                case .paymentReceiptStars(let flags, let date, let botId, let title, let description, let photo, let invoice, let currency, let totalAmount, let transactionId, let users):
                return ("paymentReceiptStars", [("flags", flags as Any), ("date", date as Any), ("botId", botId as Any), ("title", title as Any), ("description", description as Any), ("photo", photo as Any), ("invoice", invoice as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("transactionId", transactionId as Any), ("users", users as Any)])
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
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
            var _8: Api.Invoice?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _9: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _10: Api.ShippingOption?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.ShippingOption
            } }
            var _11: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_11 = reader.readInt64() }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            if !_c13 { return nil }
            if !_c14 { return nil }
            if !_c15 { return nil }
            return Api.payments.PaymentReceipt.paymentReceipt(flags: _1!, date: _2!, botId: _3!, providerId: _4!, title: _5!, description: _6!, photo: _7, invoice: _8!, info: _9, shipping: _10, tipAmount: _11, currency: _12!, totalAmount: _13!, credentialsTitle: _14!, users: _15!)
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
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WebDocument
            } }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            return Api.payments.PaymentReceipt.paymentReceiptStars(flags: _1!, date: _2!, botId: _3!, title: _4!, description: _5!, photo: _6, invoice: _7!, currency: _8!, totalAmount: _9!, transactionId: _10!, users: _11!)
        }
    
    }
}
public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription {
        case paymentResult(updates: Api.Updates)
        case paymentVerificationNeeded(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentResult(let updates):
                    if boxed {
                        buffer.appendInt32(1314881805)
                    }
                    updates.serialize(buffer, true)
                    break
                case .paymentVerificationNeeded(let url):
                    if boxed {
                        buffer.appendInt32(-666824391)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentResult(let updates):
                return ("paymentResult", [("updates", updates as Any)])
                case .paymentVerificationNeeded(let url):
                return ("paymentVerificationNeeded", [("url", url as Any)])
    }
    }
    
        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.PaymentResult.paymentResult(updates: _1!)
        }
        public static func parse_paymentVerificationNeeded(_ reader: BufferReader) -> PaymentResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.PaymentResult.paymentVerificationNeeded(url: _1!)
        }
    
    }
}
public extension Api.payments {
    enum ResaleStarGifts: TypeConstructorDescription {
        case resaleStarGifts(flags: Int32, count: Int32, gifts: [Api.StarGift], nextOffset: String?, attributes: [Api.StarGiftAttribute]?, attributesHash: Int64?, chats: [Api.Chat], counters: [Api.StarGiftAttributeCounter]?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resaleStarGifts(let flags, let count, let gifts, let nextOffset, let attributes, let attributesHash, let chats, let counters, let users):
                    if boxed {
                        buffer.appendInt32(-1803939105)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes!.count))
                    for item in attributes! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(attributesHash!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(counters!.count))
                    for item in counters! {
                        item.serialize(buffer, true)
                    }}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .resaleStarGifts(let flags, let count, let gifts, let nextOffset, let attributes, let attributesHash, let chats, let counters, let users):
                return ("resaleStarGifts", [("flags", flags as Any), ("count", count as Any), ("gifts", gifts as Any), ("nextOffset", nextOffset as Any), ("attributes", attributes as Any), ("attributesHash", attributesHash as Any), ("chats", chats as Any), ("counters", counters as Any), ("users", users as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: [Api.StarGiftAttribute]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            } }
            var _6: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt64() }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.StarGiftAttributeCounter]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttributeCounter.self)
            } }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            return Api.payments.ResaleStarGifts.resaleStarGifts(flags: _1!, count: _2!, gifts: _3!, nextOffset: _4, attributes: _5, attributesHash: _6, chats: _7!, counters: _8, users: _9!)
        }
    
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription {
        case savedInfo(flags: Int32, savedInfo: Api.PaymentRequestedInfo?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedInfo(let flags, let savedInfo):
                    if boxed {
                        buffer.appendInt32(-74456004)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {savedInfo!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedInfo(let flags, let savedInfo):
                return ("savedInfo", [("flags", flags as Any), ("savedInfo", savedInfo as Any)])
    }
    }
    
        public static func parse_savedInfo(_ reader: BufferReader) -> SavedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.payments.SavedInfo.savedInfo(flags: _1!, savedInfo: _2)
        }
    
    }
}
public extension Api.payments {
    enum SavedStarGifts: TypeConstructorDescription {
        case savedStarGifts(flags: Int32, count: Int32, chatNotificationsEnabled: Api.Bool?, gifts: [Api.SavedStarGift], nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedStarGifts(let flags, let count, let chatNotificationsEnabled, let gifts, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1779201615)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {chatNotificationsEnabled!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedStarGifts(let flags, let count, let chatNotificationsEnabled, let gifts, let nextOffset, let chats, let users):
                return ("savedStarGifts", [("flags", flags as Any), ("count", count as Any), ("chatNotificationsEnabled", chatNotificationsEnabled as Any), ("gifts", gifts as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
    }
    }
    
        public static func parse_savedStarGifts(_ reader: BufferReader) -> SavedStarGifts? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _4: [Api.SavedStarGift]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SavedStarGift.self)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            return Api.payments.SavedStarGifts.savedStarGifts(flags: _1!, count: _2!, chatNotificationsEnabled: _3, gifts: _4!, nextOffset: _5, chats: _6!, users: _7!)
        }
    
    }
}
public extension Api.payments {
    enum StarGiftActiveAuctions: TypeConstructorDescription {
        case starGiftActiveAuctions(auctions: [Api.StarGiftActiveAuctionState], users: [Api.User], chats: [Api.Chat])
        case starGiftActiveAuctionsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftActiveAuctions(let auctions, let users, let chats):
                    if boxed {
                        buffer.appendInt32(-1359565892)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(auctions.count))
                    for item in auctions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
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
                case .starGiftActiveAuctions(let auctions, let users, let chats):
                return ("starGiftActiveAuctions", [("auctions", auctions as Any), ("users", users as Any), ("chats", chats as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.payments.StarGiftActiveAuctions.starGiftActiveAuctions(auctions: _1!, users: _2!, chats: _3!)
        }
        public static func parse_starGiftActiveAuctionsNotModified(_ reader: BufferReader) -> StarGiftActiveAuctions? {
            return Api.payments.StarGiftActiveAuctions.starGiftActiveAuctionsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarGiftAuctionAcquiredGifts: TypeConstructorDescription {
        case starGiftAuctionAcquiredGifts(gifts: [Api.StarGiftAuctionAcquiredGift], users: [Api.User], chats: [Api.Chat])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionAcquiredGifts(let gifts, let users, let chats):
                    if boxed {
                        buffer.appendInt32(2103169520)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAuctionAcquiredGifts(let gifts, let users, let chats):
                return ("starGiftAuctionAcquiredGifts", [("gifts", gifts as Any), ("users", users as Any), ("chats", chats as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.payments.StarGiftAuctionAcquiredGifts.starGiftAuctionAcquiredGifts(gifts: _1!, users: _2!, chats: _3!)
        }
    
    }
}
public extension Api.payments {
    enum StarGiftAuctionState: TypeConstructorDescription {
        case starGiftAuctionState(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState, timeout: Int32, users: [Api.User], chats: [Api.Chat])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftAuctionState(let gift, let state, let userState, let timeout, let users, let chats):
                    if boxed {
                        buffer.appendInt32(1798960364)
                    }
                    gift.serialize(buffer, true)
                    state.serialize(buffer, true)
                    userState.serialize(buffer, true)
                    serializeInt32(timeout, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftAuctionState(let gift, let state, let userState, let timeout, let users, let chats):
                return ("starGiftAuctionState", [("gift", gift as Any), ("state", state as Any), ("userState", userState as Any), ("timeout", timeout as Any), ("users", users as Any), ("chats", chats as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.payments.StarGiftAuctionState.starGiftAuctionState(gift: _1!, state: _2!, userState: _3!, timeout: _4!, users: _5!, chats: _6!)
        }
    
    }
}
public extension Api.payments {
    enum StarGiftCollections: TypeConstructorDescription {
        case starGiftCollections(collections: [Api.StarGiftCollection])
        case starGiftCollectionsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftCollections(let collections):
                    if boxed {
                        buffer.appendInt32(-1977011469)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(collections.count))
                    for item in collections {
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
                case .starGiftCollections(let collections):
                return ("starGiftCollections", [("collections", collections as Any)])
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
            if !_c1 { return nil }
            return Api.payments.StarGiftCollections.starGiftCollections(collections: _1!)
        }
        public static func parse_starGiftCollectionsNotModified(_ reader: BufferReader) -> StarGiftCollections? {
            return Api.payments.StarGiftCollections.starGiftCollectionsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarGiftUpgradeAttributes: TypeConstructorDescription {
        case starGiftUpgradeAttributes(attributes: [Api.StarGiftAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftUpgradeAttributes(let attributes):
                    if boxed {
                        buffer.appendInt32(1187439471)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftUpgradeAttributes(let attributes):
                return ("starGiftUpgradeAttributes", [("attributes", attributes as Any)])
    }
    }
    
        public static func parse_starGiftUpgradeAttributes(_ reader: BufferReader) -> StarGiftUpgradeAttributes? {
            var _1: [Api.StarGiftAttribute]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarGiftAttribute.self)
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.StarGiftUpgradeAttributes.starGiftUpgradeAttributes(attributes: _1!)
        }
    
    }
}
public extension Api.payments {
    enum StarGiftUpgradePreview: TypeConstructorDescription {
        case starGiftUpgradePreview(sampleAttributes: [Api.StarGiftAttribute], prices: [Api.StarGiftUpgradePrice], nextPrices: [Api.StarGiftUpgradePrice])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftUpgradePreview(let sampleAttributes, let prices, let nextPrices):
                    if boxed {
                        buffer.appendInt32(1038213101)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sampleAttributes.count))
                    for item in sampleAttributes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prices.count))
                    for item in prices {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(nextPrices.count))
                    for item in nextPrices {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftUpgradePreview(let sampleAttributes, let prices, let nextPrices):
                return ("starGiftUpgradePreview", [("sampleAttributes", sampleAttributes as Any), ("prices", prices as Any), ("nextPrices", nextPrices as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.payments.StarGiftUpgradePreview.starGiftUpgradePreview(sampleAttributes: _1!, prices: _2!, nextPrices: _3!)
        }
    
    }
}
public extension Api.payments {
    enum StarGiftWithdrawalUrl: TypeConstructorDescription {
        case starGiftWithdrawalUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGiftWithdrawalUrl(let url):
                    if boxed {
                        buffer.appendInt32(-2069218660)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starGiftWithdrawalUrl(let url):
                return ("starGiftWithdrawalUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starGiftWithdrawalUrl(_ reader: BufferReader) -> StarGiftWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.StarGiftWithdrawalUrl.starGiftWithdrawalUrl(url: _1!)
        }
    
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription {
        case starGifts(hash: Int32, gifts: [Api.StarGift], chats: [Api.Chat], users: [Api.User])
        case starGiftsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starGifts(let hash, let gifts, let chats, let users):
                    if boxed {
                        buffer.appendInt32(785918357)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(gifts.count))
                    for item in gifts {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
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
                case .starGifts(let hash, let gifts, let chats, let users):
                return ("starGifts", [("hash", hash as Any), ("gifts", gifts as Any), ("chats", chats as Any), ("users", users as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.payments.StarGifts.starGifts(hash: _1!, gifts: _2!, chats: _3!, users: _4!)
        }
        public static func parse_starGiftsNotModified(_ reader: BufferReader) -> StarGifts? {
            return Api.payments.StarGifts.starGiftsNotModified
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription {
        case starsRevenueAdsAccountUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueAdsAccountUrl(let url):
                    if boxed {
                        buffer.appendInt32(961445665)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueAdsAccountUrl(let url):
                return ("starsRevenueAdsAccountUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueAdsAccountUrl(_ reader: BufferReader) -> StarsRevenueAdsAccountUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.StarsRevenueAdsAccountUrl.starsRevenueAdsAccountUrl(url: _1!)
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription {
        case starsRevenueStats(flags: Int32, topHoursGraph: Api.StatsGraph?, revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueStats(let flags, let topHoursGraph, let revenueGraph, let status, let usdRate):
                    if boxed {
                        buffer.appendInt32(1814066038)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {topHoursGraph!.serialize(buffer, true)}
                    revenueGraph.serialize(buffer, true)
                    status.serialize(buffer, true)
                    serializeDouble(usdRate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueStats(let flags, let topHoursGraph, let revenueGraph, let status, let usdRate):
                return ("starsRevenueStats", [("flags", flags as Any), ("topHoursGraph", topHoursGraph as Any), ("revenueGraph", revenueGraph as Any), ("status", status as Any), ("usdRate", usdRate as Any)])
    }
    }
    
        public static func parse_starsRevenueStats(_ reader: BufferReader) -> StarsRevenueStats? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StatsGraph?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            } }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.payments.StarsRevenueStats.starsRevenueStats(flags: _1!, topHoursGraph: _2, revenueGraph: _3!, status: _4!, usdRate: _5!)
        }
    
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription {
        case starsRevenueWithdrawalUrl(url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsRevenueWithdrawalUrl(let url):
                    if boxed {
                        buffer.appendInt32(497778871)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsRevenueWithdrawalUrl(let url):
                return ("starsRevenueWithdrawalUrl", [("url", url as Any)])
    }
    }
    
        public static func parse_starsRevenueWithdrawalUrl(_ reader: BufferReader) -> StarsRevenueWithdrawalUrl? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.payments.StarsRevenueWithdrawalUrl.starsRevenueWithdrawalUrl(url: _1!)
        }
    
    }
}
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription {
        case starsStatus(flags: Int32, balance: Api.StarsAmount, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1822222573)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    balance.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(subscriptions!.count))
                    for item in subscriptions! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(subscriptionsNextOffset!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt64(subscriptionsMissingBalance!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(history!.count))
                    for item in history! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .starsStatus(let flags, let balance, let subscriptions, let subscriptionsNextOffset, let subscriptionsMissingBalance, let history, let nextOffset, let chats, let users):
                return ("starsStatus", [("flags", flags as Any), ("balance", balance as Any), ("subscriptions", subscriptions as Any), ("subscriptionsNextOffset", subscriptionsNextOffset as Any), ("subscriptionsMissingBalance", subscriptionsMissingBalance as Any), ("history", history as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsSubscription.self)
            } }
            var _4: String?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseString(reader) }
            var _5: Int64?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt64() }
            var _6: [Api.StarsTransaction]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StarsTransaction.self)
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            return Api.payments.StarsStatus.starsStatus(flags: _1!, balance: _2!, subscriptions: _3, subscriptionsNextOffset: _4, subscriptionsMissingBalance: _5, history: _6, nextOffset: _7, chats: _8!, users: _9!)
        }
    
    }
}
public extension Api.payments {
    enum SuggestedStarRefBots: TypeConstructorDescription {
        case suggestedStarRefBots(flags: Int32, count: Int32, suggestedBots: [Api.StarRefProgram], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedStarRefBots(let flags, let count, let suggestedBots, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(-1261053863)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(suggestedBots.count))
                    for item in suggestedBots {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(nextOffset!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedStarRefBots(let flags, let count, let suggestedBots, let users, let nextOffset):
                return ("suggestedStarRefBots", [("flags", flags as Any), ("count", count as Any), ("suggestedBots", suggestedBots as Any), ("users", users as Any), ("nextOffset", nextOffset as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.payments.SuggestedStarRefBots.suggestedStarRefBots(flags: _1!, count: _2!, suggestedBots: _3!, users: _4!, nextOffset: _5)
        }
    
    }
}
public extension Api.payments {
    enum UniqueStarGift: TypeConstructorDescription {
        case uniqueStarGift(gift: Api.StarGift, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .uniqueStarGift(let gift, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1097619176)
                    }
                    gift.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .uniqueStarGift(let gift, let chats, let users):
                return ("uniqueStarGift", [("gift", gift as Any), ("chats", chats as Any), ("users", users as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.payments.UniqueStarGift.uniqueStarGift(gift: _1!, chats: _2!, users: _3!)
        }
    
    }
}
public extension Api.payments {
    enum UniqueStarGiftValueInfo: TypeConstructorDescription {
        case uniqueStarGiftValueInfo(flags: Int32, currency: String, value: Int64, initialSaleDate: Int32, initialSaleStars: Int64, initialSalePrice: Int64, lastSaleDate: Int32?, lastSalePrice: Int64?, floorPrice: Int64?, averagePrice: Int64?, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .uniqueStarGiftValueInfo(let flags, let currency, let value, let initialSaleDate, let initialSaleStars, let initialSalePrice, let lastSaleDate, let lastSalePrice, let floorPrice, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                    if boxed {
                        buffer.appendInt32(1362093126)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(value, buffer: buffer, boxed: false)
                    serializeInt32(initialSaleDate, buffer: buffer, boxed: false)
                    serializeInt64(initialSaleStars, buffer: buffer, boxed: false)
                    serializeInt64(initialSalePrice, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(lastSaleDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(lastSalePrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(floorPrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt64(averagePrice!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(listedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(fragmentListedCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(fragmentListedUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .uniqueStarGiftValueInfo(let flags, let currency, let value, let initialSaleDate, let initialSaleStars, let initialSalePrice, let lastSaleDate, let lastSalePrice, let floorPrice, let averagePrice, let listedCount, let fragmentListedCount, let fragmentListedUrl):
                return ("uniqueStarGiftValueInfo", [("flags", flags as Any), ("currency", currency as Any), ("value", value as Any), ("initialSaleDate", initialSaleDate as Any), ("initialSaleStars", initialSaleStars as Any), ("initialSalePrice", initialSalePrice as Any), ("lastSaleDate", lastSaleDate as Any), ("lastSalePrice", lastSalePrice as Any), ("floorPrice", floorPrice as Any), ("averagePrice", averagePrice as Any), ("listedCount", listedCount as Any), ("fragmentListedCount", fragmentListedCount as Any), ("fragmentListedUrl", fragmentListedUrl as Any)])
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
            if Int(_1!) & Int(1 << 0) != 0 {_7 = reader.readInt32() }
            var _8: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_8 = reader.readInt64() }
            var _9: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_9 = reader.readInt64() }
            var _10: Int64?
            if Int(_1!) & Int(1 << 3) != 0 {_10 = reader.readInt64() }
            var _11: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_11 = reader.readInt32() }
            var _12: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_12 = reader.readInt32() }
            var _13: String?
            if Int(_1!) & Int(1 << 5) != 0 {_13 = parseString(reader) }
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            if !_c7 { return nil }
            if !_c8 { return nil }
            if !_c9 { return nil }
            if !_c10 { return nil }
            if !_c11 { return nil }
            if !_c12 { return nil }
            if !_c13 { return nil }
            return Api.payments.UniqueStarGiftValueInfo.uniqueStarGiftValueInfo(flags: _1!, currency: _2!, value: _3!, initialSaleDate: _4!, initialSaleStars: _5!, initialSalePrice: _6!, lastSaleDate: _7, lastSalePrice: _8, floorPrice: _9, averagePrice: _10, listedCount: _11, fragmentListedCount: _12, fragmentListedUrl: _13)
        }
    
    }
}
public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription {
        case validatedRequestedInfo(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                    if boxed {
                        buffer.appendInt32(-784000893)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(id!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(shippingOptions!.count))
                    for item in shippingOptions! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .validatedRequestedInfo(let flags, let id, let shippingOptions):
                return ("validatedRequestedInfo", [("flags", flags as Any), ("id", id as Any), ("shippingOptions", shippingOptions as Any)])
    }
    }
    
        public static func parse_validatedRequestedInfo(_ reader: BufferReader) -> ValidatedRequestedInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: [Api.ShippingOption]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ShippingOption.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            return Api.payments.ValidatedRequestedInfo.validatedRequestedInfo(flags: _1!, id: _2, shippingOptions: _3)
        }
    
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription {
        case exportedGroupCallInvite(link: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedGroupCallInvite(let link):
                    if boxed {
                        buffer.appendInt32(541839704)
                    }
                    serializeString(link, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedGroupCallInvite(let link):
                return ("exportedGroupCallInvite", [("link", link as Any)])
    }
    }
    
        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.phone.ExportedGroupCallInvite.exportedGroupCallInvite(link: _1!)
        }
    
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription {
        case groupCall(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1636664659)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(participantsNextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCall(let call, let participants, let participantsNextOffset, let chats, let users):
                return ("groupCall", [("call", call as Any), ("participants", participants as Any), ("participantsNextOffset", participantsNextOffset as Any), ("chats", chats as Any), ("users", users as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            return Api.phone.GroupCall.groupCall(call: _1!, participants: _2!, participantsNextOffset: _3!, chats: _4!, users: _5!)
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStars: TypeConstructorDescription {
        case groupCallStars(totalStars: Int64, topDonors: [Api.GroupCallDonor], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStars(let totalStars, let topDonors, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1658995418)
                    }
                    serializeInt64(totalStars, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topDonors.count))
                    for item in topDonors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStars(let totalStars, let topDonors, let chats, let users):
                return ("groupCallStars", [("totalStars", totalStars as Any), ("topDonors", topDonors as Any), ("chats", chats as Any), ("users", users as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            return Api.phone.GroupCallStars.groupCallStars(totalStars: _1!, topDonors: _2!, chats: _3!, users: _4!)
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription {
        case groupCallStreamChannels(channels: [Api.GroupCallStreamChannel])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamChannels(let channels):
                    if boxed {
                        buffer.appendInt32(-790330702)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(channels.count))
                    for item in channels {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamChannels(let channels):
                return ("groupCallStreamChannels", [("channels", channels as Any)])
    }
    }
    
        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            var _1: [Api.GroupCallStreamChannel]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallStreamChannel.self)
            }
            let _c1 = _1 != nil
            if !_c1 { return nil }
            return Api.phone.GroupCallStreamChannels.groupCallStreamChannels(channels: _1!)
        }
    
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription {
        case groupCallStreamRtmpUrl(url: String, key: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                    if boxed {
                        buffer.appendInt32(767505458)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupCallStreamRtmpUrl(let url, let key):
                return ("groupCallStreamRtmpUrl", [("url", url as Any), ("key", key as Any)])
    }
    }
    
        public static func parse_groupCallStreamRtmpUrl(_ reader: BufferReader) -> GroupCallStreamRtmpUrl? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if !_c1 { return nil }
            if !_c2 { return nil }
            return Api.phone.GroupCallStreamRtmpUrl.groupCallStreamRtmpUrl(url: _1!, key: _2!)
        }
    
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription {
        case groupParticipants(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                    if boxed {
                        buffer.appendInt32(-193506890)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeString(nextOffset, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .groupParticipants(let count, let participants, let nextOffset, let chats, let users, let version):
                return ("groupParticipants", [("count", count as Any), ("participants", participants as Any), ("nextOffset", nextOffset as Any), ("chats", chats as Any), ("users", users as Any), ("version", version as Any)])
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
            if !_c1 { return nil }
            if !_c2 { return nil }
            if !_c3 { return nil }
            if !_c4 { return nil }
            if !_c5 { return nil }
            if !_c6 { return nil }
            return Api.phone.GroupParticipants.groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!)
        }
    
    }
}
