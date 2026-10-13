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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
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
        public class Cons_exportedAuthorization: TypeConstructorDescription {
            public var id: Int64
            public var bytes: Buffer
            public init(id: Int64, bytes: Buffer) {
                self.id = id
                self.bytes = bytes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedAuthorization", [("id", ConstructorParameterDescription(self.id)), ("bytes", ConstructorParameterDescription(self.bytes))])
            }
        }
        case exportedAuthorization(Cons_exportedAuthorization)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedAuthorization(let _data):
                if boxed {
                    buffer.appendInt32(-1271602504)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedAuthorization(let _data):
                return ("exportedAuthorization", [("id", ConstructorParameterDescription(_data.id)), ("bytes", ConstructorParameterDescription(_data.bytes))])
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
                return Api.auth.ExportedAuthorization.exportedAuthorization(Cons_exportedAuthorization(id: _1!, bytes: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum FirebasePnvIntent: TypeConstructorDescription {
        public class Cons_firebasePnvIntent: TypeConstructorDescription {
            public var nonce: String
            public var digitalCredentialPayload: String
            public init(nonce: String, digitalCredentialPayload: String) {
                self.nonce = nonce
                self.digitalCredentialPayload = digitalCredentialPayload
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("firebasePnvIntent", [("nonce", ConstructorParameterDescription(self.nonce)), ("digitalCredentialPayload", ConstructorParameterDescription(self.digitalCredentialPayload))])
            }
        }
        case firebasePnvIntent(Cons_firebasePnvIntent)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .firebasePnvIntent(let _data):
                if boxed {
                    buffer.appendInt32(-547700724)
                }
                serializeString(_data.nonce, buffer: buffer, boxed: false)
                serializeString(_data.digitalCredentialPayload, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .firebasePnvIntent(let _data):
                return ("firebasePnvIntent", [("nonce", ConstructorParameterDescription(_data.nonce)), ("digitalCredentialPayload", ConstructorParameterDescription(_data.digitalCredentialPayload))])
            }
        }

        public static func parse_firebasePnvIntent(_ reader: BufferReader) -> FirebasePnvIntent? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.auth.FirebasePnvIntent.firebasePnvIntent(Cons_firebasePnvIntent(nonce: _1!, digitalCredentialPayload: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum LoggedOut: TypeConstructorDescription {
        public class Cons_loggedOut: TypeConstructorDescription {
            public var flags: Int32
            public var futureAuthToken: Buffer?
            public init(flags: Int32, futureAuthToken: Buffer?) {
                self.flags = flags
                self.futureAuthToken = futureAuthToken
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("loggedOut", [("flags", ConstructorParameterDescription(self.flags)), ("futureAuthToken", ConstructorParameterDescription(self.futureAuthToken))])
            }
        }
        case loggedOut(Cons_loggedOut)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .loggedOut(let _data):
                if boxed {
                    buffer.appendInt32(-1012759713)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.futureAuthToken!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .loggedOut(let _data):
                return ("loggedOut", [("flags", ConstructorParameterDescription(_data.flags)), ("futureAuthToken", ConstructorParameterDescription(_data.futureAuthToken))])
            }
        }

        public static func parse_loggedOut(_ reader: BufferReader) -> LoggedOut? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.LoggedOut.loggedOut(Cons_loggedOut(flags: _1!, futureAuthToken: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum LoginToken: TypeConstructorDescription {
        public class Cons_loginToken: TypeConstructorDescription {
            public var expires: Int32
            public var token: Buffer
            public init(expires: Int32, token: Buffer) {
                self.expires = expires
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("loginToken", [("expires", ConstructorParameterDescription(self.expires)), ("token", ConstructorParameterDescription(self.token))])
            }
        }
        public class Cons_loginTokenMigrateTo: TypeConstructorDescription {
            public var dcId: Int32
            public var token: Buffer
            public init(dcId: Int32, token: Buffer) {
                self.dcId = dcId
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("loginTokenMigrateTo", [("dcId", ConstructorParameterDescription(self.dcId)), ("token", ConstructorParameterDescription(self.token))])
            }
        }
        public class Cons_loginTokenSuccess: TypeConstructorDescription {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("loginTokenSuccess", [("authorization", ConstructorParameterDescription(self.authorization))])
            }
        }
        case loginToken(Cons_loginToken)
        case loginTokenMigrateTo(Cons_loginTokenMigrateTo)
        case loginTokenSuccess(Cons_loginTokenSuccess)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .loginToken(let _data):
                if boxed {
                    buffer.appendInt32(1654593920)
                }
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                serializeBytes(_data.token, buffer: buffer, boxed: false)
                break
            case .loginTokenMigrateTo(let _data):
                if boxed {
                    buffer.appendInt32(110008598)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeBytes(_data.token, buffer: buffer, boxed: false)
                break
            case .loginTokenSuccess(let _data):
                if boxed {
                    buffer.appendInt32(957176926)
                }
                _data.authorization.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .loginToken(let _data):
                return ("loginToken", [("expires", ConstructorParameterDescription(_data.expires)), ("token", ConstructorParameterDescription(_data.token))])
            case .loginTokenMigrateTo(let _data):
                return ("loginTokenMigrateTo", [("dcId", ConstructorParameterDescription(_data.dcId)), ("token", ConstructorParameterDescription(_data.token))])
            case .loginTokenSuccess(let _data):
                return ("loginTokenSuccess", [("authorization", ConstructorParameterDescription(_data.authorization))])
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
                return Api.auth.LoginToken.loginToken(Cons_loginToken(expires: _1!, token: _2!))
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
                return Api.auth.LoginToken.loginTokenMigrateTo(Cons_loginTokenMigrateTo(dcId: _1!, token: _2!))
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
                return Api.auth.LoginToken.loginTokenSuccess(Cons_loginTokenSuccess(authorization: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum PasskeyLoginOptions: TypeConstructorDescription {
        public class Cons_passkeyLoginOptions: TypeConstructorDescription {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passkeyLoginOptions", [("options", ConstructorParameterDescription(self.options))])
            }
        }
        case passkeyLoginOptions(Cons_passkeyLoginOptions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkeyLoginOptions(let _data):
                if boxed {
                    buffer.appendInt32(-503089271)
                }
                _data.options.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passkeyLoginOptions(let _data):
                return ("passkeyLoginOptions", [("options", ConstructorParameterDescription(_data.options))])
            }
        }

        public static func parse_passkeyLoginOptions(_ reader: BufferReader) -> PasskeyLoginOptions? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.PasskeyLoginOptions.passkeyLoginOptions(Cons_passkeyLoginOptions(options: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum PasswordRecovery: TypeConstructorDescription {
        public class Cons_passwordRecovery: TypeConstructorDescription {
            public var emailPattern: String
            public init(emailPattern: String) {
                self.emailPattern = emailPattern
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passwordRecovery", [("emailPattern", ConstructorParameterDescription(self.emailPattern))])
            }
        }
        case passwordRecovery(Cons_passwordRecovery)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordRecovery(let _data):
                if boxed {
                    buffer.appendInt32(326715557)
                }
                serializeString(_data.emailPattern, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passwordRecovery(let _data):
                return ("passwordRecovery", [("emailPattern", ConstructorParameterDescription(_data.emailPattern))])
            }
        }

        public static func parse_passwordRecovery(_ reader: BufferReader) -> PasswordRecovery? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.PasswordRecovery.passwordRecovery(Cons_passwordRecovery(emailPattern: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum SentCode: TypeConstructorDescription {
        public class Cons_sentCode: TypeConstructorDescription {
            public var flags: Int32
            public var type: Api.auth.SentCodeType
            public var phoneCodeHash: String
            public var nextType: Api.auth.CodeType?
            public var timeout: Int32?
            public init(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?) {
                self.flags = flags
                self.type = type
                self.phoneCodeHash = phoneCodeHash
                self.nextType = nextType
                self.timeout = timeout
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCode", [("flags", ConstructorParameterDescription(self.flags)), ("type", ConstructorParameterDescription(self.type)), ("phoneCodeHash", ConstructorParameterDescription(self.phoneCodeHash)), ("nextType", ConstructorParameterDescription(self.nextType)), ("timeout", ConstructorParameterDescription(self.timeout))])
            }
        }
        public class Cons_sentCodePaymentRequired: TypeConstructorDescription {
            public var storeProduct: String
            public var phoneCodeHash: String
            public var supportEmailAddress: String
            public var supportEmailSubject: String
            public var premiumDays: Int32
            public var currency: String
            public var amount: Int64
            public init(storeProduct: String, phoneCodeHash: String, supportEmailAddress: String, supportEmailSubject: String, premiumDays: Int32, currency: String, amount: Int64) {
                self.storeProduct = storeProduct
                self.phoneCodeHash = phoneCodeHash
                self.supportEmailAddress = supportEmailAddress
                self.supportEmailSubject = supportEmailSubject
                self.premiumDays = premiumDays
                self.currency = currency
                self.amount = amount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodePaymentRequired", [("storeProduct", ConstructorParameterDescription(self.storeProduct)), ("phoneCodeHash", ConstructorParameterDescription(self.phoneCodeHash)), ("supportEmailAddress", ConstructorParameterDescription(self.supportEmailAddress)), ("supportEmailSubject", ConstructorParameterDescription(self.supportEmailSubject)), ("premiumDays", ConstructorParameterDescription(self.premiumDays)), ("currency", ConstructorParameterDescription(self.currency)), ("amount", ConstructorParameterDescription(self.amount))])
            }
        }
        public class Cons_sentCodeSuccess: TypeConstructorDescription {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeSuccess", [("authorization", ConstructorParameterDescription(self.authorization))])
            }
        }
        case sentCode(Cons_sentCode)
        case sentCodePaymentRequired(Cons_sentCodePaymentRequired)
        case sentCodeSuccess(Cons_sentCodeSuccess)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sentCode(let _data):
                if boxed {
                    buffer.appendInt32(1577067778)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.type.serialize(buffer, true)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.nextType!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.timeout!, buffer: buffer, boxed: false)
                }
                break
            case .sentCodePaymentRequired(let _data):
                if boxed {
                    buffer.appendInt32(-125665601)
                }
                serializeString(_data.storeProduct, buffer: buffer, boxed: false)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                serializeString(_data.supportEmailAddress, buffer: buffer, boxed: false)
                serializeString(_data.supportEmailSubject, buffer: buffer, boxed: false)
                serializeInt32(_data.premiumDays, buffer: buffer, boxed: false)
                serializeString(_data.currency, buffer: buffer, boxed: false)
                serializeInt64(_data.amount, buffer: buffer, boxed: false)
                break
            case .sentCodeSuccess(let _data):
                if boxed {
                    buffer.appendInt32(596704836)
                }
                _data.authorization.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sentCode(let _data):
                return ("sentCode", [("flags", ConstructorParameterDescription(_data.flags)), ("type", ConstructorParameterDescription(_data.type)), ("phoneCodeHash", ConstructorParameterDescription(_data.phoneCodeHash)), ("nextType", ConstructorParameterDescription(_data.nextType)), ("timeout", ConstructorParameterDescription(_data.timeout))])
            case .sentCodePaymentRequired(let _data):
                return ("sentCodePaymentRequired", [("storeProduct", ConstructorParameterDescription(_data.storeProduct)), ("phoneCodeHash", ConstructorParameterDescription(_data.phoneCodeHash)), ("supportEmailAddress", ConstructorParameterDescription(_data.supportEmailAddress)), ("supportEmailSubject", ConstructorParameterDescription(_data.supportEmailSubject)), ("premiumDays", ConstructorParameterDescription(_data.premiumDays)), ("currency", ConstructorParameterDescription(_data.currency)), ("amount", ConstructorParameterDescription(_data.amount))])
            case .sentCodeSuccess(let _data):
                return ("sentCodeSuccess", [("authorization", ConstructorParameterDescription(_data.authorization))])
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
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.auth.CodeType
                }
            }
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCode.sentCode(Cons_sentCode(flags: _1!, type: _2!, phoneCodeHash: _3!, nextType: _4, timeout: _5))
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
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            _6 = parseString(reader)
            var _7: Int64?
            _7 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.auth.SentCode.sentCodePaymentRequired(Cons_sentCodePaymentRequired(storeProduct: _1!, phoneCodeHash: _2!, supportEmailAddress: _3!, supportEmailSubject: _4!, premiumDays: _5!, currency: _6!, amount: _7!))
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
                return Api.auth.SentCode.sentCodeSuccess(Cons_sentCodeSuccess(authorization: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.auth {
    enum SentCodeType: TypeConstructorDescription {
        public class Cons_sentCodeTypeApp: TypeConstructorDescription {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeApp", [("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeCall: TypeConstructorDescription {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeCall", [("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeEmailCode: TypeConstructorDescription {
            public var flags: Int32
            public var emailPattern: String
            public var length: Int32
            public var resetAvailablePeriod: Int32?
            public var resetPendingDate: Int32?
            public init(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?) {
                self.flags = flags
                self.emailPattern = emailPattern
                self.length = length
                self.resetAvailablePeriod = resetAvailablePeriod
                self.resetPendingDate = resetPendingDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeEmailCode", [("flags", ConstructorParameterDescription(self.flags)), ("emailPattern", ConstructorParameterDescription(self.emailPattern)), ("length", ConstructorParameterDescription(self.length)), ("resetAvailablePeriod", ConstructorParameterDescription(self.resetAvailablePeriod)), ("resetPendingDate", ConstructorParameterDescription(self.resetPendingDate))])
            }
        }
        public class Cons_sentCodeTypeFirebaseSms: TypeConstructorDescription {
            public var flags: Int32
            public var nonce: Buffer?
            public var playIntegrityProjectId: Int64?
            public var playIntegrityNonce: Buffer?
            public var receipt: String?
            public var pushTimeout: Int32?
            public var length: Int32
            public init(flags: Int32, nonce: Buffer?, playIntegrityProjectId: Int64?, playIntegrityNonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32) {
                self.flags = flags
                self.nonce = nonce
                self.playIntegrityProjectId = playIntegrityProjectId
                self.playIntegrityNonce = playIntegrityNonce
                self.receipt = receipt
                self.pushTimeout = pushTimeout
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeFirebaseSms", [("flags", ConstructorParameterDescription(self.flags)), ("nonce", ConstructorParameterDescription(self.nonce)), ("playIntegrityProjectId", ConstructorParameterDescription(self.playIntegrityProjectId)), ("playIntegrityNonce", ConstructorParameterDescription(self.playIntegrityNonce)), ("receipt", ConstructorParameterDescription(self.receipt)), ("pushTimeout", ConstructorParameterDescription(self.pushTimeout)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeFlashCall: TypeConstructorDescription {
            public var pattern: String
            public init(pattern: String) {
                self.pattern = pattern
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeFlashCall", [("pattern", ConstructorParameterDescription(self.pattern))])
            }
        }
        public class Cons_sentCodeTypeFragmentSms: TypeConstructorDescription {
            public var url: String
            public var length: Int32
            public init(url: String, length: Int32) {
                self.url = url
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeFragmentSms", [("url", ConstructorParameterDescription(self.url)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeMissedCall: TypeConstructorDescription {
            public var prefix: String
            public var length: Int32
            public init(prefix: String, length: Int32) {
                self.prefix = prefix
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeMissedCall", [("prefix", ConstructorParameterDescription(self.prefix)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeSetUpEmailRequired: TypeConstructorDescription {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeSetUpEmailRequired", [("flags", ConstructorParameterDescription(self.flags))])
            }
        }
        public class Cons_sentCodeTypeSms: TypeConstructorDescription {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeSms", [("length", ConstructorParameterDescription(self.length))])
            }
        }
        public class Cons_sentCodeTypeSmsPhrase: TypeConstructorDescription {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeSmsPhrase", [("flags", ConstructorParameterDescription(self.flags)), ("beginning", ConstructorParameterDescription(self.beginning))])
            }
        }
        public class Cons_sentCodeTypeSmsWord: TypeConstructorDescription {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentCodeTypeSmsWord", [("flags", ConstructorParameterDescription(self.flags)), ("beginning", ConstructorParameterDescription(self.beginning))])
            }
        }
        case sentCodeTypeApp(Cons_sentCodeTypeApp)
        case sentCodeTypeCall(Cons_sentCodeTypeCall)
        case sentCodeTypeEmailCode(Cons_sentCodeTypeEmailCode)
        case sentCodeTypeFirebaseSms(Cons_sentCodeTypeFirebaseSms)
        case sentCodeTypeFlashCall(Cons_sentCodeTypeFlashCall)
        case sentCodeTypeFragmentSms(Cons_sentCodeTypeFragmentSms)
        case sentCodeTypeMissedCall(Cons_sentCodeTypeMissedCall)
        case sentCodeTypeSetUpEmailRequired(Cons_sentCodeTypeSetUpEmailRequired)
        case sentCodeTypeSms(Cons_sentCodeTypeSms)
        case sentCodeTypeSmsPhrase(Cons_sentCodeTypeSmsPhrase)
        case sentCodeTypeSmsWord(Cons_sentCodeTypeSmsWord)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sentCodeTypeApp(let _data):
                if boxed {
                    buffer.appendInt32(1035688326)
                }
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeCall(let _data):
                if boxed {
                    buffer.appendInt32(1398007207)
                }
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeEmailCode(let _data):
                if boxed {
                    buffer.appendInt32(-196020837)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeString(_data.emailPattern, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.resetAvailablePeriod!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.resetPendingDate!, buffer: buffer, boxed: false)
                }
                break
            case .sentCodeTypeFirebaseSms(let _data):
                if boxed {
                    buffer.appendInt32(10475318)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.nonce!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.playIntegrityProjectId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeBytes(_data.playIntegrityNonce!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.receipt!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.pushTimeout!, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeFlashCall(let _data):
                if boxed {
                    buffer.appendInt32(-1425815847)
                }
                serializeString(_data.pattern, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeFragmentSms(let _data):
                if boxed {
                    buffer.appendInt32(-648651719)
                }
                serializeString(_data.url, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeMissedCall(let _data):
                if boxed {
                    buffer.appendInt32(-2113903484)
                }
                serializeString(_data.prefix, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeSetUpEmailRequired(let _data):
                if boxed {
                    buffer.appendInt32(-1521934870)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeSms(let _data):
                if boxed {
                    buffer.appendInt32(-1073693790)
                }
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            case .sentCodeTypeSmsPhrase(let _data):
                if boxed {
                    buffer.appendInt32(-1284008785)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.beginning!, buffer: buffer, boxed: false)
                }
                break
            case .sentCodeTypeSmsWord(let _data):
                if boxed {
                    buffer.appendInt32(-1542017919)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.beginning!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sentCodeTypeApp(let _data):
                return ("sentCodeTypeApp", [("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeCall(let _data):
                return ("sentCodeTypeCall", [("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeEmailCode(let _data):
                return ("sentCodeTypeEmailCode", [("flags", ConstructorParameterDescription(_data.flags)), ("emailPattern", ConstructorParameterDescription(_data.emailPattern)), ("length", ConstructorParameterDescription(_data.length)), ("resetAvailablePeriod", ConstructorParameterDescription(_data.resetAvailablePeriod)), ("resetPendingDate", ConstructorParameterDescription(_data.resetPendingDate))])
            case .sentCodeTypeFirebaseSms(let _data):
                return ("sentCodeTypeFirebaseSms", [("flags", ConstructorParameterDescription(_data.flags)), ("nonce", ConstructorParameterDescription(_data.nonce)), ("playIntegrityProjectId", ConstructorParameterDescription(_data.playIntegrityProjectId)), ("playIntegrityNonce", ConstructorParameterDescription(_data.playIntegrityNonce)), ("receipt", ConstructorParameterDescription(_data.receipt)), ("pushTimeout", ConstructorParameterDescription(_data.pushTimeout)), ("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeFlashCall(let _data):
                return ("sentCodeTypeFlashCall", [("pattern", ConstructorParameterDescription(_data.pattern))])
            case .sentCodeTypeFragmentSms(let _data):
                return ("sentCodeTypeFragmentSms", [("url", ConstructorParameterDescription(_data.url)), ("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeMissedCall(let _data):
                return ("sentCodeTypeMissedCall", [("prefix", ConstructorParameterDescription(_data.prefix)), ("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeSetUpEmailRequired(let _data):
                return ("sentCodeTypeSetUpEmailRequired", [("flags", ConstructorParameterDescription(_data.flags))])
            case .sentCodeTypeSms(let _data):
                return ("sentCodeTypeSms", [("length", ConstructorParameterDescription(_data.length))])
            case .sentCodeTypeSmsPhrase(let _data):
                return ("sentCodeTypeSmsPhrase", [("flags", ConstructorParameterDescription(_data.flags)), ("beginning", ConstructorParameterDescription(_data.beginning))])
            case .sentCodeTypeSmsWord(let _data):
                return ("sentCodeTypeSmsWord", [("flags", ConstructorParameterDescription(_data.flags)), ("beginning", ConstructorParameterDescription(_data.beginning))])
            }
        }

        public static func parse_sentCodeTypeApp(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.auth.SentCodeType.sentCodeTypeApp(Cons_sentCodeTypeApp(length: _1!))
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
                return Api.auth.SentCodeType.sentCodeTypeCall(Cons_sentCodeTypeCall(length: _1!))
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
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.SentCodeType.sentCodeTypeEmailCode(Cons_sentCodeTypeEmailCode(flags: _1!, emailPattern: _2!, length: _3!, resetAvailablePeriod: _4, resetPendingDate: _5))
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeFirebaseSms(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseBytes(reader)
            }
            var _3: Int64?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _3 = reader.readInt64()
            }
            var _4: Buffer?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _4 = parseBytes(reader)
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.auth.SentCodeType.sentCodeTypeFirebaseSms(Cons_sentCodeTypeFirebaseSms(flags: _1!, nonce: _2, playIntegrityProjectId: _3, playIntegrityNonce: _4, receipt: _5, pushTimeout: _6, length: _7!))
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
                return Api.auth.SentCodeType.sentCodeTypeFlashCall(Cons_sentCodeTypeFlashCall(pattern: _1!))
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
                return Api.auth.SentCodeType.sentCodeTypeFragmentSms(Cons_sentCodeTypeFragmentSms(url: _1!, length: _2!))
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
                return Api.auth.SentCodeType.sentCodeTypeMissedCall(Cons_sentCodeTypeMissedCall(prefix: _1!, length: _2!))
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
                return Api.auth.SentCodeType.sentCodeTypeSetUpEmailRequired(Cons_sentCodeTypeSetUpEmailRequired(flags: _1!))
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
                return Api.auth.SentCodeType.sentCodeTypeSms(Cons_sentCodeTypeSms(length: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSmsPhrase(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeSmsPhrase(Cons_sentCodeTypeSmsPhrase(flags: _1!, beginning: _2))
            }
            else {
                return nil
            }
        }
        public static func parse_sentCodeTypeSmsWord(_ reader: BufferReader) -> SentCodeType? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeSmsWord(Cons_sentCodeTypeSmsWord(flags: _1!, beginning: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum AccessSettings: TypeConstructorDescription {
        public class Cons_accessSettings: TypeConstructorDescription {
            public var flags: Int32
            public var addUsers: [Api.User]?
            public init(flags: Int32, addUsers: [Api.User]?) {
                self.flags = flags
                self.addUsers = addUsers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("accessSettings", [("flags", ConstructorParameterDescription(self.flags)), ("addUsers", ConstructorParameterDescription(self.addUsers))])
            }
        }
        case accessSettings(Cons_accessSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .accessSettings(let _data):
                if boxed {
                    buffer.appendInt32(-585121901)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.addUsers!.count))
                    for item in _data.addUsers! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .accessSettings(let _data):
                return ("accessSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("addUsers", ConstructorParameterDescription(_data.addUsers))])
            }
        }

        public static func parse_accessSettings(_ reader: BufferReader) -> AccessSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.User]?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.bots.AccessSettings.accessSettings(Cons_accessSettings(flags: _1!, addUsers: _2))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum BotInfo: TypeConstructorDescription {
        public class Cons_botInfo: TypeConstructorDescription {
            public var name: String
            public var about: String
            public var description: String
            public init(name: String, about: String, description: String) {
                self.name = name
                self.about = about
                self.description = description
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("botInfo", [("name", ConstructorParameterDescription(self.name)), ("about", ConstructorParameterDescription(self.about)), ("description", ConstructorParameterDescription(self.description))])
            }
        }
        case botInfo(Cons_botInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .botInfo(let _data):
                if boxed {
                    buffer.appendInt32(-391678544)
                }
                serializeString(_data.name, buffer: buffer, boxed: false)
                serializeString(_data.about, buffer: buffer, boxed: false)
                serializeString(_data.description, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .botInfo(let _data):
                return ("botInfo", [("name", ConstructorParameterDescription(_data.name)), ("about", ConstructorParameterDescription(_data.about)), ("description", ConstructorParameterDescription(_data.description))])
            }
        }

        public static func parse_botInfo(_ reader: BufferReader) -> BotInfo? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.bots.BotInfo.botInfo(Cons_botInfo(name: _1!, about: _2!, description: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum ExportedBotToken: TypeConstructorDescription {
        public class Cons_exportedBotToken: TypeConstructorDescription {
            public var token: String
            public init(token: String) {
                self.token = token
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("exportedBotToken", [("token", ConstructorParameterDescription(self.token))])
            }
        }
        case exportedBotToken(Cons_exportedBotToken)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .exportedBotToken(let _data):
                if boxed {
                    buffer.appendInt32(1012971041)
                }
                serializeString(_data.token, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .exportedBotToken(let _data):
                return ("exportedBotToken", [("token", ConstructorParameterDescription(_data.token))])
            }
        }

        public static func parse_exportedBotToken(_ reader: BufferReader) -> ExportedBotToken? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.bots.ExportedBotToken.exportedBotToken(Cons_exportedBotToken(token: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum PopularAppBots: TypeConstructorDescription {
        public class Cons_popularAppBots: TypeConstructorDescription {
            public var flags: Int32
            public var nextOffset: String?
            public var users: [Api.User]
            public init(flags: Int32, nextOffset: String?, users: [Api.User]) {
                self.flags = flags
                self.nextOffset = nextOffset
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("popularAppBots", [("flags", ConstructorParameterDescription(self.flags)), ("nextOffset", ConstructorParameterDescription(self.nextOffset)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case popularAppBots(Cons_popularAppBots)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .popularAppBots(let _data):
                if boxed {
                    buffer.appendInt32(428978491)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .popularAppBots(let _data):
                return ("popularAppBots", [("flags", ConstructorParameterDescription(_data.flags)), ("nextOffset", ConstructorParameterDescription(_data.nextOffset)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_popularAppBots(_ reader: BufferReader) -> PopularAppBots? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.bots.PopularAppBots.popularAppBots(Cons_popularAppBots(flags: _1!, nextOffset: _2, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.bots {
    enum PreviewInfo: TypeConstructorDescription {
        public class Cons_previewInfo: TypeConstructorDescription {
            public var media: [Api.BotPreviewMedia]
            public var langCodes: [String]
            public init(media: [Api.BotPreviewMedia], langCodes: [String]) {
                self.media = media
                self.langCodes = langCodes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("previewInfo", [("media", ConstructorParameterDescription(self.media)), ("langCodes", ConstructorParameterDescription(self.langCodes))])
            }
        }
        case previewInfo(Cons_previewInfo)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .previewInfo(let _data):
                if boxed {
                    buffer.appendInt32(212278628)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.media.count))
                for item in _data.media {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.langCodes.count))
                for item in _data.langCodes {
                    serializeString(item, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .previewInfo(let _data):
                return ("previewInfo", [("media", ConstructorParameterDescription(_data.media)), ("langCodes", ConstructorParameterDescription(_data.langCodes))])
            }
        }

        public static func parse_previewInfo(_ reader: BufferReader) -> PreviewInfo? {
            var _1: [Api.BotPreviewMedia]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotPreviewMedia.self)
            }
            var _2: [String]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: String.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.bots.PreviewInfo.previewInfo(Cons_previewInfo(media: _1!, langCodes: _2!))
            }
            else {
                return nil
            }
        }
    }
}
