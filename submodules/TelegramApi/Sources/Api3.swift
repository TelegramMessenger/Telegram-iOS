public extension Api {
public struct channels {
    public enum ChannelParticipants: TypeConstructorDescription {
        case channelParticipants(count: Int32, participants: [Api.ChannelParticipant], chats: [Api.Chat], users: [Api.User])
        case channelParticipantsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipants(let count, let participants, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1699676497)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
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
                case .channelParticipantsNotModified:
                    if boxed {
                        buffer.appendInt32(-266911767)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .channelParticipants(let count, let participants, let chats, let users):
                return ("channelParticipants", [("count", count), ("participants", participants), ("chats", chats), ("users", users)])
                case .channelParticipantsNotModified:
                return ("channelParticipantsNotModified", [])
    }
    }
    
        public static func parse_channelParticipants(_ reader: BufferReader) -> ChannelParticipants? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ChannelParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelParticipant.self)
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
                return Api.channels.ChannelParticipants.channelParticipants(count: _1!, participants: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelParticipantsNotModified(_ reader: BufferReader) -> ChannelParticipants? {
            return Api.channels.ChannelParticipants.channelParticipantsNotModified
        }
    
    }
    public enum ChannelParticipant: TypeConstructorDescription {
        case channelParticipant(participant: Api.ChannelParticipant, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipant(let participant, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-541588713)
                    }
                    participant.serialize(buffer, true)
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
                case .channelParticipant(let participant, let chats, let users):
                return ("channelParticipant", [("participant", participant), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
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
                return Api.channels.ChannelParticipant.channelParticipant(participant: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SendAsPeers: TypeConstructorDescription {
        case sendAsPeers(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sendAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-2091463255)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
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
                case .sendAsPeers(let peers, let chats, let users):
                return ("sendAsPeers", [("peers", peers), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_sendAsPeers(_ reader: BufferReader) -> SendAsPeers? {
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
                return Api.channels.SendAsPeers.sendAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AdminLogResults: TypeConstructorDescription {
        case adminLogResults(events: [Api.ChannelAdminLogEvent], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .adminLogResults(let events, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-309659827)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(events.count))
                    for item in events {
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
                case .adminLogResults(let events, let chats, let users):
                return ("adminLogResults", [("events", events), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_adminLogResults(_ reader: BufferReader) -> AdminLogResults? {
            var _1: [Api.ChannelAdminLogEvent]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ChannelAdminLogEvent.self)
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
                return Api.channels.AdminLogResults.adminLogResults(events: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct payments {
    public enum ValidatedRequestedInfo: TypeConstructorDescription {
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
                return ("validatedRequestedInfo", [("flags", flags), ("id", id), ("shippingOptions", shippingOptions)])
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
            if _c1 && _c2 && _c3 {
                return Api.payments.ValidatedRequestedInfo.validatedRequestedInfo(flags: _1!, id: _2, shippingOptions: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentResult: TypeConstructorDescription {
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
                return ("paymentResult", [("updates", updates)])
                case .paymentVerificationNeeded(let url):
                return ("paymentVerificationNeeded", [("url", url)])
    }
    }
    
        public static func parse_paymentResult(_ reader: BufferReader) -> PaymentResult? {
            var _1: Api.Updates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Updates
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.payments.PaymentResult.paymentResult(updates: _1!)
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
                return Api.payments.PaymentResult.paymentVerificationNeeded(url: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentForm: TypeConstructorDescription {
        case paymentForm(flags: Int32, formId: Int64, botId: Int64, invoice: Api.Invoice, providerId: Int64, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: Api.PaymentSavedCredentials?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentForm(let flags, let formId, let botId, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let savedInfo, let savedCredentials, let users):
                    if boxed {
                        buffer.appendInt32(378828315)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(formId, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    serializeInt64(providerId, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(nativeProvider!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {nativeParams!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {savedInfo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {savedCredentials!.serialize(buffer, true)}
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
                case .paymentForm(let flags, let formId, let botId, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let savedInfo, let savedCredentials, let users):
                return ("paymentForm", [("flags", flags), ("formId", formId), ("botId", botId), ("invoice", invoice), ("providerId", providerId), ("url", url), ("nativeProvider", nativeProvider), ("nativeParams", nativeParams), ("savedInfo", savedInfo), ("savedCredentials", savedCredentials), ("users", users)])
    }
    }
    
        public static func parse_paymentForm(_ reader: BufferReader) -> PaymentForm? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.Invoice?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: String?
            _6 = parseString(reader)
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
            var _8: Api.DataJSON?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.DataJSON
            } }
            var _9: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _10: Api.PaymentSavedCredentials?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.PaymentSavedCredentials
            } }
            var _11: [Api.User]?
            if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 1) == 0) || _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.payments.PaymentForm.paymentForm(flags: _1!, formId: _2!, botId: _3!, invoice: _4!, providerId: _5!, url: _6!, nativeProvider: _7, nativeParams: _8, savedInfo: _9, savedCredentials: _10, users: _11!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentReceipt: TypeConstructorDescription {
        case paymentReceipt(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User])
    
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
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .paymentReceipt(let flags, let date, let botId, let providerId, let title, let description, let photo, let invoice, let info, let shipping, let tipAmount, let currency, let totalAmount, let credentialsTitle, let users):
                return ("paymentReceipt", [("flags", flags), ("date", date), ("botId", botId), ("providerId", providerId), ("title", title), ("description", description), ("photo", photo), ("invoice", invoice), ("info", info), ("shipping", shipping), ("tipAmount", tipAmount), ("currency", currency), ("totalAmount", totalAmount), ("credentialsTitle", credentialsTitle), ("users", users)])
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.payments.PaymentReceipt.paymentReceipt(flags: _1!, date: _2!, botId: _3!, providerId: _4!, title: _5!, description: _6!, photo: _7, invoice: _8!, info: _9, shipping: _10, tipAmount: _11, currency: _12!, totalAmount: _13!, credentialsTitle: _14!, users: _15!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SavedInfo: TypeConstructorDescription {
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
                return ("savedInfo", [("flags", flags), ("savedInfo", savedInfo)])
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
            if _c1 && _c2 {
                return Api.payments.SavedInfo.savedInfo(flags: _1!, savedInfo: _2)
            }
            else {
                return nil
            }
        }
    
    }
    public enum BankCardData: TypeConstructorDescription {
        case bankCardData(title: String, openUrls: [Api.BankCardOpenUrl])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .bankCardData(let title, let openUrls):
                    if boxed {
                        buffer.appendInt32(1042605427)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(openUrls.count))
                    for item in openUrls {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .bankCardData(let title, let openUrls):
                return ("bankCardData", [("title", title), ("openUrls", openUrls)])
    }
    }
    
        public static func parse_bankCardData(_ reader: BufferReader) -> BankCardData? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.BankCardOpenUrl]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BankCardOpenUrl.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.payments.BankCardData.bankCardData(title: _1!, openUrls: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct stats {
    public enum BroadcastStats: TypeConstructorDescription {
        case broadcastStats(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, recentMessageInteractions: [Api.MessageInteractionCounters])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let recentMessageInteractions):
                    if boxed {
                        buffer.appendInt32(-1107852396)
                    }
                    period.serialize(buffer, true)
                    followers.serialize(buffer, true)
                    viewsPerPost.serialize(buffer, true)
                    sharesPerPost.serialize(buffer, true)
                    enabledNotifications.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    followersGraph.serialize(buffer, true)
                    muteGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    interactionsGraph.serialize(buffer, true)
                    ivInteractionsGraph.serialize(buffer, true)
                    viewsBySourceGraph.serialize(buffer, true)
                    newFollowersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentMessageInteractions.count))
                    for item in recentMessageInteractions {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .broadcastStats(let period, let followers, let viewsPerPost, let sharesPerPost, let enabledNotifications, let growthGraph, let followersGraph, let muteGraph, let topHoursGraph, let interactionsGraph, let ivInteractionsGraph, let viewsBySourceGraph, let newFollowersBySourceGraph, let languagesGraph, let recentMessageInteractions):
                return ("broadcastStats", [("period", period), ("followers", followers), ("viewsPerPost", viewsPerPost), ("sharesPerPost", sharesPerPost), ("enabledNotifications", enabledNotifications), ("growthGraph", growthGraph), ("followersGraph", followersGraph), ("muteGraph", muteGraph), ("topHoursGraph", topHoursGraph), ("interactionsGraph", interactionsGraph), ("ivInteractionsGraph", ivInteractionsGraph), ("viewsBySourceGraph", viewsBySourceGraph), ("newFollowersBySourceGraph", newFollowersBySourceGraph), ("languagesGraph", languagesGraph), ("recentMessageInteractions", recentMessageInteractions)])
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
            var _5: Api.StatsPercentValue?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StatsPercentValue
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
            var _14: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            var _15: [Api.MessageInteractionCounters]?
            if let _ = reader.readInt32() {
                _15 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageInteractionCounters.self)
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
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 {
                return Api.stats.BroadcastStats.broadcastStats(period: _1!, followers: _2!, viewsPerPost: _3!, sharesPerPost: _4!, enabledNotifications: _5!, growthGraph: _6!, followersGraph: _7!, muteGraph: _8!, topHoursGraph: _9!, interactionsGraph: _10!, ivInteractionsGraph: _11!, viewsBySourceGraph: _12!, newFollowersBySourceGraph: _13!, languagesGraph: _14!, recentMessageInteractions: _15!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MegagroupStats: TypeConstructorDescription {
        case megagroupStats(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                    if boxed {
                        buffer.appendInt32(-276825834)
                    }
                    period.serialize(buffer, true)
                    members.serialize(buffer, true)
                    messages.serialize(buffer, true)
                    viewers.serialize(buffer, true)
                    posters.serialize(buffer, true)
                    growthGraph.serialize(buffer, true)
                    membersGraph.serialize(buffer, true)
                    newMembersBySourceGraph.serialize(buffer, true)
                    languagesGraph.serialize(buffer, true)
                    messagesGraph.serialize(buffer, true)
                    actionsGraph.serialize(buffer, true)
                    topHoursGraph.serialize(buffer, true)
                    weekdaysGraph.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topPosters.count))
                    for item in topPosters {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topAdmins.count))
                    for item in topAdmins {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topInviters.count))
                    for item in topInviters {
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
                case .megagroupStats(let period, let members, let messages, let viewers, let posters, let growthGraph, let membersGraph, let newMembersBySourceGraph, let languagesGraph, let messagesGraph, let actionsGraph, let topHoursGraph, let weekdaysGraph, let topPosters, let topAdmins, let topInviters, let users):
                return ("megagroupStats", [("period", period), ("members", members), ("messages", messages), ("viewers", viewers), ("posters", posters), ("growthGraph", growthGraph), ("membersGraph", membersGraph), ("newMembersBySourceGraph", newMembersBySourceGraph), ("languagesGraph", languagesGraph), ("messagesGraph", messagesGraph), ("actionsGraph", actionsGraph), ("topHoursGraph", topHoursGraph), ("weekdaysGraph", weekdaysGraph), ("topPosters", topPosters), ("topAdmins", topAdmins), ("topInviters", topInviters), ("users", users)])
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
                return Api.stats.MegagroupStats.megagroupStats(period: _1!, members: _2!, messages: _3!, viewers: _4!, posters: _5!, growthGraph: _6!, membersGraph: _7!, newMembersBySourceGraph: _8!, languagesGraph: _9!, messagesGraph: _10!, actionsGraph: _11!, topHoursGraph: _12!, weekdaysGraph: _13!, topPosters: _14!, topAdmins: _15!, topInviters: _16!, users: _17!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum MessageStats: TypeConstructorDescription {
        case messageStats(viewsGraph: Api.StatsGraph)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageStats(let viewsGraph):
                    if boxed {
                        buffer.appendInt32(-1986399595)
                    }
                    viewsGraph.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageStats(let viewsGraph):
                return ("messageStats", [("viewsGraph", viewsGraph)])
    }
    }
    
        public static func parse_messageStats(_ reader: BufferReader) -> MessageStats? {
            var _1: Api.StatsGraph?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StatsGraph
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.stats.MessageStats.messageStats(viewsGraph: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct auth {
    public enum LoginToken: TypeConstructorDescription {
        case loginToken(expires: Int32, token: Buffer)
        case loginTokenMigrateTo(dcId: Int32, token: Buffer)
        case loginTokenSuccess(authorization: Api.auth.Authorization)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .loginToken(let expires, let token):
                    if boxed {
                        buffer.appendInt32(1654593920)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    break
                case .loginTokenMigrateTo(let dcId, let token):
                    if boxed {
                        buffer.appendInt32(110008598)
                    }
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    serializeBytes(token, buffer: buffer, boxed: false)
                    break
                case .loginTokenSuccess(let authorization):
                    if boxed {
                        buffer.appendInt32(957176926)
                    }
                    authorization.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .loginToken(let expires, let token):
                return ("loginToken", [("expires", expires), ("token", token)])
                case .loginTokenMigrateTo(let dcId, let token):
                return ("loginTokenMigrateTo", [("dcId", dcId), ("token", token)])
                case .loginTokenSuccess(let authorization):
                return ("loginTokenSuccess", [("authorization", authorization)])
    }
    }
    
        public static func parse_loginToken(_ reader: BufferReader) -> LoginToken? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoginToken.loginToken(expires: _1!, token: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_loginTokenMigrateTo(_ reader: BufferReader) -> LoginToken? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoginToken.loginTokenMigrateTo(dcId: _1!, token: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_loginTokenSuccess(_ reader: BufferReader) -> LoginToken? {
            var _1: Api.auth.Authorization?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.Authorization
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.LoginToken.loginTokenSuccess(authorization: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Authorization: TypeConstructorDescription {
        case authorization(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, user: Api.User)
        case authorizationSignUpRequired(flags: Int32, termsOfService: Api.help.TermsOfService?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let user):
                    if boxed {
                        buffer.appendInt32(872119224)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(otherwiseReloginDays!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(tmpSessions!, buffer: buffer, boxed: false)}
                    user.serialize(buffer, true)
                    break
                case .authorizationSignUpRequired(let flags, let termsOfService):
                    if boxed {
                        buffer.appendInt32(1148485274)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {termsOfService!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let user):
                return ("authorization", [("flags", flags), ("otherwiseReloginDays", otherwiseReloginDays), ("tmpSessions", tmpSessions), ("user", user)])
                case .authorizationSignUpRequired(let flags, let termsOfService):
                return ("authorizationSignUpRequired", [("flags", flags), ("termsOfService", termsOfService)])
    }
    }
    
        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.User?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.auth.Authorization.authorization(flags: _1!, otherwiseReloginDays: _2, tmpSessions: _3, user: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_authorizationSignUpRequired(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.help.TermsOfService?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.Authorization.authorizationSignUpRequired(flags: _1!, termsOfService: _2)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PasswordRecovery: TypeConstructorDescription {
        case passwordRecovery(emailPattern: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordRecovery(let emailPattern):
                    if boxed {
                        buffer.appendInt32(326715557)
                    }
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordRecovery(let emailPattern):
                return ("passwordRecovery", [("emailPattern", emailPattern)])
    }
    }
    
        public static func parse_passwordRecovery(_ reader: BufferReader) -> PasswordRecovery? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.PasswordRecovery.passwordRecovery(emailPattern: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ExportedAuthorization: TypeConstructorDescription {
        case exportedAuthorization(id: Int64, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedAuthorization(let id, let bytes):
                    if boxed {
                        buffer.appendInt32(-1271602504)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeBytes(bytes, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .exportedAuthorization(let id, let bytes):
                return ("exportedAuthorization", [("id", id), ("bytes", bytes)])
    }
    }
    
        public static func parse_exportedAuthorization(_ reader: BufferReader) -> ExportedAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.ExportedAuthorization.exportedAuthorization(id: _1!, bytes: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum SentCode: TypeConstructorDescription {
        case sentCode(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentCode(let flags, let type, let phoneCodeHash, let nextType, let timeout):
                    if boxed {
                        buffer.appendInt32(1577067778)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    type.serialize(buffer, true)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {nextType!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCode(let flags, let type, let phoneCodeHash, let nextType, let timeout):
                return ("sentCode", [("flags", flags), ("type", type), ("phoneCodeHash", phoneCodeHash), ("nextType", nextType), ("timeout", timeout)])
    }
    }
    
        public static func parse_sentCode(_ reader: BufferReader) -> SentCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.auth.SentCodeType?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.auth.SentCodeType
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.auth.CodeType?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.auth.CodeType
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCode.sentCode(flags: _1!, type: _2!, phoneCodeHash: _3!, nextType: _4, timeout: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum CodeType: TypeConstructorDescription {
        case codeTypeSms
        case codeTypeCall
        case codeTypeFlashCall
        case codeTypeMissedCall
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .codeTypeSms:
                    if boxed {
                        buffer.appendInt32(1923290508)
                    }
                    
                    break
                case .codeTypeCall:
                    if boxed {
                        buffer.appendInt32(1948046307)
                    }
                    
                    break
                case .codeTypeFlashCall:
                    if boxed {
                        buffer.appendInt32(577556219)
                    }
                    
                    break
                case .codeTypeMissedCall:
                    if boxed {
                        buffer.appendInt32(-702884114)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .codeTypeSms:
                return ("codeTypeSms", [])
                case .codeTypeCall:
                return ("codeTypeCall", [])
                case .codeTypeFlashCall:
                return ("codeTypeFlashCall", [])
                case .codeTypeMissedCall:
                return ("codeTypeMissedCall", [])
    }
    }
    
        public static func parse_codeTypeSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeSms
        }
        public static func parse_codeTypeCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeCall
        }
        public static func parse_codeTypeFlashCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeFlashCall
        }
        public static func parse_codeTypeMissedCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeMissedCall
        }
    
    }
    public enum SentCodeType: TypeConstructorDescription {
        case sentCodeTypeApp(length: Int32)
        case sentCodeTypeSms(length: Int32)
        case sentCodeTypeCall(length: Int32)
        case sentCodeTypeFlashCall(pattern: String)
        case sentCodeTypeMissedCall(prefix: String, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentCodeTypeApp(let length):
                    if boxed {
                        buffer.appendInt32(1035688326)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSms(let length):
                    if boxed {
                        buffer.appendInt32(-1073693790)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeCall(let length):
                    if boxed {
                        buffer.appendInt32(1398007207)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeFlashCall(let pattern):
                    if boxed {
                        buffer.appendInt32(-1425815847)
                    }
                    serializeString(pattern, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeMissedCall(let prefix, let length):
                    if boxed {
                        buffer.appendInt32(-2113903484)
                    }
                    serializeString(prefix, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCodeTypeApp(let length):
                return ("sentCodeTypeApp", [("length", length)])
                case .sentCodeTypeSms(let length):
                return ("sentCodeTypeSms", [("length", length)])
                case .sentCodeTypeCall(let length):
                return ("sentCodeTypeCall", [("length", length)])
                case .sentCodeTypeFlashCall(let pattern):
                return ("sentCodeTypeFlashCall", [("pattern", pattern)])
                case .sentCodeTypeMissedCall(let prefix, let length):
                return ("sentCodeTypeMissedCall", [("prefix", prefix), ("length", length)])
    }
    }
    
        public static func parse_sentCodeTypeApp(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeApp(length: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeSms(length: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeCall(length: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFlashCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeFlashCall(pattern: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeMissedCall(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeMissedCall(prefix: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum LoggedOut: TypeConstructorDescription {
        case loggedOut(flags: Int32, futureAuthToken: Buffer?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .loggedOut(let flags, let futureAuthToken):
                    if boxed {
                        buffer.appendInt32(-1012759713)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(futureAuthToken!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .loggedOut(let flags, let futureAuthToken):
                return ("loggedOut", [("flags", flags), ("futureAuthToken", futureAuthToken)])
    }
    }
    
        public static func parse_loggedOut(_ reader: BufferReader) -> LoggedOut? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoggedOut.loggedOut(flags: _1!, futureAuthToken: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct users {
    public enum UserFull: TypeConstructorDescription {
        case userFull(fullUser: Api.UserFull, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userFull(let fullUser, let chats, let users):
                    if boxed {
                        buffer.appendInt32(997004590)
                    }
                    fullUser.serialize(buffer, true)
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
                case .userFull(let fullUser, let chats, let users):
                return ("userFull", [("fullUser", fullUser), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Api.UserFull?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.UserFull
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
                return Api.users.UserFull.userFull(fullUser: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
public extension Api {
public struct contacts {
    public enum Blocked: TypeConstructorDescription {
        case blocked(blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User])
        case blockedSlice(count: Int32, blocked: [Api.PeerBlocked], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .blocked(let blocked, let chats, let users):
                    if boxed {
                        buffer.appendInt32(182326673)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocked.count))
                    for item in blocked {
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
                case .blockedSlice(let count, let blocked, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-513392236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocked.count))
                    for item in blocked {
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
                case .blocked(let blocked, let chats, let users):
                return ("blocked", [("blocked", blocked), ("chats", chats), ("users", users)])
                case .blockedSlice(let count, let blocked, let chats, let users):
                return ("blockedSlice", [("count", count), ("blocked", blocked), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_blocked(_ reader: BufferReader) -> Blocked? {
            var _1: [Api.PeerBlocked]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerBlocked.self)
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
                return Api.contacts.Blocked.blocked(blocked: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_blockedSlice(_ reader: BufferReader) -> Blocked? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.PeerBlocked]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerBlocked.self)
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
                return Api.contacts.Blocked.blockedSlice(count: _1!, blocked: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Contacts: TypeConstructorDescription {
        case contactsNotModified
        case contacts(contacts: [Api.Contact], savedCount: Int32, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contactsNotModified:
                    if boxed {
                        buffer.appendInt32(-1219778094)
                    }
                    
                    break
                case .contacts(let contacts, let savedCount, let users):
                    if boxed {
                        buffer.appendInt32(-353862078)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(contacts.count))
                    for item in contacts {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(savedCount, buffer: buffer, boxed: false)
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
                case .contactsNotModified:
                return ("contactsNotModified", [])
                case .contacts(let contacts, let savedCount, let users):
                return ("contacts", [("contacts", contacts), ("savedCount", savedCount), ("users", users)])
    }
    }
    
        public static func parse_contactsNotModified(_ reader: BufferReader) -> Contacts? {
            return Api.contacts.Contacts.contactsNotModified
        }
        public static func parse_contacts(_ reader: BufferReader) -> Contacts? {
            var _1: [Api.Contact]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Contact.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.contacts.Contacts.contacts(contacts: _1!, savedCount: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ResolvedPeer: TypeConstructorDescription {
        case resolvedPeer(peer: Api.Peer, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resolvedPeer(let peer, let chats, let users):
                    if boxed {
                        buffer.appendInt32(2131196633)
                    }
                    peer.serialize(buffer, true)
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
                case .resolvedPeer(let peer, let chats, let users):
                return ("resolvedPeer", [("peer", peer), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_resolvedPeer(_ reader: BufferReader) -> ResolvedPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
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
                return Api.contacts.ResolvedPeer.resolvedPeer(peer: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ImportedContacts: TypeConstructorDescription {
        case importedContacts(imported: [Api.ImportedContact], popularInvites: [Api.PopularContact], retryContacts: [Int64], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .importedContacts(let imported, let popularInvites, let retryContacts, let users):
                    if boxed {
                        buffer.appendInt32(2010127419)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(imported.count))
                    for item in imported {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(popularInvites.count))
                    for item in popularInvites {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(retryContacts.count))
                    for item in retryContacts {
                        serializeInt64(item, buffer: buffer, boxed: false)
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
                case .importedContacts(let imported, let popularInvites, let retryContacts, let users):
                return ("importedContacts", [("imported", imported), ("popularInvites", popularInvites), ("retryContacts", retryContacts), ("users", users)])
    }
    }
    
        public static func parse_importedContacts(_ reader: BufferReader) -> ImportedContacts? {
            var _1: [Api.ImportedContact]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ImportedContact.self)
            }
            var _2: [Api.PopularContact]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PopularContact.self)
            }
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
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
                return Api.contacts.ImportedContacts.importedContacts(imported: _1!, popularInvites: _2!, retryContacts: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Found: TypeConstructorDescription {
        case found(myResults: [Api.Peer], results: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .found(let myResults, let results, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1290580579)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(myResults.count))
                    for item in myResults {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results.count))
                    for item in results {
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
                case .found(let myResults, let results, let chats, let users):
                return ("found", [("myResults", myResults), ("results", results), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_found(_ reader: BufferReader) -> Found? {
            var _1: [Api.Peer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            }
            var _2: [Api.Peer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
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
                return Api.contacts.Found.found(myResults: _1!, results: _2!, chats: _3!, users: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TopPeers: TypeConstructorDescription {
        case topPeersNotModified
        case topPeers(categories: [Api.TopPeerCategoryPeers], chats: [Api.Chat], users: [Api.User])
        case topPeersDisabled
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeersNotModified:
                    if boxed {
                        buffer.appendInt32(-567906571)
                    }
                    
                    break
                case .topPeers(let categories, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1891070632)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(categories.count))
                    for item in categories {
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
                case .topPeersDisabled:
                    if boxed {
                        buffer.appendInt32(-1255369827)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeersNotModified:
                return ("topPeersNotModified", [])
                case .topPeers(let categories, let chats, let users):
                return ("topPeers", [("categories", categories), ("chats", chats), ("users", users)])
                case .topPeersDisabled:
                return ("topPeersDisabled", [])
    }
    }
    
        public static func parse_topPeersNotModified(_ reader: BufferReader) -> TopPeers? {
            return Api.contacts.TopPeers.topPeersNotModified
        }
        public static func parse_topPeers(_ reader: BufferReader) -> TopPeers? {
            var _1: [Api.TopPeerCategoryPeers]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TopPeerCategoryPeers.self)
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
                return Api.contacts.TopPeers.topPeers(categories: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_topPeersDisabled(_ reader: BufferReader) -> TopPeers? {
            return Api.contacts.TopPeers.topPeersDisabled
        }
    
    }
}
}
public extension Api {
public struct help {
    public enum SupportName: TypeConstructorDescription {
        case supportName(name: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .supportName(let name):
                    if boxed {
                        buffer.appendInt32(-1945767479)
                    }
                    serializeString(name, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .supportName(let name):
                return ("supportName", [("name", name)])
    }
    }
    
        public static func parse_supportName(_ reader: BufferReader) -> SupportName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.SupportName.supportName(name: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum AppUpdate: TypeConstructorDescription {
        case appUpdate(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?, sticker: Api.Document?)
        case noAppUpdate
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url, let sticker):
                    if boxed {
                        buffer.appendInt32(-860107216)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeString(version, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(url!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {sticker!.serialize(buffer, true)}
                    break
                case .noAppUpdate:
                    if boxed {
                        buffer.appendInt32(-1000708810)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url, let sticker):
                return ("appUpdate", [("flags", flags), ("id", id), ("version", version), ("text", text), ("entities", entities), ("document", document), ("url", url), ("sticker", sticker)])
                case .noAppUpdate:
                return ("noAppUpdate", [])
    }
    }
    
        public static func parse_appUpdate(_ reader: BufferReader) -> AppUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _6: Api.Document?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            var _8: Api.Document?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 3) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.help.AppUpdate.appUpdate(flags: _1!, id: _2!, version: _3!, text: _4!, entities: _5!, document: _6, url: _7, sticker: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_noAppUpdate(_ reader: BufferReader) -> AppUpdate? {
            return Api.help.AppUpdate.noAppUpdate
        }
    
    }
    public enum PassportConfig: TypeConstructorDescription {
        case passportConfigNotModified
        case passportConfig(hash: Int32, countriesLangs: Api.DataJSON)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passportConfigNotModified:
                    if boxed {
                        buffer.appendInt32(-1078332329)
                    }
                    
                    break
                case .passportConfig(let hash, let countriesLangs):
                    if boxed {
                        buffer.appendInt32(-1600596305)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    countriesLangs.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passportConfigNotModified:
                return ("passportConfigNotModified", [])
                case .passportConfig(let hash, let countriesLangs):
                return ("passportConfig", [("hash", hash), ("countriesLangs", countriesLangs)])
    }
    }
    
        public static func parse_passportConfigNotModified(_ reader: BufferReader) -> PassportConfig? {
            return Api.help.PassportConfig.passportConfigNotModified
        }
        public static func parse_passportConfig(_ reader: BufferReader) -> PassportConfig? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.PassportConfig.passportConfig(hash: _1!, countriesLangs: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum DeepLinkInfo: TypeConstructorDescription {
        case deepLinkInfoEmpty
        case deepLinkInfo(flags: Int32, message: String, entities: [Api.MessageEntity]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .deepLinkInfoEmpty:
                    if boxed {
                        buffer.appendInt32(1722786150)
                    }
                    
                    break
                case .deepLinkInfo(let flags, let message, let entities):
                    if boxed {
                        buffer.appendInt32(1783556146)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .deepLinkInfoEmpty:
                return ("deepLinkInfoEmpty", [])
                case .deepLinkInfo(let flags, let message, let entities):
                return ("deepLinkInfo", [("flags", flags), ("message", message), ("entities", entities)])
    }
    }
    
        public static func parse_deepLinkInfoEmpty(_ reader: BufferReader) -> DeepLinkInfo? {
            return Api.help.DeepLinkInfo.deepLinkInfoEmpty
        }
        public static func parse_deepLinkInfo(_ reader: BufferReader) -> DeepLinkInfo? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.help.DeepLinkInfo.deepLinkInfo(flags: _1!, message: _2!, entities: _3)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TermsOfService: TypeConstructorDescription {
        case termsOfService(flags: Int32, id: Api.DataJSON, text: String, entities: [Api.MessageEntity], minAgeConfirm: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .termsOfService(let flags, let id, let text, let entities, let minAgeConfirm):
                    if boxed {
                        buffer.appendInt32(2013922064)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    id.serialize(buffer, true)
                    serializeString(text, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(minAgeConfirm!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .termsOfService(let flags, let id, let text, let entities, let minAgeConfirm):
                return ("termsOfService", [("flags", flags), ("id", id), ("text", text), ("entities", entities), ("minAgeConfirm", minAgeConfirm)])
    }
    }
    
        public static func parse_termsOfService(_ reader: BufferReader) -> TermsOfService? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.help.TermsOfService.termsOfService(flags: _1!, id: _2!, text: _3!, entities: _4!, minAgeConfirm: _5)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Country: TypeConstructorDescription {
        case country(flags: Int32, iso2: String, defaultName: String, name: String?, countryCodes: [Api.help.CountryCode])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .country(let flags, let iso2, let defaultName, let name, let countryCodes):
                    if boxed {
                        buffer.appendInt32(-1014526429)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(iso2, buffer: buffer, boxed: false)
                    serializeString(defaultName, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(name!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countryCodes.count))
                    for item in countryCodes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .country(let flags, let iso2, let defaultName, let name, let countryCodes):
                return ("country", [("flags", flags), ("iso2", iso2), ("defaultName", defaultName), ("name", name), ("countryCodes", countryCodes)])
    }
    }
    
        public static func parse_country(_ reader: BufferReader) -> Country? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: [Api.help.CountryCode]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.help.CountryCode.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.help.Country.country(flags: _1!, iso2: _2!, defaultName: _3!, name: _4, countryCodes: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PromoData: TypeConstructorDescription {
        case promoDataEmpty(expires: Int32)
        case promoData(flags: Int32, expires: Int32, peer: Api.Peer, chats: [Api.Chat], users: [Api.User], psaType: String?, psaMessage: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .promoDataEmpty(let expires):
                    if boxed {
                        buffer.appendInt32(-1728664459)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
                case .promoData(let flags, let expires, let peer, let chats, let users, let psaType, let psaMessage):
                    if boxed {
                        buffer.appendInt32(-1942390465)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
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
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(psaType!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(psaMessage!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .promoDataEmpty(let expires):
                return ("promoDataEmpty", [("expires", expires)])
                case .promoData(let flags, let expires, let peer, let chats, let users, let psaType, let psaMessage):
                return ("promoData", [("flags", flags), ("expires", expires), ("peer", peer), ("chats", chats), ("users", users), ("psaType", psaType), ("psaMessage", psaMessage)])
    }
    }
    
        public static func parse_promoDataEmpty(_ reader: BufferReader) -> PromoData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.PromoData.promoDataEmpty(expires: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_promoData(_ reader: BufferReader) -> PromoData? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 2) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.help.PromoData.promoData(flags: _1!, expires: _2!, peer: _3!, chats: _4!, users: _5!, psaType: _6, psaMessage: _7)
            }
            else {
                return nil
            }
        }
    
    }
    public enum RecentMeUrls: TypeConstructorDescription {
        case recentMeUrls(urls: [Api.RecentMeUrl], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .recentMeUrls(let urls, let chats, let users):
                    if boxed {
                        buffer.appendInt32(235081943)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(urls.count))
                    for item in urls {
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
                case .recentMeUrls(let urls, let chats, let users):
                return ("recentMeUrls", [("urls", urls), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_recentMeUrls(_ reader: BufferReader) -> RecentMeUrls? {
            var _1: [Api.RecentMeUrl]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RecentMeUrl.self)
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
                return Api.help.RecentMeUrls.recentMeUrls(urls: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum CountryCode: TypeConstructorDescription {
        case countryCode(flags: Int32, countryCode: String, prefixes: [String]?, patterns: [String]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .countryCode(let flags, let countryCode, let prefixes, let patterns):
                    if boxed {
                        buffer.appendInt32(1107543535)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(countryCode, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(prefixes!.count))
                    for item in prefixes! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(patterns!.count))
                    for item in patterns! {
                        serializeString(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .countryCode(let flags, let countryCode, let prefixes, let patterns):
                return ("countryCode", [("flags", flags), ("countryCode", countryCode), ("prefixes", prefixes), ("patterns", patterns)])
    }
    }
    
        public static func parse_countryCode(_ reader: BufferReader) -> CountryCode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: [String]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            var _4: [String]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.help.CountryCode.countryCode(flags: _1!, countryCode: _2!, prefixes: _3, patterns: _4)
            }
            else {
                return nil
            }
        }
    
    }
    public enum Support: TypeConstructorDescription {
        case support(phoneNumber: String, user: Api.User)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .support(let phoneNumber, let user):
                    if boxed {
                        buffer.appendInt32(398898678)
                    }
                    serializeString(phoneNumber, buffer: buffer, boxed: false)
                    user.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .support(let phoneNumber, let user):
                return ("support", [("phoneNumber", phoneNumber), ("user", user)])
    }
    }
    
        public static func parse_support(_ reader: BufferReader) -> Support? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.Support.support(phoneNumber: _1!, user: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum InviteText: TypeConstructorDescription {
        case inviteText(message: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inviteText(let message):
                    if boxed {
                        buffer.appendInt32(415997816)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inviteText(let message):
                return ("inviteText", [("message", message)])
    }
    }
    
        public static func parse_inviteText(_ reader: BufferReader) -> InviteText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.InviteText.inviteText(message: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum UserInfo: TypeConstructorDescription {
        case userInfoEmpty
        case userInfo(message: String, entities: [Api.MessageEntity], author: String, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userInfoEmpty:
                    if boxed {
                        buffer.appendInt32(-206688531)
                    }
                    
                    break
                case .userInfo(let message, let entities, let author, let date):
                    if boxed {
                        buffer.appendInt32(32192344)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    serializeString(author, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userInfoEmpty:
                return ("userInfoEmpty", [])
                case .userInfo(let message, let entities, let author, let date):
                return ("userInfo", [("message", message), ("entities", entities), ("author", author), ("date", date)])
    }
    }
    
        public static func parse_userInfoEmpty(_ reader: BufferReader) -> UserInfo? {
            return Api.help.UserInfo.userInfoEmpty
        }
        public static func parse_userInfo(_ reader: BufferReader) -> UserInfo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.help.UserInfo.userInfo(message: _1!, entities: _2!, author: _3!, date: _4!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum TermsOfServiceUpdate: TypeConstructorDescription {
        case termsOfServiceUpdateEmpty(expires: Int32)
        case termsOfServiceUpdate(expires: Int32, termsOfService: Api.help.TermsOfService)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .termsOfServiceUpdateEmpty(let expires):
                    if boxed {
                        buffer.appendInt32(-483352705)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
                case .termsOfServiceUpdate(let expires, let termsOfService):
                    if boxed {
                        buffer.appendInt32(686618977)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    termsOfService.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .termsOfServiceUpdateEmpty(let expires):
                return ("termsOfServiceUpdateEmpty", [("expires", expires)])
                case .termsOfServiceUpdate(let expires, let termsOfService):
                return ("termsOfServiceUpdate", [("expires", expires), ("termsOfService", termsOfService)])
    }
    }
    
        public static func parse_termsOfServiceUpdateEmpty(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdateEmpty(expires: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_termsOfServiceUpdate(_ reader: BufferReader) -> TermsOfServiceUpdate? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.help.TermsOfService?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.TermsOfServiceUpdate.termsOfServiceUpdate(expires: _1!, termsOfService: _2!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum CountriesList: TypeConstructorDescription {
        case countriesListNotModified
        case countriesList(countries: [Api.help.Country], hash: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .countriesListNotModified:
                    if boxed {
                        buffer.appendInt32(-1815339214)
                    }
                    
                    break
                case .countriesList(let countries, let hash):
                    if boxed {
                        buffer.appendInt32(-2016381538)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(countries.count))
                    for item in countries {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .countriesListNotModified:
                return ("countriesListNotModified", [])
                case .countriesList(let countries, let hash):
                return ("countriesList", [("countries", countries), ("hash", hash)])
    }
    }
    
        public static func parse_countriesListNotModified(_ reader: BufferReader) -> CountriesList? {
            return Api.help.CountriesList.countriesListNotModified
        }
        public static func parse_countriesList(_ reader: BufferReader) -> CountriesList? {
            var _1: [Api.help.Country]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.help.Country.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.help.CountriesList.countriesList(countries: _1!, hash: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
