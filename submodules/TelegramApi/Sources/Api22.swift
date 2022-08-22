public extension Api {
    enum WebPageAttribute: TypeConstructorDescription {
        case webPageAttributeTheme(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPageAttributeTheme(let flags, let documents, let settings):
                    if boxed {
                        buffer.appendInt32(1421174295)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents!.count))
                    for item in documents! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {settings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webPageAttributeTheme(let flags, let documents, let settings):
                return ("webPageAttributeTheme", [("flags", String(describing: flags)), ("documents", String(describing: documents)), ("settings", String(describing: settings))])
    }
    }
    
        public static func parse_webPageAttributeTheme(_ reader: BufferReader) -> WebPageAttribute? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            } }
            var _3: Api.ThemeSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.ThemeSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WebPageAttribute.webPageAttributeTheme(flags: _1!, documents: _2, settings: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebViewMessageSent: TypeConstructorDescription {
        case webViewMessageSent(flags: Int32, msgId: Api.InputBotInlineMessageID?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webViewMessageSent(let flags, let msgId):
                    if boxed {
                        buffer.appendInt32(211046684)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {msgId!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webViewMessageSent(let flags, let msgId):
                return ("webViewMessageSent", [("flags", String(describing: flags)), ("msgId", String(describing: msgId))])
    }
    }
    
        public static func parse_webViewMessageSent(_ reader: BufferReader) -> WebViewMessageSent? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebViewMessageSent.webViewMessageSent(flags: _1!, msgId: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebViewResult: TypeConstructorDescription {
        case webViewResultUrl(queryId: Int64, url: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webViewResultUrl(let queryId, let url):
                    if boxed {
                        buffer.appendInt32(202659196)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webViewResultUrl(let queryId, let url):
                return ("webViewResultUrl", [("queryId", String(describing: queryId)), ("url", String(describing: url))])
    }
    }
    
        public static func parse_webViewResultUrl(_ reader: BufferReader) -> WebViewResult? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.WebViewResult.webViewResultUrl(queryId: _1!, url: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum AuthorizationForm: TypeConstructorDescription {
        case authorizationForm(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                    if boxed {
                        buffer.appendInt32(-1389486888)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(requiredTypes.count))
                    for item in requiredTypes {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(errors.count))
                    for item in errors {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(privacyPolicyUrl!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizationForm(let flags, let requiredTypes, let values, let errors, let users, let privacyPolicyUrl):
                return ("authorizationForm", [("flags", String(describing: flags)), ("requiredTypes", String(describing: requiredTypes)), ("values", String(describing: values)), ("errors", String(describing: errors)), ("users", String(describing: users)), ("privacyPolicyUrl", String(describing: privacyPolicyUrl))])
    }
    }
    
        public static func parse_authorizationForm(_ reader: BufferReader) -> AuthorizationForm? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.SecureRequiredType]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureRequiredType.self)
            }
            var _3: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _4: [Api.SecureValueError]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueError.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.AuthorizationForm.authorizationForm(flags: _1!, requiredTypes: _2!, values: _3!, errors: _4!, users: _5!, privacyPolicyUrl: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Authorizations: TypeConstructorDescription {
        case authorizations(authorizationTtlDays: Int32, authorizations: [Api.Authorization])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorizations(let authorizationTtlDays, let authorizations):
                    if boxed {
                        buffer.appendInt32(1275039392)
                    }
                    serializeInt32(authorizationTtlDays, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(authorizations.count))
                    for item in authorizations {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .authorizations(let authorizationTtlDays, let authorizations):
                return ("authorizations", [("authorizationTtlDays", String(describing: authorizationTtlDays)), ("authorizations", String(describing: authorizations))])
    }
    }
    
        public static func parse_authorizations(_ reader: BufferReader) -> Authorizations? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Authorization]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Authorization.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.Authorizations.authorizations(authorizationTtlDays: _1!, authorizations: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum AutoDownloadSettings: TypeConstructorDescription {
        case autoDownloadSettings(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                    if boxed {
                        buffer.appendInt32(1674235686)
                    }
                    low.serialize(buffer, true)
                    medium.serialize(buffer, true)
                    high.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .autoDownloadSettings(let low, let medium, let high):
                return ("autoDownloadSettings", [("low", String(describing: low)), ("medium", String(describing: medium)), ("high", String(describing: high))])
    }
    }
    
        public static func parse_autoDownloadSettings(_ reader: BufferReader) -> AutoDownloadSettings? {
            var _1: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _2: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            var _3: Api.AutoDownloadSettings?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.AutoDownloadSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.AutoDownloadSettings.autoDownloadSettings(low: _1!, medium: _2!, high: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ContentSettings: TypeConstructorDescription {
        case contentSettings(flags: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .contentSettings(let flags):
                    if boxed {
                        buffer.appendInt32(1474462241)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .contentSettings(let flags):
                return ("contentSettings", [("flags", String(describing: flags))])
    }
    }
    
        public static func parse_contentSettings(_ reader: BufferReader) -> ContentSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ContentSettings.contentSettings(flags: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription {
        case password(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom, let pendingResetDate):
                    if boxed {
                        buffer.appendInt32(408623183)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {currentAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(srpB!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(srpId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(emailUnconfirmedPattern!, buffer: buffer, boxed: false)}
                    newAlgo.serialize(buffer, true)
                    newSecureAlgo.serialize(buffer, true)
                    serializeBytes(secureRandom, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(pendingResetDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .password(let flags, let currentAlgo, let srpB, let srpId, let hint, let emailUnconfirmedPattern, let newAlgo, let newSecureAlgo, let secureRandom, let pendingResetDate):
                return ("password", [("flags", String(describing: flags)), ("currentAlgo", String(describing: currentAlgo)), ("srpB", String(describing: srpB)), ("srpId", String(describing: srpId)), ("hint", String(describing: hint)), ("emailUnconfirmedPattern", String(describing: emailUnconfirmedPattern)), ("newAlgo", String(describing: newAlgo)), ("newSecureAlgo", String(describing: newSecureAlgo)), ("secureRandom", String(describing: secureRandom)), ("pendingResetDate", String(describing: pendingResetDate))])
    }
    }
    
        public static func parse_password(_ reader: BufferReader) -> Password? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = parseBytes(reader) }
            var _4: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt64() }
            var _5: String?
            if Int(_1!) & Int(1 << 3) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 4) != 0 {_6 = parseString(reader) }
            var _7: Api.PasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            }
            var _8: Api.SecurePasswordKdfAlgo?
            if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.SecurePasswordKdfAlgo
            }
            var _9: Buffer?
            _9 = parseBytes(reader)
            var _10: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_10 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 2) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 5) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.account.Password.password(flags: _1!, currentAlgo: _2, srpB: _3, srpId: _4, hint: _5, emailUnconfirmedPattern: _6, newAlgo: _7!, newSecureAlgo: _8!, secureRandom: _9!, pendingResetDate: _10)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription {
        case passwordInputSettings(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                    if boxed {
                        buffer.appendInt32(-1036572727)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {newAlgo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(newPasswordHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(hint!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {newSecureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordInputSettings(let flags, let newAlgo, let newPasswordHash, let hint, let email, let newSecureSettings):
                return ("passwordInputSettings", [("flags", String(describing: flags)), ("newAlgo", String(describing: newAlgo)), ("newPasswordHash", String(describing: newPasswordHash)), ("hint", String(describing: hint)), ("email", String(describing: email)), ("newSecureSettings", String(describing: newSecureSettings))])
    }
    }
    
        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
            } }
            var _3: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = parseBytes(reader) }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.PasswordInputSettings.passwordInputSettings(flags: _1!, newAlgo: _2, newPasswordHash: _3, hint: _4, email: _5, newSecureSettings: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription {
        case passwordSettings(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                    if boxed {
                        buffer.appendInt32(-1705233435)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(email!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {secureSettings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .passwordSettings(let flags, let email, let secureSettings):
                return ("passwordSettings", [("flags", String(describing: flags)), ("email", String(describing: email)), ("secureSettings", String(describing: secureSettings))])
    }
    }
    
        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Api.SecureSecretSettings?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.PasswordSettings.passwordSettings(flags: _1!, email: _2, secureSettings: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription {
        case privacyRules(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .privacyRules(let rules, let chats, let users):
                    if boxed {
                        buffer.appendInt32(1352683077)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
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
                case .privacyRules(let rules, let chats, let users):
                return ("privacyRules", [("rules", String(describing: rules)), ("chats", String(describing: chats)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_privacyRules(_ reader: BufferReader) -> PrivacyRules? {
            var _1: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
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
                return Api.account.PrivacyRules.privacyRules(rules: _1!, chats: _2!, users: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription {
        case resetPasswordFailedWait(retryDate: Int32)
        case resetPasswordOk
        case resetPasswordRequestedWait(untilDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .resetPasswordFailedWait(let retryDate):
                    if boxed {
                        buffer.appendInt32(-478701471)
                    }
                    serializeInt32(retryDate, buffer: buffer, boxed: false)
                    break
                case .resetPasswordOk:
                    if boxed {
                        buffer.appendInt32(-383330754)
                    }
                    
                    break
                case .resetPasswordRequestedWait(let untilDate):
                    if boxed {
                        buffer.appendInt32(-370148227)
                    }
                    serializeInt32(untilDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .resetPasswordFailedWait(let retryDate):
                return ("resetPasswordFailedWait", [("retryDate", String(describing: retryDate))])
                case .resetPasswordOk:
                return ("resetPasswordOk", [])
                case .resetPasswordRequestedWait(let untilDate):
                return ("resetPasswordRequestedWait", [("untilDate", String(describing: untilDate))])
    }
    }
    
        public static func parse_resetPasswordFailedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordFailedWait(retryDate: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_resetPasswordOk(_ reader: BufferReader) -> ResetPasswordResult? {
            return Api.account.ResetPasswordResult.resetPasswordOk
        }
        public static func parse_resetPasswordRequestedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordRequestedWait(untilDate: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum SavedRingtone: TypeConstructorDescription {
        case savedRingtone
        case savedRingtoneConverted(document: Api.Document)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedRingtone:
                    if boxed {
                        buffer.appendInt32(-1222230163)
                    }
                    
                    break
                case .savedRingtoneConverted(let document):
                    if boxed {
                        buffer.appendInt32(523271863)
                    }
                    document.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedRingtone:
                return ("savedRingtone", [])
                case .savedRingtoneConverted(let document):
                return ("savedRingtoneConverted", [("document", String(describing: document))])
    }
    }
    
        public static func parse_savedRingtone(_ reader: BufferReader) -> SavedRingtone? {
            return Api.account.SavedRingtone.savedRingtone
        }
        public static func parse_savedRingtoneConverted(_ reader: BufferReader) -> SavedRingtone? {
            var _1: Api.Document?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.SavedRingtone.savedRingtoneConverted(document: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum SavedRingtones: TypeConstructorDescription {
        case savedRingtones(hash: Int64, ringtones: [Api.Document])
        case savedRingtonesNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .savedRingtones(let hash, let ringtones):
                    if boxed {
                        buffer.appendInt32(-1041683259)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(ringtones.count))
                    for item in ringtones {
                        item.serialize(buffer, true)
                    }
                    break
                case .savedRingtonesNotModified:
                    if boxed {
                        buffer.appendInt32(-67704655)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .savedRingtones(let hash, let ringtones):
                return ("savedRingtones", [("hash", String(describing: hash)), ("ringtones", String(describing: ringtones))])
                case .savedRingtonesNotModified:
                return ("savedRingtonesNotModified", [])
    }
    }
    
        public static func parse_savedRingtones(_ reader: BufferReader) -> SavedRingtones? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.SavedRingtones.savedRingtones(hash: _1!, ringtones: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_savedRingtonesNotModified(_ reader: BufferReader) -> SavedRingtones? {
            return Api.account.SavedRingtones.savedRingtonesNotModified
        }
    
    }
}
public extension Api.account {
    enum SentEmailCode: TypeConstructorDescription {
        case sentEmailCode(emailPattern: String, length: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentEmailCode(let emailPattern, let length):
                    if boxed {
                        buffer.appendInt32(-2128640689)
                    }
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentEmailCode(let emailPattern, let length):
                return ("sentEmailCode", [("emailPattern", String(describing: emailPattern)), ("length", String(describing: length))])
    }
    }
    
        public static func parse_sentEmailCode(_ reader: BufferReader) -> SentEmailCode? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.SentEmailCode.sentEmailCode(emailPattern: _1!, length: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Takeout: TypeConstructorDescription {
        case takeout(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .takeout(let id):
                    if boxed {
                        buffer.appendInt32(1304052993)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .takeout(let id):
                return ("takeout", [("id", String(describing: id))])
    }
    }
    
        public static func parse_takeout(_ reader: BufferReader) -> Takeout? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Takeout.takeout(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum Themes: TypeConstructorDescription {
        case themes(hash: Int64, themes: [Api.Theme])
        case themesNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .themes(let hash, let themes):
                    if boxed {
                        buffer.appendInt32(-1707242387)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(themes.count))
                    for item in themes {
                        item.serialize(buffer, true)
                    }
                    break
                case .themesNotModified:
                    if boxed {
                        buffer.appendInt32(-199313886)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .themes(let hash, let themes):
                return ("themes", [("hash", String(describing: hash)), ("themes", String(describing: themes))])
                case .themesNotModified:
                return ("themesNotModified", [])
    }
    }
    
        public static func parse_themes(_ reader: BufferReader) -> Themes? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.Theme]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Theme.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.Themes.themes(hash: _1!, themes: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_themesNotModified(_ reader: BufferReader) -> Themes? {
            return Api.account.Themes.themesNotModified
        }
    
    }
}
public extension Api.account {
    enum TmpPassword: TypeConstructorDescription {
        case tmpPassword(tmpPassword: Buffer, validUntil: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .tmpPassword(let tmpPassword, let validUntil):
                    if boxed {
                        buffer.appendInt32(-614138572)
                    }
                    serializeBytes(tmpPassword, buffer: buffer, boxed: false)
                    serializeInt32(validUntil, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .tmpPassword(let tmpPassword, let validUntil):
                return ("tmpPassword", [("tmpPassword", String(describing: tmpPassword)), ("validUntil", String(describing: validUntil))])
    }
    }
    
        public static func parse_tmpPassword(_ reader: BufferReader) -> TmpPassword? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.TmpPassword.tmpPassword(tmpPassword: _1!, validUntil: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.account {
    enum WallPapers: TypeConstructorDescription {
        case wallPapers(hash: Int64, wallpapers: [Api.WallPaper])
        case wallPapersNotModified
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPapers(let hash, let wallpapers):
                    if boxed {
                        buffer.appendInt32(-842824308)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(wallpapers.count))
                    for item in wallpapers {
                        item.serialize(buffer, true)
                    }
                    break
                case .wallPapersNotModified:
                    if boxed {
                        buffer.appendInt32(471437699)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPapers(let hash, let wallpapers):
                return ("wallPapers", [("hash", String(describing: hash)), ("wallpapers", String(describing: wallpapers))])
                case .wallPapersNotModified:
                return ("wallPapersNotModified", [])
    }
    }
    
        public static func parse_wallPapers(_ reader: BufferReader) -> WallPapers? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.WallPaper]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WallPaper.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.WallPapers.wallPapers(hash: _1!, wallpapers: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_wallPapersNotModified(_ reader: BufferReader) -> WallPapers? {
            return Api.account.WallPapers.wallPapersNotModified
        }
    
    }
}
public extension Api.account {
    enum WebAuthorizations: TypeConstructorDescription {
        case webAuthorizations(authorizations: [Api.WebAuthorization], users: [Api.User])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webAuthorizations(let authorizations, let users):
                    if boxed {
                        buffer.appendInt32(-313079300)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(authorizations.count))
                    for item in authorizations {
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
                case .webAuthorizations(let authorizations, let users):
                return ("webAuthorizations", [("authorizations", String(describing: authorizations)), ("users", String(describing: users))])
    }
    }
    
        public static func parse_webAuthorizations(_ reader: BufferReader) -> WebAuthorizations? {
            var _1: [Api.WebAuthorization]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebAuthorization.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.WebAuthorizations.webAuthorizations(authorizations: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum Authorization: TypeConstructorDescription {
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
                return ("authorization", [("flags", String(describing: flags)), ("otherwiseReloginDays", String(describing: otherwiseReloginDays)), ("tmpSessions", String(describing: tmpSessions)), ("user", String(describing: user))])
                case .authorizationSignUpRequired(let flags, let termsOfService):
                return ("authorizationSignUpRequired", [("flags", String(describing: flags)), ("termsOfService", String(describing: termsOfService))])
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
}
public extension Api.auth {
    enum CodeType: TypeConstructorDescription {
        case codeTypeCall
        case codeTypeFlashCall
        case codeTypeMissedCall
        case codeTypeSms
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
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
                case .codeTypeSms:
                    if boxed {
                        buffer.appendInt32(1923290508)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .codeTypeCall:
                return ("codeTypeCall", [])
                case .codeTypeFlashCall:
                return ("codeTypeFlashCall", [])
                case .codeTypeMissedCall:
                return ("codeTypeMissedCall", [])
                case .codeTypeSms:
                return ("codeTypeSms", [])
    }
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
        public static func parse_codeTypeSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeSms
        }
    
    }
}
