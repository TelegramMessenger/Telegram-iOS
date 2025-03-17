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
                return ("themes", [("hash", hash as Any), ("themes", themes as Any)])
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
                return ("tmpPassword", [("tmpPassword", tmpPassword as Any), ("validUntil", validUntil as Any)])
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
                return ("wallPapers", [("hash", hash as Any), ("wallpapers", wallpapers as Any)])
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
                return ("webAuthorizations", [("authorizations", authorizations as Any), ("users", users as Any)])
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
        case authorization(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User)
        case authorizationSignUpRequired(flags: Int32, termsOfService: Api.help.TermsOfService?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let futureAuthToken, let user):
                    if boxed {
                        buffer.appendInt32(782418132)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(otherwiseReloginDays!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(tmpSessions!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(futureAuthToken!, buffer: buffer, boxed: false)}
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
                case .authorization(let flags, let otherwiseReloginDays, let tmpSessions, let futureAuthToken, let user):
                return ("authorization", [("flags", flags as Any), ("otherwiseReloginDays", otherwiseReloginDays as Any), ("tmpSessions", tmpSessions as Any), ("futureAuthToken", futureAuthToken as Any), ("user", user as Any)])
                case .authorizationSignUpRequired(let flags, let termsOfService):
                return ("authorizationSignUpRequired", [("flags", flags as Any), ("termsOfService", termsOfService as Any)])
    }
    }
    
        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseBytes(reader) }
            var _5: Api.User?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.Authorization.authorization(flags: _1!, otherwiseReloginDays: _2, tmpSessions: _3, futureAuthToken: _4, user: _5!)
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
        case codeTypeFragmentSms
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
                case .codeTypeFragmentSms:
                    if boxed {
                        buffer.appendInt32(116234636)
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
                case .codeTypeFragmentSms:
                return ("codeTypeFragmentSms", [])
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
        public static func parse_codeTypeFragmentSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeFragmentSms
        }
        public static func parse_codeTypeMissedCall(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeMissedCall
        }
        public static func parse_codeTypeSms(_ reader: BufferReader) -> CodeType? {
            return Api.auth.CodeType.codeTypeSms
        }
    
    }
}
public extension Api.auth {
    enum ExportedAuthorization: TypeConstructorDescription {
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
                return ("exportedAuthorization", [("id", id as Any), ("bytes", bytes as Any)])
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
}
public extension Api.auth {
    enum LoggedOut: TypeConstructorDescription {
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
                return ("loggedOut", [("flags", flags as Any), ("futureAuthToken", futureAuthToken as Any)])
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
public extension Api.auth {
    enum LoginToken: TypeConstructorDescription {
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
                return ("loginToken", [("expires", expires as Any), ("token", token as Any)])
                case .loginTokenMigrateTo(let dcId, let token):
                return ("loginTokenMigrateTo", [("dcId", dcId as Any), ("token", token as Any)])
                case .loginTokenSuccess(let authorization):
                return ("loginTokenSuccess", [("authorization", authorization as Any)])
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
}
public extension Api.auth {
    enum PasswordRecovery: TypeConstructorDescription {
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
                return ("passwordRecovery", [("emailPattern", emailPattern as Any)])
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
}
public extension Api.auth {
    enum SentCode: TypeConstructorDescription {
        case sentCode(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?)
        case sentCodePaymentRequired(storeProduct: String, phoneCodeHash: String)
        case sentCodeSuccess(authorization: Api.auth.Authorization)
    
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
                case .sentCodePaymentRequired(let storeProduct, let phoneCodeHash):
                    if boxed {
                        buffer.appendInt32(-674301568)
                    }
                    serializeString(storeProduct, buffer: buffer, boxed: false)
                    serializeString(phoneCodeHash, buffer: buffer, boxed: false)
                    break
                case .sentCodeSuccess(let authorization):
                    if boxed {
                        buffer.appendInt32(596704836)
                    }
                    authorization.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCode(let flags, let type, let phoneCodeHash, let nextType, let timeout):
                return ("sentCode", [("flags", flags as Any), ("type", type as Any), ("phoneCodeHash", phoneCodeHash as Any), ("nextType", nextType as Any), ("timeout", timeout as Any)])
                case .sentCodePaymentRequired(let storeProduct, let phoneCodeHash):
                return ("sentCodePaymentRequired", [("storeProduct", storeProduct as Any), ("phoneCodeHash", phoneCodeHash as Any)])
                case .sentCodeSuccess(let authorization):
                return ("sentCodeSuccess", [("authorization", authorization as Any)])
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
        public static func parse_sentCodePaymentRequired(_ reader: BufferReader) -> SentCode? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCode.sentCodePaymentRequired(storeProduct: _1!, phoneCodeHash: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeSuccess(_ reader: BufferReader) -> SentCode? {
            var _1: Api.auth.Authorization?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.Authorization
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCode.sentCodeSuccess(authorization: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api.auth {
    enum SentCodeType: TypeConstructorDescription {
        case sentCodeTypeApp(length: Int32)
        case sentCodeTypeCall(length: Int32)
        case sentCodeTypeEmailCode(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?)
        case sentCodeTypeFirebaseSms(flags: Int32, nonce: Buffer?, playIntegrityProjectId: Int64?, playIntegrityNonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32)
        case sentCodeTypeFlashCall(pattern: String)
        case sentCodeTypeFragmentSms(url: String, length: Int32)
        case sentCodeTypeMissedCall(prefix: String, length: Int32)
        case sentCodeTypeSetUpEmailRequired(flags: Int32)
        case sentCodeTypeSms(length: Int32)
        case sentCodeTypeSmsPhrase(flags: Int32, beginning: String?)
        case sentCodeTypeSmsWord(flags: Int32, beginning: String?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .sentCodeTypeApp(let length):
                    if boxed {
                        buffer.appendInt32(1035688326)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeCall(let length):
                    if boxed {
                        buffer.appendInt32(1398007207)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeEmailCode(let flags, let emailPattern, let length, let resetAvailablePeriod, let resetPendingDate):
                    if boxed {
                        buffer.appendInt32(-196020837)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(emailPattern, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(resetAvailablePeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(resetPendingDate!, buffer: buffer, boxed: false)}
                    break
                case .sentCodeTypeFirebaseSms(let flags, let nonce, let playIntegrityProjectId, let playIntegrityNonce, let receipt, let pushTimeout, let length):
                    if boxed {
                        buffer.appendInt32(10475318)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(nonce!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt64(playIntegrityProjectId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeBytes(playIntegrityNonce!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(receipt!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(pushTimeout!, buffer: buffer, boxed: false)}
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeFlashCall(let pattern):
                    if boxed {
                        buffer.appendInt32(-1425815847)
                    }
                    serializeString(pattern, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeFragmentSms(let url, let length):
                    if boxed {
                        buffer.appendInt32(-648651719)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeMissedCall(let prefix, let length):
                    if boxed {
                        buffer.appendInt32(-2113903484)
                    }
                    serializeString(prefix, buffer: buffer, boxed: false)
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSetUpEmailRequired(let flags):
                    if boxed {
                        buffer.appendInt32(-1521934870)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSms(let length):
                    if boxed {
                        buffer.appendInt32(-1073693790)
                    }
                    serializeInt32(length, buffer: buffer, boxed: false)
                    break
                case .sentCodeTypeSmsPhrase(let flags, let beginning):
                    if boxed {
                        buffer.appendInt32(-1284008785)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(beginning!, buffer: buffer, boxed: false)}
                    break
                case .sentCodeTypeSmsWord(let flags, let beginning):
                    if boxed {
                        buffer.appendInt32(-1542017919)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(beginning!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .sentCodeTypeApp(let length):
                return ("sentCodeTypeApp", [("length", length as Any)])
                case .sentCodeTypeCall(let length):
                return ("sentCodeTypeCall", [("length", length as Any)])
                case .sentCodeTypeEmailCode(let flags, let emailPattern, let length, let resetAvailablePeriod, let resetPendingDate):
                return ("sentCodeTypeEmailCode", [("flags", flags as Any), ("emailPattern", emailPattern as Any), ("length", length as Any), ("resetAvailablePeriod", resetAvailablePeriod as Any), ("resetPendingDate", resetPendingDate as Any)])
                case .sentCodeTypeFirebaseSms(let flags, let nonce, let playIntegrityProjectId, let playIntegrityNonce, let receipt, let pushTimeout, let length):
                return ("sentCodeTypeFirebaseSms", [("flags", flags as Any), ("nonce", nonce as Any), ("playIntegrityProjectId", playIntegrityProjectId as Any), ("playIntegrityNonce", playIntegrityNonce as Any), ("receipt", receipt as Any), ("pushTimeout", pushTimeout as Any), ("length", length as Any)])
                case .sentCodeTypeFlashCall(let pattern):
                return ("sentCodeTypeFlashCall", [("pattern", pattern as Any)])
                case .sentCodeTypeFragmentSms(let url, let length):
                return ("sentCodeTypeFragmentSms", [("url", url as Any), ("length", length as Any)])
                case .sentCodeTypeMissedCall(let prefix, let length):
                return ("sentCodeTypeMissedCall", [("prefix", prefix as Any), ("length", length as Any)])
                case .sentCodeTypeSetUpEmailRequired(let flags):
                return ("sentCodeTypeSetUpEmailRequired", [("flags", flags as Any)])
                case .sentCodeTypeSms(let length):
                return ("sentCodeTypeSms", [("length", length as Any)])
                case .sentCodeTypeSmsPhrase(let flags, let beginning):
                return ("sentCodeTypeSmsPhrase", [("flags", flags as Any), ("beginning", beginning as Any)])
                case .sentCodeTypeSmsWord(let flags, let beginning):
                return ("sentCodeTypeSmsWord", [("flags", flags as Any), ("beginning", beginning as Any)])
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
        public static func parse_sentCodeTypeEmailCode(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCodeType.sentCodeTypeEmailCode(flags: _1!, emailPattern: _2!, length: _3!, resetAvailablePeriod: _4, resetPendingDate: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFirebaseSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseBytes(reader) }
            var _3: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt64() }
            var _4: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = parseBytes(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.auth.SentCodeType.sentCodeTypeFirebaseSms(flags: _1!, nonce: _2, playIntegrityProjectId: _3, playIntegrityNonce: _4, receipt: _5, pushTimeout: _6, length: _7!)
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
        public static func parse_sentCodeTypeFragmentSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeFragmentSms(url: _1!, length: _2!)
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
        public static func parse_sentCodeTypeSetUpEmailRequired(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeSetUpEmailRequired(flags: _1!)
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
        public static func parse_sentCodeTypeSmsPhrase(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeSmsPhrase(flags: _1!, beginning: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSmsWord(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeSmsWord(flags: _1!, beginning: _2)
            }
            else {
                return nil
            }
        }
    
    }
}
