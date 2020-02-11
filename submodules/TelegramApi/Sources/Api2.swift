public extension Api {
public struct channels {
    public enum ChannelParticipants: TypeConstructorDescription {
        case channelParticipants(count: Int32, participants: [Api.ChannelParticipant], users: [Api.User])
        case channelParticipantsNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipants(let count, let participants, let users):
                    if boxed {
                        buffer.appendInt32(-177282392)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
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
                case .channelParticipants(let count, let participants, let users):
                return ("channelParticipants", [("count", count), ("participants", participants), ("users", users)])
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
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.channels.ChannelParticipants.channelParticipants(count: _1!, participants: _2!, users: _3!)
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
        case channelParticipant(participant: Api.ChannelParticipant, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelParticipant(let participant, let users):
                    if boxed {
                        buffer.appendInt32(-791039645)
                    }
                    participant.serialize(buffer, true)
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
                case .channelParticipant(let participant, let users):
                return ("channelParticipant", [("participant", participant), ("users", users)])
    }
    }
    
        public static func parse_channelParticipant(_ reader: BufferReader) -> ChannelParticipant? {
            var _1: Api.ChannelParticipant?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.channels.ChannelParticipant.channelParticipant(participant: _1!, users: _2!)
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
        case paymentForm(flags: Int32, botId: Int32, invoice: Api.Invoice, providerId: Int32, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: Api.PaymentSavedCredentials?, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentForm(let flags, let botId, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let savedInfo, let savedCredentials, let users):
                    if boxed {
                        buffer.appendInt32(1062645411)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    serializeInt32(providerId, buffer: buffer, boxed: false)
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
                case .paymentForm(let flags, let botId, let invoice, let providerId, let url, let nativeProvider, let nativeParams, let savedInfo, let savedCredentials, let users):
                return ("paymentForm", [("flags", flags), ("botId", botId), ("invoice", invoice), ("providerId", providerId), ("url", url), ("nativeProvider", nativeProvider), ("nativeParams", nativeParams), ("savedInfo", savedInfo), ("savedCredentials", savedCredentials), ("users", users)])
    }
    }
    
        public static func parse_paymentForm(_ reader: BufferReader) -> PaymentForm? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Invoice?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            _5 = parseString(reader)
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
            var _7: Api.DataJSON?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.DataJSON
            } }
            var _8: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _9: Api.PaymentSavedCredentials?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.PaymentSavedCredentials
            } }
            var _10: [Api.User]?
            if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 1) == 0) || _9 != nil
            let _c10 = _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.payments.PaymentForm.paymentForm(flags: _1!, botId: _2!, invoice: _3!, providerId: _4!, url: _5!, nativeProvider: _6, nativeParams: _7, savedInfo: _8, savedCredentials: _9, users: _10!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum PaymentReceipt: TypeConstructorDescription {
        case paymentReceipt(flags: Int32, date: Int32, botId: Int32, invoice: Api.Invoice, providerId: Int32, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .paymentReceipt(let flags, let date, let botId, let invoice, let providerId, let info, let shipping, let currency, let totalAmount, let credentialsTitle, let users):
                    if boxed {
                        buffer.appendInt32(1342771681)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(botId, buffer: buffer, boxed: false)
                    invoice.serialize(buffer, true)
                    serializeInt32(providerId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {shipping!.serialize(buffer, true)}
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
                case .paymentReceipt(let flags, let date, let botId, let invoice, let providerId, let info, let shipping, let currency, let totalAmount, let credentialsTitle, let users):
                return ("paymentReceipt", [("flags", flags), ("date", date), ("botId", botId), ("invoice", invoice), ("providerId", providerId), ("info", info), ("shipping", shipping), ("currency", currency), ("totalAmount", totalAmount), ("credentialsTitle", credentialsTitle), ("users", users)])
    }
    }
    
        public static func parse_paymentReceipt(_ reader: BufferReader) -> PaymentReceipt? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Invoice?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Invoice
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _7: Api.ShippingOption?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ShippingOption
            } }
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
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = _10 != nil
            let _c11 = _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.payments.PaymentReceipt.paymentReceipt(flags: _1!, date: _2!, botId: _3!, invoice: _4!, providerId: _5!, info: _6, shipping: _7, currency: _8!, totalAmount: _9!, credentialsTitle: _10!, users: _11!)
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
        case authorization(flags: Int32, tmpSessions: Int32?, user: Api.User)
        case authorizationSignUpRequired(flags: Int32, termsOfService: Api.help.TermsOfService?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorization(let flags, let tmpSessions, let user):
                    if boxed {
                        buffer.appendInt32(-855308010)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
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
                case .authorization(let flags, let tmpSessions, let user):
                return ("authorization", [("flags", flags), ("tmpSessions", tmpSessions), ("user", user)])
                case .authorizationSignUpRequired(let flags, let termsOfService):
                return ("authorizationSignUpRequired", [("flags", flags), ("termsOfService", termsOfService)])
    }
    }
    
        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Api.User?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.auth.Authorization.authorization(flags: _1!, tmpSessions: _2, user: _3!)
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
        case exportedAuthorization(id: Int32, bytes: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .exportedAuthorization(let id, let bytes):
                    if boxed {
                        buffer.appendInt32(-543777747)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
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
            var _1: Int32?
            _1 = reader.readInt32()
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
    public enum CheckedPhone: TypeConstructorDescription {
        case checkedPhone(phoneRegistered: Api.Bool)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .checkedPhone(let phoneRegistered):
                    if boxed {
                        buffer.appendInt32(-2128698738)
                    }
                    phoneRegistered.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .checkedPhone(let phoneRegistered):
                return ("checkedPhone", [("phoneRegistered", phoneRegistered)])
    }
    }
    
        public static func parse_checkedPhone(_ reader: BufferReader) -> CheckedPhone? {
            var _1: Api.Bool?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.CheckedPhone.checkedPhone(phoneRegistered: _1!)
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
    
    }
    public enum SentCodeType: TypeConstructorDescription {
        case sentCodeTypeApp(length: Int32)
        case sentCodeTypeSms(length: Int32)
        case sentCodeTypeCall(length: Int32)
        case sentCodeTypeFlashCall(pattern: String)
    
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
    
    }
}
}
public extension Api {
public struct contacts {
    public enum Blocked: TypeConstructorDescription {
        case blocked(blocked: [Api.ContactBlocked], users: [Api.User])
        case blockedSlice(count: Int32, blocked: [Api.ContactBlocked], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .blocked(let blocked, let users):
                    if boxed {
                        buffer.appendInt32(471043349)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocked.count))
                    for item in blocked {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .blockedSlice(let count, let blocked, let users):
                    if boxed {
                        buffer.appendInt32(-1878523231)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocked.count))
                    for item in blocked {
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
                case .blocked(let blocked, let users):
                return ("blocked", [("blocked", blocked), ("users", users)])
                case .blockedSlice(let count, let blocked, let users):
                return ("blockedSlice", [("count", count), ("blocked", blocked), ("users", users)])
    }
    }
    
        public static func parse_blocked(_ reader: BufferReader) -> Blocked? {
            var _1: [Api.ContactBlocked]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ContactBlocked.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.contacts.Blocked.blocked(blocked: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_blockedSlice(_ reader: BufferReader) -> Blocked? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ContactBlocked]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ContactBlocked.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.contacts.Blocked.blockedSlice(count: _1!, blocked: _2!, users: _3!)
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
    public enum AppUpdate: TypeConstructorDescription {
        case noAppUpdate
        case appUpdate(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .noAppUpdate:
                    if boxed {
                        buffer.appendInt32(-1000708810)
                    }
                    
                    break
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url):
                    if boxed {
                        buffer.appendInt32(497489295)
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
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .noAppUpdate:
                return ("noAppUpdate", [])
                case .appUpdate(let flags, let id, let version, let text, let entities, let document, let url):
                return ("appUpdate", [("flags", flags), ("id", id), ("version", version), ("text", text), ("entities", entities), ("document", document), ("url", url)])
    }
    }
    
        public static func parse_noAppUpdate(_ reader: BufferReader) -> AppUpdate? {
            return Api.help.AppUpdate.noAppUpdate
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 2) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.help.AppUpdate.appUpdate(flags: _1!, id: _2!, version: _3!, text: _4!, entities: _5!, document: _6, url: _7)
            }
            else {
                return nil
            }
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
    public enum ProxyData: TypeConstructorDescription {
        case proxyDataEmpty(expires: Int32)
        case proxyDataPromo(expires: Int32, peer: Api.Peer, chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .proxyDataEmpty(let expires):
                    if boxed {
                        buffer.appendInt32(-526508104)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
                case .proxyDataPromo(let expires, let peer, let chats, let users):
                    if boxed {
                        buffer.appendInt32(737668643)
                    }
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
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .proxyDataEmpty(let expires):
                return ("proxyDataEmpty", [("expires", expires)])
                case .proxyDataPromo(let expires, let peer, let chats, let users):
                return ("proxyDataPromo", [("expires", expires), ("peer", peer), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_proxyDataEmpty(_ reader: BufferReader) -> ProxyData? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.help.ProxyData.proxyDataEmpty(expires: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_proxyDataPromo(_ reader: BufferReader) -> ProxyData? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
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
                return Api.help.ProxyData.proxyDataPromo(expires: _1!, peer: _2!, chats: _3!, users: _4!)
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
}
}
public extension Api {
public struct updates {
    public enum Difference: TypeConstructorDescription {
        case differenceEmpty(date: Int32, seq: Int32)
        case difference(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State)
        case differenceSlice(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State)
        case differenceTooLong(pts: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .differenceEmpty(let date, let seq):
                    if boxed {
                        buffer.appendInt32(1567990072)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                    if boxed {
                        buffer.appendInt32(16030880)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                    state.serialize(buffer, true)
                    break
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                    if boxed {
                        buffer.appendInt32(-1459938943)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newEncryptedMessages.count))
                    for item in newEncryptedMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                    intermediateState.serialize(buffer, true)
                    break
                case .differenceTooLong(let pts):
                    if boxed {
                        buffer.appendInt32(1258196845)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .differenceEmpty(let date, let seq):
                return ("differenceEmpty", [("date", date), ("seq", seq)])
                case .difference(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let state):
                return ("difference", [("newMessages", newMessages), ("newEncryptedMessages", newEncryptedMessages), ("otherUpdates", otherUpdates), ("chats", chats), ("users", users), ("state", state)])
                case .differenceSlice(let newMessages, let newEncryptedMessages, let otherUpdates, let chats, let users, let intermediateState):
                return ("differenceSlice", [("newMessages", newMessages), ("newEncryptedMessages", newEncryptedMessages), ("otherUpdates", otherUpdates), ("chats", chats), ("users", users), ("intermediateState", intermediateState)])
                case .differenceTooLong(let pts):
                return ("differenceTooLong", [("pts", pts)])
    }
    }
    
        public static func parse_differenceEmpty(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.updates.Difference.differenceEmpty(date: _1!, seq: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_difference(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.difference(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, state: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceSlice(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.differenceSlice(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, intermediateState: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_differenceTooLong(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.updates.Difference.differenceTooLong(pts: _1!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum State: TypeConstructorDescription {
        case state(pts: Int32, qts: Int32, date: Int32, seq: Int32, unreadCount: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .state(let pts, let qts, let date, let seq, let unreadCount):
                    if boxed {
                        buffer.appendInt32(-1519637954)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    serializeInt32(unreadCount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .state(let pts, let qts, let date, let seq, let unreadCount):
                return ("state", [("pts", pts), ("qts", qts), ("date", date), ("seq", seq), ("unreadCount", unreadCount)])
    }
    }
    
        public static func parse_state(_ reader: BufferReader) -> State? {
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.updates.State.state(pts: _1!, qts: _2!, date: _3!, seq: _4!, unreadCount: _5!)
            }
            else {
                return nil
            }
        }
    
    }
    public enum ChannelDifference: TypeConstructorDescription {
        case channelDifferenceEmpty(flags: Int32, pts: Int32, timeout: Int32?)
        case channelDifference(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User])
        case channelDifferenceTooLong(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                    if boxed {
                        buffer.appendInt32(1041346555)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    break
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                    if boxed {
                        buffer.appendInt32(543450958)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newMessages.count))
                    for item in newMessages {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(otherUpdates.count))
                    for item in otherUpdates {
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
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1531132162)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(timeout!, buffer: buffer, boxed: false)}
                    dialog.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
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
                case .channelDifferenceEmpty(let flags, let pts, let timeout):
                return ("channelDifferenceEmpty", [("flags", flags), ("pts", pts), ("timeout", timeout)])
                case .channelDifference(let flags, let pts, let timeout, let newMessages, let otherUpdates, let chats, let users):
                return ("channelDifference", [("flags", flags), ("pts", pts), ("timeout", timeout), ("newMessages", newMessages), ("otherUpdates", otherUpdates), ("chats", chats), ("users", users)])
                case .channelDifferenceTooLong(let flags, let timeout, let dialog, let messages, let chats, let users):
                return ("channelDifferenceTooLong", [("flags", flags), ("timeout", timeout), ("dialog", dialog), ("messages", messages), ("chats", chats), ("users", users)])
    }
    }
    
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.updates.ChannelDifference.channelDifferenceEmpty(flags: _1!, pts: _2!, timeout: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Update]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
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
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.updates.ChannelDifference.channelDifference(flags: _1!, pts: _2!, timeout: _3, newMessages: _4!, otherUpdates: _5!, chats: _6!, users: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.Dialog?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Dialog
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
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
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.ChannelDifference.channelDifferenceTooLong(flags: _1!, timeout: _2, dialog: _3!, messages: _4!, chats: _5!, users: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
}
