public extension Api {
    indirect enum KeyboardButton: TypeConstructorDescription {
        case inputKeyboardButtonRequestPeer(flags: Int32, text: String, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32)
        case inputKeyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, bot: Api.InputUser)
        case inputKeyboardButtonUserProfile(text: String, userId: Api.InputUser)
        case keyboardButton(text: String)
        case keyboardButtonBuy(text: String)
        case keyboardButtonCallback(flags: Int32, text: String, data: Buffer)
        case keyboardButtonCopy(text: String, copyText: String)
        case keyboardButtonGame(text: String)
        case keyboardButtonRequestGeoLocation(text: String)
        case keyboardButtonRequestPeer(text: String, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32)
        case keyboardButtonRequestPhone(text: String)
        case keyboardButtonRequestPoll(flags: Int32, quiz: Api.Bool?, text: String)
        case keyboardButtonSimpleWebView(text: String, url: String)
        case keyboardButtonSwitchInline(flags: Int32, text: String, query: String, peerTypes: [Api.InlineQueryPeerType]?)
        case keyboardButtonUrl(text: String, url: String)
        case keyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, buttonId: Int32)
        case keyboardButtonUserProfile(text: String, userId: Int64)
        case keyboardButtonWebView(text: String, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputKeyboardButtonRequestPeer(let flags, let text, let buttonId, let peerType, let maxQuantity):
                    if boxed {
                        buffer.appendInt32(-916050683)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    peerType.serialize(buffer, true)
                    serializeInt32(maxQuantity, buffer: buffer, boxed: false)
                    break
                case .inputKeyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let bot):
                    if boxed {
                        buffer.appendInt32(-802258988)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(fwdText!, buffer: buffer, boxed: false)}
                    serializeString(url, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    break
                case .inputKeyboardButtonUserProfile(let text, let userId):
                    if boxed {
                        buffer.appendInt32(-376962181)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    userId.serialize(buffer, true)
                    break
                case .keyboardButton(let text):
                    if boxed {
                        buffer.appendInt32(-1560655744)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonBuy(let text):
                    if boxed {
                        buffer.appendInt32(-1344716869)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonCallback(let flags, let text, let data):
                    if boxed {
                        buffer.appendInt32(901503851)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonCopy(let text, let copyText):
                    if boxed {
                        buffer.appendInt32(1976723854)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(copyText, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonGame(let text):
                    if boxed {
                        buffer.appendInt32(1358175439)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestGeoLocation(let text):
                    if boxed {
                        buffer.appendInt32(-59151553)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestPeer(let text, let buttonId, let peerType, let maxQuantity):
                    if boxed {
                        buffer.appendInt32(1406648280)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    peerType.serialize(buffer, true)
                    serializeInt32(maxQuantity, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestPhone(let text):
                    if boxed {
                        buffer.appendInt32(-1318425559)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonRequestPoll(let flags, let quiz, let text):
                    if boxed {
                        buffer.appendInt32(-1144565411)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {quiz!.serialize(buffer, true)}
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonSimpleWebView(let text, let url):
                    if boxed {
                        buffer.appendInt32(-1598009252)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonSwitchInline(let flags, let text, let query, let peerTypes):
                    if boxed {
                        buffer.appendInt32(-1816527947)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peerTypes!.count))
                    for item in peerTypes! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .keyboardButtonUrl(let text, let url):
                    if boxed {
                        buffer.appendInt32(629866245)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let buttonId):
                    if boxed {
                        buffer.appendInt32(280464681)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(fwdText!, buffer: buffer, boxed: false)}
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonUserProfile(let text, let userId):
                    if boxed {
                        buffer.appendInt32(814112961)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .keyboardButtonWebView(let text, let url):
                    if boxed {
                        buffer.appendInt32(326529584)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputKeyboardButtonRequestPeer(let flags, let text, let buttonId, let peerType, let maxQuantity):
                return ("inputKeyboardButtonRequestPeer", [("flags", flags as Any), ("text", text as Any), ("buttonId", buttonId as Any), ("peerType", peerType as Any), ("maxQuantity", maxQuantity as Any)])
                case .inputKeyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let bot):
                return ("inputKeyboardButtonUrlAuth", [("flags", flags as Any), ("text", text as Any), ("fwdText", fwdText as Any), ("url", url as Any), ("bot", bot as Any)])
                case .inputKeyboardButtonUserProfile(let text, let userId):
                return ("inputKeyboardButtonUserProfile", [("text", text as Any), ("userId", userId as Any)])
                case .keyboardButton(let text):
                return ("keyboardButton", [("text", text as Any)])
                case .keyboardButtonBuy(let text):
                return ("keyboardButtonBuy", [("text", text as Any)])
                case .keyboardButtonCallback(let flags, let text, let data):
                return ("keyboardButtonCallback", [("flags", flags as Any), ("text", text as Any), ("data", data as Any)])
                case .keyboardButtonCopy(let text, let copyText):
                return ("keyboardButtonCopy", [("text", text as Any), ("copyText", copyText as Any)])
                case .keyboardButtonGame(let text):
                return ("keyboardButtonGame", [("text", text as Any)])
                case .keyboardButtonRequestGeoLocation(let text):
                return ("keyboardButtonRequestGeoLocation", [("text", text as Any)])
                case .keyboardButtonRequestPeer(let text, let buttonId, let peerType, let maxQuantity):
                return ("keyboardButtonRequestPeer", [("text", text as Any), ("buttonId", buttonId as Any), ("peerType", peerType as Any), ("maxQuantity", maxQuantity as Any)])
                case .keyboardButtonRequestPhone(let text):
                return ("keyboardButtonRequestPhone", [("text", text as Any)])
                case .keyboardButtonRequestPoll(let flags, let quiz, let text):
                return ("keyboardButtonRequestPoll", [("flags", flags as Any), ("quiz", quiz as Any), ("text", text as Any)])
                case .keyboardButtonSimpleWebView(let text, let url):
                return ("keyboardButtonSimpleWebView", [("text", text as Any), ("url", url as Any)])
                case .keyboardButtonSwitchInline(let flags, let text, let query, let peerTypes):
                return ("keyboardButtonSwitchInline", [("flags", flags as Any), ("text", text as Any), ("query", query as Any), ("peerTypes", peerTypes as Any)])
                case .keyboardButtonUrl(let text, let url):
                return ("keyboardButtonUrl", [("text", text as Any), ("url", url as Any)])
                case .keyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let buttonId):
                return ("keyboardButtonUrlAuth", [("flags", flags as Any), ("text", text as Any), ("fwdText", fwdText as Any), ("url", url as Any), ("buttonId", buttonId as Any)])
                case .keyboardButtonUserProfile(let text, let userId):
                return ("keyboardButtonUserProfile", [("text", text as Any), ("userId", userId as Any)])
                case .keyboardButtonWebView(let text, let url):
                return ("keyboardButtonWebView", [("text", text as Any), ("url", url as Any)])
    }
    }
    
        public static func parse_inputKeyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.RequestPeerType?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.RequestPeerType
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.inputKeyboardButtonRequestPeer(flags: _1!, text: _2!, buttonId: _3!, peerType: _4!, maxQuantity: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputKeyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.InputUser?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.inputKeyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, bot: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputKeyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.InputUser?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputUser
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.inputKeyboardButtonUserProfile(text: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButton(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButton(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonBuy(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonBuy(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonCallback(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonCallback(flags: _1!, text: _2!, data: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonCopy(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonCopy(text: _1!, copyText: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonGame(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonGame(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestGeoLocation(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestGeoLocation(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPeer(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.RequestPeerType?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.RequestPeerType
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardButton.keyboardButtonRequestPeer(text: _1!, buttonId: _2!, peerType: _3!, maxQuantity: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPhone(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButton.keyboardButtonRequestPhone(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonRequestPoll(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Bool?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonRequestPoll(flags: _1!, quiz: _2, text: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonSimpleWebView(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonSimpleWebView(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonSwitchInline(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.InlineQueryPeerType]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.InlineQueryPeerType.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.KeyboardButton.keyboardButtonSwitchInline(flags: _1!, text: _2!, query: _3!, peerTypes: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrl(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonUrl(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUrlAuth(_ reader: BufferReader) -> KeyboardButton? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.KeyboardButton.keyboardButtonUrlAuth(flags: _1!, text: _2!, fwdText: _3, url: _4!, buttonId: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonUserProfile(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonUserProfile(text: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_keyboardButtonWebView(_ reader: BufferReader) -> KeyboardButton? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.KeyboardButton.keyboardButtonWebView(text: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum KeyboardButtonRow: TypeConstructorDescription {
        case keyboardButtonRow(buttons: [Api.KeyboardButton])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .keyboardButtonRow(let buttons):
                    if boxed {
                        buffer.appendInt32(2002815875)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(buttons.count))
                    for item in buttons {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .keyboardButtonRow(let buttons):
                return ("keyboardButtonRow", [("buttons", buttons as Any)])
    }
    }
    
        public static func parse_keyboardButtonRow(_ reader: BufferReader) -> KeyboardButtonRow? {
            var _1: [Api.KeyboardButton]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.KeyboardButton.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.KeyboardButtonRow.keyboardButtonRow(buttons: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum LabeledPrice: TypeConstructorDescription {
        case labeledPrice(label: String, amount: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .labeledPrice(let label, let amount):
                    if boxed {
                        buffer.appendInt32(-886477832)
                    }
                    serializeString(label, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .labeledPrice(let label, let amount):
                return ("labeledPrice", [("label", label as Any), ("amount", amount as Any)])
    }
    }
    
        public static func parse_labeledPrice(_ reader: BufferReader) -> LabeledPrice? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LabeledPrice.labeledPrice(label: _1!, amount: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum LangPackDifference: TypeConstructorDescription {
        case langPackDifference(langCode: String, fromVersion: Int32, version: Int32, strings: [Api.LangPackString])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackDifference(let langCode, let fromVersion, let version, let strings):
                    if boxed {
                        buffer.appendInt32(-209337866)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    serializeInt32(fromVersion, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(strings.count))
                    for item in strings {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackDifference(let langCode, let fromVersion, let version, let strings):
                return ("langPackDifference", [("langCode", langCode as Any), ("fromVersion", fromVersion as Any), ("version", version as Any), ("strings", strings as Any)])
    }
    }
    
        public static func parse_langPackDifference(_ reader: BufferReader) -> LangPackDifference? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.LangPackString]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.LangPackString.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.LangPackDifference.langPackDifference(langCode: _1!, fromVersion: _2!, version: _3!, strings: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum LangPackLanguage: TypeConstructorDescription {
        case langPackLanguage(flags: Int32, name: String, nativeName: String, langCode: String, baseLangCode: String?, pluralCode: String, stringsCount: Int32, translatedCount: Int32, translationsUrl: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackLanguage(let flags, let name, let nativeName, let langCode, let baseLangCode, let pluralCode, let stringsCount, let translatedCount, let translationsUrl):
                    if boxed {
                        buffer.appendInt32(-288727837)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeString(nativeName, buffer: buffer, boxed: false)
                    serializeString(langCode, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(baseLangCode!, buffer: buffer, boxed: false)}
                    serializeString(pluralCode, buffer: buffer, boxed: false)
                    serializeInt32(stringsCount, buffer: buffer, boxed: false)
                    serializeInt32(translatedCount, buffer: buffer, boxed: false)
                    serializeString(translationsUrl, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackLanguage(let flags, let name, let nativeName, let langCode, let baseLangCode, let pluralCode, let stringsCount, let translatedCount, let translationsUrl):
                return ("langPackLanguage", [("flags", flags as Any), ("name", name as Any), ("nativeName", nativeName as Any), ("langCode", langCode as Any), ("baseLangCode", baseLangCode as Any), ("pluralCode", pluralCode as Any), ("stringsCount", stringsCount as Any), ("translatedCount", translatedCount as Any), ("translationsUrl", translationsUrl as Any)])
    }
    }
    
        public static func parse_langPackLanguage(_ reader: BufferReader) -> LangPackLanguage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: String?
            _6 = parseString(reader)
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.LangPackLanguage.langPackLanguage(flags: _1!, name: _2!, nativeName: _3!, langCode: _4!, baseLangCode: _5, pluralCode: _6!, stringsCount: _7!, translatedCount: _8!, translationsUrl: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum LangPackString: TypeConstructorDescription {
        case langPackString(key: String, value: String)
        case langPackStringDeleted(key: String)
        case langPackStringPluralized(flags: Int32, key: String, zeroValue: String?, oneValue: String?, twoValue: String?, fewValue: String?, manyValue: String?, otherValue: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .langPackString(let key, let value):
                    if boxed {
                        buffer.appendInt32(-892239370)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    serializeString(value, buffer: buffer, boxed: false)
                    break
                case .langPackStringDeleted(let key):
                    if boxed {
                        buffer.appendInt32(695856818)
                    }
                    serializeString(key, buffer: buffer, boxed: false)
                    break
                case .langPackStringPluralized(let flags, let key, let zeroValue, let oneValue, let twoValue, let fewValue, let manyValue, let otherValue):
                    if boxed {
                        buffer.appendInt32(1816636575)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(key, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(zeroValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(oneValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(twoValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(fewValue!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(manyValue!, buffer: buffer, boxed: false)}
                    serializeString(otherValue, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .langPackString(let key, let value):
                return ("langPackString", [("key", key as Any), ("value", value as Any)])
                case .langPackStringDeleted(let key):
                return ("langPackStringDeleted", [("key", key as Any)])
                case .langPackStringPluralized(let flags, let key, let zeroValue, let oneValue, let twoValue, let fewValue, let manyValue, let otherValue):
                return ("langPackStringPluralized", [("flags", flags as Any), ("key", key as Any), ("zeroValue", zeroValue as Any), ("oneValue", oneValue as Any), ("twoValue", twoValue as Any), ("fewValue", fewValue as Any), ("manyValue", manyValue as Any), ("otherValue", otherValue as Any)])
    }
    }
    
        public static func parse_langPackString(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.LangPackString.langPackString(key: _1!, value: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringDeleted(_ reader: BufferReader) -> LangPackString? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.LangPackString.langPackStringDeleted(key: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_langPackStringPluralized(_ reader: BufferReader) -> LangPackString? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseString(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 2) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = parseString(reader) }
            var _8: String?
            _8 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.LangPackString.langPackStringPluralized(flags: _1!, key: _2!, zeroValue: _3, oneValue: _4, twoValue: _5, fewValue: _6, manyValue: _7, otherValue: _8!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MaskCoords: TypeConstructorDescription {
        case maskCoords(n: Int32, x: Double, y: Double, zoom: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .maskCoords(let n, let x, let y, let zoom):
                    if boxed {
                        buffer.appendInt32(-1361650766)
                    }
                    serializeInt32(n, buffer: buffer, boxed: false)
                    serializeDouble(x, buffer: buffer, boxed: false)
                    serializeDouble(y, buffer: buffer, boxed: false)
                    serializeDouble(zoom, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .maskCoords(let n, let x, let y, let zoom):
                return ("maskCoords", [("n", n as Any), ("x", x as Any), ("y", y as Any), ("zoom", zoom as Any)])
    }
    }
    
        public static func parse_maskCoords(_ reader: BufferReader) -> MaskCoords? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Double?
            _2 = reader.readDouble()
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Double?
            _4 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MaskCoords.maskCoords(n: _1!, x: _2!, y: _3!, zoom: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum MediaArea: TypeConstructorDescription {
        case inputMediaAreaChannelPost(coordinates: Api.MediaAreaCoordinates, channel: Api.InputChannel, msgId: Int32)
        case inputMediaAreaVenue(coordinates: Api.MediaAreaCoordinates, queryId: Int64, resultId: String)
        case mediaAreaChannelPost(coordinates: Api.MediaAreaCoordinates, channelId: Int64, msgId: Int32)
        case mediaAreaGeoPoint(flags: Int32, coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, address: Api.GeoPointAddress?)
        case mediaAreaSuggestedReaction(flags: Int32, coordinates: Api.MediaAreaCoordinates, reaction: Api.Reaction)
        case mediaAreaUrl(coordinates: Api.MediaAreaCoordinates, url: String)
        case mediaAreaVenue(coordinates: Api.MediaAreaCoordinates, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String)
        case mediaAreaWeather(coordinates: Api.MediaAreaCoordinates, emoji: String, temperatureC: Double, color: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .inputMediaAreaChannelPost(let coordinates, let channel, let msgId):
                    if boxed {
                        buffer.appendInt32(577893055)
                    }
                    coordinates.serialize(buffer, true)
                    channel.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .inputMediaAreaVenue(let coordinates, let queryId, let resultId):
                    if boxed {
                        buffer.appendInt32(-1300094593)
                    }
                    coordinates.serialize(buffer, true)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(resultId, buffer: buffer, boxed: false)
                    break
                case .mediaAreaChannelPost(let coordinates, let channelId, let msgId):
                    if boxed {
                        buffer.appendInt32(1996756655)
                    }
                    coordinates.serialize(buffer, true)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .mediaAreaGeoPoint(let flags, let coordinates, let geo, let address):
                    if boxed {
                        buffer.appendInt32(-891992787)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    coordinates.serialize(buffer, true)
                    geo.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {address!.serialize(buffer, true)}
                    break
                case .mediaAreaSuggestedReaction(let flags, let coordinates, let reaction):
                    if boxed {
                        buffer.appendInt32(340088945)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    coordinates.serialize(buffer, true)
                    reaction.serialize(buffer, true)
                    break
                case .mediaAreaUrl(let coordinates, let url):
                    if boxed {
                        buffer.appendInt32(926421125)
                    }
                    coordinates.serialize(buffer, true)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .mediaAreaVenue(let coordinates, let geo, let title, let address, let provider, let venueId, let venueType):
                    if boxed {
                        buffer.appendInt32(-1098720356)
                    }
                    coordinates.serialize(buffer, true)
                    geo.serialize(buffer, true)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(address, buffer: buffer, boxed: false)
                    serializeString(provider, buffer: buffer, boxed: false)
                    serializeString(venueId, buffer: buffer, boxed: false)
                    serializeString(venueType, buffer: buffer, boxed: false)
                    break
                case .mediaAreaWeather(let coordinates, let emoji, let temperatureC, let color):
                    if boxed {
                        buffer.appendInt32(1235637404)
                    }
                    coordinates.serialize(buffer, true)
                    serializeString(emoji, buffer: buffer, boxed: false)
                    serializeDouble(temperatureC, buffer: buffer, boxed: false)
                    serializeInt32(color, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .inputMediaAreaChannelPost(let coordinates, let channel, let msgId):
                return ("inputMediaAreaChannelPost", [("coordinates", coordinates as Any), ("channel", channel as Any), ("msgId", msgId as Any)])
                case .inputMediaAreaVenue(let coordinates, let queryId, let resultId):
                return ("inputMediaAreaVenue", [("coordinates", coordinates as Any), ("queryId", queryId as Any), ("resultId", resultId as Any)])
                case .mediaAreaChannelPost(let coordinates, let channelId, let msgId):
                return ("mediaAreaChannelPost", [("coordinates", coordinates as Any), ("channelId", channelId as Any), ("msgId", msgId as Any)])
                case .mediaAreaGeoPoint(let flags, let coordinates, let geo, let address):
                return ("mediaAreaGeoPoint", [("flags", flags as Any), ("coordinates", coordinates as Any), ("geo", geo as Any), ("address", address as Any)])
                case .mediaAreaSuggestedReaction(let flags, let coordinates, let reaction):
                return ("mediaAreaSuggestedReaction", [("flags", flags as Any), ("coordinates", coordinates as Any), ("reaction", reaction as Any)])
                case .mediaAreaUrl(let coordinates, let url):
                return ("mediaAreaUrl", [("coordinates", coordinates as Any), ("url", url as Any)])
                case .mediaAreaVenue(let coordinates, let geo, let title, let address, let provider, let venueId, let venueType):
                return ("mediaAreaVenue", [("coordinates", coordinates as Any), ("geo", geo as Any), ("title", title as Any), ("address", address as Any), ("provider", provider as Any), ("venueId", venueId as Any), ("venueType", venueType as Any)])
                case .mediaAreaWeather(let coordinates, let emoji, let temperatureC, let color):
                return ("mediaAreaWeather", [("coordinates", coordinates as Any), ("emoji", emoji as Any), ("temperatureC", temperatureC as Any), ("color", color as Any)])
    }
    }
    
        public static func parse_inputMediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.InputChannel?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputChannel
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaChannelPost(coordinates: _1!, channel: _2!, msgId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_inputMediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.inputMediaAreaVenue(coordinates: _1!, queryId: _2!, resultId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaChannelPost(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaChannelPost(coordinates: _1!, channelId: _2!, msgId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaGeoPoint(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
            var _4: Api.GeoPointAddress?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.GeoPointAddress
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaGeoPoint(flags: _1!, coordinates: _2!, geo: _3!, address: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaSuggestedReaction(_ reader: BufferReader) -> MediaArea? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MediaArea.mediaAreaSuggestedReaction(flags: _1!, coordinates: _2!, reaction: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaUrl(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MediaArea.mediaAreaUrl(coordinates: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaVenue(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: Api.GeoPoint?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            }
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MediaArea.mediaAreaVenue(coordinates: _1!, geo: _2!, title: _3!, address: _4!, provider: _5!, venueId: _6!, venueType: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_mediaAreaWeather(_ reader: BufferReader) -> MediaArea? {
            var _1: Api.MediaAreaCoordinates?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.MediaAreaCoordinates
            }
            var _2: String?
            _2 = parseString(reader)
            var _3: Double?
            _3 = reader.readDouble()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MediaArea.mediaAreaWeather(coordinates: _1!, emoji: _2!, temperatureC: _3!, color: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
