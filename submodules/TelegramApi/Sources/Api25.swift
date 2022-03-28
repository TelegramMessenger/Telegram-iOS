public extension Api.messages {
    enum SponsoredMessages: TypeConstructorDescription {
        case sponsoredMessages(messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sponsoredMessages(let messages, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1705297877)
                    }
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
                case .sponsoredMessages(let messages, let chats, let users):
                return ("sponsoredMessages", [("messages", String(describing: messages)), ("chats", String(describing: chats)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_sponsoredMessages(_ reader: BufferReader) -> SponsoredMessages? {
            var _1: [Api.SponsoredMessage]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SponsoredMessage.self)
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
                return Api.messages.SponsoredMessages.sponsoredMessages(messages: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum StickerSet: TypeConstructorDescription {
        case stickerSet(set: Api.StickerSet, packs: [Api.StickerPack], documents: [Api.Document])
        case stickerSetNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSet(let set, let packs, let documents):
                    if boxed {
                        buffer.appendInt32(-1240849242)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetNotModified:
                    if boxed {
                        buffer.appendInt32(-738646805)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSet(let set, let packs, let documents):
                return ("stickerSet", [("set", String(describing: set)), ("packs", String(describing: packs)), ("documents", String(describing: documents))])
                case .stickerSetNotModified:
                return ("stickerSetNotModified", [])
    }
    }
    
        public static func parse_stickerSet(_ reader: BufferReader) -> StickerSet? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.Document]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.messages.StickerSet.stickerSet(set: _1!, packs: _2!, documents: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetNotModified(_ reader: BufferReader) -> StickerSet? {
            return Api.messages.StickerSet.stickerSetNotModified
        }
    
    }
}
public extension Api.messages {
    enum StickerSetInstallResult: TypeConstructorDescription {
        case stickerSetInstallResultArchive(sets: [Api.StickerSetCovered])
        case stickerSetInstallResultSuccess
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSetInstallResultArchive(let sets):
                    if boxed {
                        buffer.appendInt32(904138920)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sets.count))
                    for item in sets {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetInstallResultSuccess:
                    if boxed {
                        buffer.appendInt32(946083368)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSetInstallResultArchive(let sets):
                return ("stickerSetInstallResultArchive", [("sets", String(describing: sets))])
                case .stickerSetInstallResultSuccess:
                return ("stickerSetInstallResultSuccess", [])
    }
    }
    
        public static func parse_stickerSetInstallResultArchive(_ reader: BufferReader) -> StickerSetInstallResult? {
            var _1: [Api.StickerSetCovered]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerSetCovered.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.StickerSetInstallResult.stickerSetInstallResultArchive(sets: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetInstallResultSuccess(_ reader: BufferReader) -> StickerSetInstallResult? {
            return Api.messages.StickerSetInstallResult.stickerSetInstallResultSuccess
        }
    
    }
}
public extension Api.messages {
    enum Stickers: TypeConstructorDescription {
        case stickers(hash: Int64, stickers: [Api.Document])
        case stickersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickers(let hash, let stickers):
                    if boxed {
                        buffer.appendInt32(816245886)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(stickers.count))
                    for item in stickers {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickersNotModified:
                    if boxed {
                        buffer.appendInt32(-244016606)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickers(let hash, let stickers):
                return ("stickers", [("hash", String(describing: hash)), ("stickers", String(describing: stickers))])
                case .stickersNotModified:
                return ("stickersNotModified", [])
    }
    }
    
        public static func parse_stickers(_ reader: BufferReader) -> Stickers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.messages.Stickers.stickers(hash: _1!, stickers: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickersNotModified(_ reader: BufferReader) -> Stickers? {
            return Api.messages.Stickers.stickersNotModified
        }
    
    }
}
public extension Api.messages {
    enum TranslatedText: TypeConstructorDescription {
        case translateNoResult
        case translateResultText(text: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .translateNoResult:
                    if boxed {
                        buffer.appendInt32(1741309751)
                    }
                    
                    break
                case .translateResultText(let text):
                    if boxed {
                        buffer.appendInt32(-1575684144)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .translateNoResult:
                return ("translateNoResult", [])
                case .translateResultText(let text):
                return ("translateResultText", [("text", String(describing: text))])
    }
    }
    
        public static func parse_translateNoResult(_ reader: BufferReader) -> TranslatedText? {
            return Api.messages.TranslatedText.translateNoResult
        }
        public static func parse_translateResultText(_ reader: BufferReader) -> TranslatedText? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.messages.TranslatedText.translateResultText(text: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.messages {
    enum VotesList: TypeConstructorDescription {
        case votesList(flags: Int32, count: Int32, votes: [Api.MessageUserVote], users: [Api.User], nextOffset: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .votesList(let flags, let count, let votes, let users, let nextOffset):
                    if boxed {
                        buffer.appendInt32(136574537)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(votes.count))
                    for item in votes {
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
                case .votesList(let flags, let count, let votes, let users, let nextOffset):
                return ("votesList", [("flags", String(describing: flags)), ("count", String(describing: count)), ("votes", String(describing: votes)), ("users", String(describing: users)), ("nextOffset", String(describing: nextOffset))])
    }
    }
    
        public static func parse_votesList(_ reader: BufferReader) -> VotesList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessageUserVote]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageUserVote.self)
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
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.messages.VotesList.votesList(flags: _1!, count: _2!, votes: _3!, users: _4!, nextOffset: _5)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.payments {
    enum BankCardData: TypeConstructorDescription {
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
                return ("bankCardData", [("title", String(describing: title)), ("openUrls", String(describing: openUrls))])
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
public extension Api.payments {
    enum PaymentForm: TypeConstructorDescription {
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
                return ("paymentForm", [("flags", String(describing: flags)), ("formId", String(describing: formId)), ("botId", String(describing: botId)), ("invoice", String(describing: invoice)), ("providerId", String(describing: providerId)), ("url", String(describing: url)), ("nativeProvider", String(describing: nativeProvider)), ("nativeParams", String(describing: nativeParams)), ("savedInfo", String(describing: savedInfo)), ("savedCredentials", String(describing: savedCredentials)), ("users", String(describing: users))])
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
}
public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription {
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
                return ("paymentReceipt", [("flags", String(describing: flags)), ("date", String(describing: date)), ("botId", String(describing: botId)), ("providerId", String(describing: providerId)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("invoice", String(describing: invoice)), ("info", String(describing: info)), ("shipping", String(describing: shipping)), ("tipAmount", String(describing: tipAmount)), ("currency", String(describing: currency)), ("totalAmount", String(describing: totalAmount)), ("credentialsTitle", String(describing: credentialsTitle)), ("users", String(describing: users))])
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
}
public extension Api.payments {
    enum PaymentResult: TypeConstructorDescription {
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
                return ("paymentResult", [("updates", String(describing: updates))])
                case .paymentVerificationNeeded(let url):
                return ("paymentVerificationNeeded", [("url", String(describing: url))])
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
                return ("savedInfo", [("flags", String(describing: flags)), ("savedInfo", String(describing: savedInfo))])
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
                return ("validatedRequestedInfo", [("flags", String(describing: flags)), ("id", String(describing: id)), ("shippingOptions", String(describing: shippingOptions))])
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
                return ("exportedGroupCallInvite", [("link", String(describing: link))])
    }
    }
    
        public static func parse_exportedGroupCallInvite(_ reader: BufferReader) -> ExportedGroupCallInvite? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.ExportedGroupCallInvite.exportedGroupCallInvite(link: _1!)
            }
            else {
                return nil
            }
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
                return ("groupCall", [("call", String(describing: call)), ("participants", String(describing: participants)), ("participantsNextOffset", String(describing: participantsNextOffset)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
                return Api.phone.GroupCall.groupCall(call: _1!, participants: _2!, participantsNextOffset: _3!, chats: _4!, users: _5!)
            }
            else {
                return nil
            }
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
                return ("groupCallStreamChannels", [("channels", String(describing: channels))])
    }
    }
    
        public static func parse_groupCallStreamChannels(_ reader: BufferReader) -> GroupCallStreamChannels? {
            var _1: [Api.GroupCallStreamChannel]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallStreamChannel.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.phone.GroupCallStreamChannels.groupCallStreamChannels(channels: _1!)
            }
            else {
                return nil
            }
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
                return ("groupCallStreamRtmpUrl", [("url", String(describing: url)), ("key", String(describing: key))])
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
                return Api.phone.GroupCallStreamRtmpUrl.groupCallStreamRtmpUrl(url: _1!, key: _2!)
            }
            else {
                return nil
            }
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
                return ("groupParticipants", [("count", String(describing: count)), ("participants", String(describing: participants)), ("nextOffset", String(describing: nextOffset)), ("chats", String(describing: chats)), ("users", String(describing: users)), ("version", String(describing: version))])
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
                return Api.phone.GroupParticipants.groupParticipants(count: _1!, participants: _2!, nextOffset: _3!, chats: _4!, users: _5!, version: _6!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription {
        case joinAsPeers(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .joinAsPeers(let peers, let chats, let users):
                    if boxed {
                        buffer.appendInt32(-1343921601)
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
                case .joinAsPeers(let peers, let chats, let users):
                return ("joinAsPeers", [("peers", String(describing: peers)), ("chats", String(describing: chats)), ("users", String(describing: users))])
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
                return Api.phone.JoinAsPeers.joinAsPeers(peers: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription {
        case phoneCall(phoneCall: Api.PhoneCall, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .phoneCall(let phoneCall, let users):
                    if boxed {
                        buffer.appendInt32(-326966976)
                    }
                    phoneCall.serialize(buffer, true)
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
                case .phoneCall(let phoneCall, let users):
                return ("phoneCall", [("phoneCall", String(describing: phoneCall)), ("users", String(describing: users))])
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
                return Api.phone.PhoneCall.phoneCall(phoneCall: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription {
        case photo(photo: Api.Photo, users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photo(let photo, let users):
                    if boxed {
                        buffer.appendInt32(539045032)
                    }
                    photo.serialize(buffer, true)
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
                case .photo(let photo, let users):
                return ("photo", [("photo", String(describing: photo)), ("users", String(describing: users))])
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
                return Api.photos.Photo.photo(photo: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription {
        case photos(photos: [Api.Photo], users: [Api.User])
        case photosSlice(count: Int32, photos: [Api.Photo], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .photos(let photos, let users):
                    if boxed {
                        buffer.appendInt32(-1916114267)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    break
                case .photosSlice(let count, let photos, let users):
                    if boxed {
                        buffer.appendInt32(352657236)
                    }
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(photos.count))
                    for item in photos {
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
                case .photos(let photos, let users):
                return ("photos", [("photos", String(describing: photos)), ("users", String(describing: users))])
                case .photosSlice(let count, let photos, let users):
                return ("photosSlice", [("count", String(describing: count)), ("photos", String(describing: photos)), ("users", String(describing: users))])
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
                return Api.photos.Photos.photos(photos: _1!, users: _2!)
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
                return Api.photos.Photos.photosSlice(count: _1!, photos: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription {
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
                return ("broadcastStats", [("period", String(describing: period)), ("followers", String(describing: followers)), ("viewsPerPost", String(describing: viewsPerPost)), ("sharesPerPost", String(describing: sharesPerPost)), ("enabledNotifications", String(describing: enabledNotifications)), ("growthGraph", String(describing: growthGraph)), ("followersGraph", String(describing: followersGraph)), ("muteGraph", String(describing: muteGraph)), ("topHoursGraph", String(describing: topHoursGraph)), ("interactionsGraph", String(describing: interactionsGraph)), ("ivInteractionsGraph", String(describing: ivInteractionsGraph)), ("viewsBySourceGraph", String(describing: viewsBySourceGraph)), ("newFollowersBySourceGraph", String(describing: newFollowersBySourceGraph)), ("languagesGraph", String(describing: languagesGraph)), ("recentMessageInteractions", String(describing: recentMessageInteractions))])
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
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription {
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
                return ("megagroupStats", [("period", String(describing: period)), ("members", String(describing: members)), ("messages", String(describing: messages)), ("viewers", String(describing: viewers)), ("posters", String(describing: posters)), ("growthGraph", String(describing: growthGraph)), ("membersGraph", String(describing: membersGraph)), ("newMembersBySourceGraph", String(describing: newMembersBySourceGraph)), ("languagesGraph", String(describing: languagesGraph)), ("messagesGraph", String(describing: messagesGraph)), ("actionsGraph", String(describing: actionsGraph)), ("topHoursGraph", String(describing: topHoursGraph)), ("weekdaysGraph", String(describing: weekdaysGraph)), ("topPosters", String(describing: topPosters)), ("topAdmins", String(describing: topAdmins)), ("topInviters", String(describing: topInviters)), ("users", String(describing: users))])
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
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription {
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
                return ("messageStats", [("viewsGraph", String(describing: viewsGraph))])
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
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription {
        case suggestedShortName(shortName: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedShortName(let shortName):
                    if boxed {
                        buffer.appendInt32(-2046910401)
                    }
                    serializeString(shortName, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedShortName(let shortName):
                return ("suggestedShortName", [("shortName", String(describing: shortName))])
    }
    }
    
        public static func parse_suggestedShortName(_ reader: BufferReader) -> SuggestedShortName? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.stickers.SuggestedShortName.suggestedShortName(shortName: _1!)
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
