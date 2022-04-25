public extension Api {
    enum KeyboardButton: TypeConstructorDescription {
        case inputKeyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, bot: Api.InputUser)
        case inputKeyboardButtonUserProfile(text: String, userId: Api.InputUser)
        case keyboardButton(text: String)
        case keyboardButtonBuy(text: String)
        case keyboardButtonCallback(flags: Int32, text: String, data: Buffer)
        case keyboardButtonGame(text: String)
        case keyboardButtonRequestGeoLocation(text: String)
        case keyboardButtonRequestPhone(text: String)
        case keyboardButtonRequestPoll(flags: Int32, quiz: Api.Bool?, text: String)
        case keyboardButtonSimpleWebView(text: String, url: String)
        case keyboardButtonSwitchInline(flags: Int32, text: String, query: String)
        case keyboardButtonUrl(text: String, url: String)
        case keyboardButtonUrlAuth(flags: Int32, text: String, fwdText: String?, url: String, buttonId: Int32)
        case keyboardButtonUserProfile(text: String, userId: Int64)
        case keyboardButtonWebView(text: String, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .keyboardButtonSwitchInline(let flags, let text, let query):
                    if boxed {
                        buffer.appendInt32(90744648)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
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
                case .inputKeyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let bot):
                return ("inputKeyboardButtonUrlAuth", [("flags", String(describing: flags)), ("text", String(describing: text)), ("fwdText", String(describing: fwdText)), ("url", String(describing: url)), ("bot", String(describing: bot))])
                case .inputKeyboardButtonUserProfile(let text, let userId):
                return ("inputKeyboardButtonUserProfile", [("text", String(describing: text)), ("userId", String(describing: userId))])
                case .keyboardButton(let text):
                return ("keyboardButton", [("text", String(describing: text))])
                case .keyboardButtonBuy(let text):
                return ("keyboardButtonBuy", [("text", String(describing: text))])
                case .keyboardButtonCallback(let flags, let text, let data):
                return ("keyboardButtonCallback", [("flags", String(describing: flags)), ("text", String(describing: text)), ("data", String(describing: data))])
                case .keyboardButtonGame(let text):
                return ("keyboardButtonGame", [("text", String(describing: text))])
                case .keyboardButtonRequestGeoLocation(let text):
                return ("keyboardButtonRequestGeoLocation", [("text", String(describing: text))])
                case .keyboardButtonRequestPhone(let text):
                return ("keyboardButtonRequestPhone", [("text", String(describing: text))])
                case .keyboardButtonRequestPoll(let flags, let quiz, let text):
                return ("keyboardButtonRequestPoll", [("flags", String(describing: flags)), ("quiz", String(describing: quiz)), ("text", String(describing: text))])
                case .keyboardButtonSimpleWebView(let text, let url):
                return ("keyboardButtonSimpleWebView", [("text", String(describing: text)), ("url", String(describing: url))])
                case .keyboardButtonSwitchInline(let flags, let text, let query):
                return ("keyboardButtonSwitchInline", [("flags", String(describing: flags)), ("text", String(describing: text)), ("query", String(describing: query))])
                case .keyboardButtonUrl(let text, let url):
                return ("keyboardButtonUrl", [("text", String(describing: text)), ("url", String(describing: url))])
                case .keyboardButtonUrlAuth(let flags, let text, let fwdText, let url, let buttonId):
                return ("keyboardButtonUrlAuth", [("flags", String(describing: flags)), ("text", String(describing: text)), ("fwdText", String(describing: fwdText)), ("url", String(describing: url)), ("buttonId", String(describing: buttonId))])
                case .keyboardButtonUserProfile(let text, let userId):
                return ("keyboardButtonUserProfile", [("text", String(describing: text)), ("userId", String(describing: userId))])
                case .keyboardButtonWebView(let text, let url):
                return ("keyboardButtonWebView", [("text", String(describing: text)), ("url", String(describing: url))])
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.KeyboardButton.keyboardButtonSwitchInline(flags: _1!, text: _2!, query: _3!)
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
                return ("keyboardButtonRow", [("buttons", String(describing: buttons))])
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
                return ("labeledPrice", [("label", String(describing: label)), ("amount", String(describing: amount))])
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
                return ("langPackDifference", [("langCode", String(describing: langCode)), ("fromVersion", String(describing: fromVersion)), ("version", String(describing: version)), ("strings", String(describing: strings))])
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
                return ("langPackLanguage", [("flags", String(describing: flags)), ("name", String(describing: name)), ("nativeName", String(describing: nativeName)), ("langCode", String(describing: langCode)), ("baseLangCode", String(describing: baseLangCode)), ("pluralCode", String(describing: pluralCode)), ("stringsCount", String(describing: stringsCount)), ("translatedCount", String(describing: translatedCount)), ("translationsUrl", String(describing: translationsUrl))])
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
                return ("langPackString", [("key", String(describing: key)), ("value", String(describing: value))])
                case .langPackStringDeleted(let key):
                return ("langPackStringDeleted", [("key", String(describing: key))])
                case .langPackStringPluralized(let flags, let key, let zeroValue, let oneValue, let twoValue, let fewValue, let manyValue, let otherValue):
                return ("langPackStringPluralized", [("flags", String(describing: flags)), ("key", String(describing: key)), ("zeroValue", String(describing: zeroValue)), ("oneValue", String(describing: oneValue)), ("twoValue", String(describing: twoValue)), ("fewValue", String(describing: fewValue)), ("manyValue", String(describing: manyValue)), ("otherValue", String(describing: otherValue))])
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
                return ("maskCoords", [("n", String(describing: n)), ("x", String(describing: x)), ("y", String(describing: y)), ("zoom", String(describing: zoom))])
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
    enum Message: TypeConstructorDescription {
        case message(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?)
        case messageEmpty(flags: Int32, id: Int32, peerId: Api.Peer?)
        case messageService(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, ttlPeriod: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .message(let flags, let id, let fromId, let peerId, let fwdFrom, let viaBotId, let replyTo, let date, let message, let media, let replyMarkup, let entities, let views, let forwards, let replies, let editDate, let postAuthor, let groupedId, let reactions, let restrictionReason, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(940666592)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {fromId!.serialize(buffer, true)}
                    peerId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt64(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(views!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(forwards!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 23) != 0 {replies!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(editDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt64(groupedId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 20) != 0 {reactions!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 22) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .messageEmpty(let flags, let id, let peerId):
                    if boxed {
                        buffer.appendInt32(-1868117372)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peerId!.serialize(buffer, true)}
                    break
                case .messageService(let flags, let id, let fromId, let peerId, let replyTo, let date, let action, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(721967202)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {fromId!.serialize(buffer, true)}
                    peerId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .message(let flags, let id, let fromId, let peerId, let fwdFrom, let viaBotId, let replyTo, let date, let message, let media, let replyMarkup, let entities, let views, let forwards, let replies, let editDate, let postAuthor, let groupedId, let reactions, let restrictionReason, let ttlPeriod):
                return ("message", [("flags", String(describing: flags)), ("id", String(describing: id)), ("fromId", String(describing: fromId)), ("peerId", String(describing: peerId)), ("fwdFrom", String(describing: fwdFrom)), ("viaBotId", String(describing: viaBotId)), ("replyTo", String(describing: replyTo)), ("date", String(describing: date)), ("message", String(describing: message)), ("media", String(describing: media)), ("replyMarkup", String(describing: replyMarkup)), ("entities", String(describing: entities)), ("views", String(describing: views)), ("forwards", String(describing: forwards)), ("replies", String(describing: replies)), ("editDate", String(describing: editDate)), ("postAuthor", String(describing: postAuthor)), ("groupedId", String(describing: groupedId)), ("reactions", String(describing: reactions)), ("restrictionReason", String(describing: restrictionReason)), ("ttlPeriod", String(describing: ttlPeriod))])
                case .messageEmpty(let flags, let id, let peerId):
                return ("messageEmpty", [("flags", String(describing: flags)), ("id", String(describing: id)), ("peerId", String(describing: peerId))])
                case .messageService(let flags, let id, let fromId, let peerId, let replyTo, let date, let action, let ttlPeriod):
                return ("messageService", [("flags", String(describing: flags)), ("id", String(describing: id)), ("fromId", String(describing: fromId)), ("peerId", String(describing: peerId)), ("replyTo", String(describing: replyTo)), ("date", String(describing: date)), ("action", String(describing: action)), ("ttlPeriod", String(describing: ttlPeriod))])
    }
    }
    
        public static func parse_message(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _6: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {_6 = reader.readInt64() }
            var _7: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            var _10: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _11: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_14 = reader.readInt32() }
            var _15: Api.MessageReplies?
            if Int(_1!) & Int(1 << 23) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.MessageReplies
            } }
            var _16: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_16 = reader.readInt32() }
            var _17: String?
            if Int(_1!) & Int(1 << 16) != 0 {_17 = parseString(reader) }
            var _18: Int64?
            if Int(_1!) & Int(1 << 17) != 0 {_18 = reader.readInt64() }
            var _19: Api.MessageReactions?
            if Int(_1!) & Int(1 << 20) != 0 {if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.MessageReactions
            } }
            var _20: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 22) != 0 {if let _ = reader.readInt32() {
                _20 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _21: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_21 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 11) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 9) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 10) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 10) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 23) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 15) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 16) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 17) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 20) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 22) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 25) == 0) || _21 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 {
                return Api.Message.message(flags: _1!, id: _2!, fromId: _3, peerId: _4!, fwdFrom: _5, viaBotId: _6, replyTo: _7, date: _8!, message: _9!, media: _10, replyMarkup: _11, entities: _12, views: _13, forwards: _14, replies: _15, editDate: _16, postAuthor: _17, groupedId: _18, reactions: _19, restrictionReason: _20, ttlPeriod: _21)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Message.messageEmpty(flags: _1!, id: _2!, peerId: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageService(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.MessageAction?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.MessageAction
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 25) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Message.messageService(flags: _1!, id: _2!, fromId: _3, peerId: _4!, replyTo: _5, date: _6!, action: _7!, ttlPeriod: _8)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageAction: TypeConstructorDescription {
        case messageActionBotAllowed(domain: String)
        case messageActionChannelCreate(title: String)
        case messageActionChannelMigrateFrom(title: String, chatId: Int64)
        case messageActionChatAddUser(users: [Int64])
        case messageActionChatCreate(title: String, users: [Int64])
        case messageActionChatDeletePhoto
        case messageActionChatDeleteUser(userId: Int64)
        case messageActionChatEditPhoto(photo: Api.Photo)
        case messageActionChatEditTitle(title: String)
        case messageActionChatJoinedByLink(inviterId: Int64)
        case messageActionChatJoinedByRequest
        case messageActionChatMigrateTo(channelId: Int64)
        case messageActionContactSignUp
        case messageActionCustomAction(message: String)
        case messageActionEmpty
        case messageActionGameScore(gameId: Int64, score: Int32)
        case messageActionGeoProximityReached(fromId: Api.Peer, toId: Api.Peer, distance: Int32)
        case messageActionGroupCall(flags: Int32, call: Api.InputGroupCall, duration: Int32?)
        case messageActionGroupCallScheduled(call: Api.InputGroupCall, scheduleDate: Int32)
        case messageActionHistoryClear
        case messageActionInviteToGroupCall(call: Api.InputGroupCall, users: [Int64])
        case messageActionPaymentSent(currency: String, totalAmount: Int64)
        case messageActionPaymentSentMe(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge)
        case messageActionPhoneCall(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case messageActionPinMessage
        case messageActionScreenshotTaken
        case messageActionSecureValuesSent(types: [Api.SecureValueType])
        case messageActionSecureValuesSentMe(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted)
        case messageActionSetChatTheme(emoticon: String)
        case messageActionSetMessagesTTL(period: Int32)
        case messageActionWebViewDataSent(text: String)
        case messageActionWebViewDataSentMe(text: String, data: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageActionBotAllowed(let domain):
                    if boxed {
                        buffer.appendInt32(-1410748418)
                    }
                    serializeString(domain, buffer: buffer, boxed: false)
                    break
                case .messageActionChannelCreate(let title):
                    if boxed {
                        buffer.appendInt32(-1781355374)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChannelMigrateFrom(let title, let chatId):
                    if boxed {
                        buffer.appendInt32(-365344535)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatAddUser(let users):
                    if boxed {
                        buffer.appendInt32(365886720)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatCreate(let title, let users):
                    if boxed {
                        buffer.appendInt32(-1119368275)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatDeletePhoto:
                    if boxed {
                        buffer.appendInt32(-1780220945)
                    }
                    
                    break
                case .messageActionChatDeleteUser(let userId):
                    if boxed {
                        buffer.appendInt32(-1539362612)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatEditPhoto(let photo):
                    if boxed {
                        buffer.appendInt32(2144015272)
                    }
                    photo.serialize(buffer, true)
                    break
                case .messageActionChatEditTitle(let title):
                    if boxed {
                        buffer.appendInt32(-1247687078)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChatJoinedByLink(let inviterId):
                    if boxed {
                        buffer.appendInt32(51520707)
                    }
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatJoinedByRequest:
                    if boxed {
                        buffer.appendInt32(-339958837)
                    }
                    
                    break
                case .messageActionChatMigrateTo(let channelId):
                    if boxed {
                        buffer.appendInt32(-519864430)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .messageActionContactSignUp:
                    if boxed {
                        buffer.appendInt32(-202219658)
                    }
                    
                    break
                case .messageActionCustomAction(let message):
                    if boxed {
                        buffer.appendInt32(-85549226)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    break
                case .messageActionEmpty:
                    if boxed {
                        buffer.appendInt32(-1230047312)
                    }
                    
                    break
                case .messageActionGameScore(let gameId, let score):
                    if boxed {
                        buffer.appendInt32(-1834538890)
                    }
                    serializeInt64(gameId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
                case .messageActionGeoProximityReached(let fromId, let toId, let distance):
                    if boxed {
                        buffer.appendInt32(-1730095465)
                    }
                    fromId.serialize(buffer, true)
                    toId.serialize(buffer, true)
                    serializeInt32(distance, buffer: buffer, boxed: false)
                    break
                case .messageActionGroupCall(let flags, let call, let duration):
                    if boxed {
                        buffer.appendInt32(2047704898)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
                case .messageActionGroupCallScheduled(let call, let scheduleDate):
                    if boxed {
                        buffer.appendInt32(-1281329567)
                    }
                    call.serialize(buffer, true)
                    serializeInt32(scheduleDate, buffer: buffer, boxed: false)
                    break
                case .messageActionHistoryClear:
                    if boxed {
                        buffer.appendInt32(-1615153660)
                    }
                    
                    break
                case .messageActionInviteToGroupCall(let call, let users):
                    if boxed {
                        buffer.appendInt32(1345295095)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionPaymentSent(let currency, let totalAmount):
                    if boxed {
                        buffer.appendInt32(1080663248)
                    }
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    break
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                    if boxed {
                        buffer.appendInt32(-1892568281)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    charge.serialize(buffer, true)
                    break
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                    if boxed {
                        buffer.appendInt32(-2132731265)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(callId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reason!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
                case .messageActionPinMessage:
                    if boxed {
                        buffer.appendInt32(-1799538451)
                    }
                    
                    break
                case .messageActionScreenshotTaken:
                    if boxed {
                        buffer.appendInt32(1200788123)
                    }
                    
                    break
                case .messageActionSecureValuesSent(let types):
                    if boxed {
                        buffer.appendInt32(-648257196)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
                case .messageActionSecureValuesSentMe(let values, let credentials):
                    if boxed {
                        buffer.appendInt32(455635795)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    credentials.serialize(buffer, true)
                    break
                case .messageActionSetChatTheme(let emoticon):
                    if boxed {
                        buffer.appendInt32(-1434950843)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .messageActionSetMessagesTTL(let period):
                    if boxed {
                        buffer.appendInt32(-1441072131)
                    }
                    serializeInt32(period, buffer: buffer, boxed: false)
                    break
                case .messageActionWebViewDataSent(let text):
                    if boxed {
                        buffer.appendInt32(-1262252875)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .messageActionWebViewDataSentMe(let text, let data):
                    if boxed {
                        buffer.appendInt32(1205698681)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(data, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageActionBotAllowed(let domain):
                return ("messageActionBotAllowed", [("domain", String(describing: domain))])
                case .messageActionChannelCreate(let title):
                return ("messageActionChannelCreate", [("title", String(describing: title))])
                case .messageActionChannelMigrateFrom(let title, let chatId):
                return ("messageActionChannelMigrateFrom", [("title", String(describing: title)), ("chatId", String(describing: chatId))])
                case .messageActionChatAddUser(let users):
                return ("messageActionChatAddUser", [("users", String(describing: users))])
                case .messageActionChatCreate(let title, let users):
                return ("messageActionChatCreate", [("title", String(describing: title)), ("users", String(describing: users))])
                case .messageActionChatDeletePhoto:
                return ("messageActionChatDeletePhoto", [])
                case .messageActionChatDeleteUser(let userId):
                return ("messageActionChatDeleteUser", [("userId", String(describing: userId))])
                case .messageActionChatEditPhoto(let photo):
                return ("messageActionChatEditPhoto", [("photo", String(describing: photo))])
                case .messageActionChatEditTitle(let title):
                return ("messageActionChatEditTitle", [("title", String(describing: title))])
                case .messageActionChatJoinedByLink(let inviterId):
                return ("messageActionChatJoinedByLink", [("inviterId", String(describing: inviterId))])
                case .messageActionChatJoinedByRequest:
                return ("messageActionChatJoinedByRequest", [])
                case .messageActionChatMigrateTo(let channelId):
                return ("messageActionChatMigrateTo", [("channelId", String(describing: channelId))])
                case .messageActionContactSignUp:
                return ("messageActionContactSignUp", [])
                case .messageActionCustomAction(let message):
                return ("messageActionCustomAction", [("message", String(describing: message))])
                case .messageActionEmpty:
                return ("messageActionEmpty", [])
                case .messageActionGameScore(let gameId, let score):
                return ("messageActionGameScore", [("gameId", String(describing: gameId)), ("score", String(describing: score))])
                case .messageActionGeoProximityReached(let fromId, let toId, let distance):
                return ("messageActionGeoProximityReached", [("fromId", String(describing: fromId)), ("toId", String(describing: toId)), ("distance", String(describing: distance))])
                case .messageActionGroupCall(let flags, let call, let duration):
                return ("messageActionGroupCall", [("flags", String(describing: flags)), ("call", String(describing: call)), ("duration", String(describing: duration))])
                case .messageActionGroupCallScheduled(let call, let scheduleDate):
                return ("messageActionGroupCallScheduled", [("call", String(describing: call)), ("scheduleDate", String(describing: scheduleDate))])
                case .messageActionHistoryClear:
                return ("messageActionHistoryClear", [])
                case .messageActionInviteToGroupCall(let call, let users):
                return ("messageActionInviteToGroupCall", [("call", String(describing: call)), ("users", String(describing: users))])
                case .messageActionPaymentSent(let currency, let totalAmount):
                return ("messageActionPaymentSent", [("currency", String(describing: currency)), ("totalAmount", String(describing: totalAmount))])
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                return ("messageActionPaymentSentMe", [("flags", String(describing: flags)), ("currency", String(describing: currency)), ("totalAmount", String(describing: totalAmount)), ("payload", String(describing: payload)), ("info", String(describing: info)), ("shippingOptionId", String(describing: shippingOptionId)), ("charge", String(describing: charge))])
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                return ("messageActionPhoneCall", [("flags", String(describing: flags)), ("callId", String(describing: callId)), ("reason", String(describing: reason)), ("duration", String(describing: duration))])
                case .messageActionPinMessage:
                return ("messageActionPinMessage", [])
                case .messageActionScreenshotTaken:
                return ("messageActionScreenshotTaken", [])
                case .messageActionSecureValuesSent(let types):
                return ("messageActionSecureValuesSent", [("types", String(describing: types))])
                case .messageActionSecureValuesSentMe(let values, let credentials):
                return ("messageActionSecureValuesSentMe", [("values", String(describing: values)), ("credentials", String(describing: credentials))])
                case .messageActionSetChatTheme(let emoticon):
                return ("messageActionSetChatTheme", [("emoticon", String(describing: emoticon))])
                case .messageActionSetMessagesTTL(let period):
                return ("messageActionSetMessagesTTL", [("period", String(describing: period))])
                case .messageActionWebViewDataSent(let text):
                return ("messageActionWebViewDataSent", [("text", String(describing: text))])
                case .messageActionWebViewDataSentMe(let text, let data):
                return ("messageActionWebViewDataSentMe", [("text", String(describing: text)), ("data", String(describing: data))])
    }
    }
    
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionBotAllowed(domain: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChannelCreate(title: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChannelMigrateFrom(title: _1!, chatId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatAddUser(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChatCreate(title: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatDeletePhoto
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatDeleteUser(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditPhoto(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditPhoto(photo: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditTitle(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditTitle(title: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatJoinedByLink(inviterId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByRequest(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatJoinedByRequest
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatMigrateTo(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionContactSignUp
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionCustomAction(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionEmpty
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGameScore(gameId: _1!, score: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGeoProximityReached(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionGeoProximityReached(fromId: _1!, toId: _2!, distance: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionGroupCall(flags: _1!, call: _2!, duration: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCallScheduled(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGroupCallScheduled(call: _1!, scheduleDate: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionHistoryClear
        }
        public static func parse_messageActionInviteToGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionInviteToGroupCall(call: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionPaymentSent(currency: _1!, totalAmount: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: Api.PaymentCharge?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PaymentCharge
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageAction.messageActionPaymentSentMe(flags: _1!, currency: _2!, totalAmount: _3!, payload: _4!, info: _5, shippingOptionId: _6, charge: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPhoneCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PhoneCallDiscardReason?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PhoneCallDiscardReason
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionPhoneCall(flags: _1!, callId: _2!, reason: _3, duration: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionPinMessage
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionScreenshotTaken
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValueType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSecureValuesSent(types: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSecureValuesSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _2: Api.SecureCredentialsEncrypted?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureCredentialsEncrypted
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionSecureValuesSentMe(values: _1!, credentials: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetChatTheme(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetChatTheme(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetMessagesTTL(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetMessagesTTL(period: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSent(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionWebViewDataSent(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionWebViewDataSentMe(text: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
