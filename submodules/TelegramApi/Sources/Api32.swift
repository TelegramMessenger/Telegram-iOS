public extension Api.account {
    enum EmojiStatuses: TypeConstructorDescription {
        public class Cons_emojiStatuses: TypeConstructorDescription {
            public var hash: Int64
            public var statuses: [Api.EmojiStatus]
            public init(hash: Int64, statuses: [Api.EmojiStatus]) {
                self.hash = hash
                self.statuses = statuses
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("emojiStatuses", [("hash", ConstructorParameterDescription(self.hash)), ("statuses", ConstructorParameterDescription(self.statuses))])
            }
        }
        case emojiStatuses(Cons_emojiStatuses)
        case emojiStatusesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .emojiStatuses(let _data):
                if boxed {
                    buffer.appendInt32(-1866176559)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.statuses.count))
                for item in _data.statuses {
                    item.serialize(buffer, true)
                }
                break
            case .emojiStatusesNotModified:
                if boxed {
                    buffer.appendInt32(-796072379)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .emojiStatuses(let _data):
                return ("emojiStatuses", [("hash", ConstructorParameterDescription(_data.hash)), ("statuses", ConstructorParameterDescription(_data.statuses))])
            case .emojiStatusesNotModified:
                return ("emojiStatusesNotModified", [])
            }
        }

        public static func parse_emojiStatuses(_ reader: BufferReader) -> EmojiStatuses? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.EmojiStatus]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EmojiStatus.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.account.EmojiStatuses.emojiStatuses(Cons_emojiStatuses(hash: _1!, statuses: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_emojiStatusesNotModified(_ reader: BufferReader) -> EmojiStatuses? {
            return Api.account.EmojiStatuses.emojiStatusesNotModified
        }
    }
}
public extension Api.account {
    enum PaidMessagesRevenue: TypeConstructorDescription {
        public class Cons_paidMessagesRevenue: TypeConstructorDescription {
            public var starsAmount: Int64
            public init(starsAmount: Int64) {
                self.starsAmount = starsAmount
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("paidMessagesRevenue", [("starsAmount", ConstructorParameterDescription(self.starsAmount))])
            }
        }
        case paidMessagesRevenue(Cons_paidMessagesRevenue)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .paidMessagesRevenue(let _data):
                if boxed {
                    buffer.appendInt32(504403720)
                }
                serializeInt64(_data.starsAmount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .paidMessagesRevenue(let _data):
                return ("paidMessagesRevenue", [("starsAmount", ConstructorParameterDescription(_data.starsAmount))])
            }
        }

        public static func parse_paidMessagesRevenue(_ reader: BufferReader) -> PaidMessagesRevenue? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.PaidMessagesRevenue.paidMessagesRevenue(Cons_paidMessagesRevenue(starsAmount: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasskeyRegistrationOptions: TypeConstructorDescription {
        public class Cons_passkeyRegistrationOptions: TypeConstructorDescription {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passkeyRegistrationOptions", [("options", ConstructorParameterDescription(self.options))])
            }
        }
        case passkeyRegistrationOptions(Cons_passkeyRegistrationOptions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkeyRegistrationOptions(let _data):
                if boxed {
                    buffer.appendInt32(-513057567)
                }
                _data.options.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passkeyRegistrationOptions(let _data):
                return ("passkeyRegistrationOptions", [("options", ConstructorParameterDescription(_data.options))])
            }
        }

        public static func parse_passkeyRegistrationOptions(_ reader: BufferReader) -> PasskeyRegistrationOptions? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.PasskeyRegistrationOptions.passkeyRegistrationOptions(Cons_passkeyRegistrationOptions(options: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Passkeys: TypeConstructorDescription {
        public class Cons_passkeys: TypeConstructorDescription {
            public var passkeys: [Api.Passkey]
            public init(passkeys: [Api.Passkey]) {
                self.passkeys = passkeys
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passkeys", [("passkeys", ConstructorParameterDescription(self.passkeys))])
            }
        }
        case passkeys(Cons_passkeys)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passkeys(let _data):
                if boxed {
                    buffer.appendInt32(-119494116)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.passkeys.count))
                for item in _data.passkeys {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passkeys(let _data):
                return ("passkeys", [("passkeys", ConstructorParameterDescription(_data.passkeys))])
            }
        }

        public static func parse_passkeys(_ reader: BufferReader) -> Passkeys? {
            var _1: [Api.Passkey]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Passkey.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Passkeys.passkeys(Cons_passkeys(passkeys: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription {
        public class Cons_password: TypeConstructorDescription {
            public var flags: Int32
            public var currentAlgo: Api.PasswordKdfAlgo?
            public var srpB: Buffer?
            public var srpId: Int64?
            public var hint: String?
            public var emailUnconfirmedPattern: String?
            public var newAlgo: Api.PasswordKdfAlgo
            public var newSecureAlgo: Api.SecurePasswordKdfAlgo
            public var secureRandom: Buffer
            public var pendingResetDate: Int32?
            public var loginEmailPattern: String?
            public init(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?) {
                self.flags = flags
                self.currentAlgo = currentAlgo
                self.srpB = srpB
                self.srpId = srpId
                self.hint = hint
                self.emailUnconfirmedPattern = emailUnconfirmedPattern
                self.newAlgo = newAlgo
                self.newSecureAlgo = newSecureAlgo
                self.secureRandom = secureRandom
                self.pendingResetDate = pendingResetDate
                self.loginEmailPattern = loginEmailPattern
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("password", [("flags", ConstructorParameterDescription(self.flags)), ("currentAlgo", ConstructorParameterDescription(self.currentAlgo)), ("srpB", ConstructorParameterDescription(self.srpB)), ("srpId", ConstructorParameterDescription(self.srpId)), ("hint", ConstructorParameterDescription(self.hint)), ("emailUnconfirmedPattern", ConstructorParameterDescription(self.emailUnconfirmedPattern)), ("newAlgo", ConstructorParameterDescription(self.newAlgo)), ("newSecureAlgo", ConstructorParameterDescription(self.newSecureAlgo)), ("secureRandom", ConstructorParameterDescription(self.secureRandom)), ("pendingResetDate", ConstructorParameterDescription(self.pendingResetDate)), ("loginEmailPattern", ConstructorParameterDescription(self.loginEmailPattern))])
            }
        }
        case password(Cons_password)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .password(let _data):
                if boxed {
                    buffer.appendInt32(-1787080453)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.currentAlgo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeBytes(_data.srpB!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt64(_data.srpId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeString(_data.hint!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeString(_data.emailUnconfirmedPattern!, buffer: buffer, boxed: false)
                }
                _data.newAlgo.serialize(buffer, true)
                _data.newSecureAlgo.serialize(buffer, true)
                serializeBytes(_data.secureRandom, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    serializeInt32(_data.pendingResetDate!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.loginEmailPattern!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .password(let _data):
                return ("password", [("flags", ConstructorParameterDescription(_data.flags)), ("currentAlgo", ConstructorParameterDescription(_data.currentAlgo)), ("srpB", ConstructorParameterDescription(_data.srpB)), ("srpId", ConstructorParameterDescription(_data.srpId)), ("hint", ConstructorParameterDescription(_data.hint)), ("emailUnconfirmedPattern", ConstructorParameterDescription(_data.emailUnconfirmedPattern)), ("newAlgo", ConstructorParameterDescription(_data.newAlgo)), ("newSecureAlgo", ConstructorParameterDescription(_data.newSecureAlgo)), ("secureRandom", ConstructorParameterDescription(_data.secureRandom)), ("pendingResetDate", ConstructorParameterDescription(_data.pendingResetDate)), ("loginEmailPattern", ConstructorParameterDescription(_data.loginEmailPattern))])
            }
        }

        public static func parse_password(_ reader: BufferReader) -> Password? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
                }
            }
            var _3: Buffer?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: Int64?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _4 = reader.readInt64()
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 3) != 0 {
                _5 = parseString(reader)
            }
            var _6: String?
            if Int(_1 ?? 0) & Int(1 << 4) != 0 {
                _6 = parseString(reader)
            }
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
            if Int(_1 ?? 0) & Int(1 << 5) != 0 {
                _10 = reader.readInt32()
            }
            var _11: String?
            if Int(_1 ?? 0) & Int(1 << 6) != 0 {
                _11 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 4) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1 ?? 0) & Int(1 << 5) == 0) || _10 != nil
            let _c11 = (Int(_1 ?? 0) & Int(1 << 6) == 0) || _11 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 {
                return Api.account.Password.password(Cons_password(flags: _1!, currentAlgo: _2, srpB: _3, srpId: _4, hint: _5, emailUnconfirmedPattern: _6, newAlgo: _7!, newSecureAlgo: _8!, secureRandom: _9!, pendingResetDate: _10, loginEmailPattern: _11))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription {
        public class Cons_passwordInputSettings: TypeConstructorDescription {
            public var flags: Int32
            public var newAlgo: Api.PasswordKdfAlgo?
            public var newPasswordHash: Buffer?
            public var hint: String?
            public var email: String?
            public var newSecureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.newAlgo = newAlgo
                self.newPasswordHash = newPasswordHash
                self.hint = hint
                self.email = email
                self.newSecureSettings = newSecureSettings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passwordInputSettings", [("flags", ConstructorParameterDescription(self.flags)), ("newAlgo", ConstructorParameterDescription(self.newAlgo)), ("newPasswordHash", ConstructorParameterDescription(self.newPasswordHash)), ("hint", ConstructorParameterDescription(self.hint)), ("email", ConstructorParameterDescription(self.email)), ("newSecureSettings", ConstructorParameterDescription(self.newSecureSettings))])
            }
        }
        case passwordInputSettings(Cons_passwordInputSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordInputSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1036572727)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.newAlgo!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeBytes(_data.newPasswordHash!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.hint!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeString(_data.email!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.newSecureSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passwordInputSettings(let _data):
                return ("passwordInputSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("newAlgo", ConstructorParameterDescription(_data.newAlgo)), ("newPasswordHash", ConstructorParameterDescription(_data.newPasswordHash)), ("hint", ConstructorParameterDescription(_data.hint)), ("email", ConstructorParameterDescription(_data.email)), ("newSecureSettings", ConstructorParameterDescription(_data.newSecureSettings))])
            }
        }

        public static func parse_passwordInputSettings(_ reader: BufferReader) -> PasswordInputSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.PasswordKdfAlgo?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.PasswordKdfAlgo
                }
            }
            var _3: Buffer?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = parseBytes(reader)
            }
            var _4: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _4 = parseString(reader)
            }
            var _5: String?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Api.SecureSecretSettings?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _6 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.PasswordInputSettings.passwordInputSettings(Cons_passwordInputSettings(flags: _1!, newAlgo: _2, newPasswordHash: _3, hint: _4, email: _5, newSecureSettings: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription {
        public class Cons_passwordSettings: TypeConstructorDescription {
            public var flags: Int32
            public var email: String?
            public var secureSettings: Api.SecureSecretSettings?
            public init(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?) {
                self.flags = flags
                self.email = email
                self.secureSettings = secureSettings
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("passwordSettings", [("flags", ConstructorParameterDescription(self.flags)), ("email", ConstructorParameterDescription(self.email)), ("secureSettings", ConstructorParameterDescription(self.secureSettings))])
            }
        }
        case passwordSettings(Cons_passwordSettings)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .passwordSettings(let _data):
                if boxed {
                    buffer.appendInt32(-1705233435)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.email!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    _data.secureSettings!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .passwordSettings(let _data):
                return ("passwordSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("email", ConstructorParameterDescription(_data.email)), ("secureSettings", ConstructorParameterDescription(_data.secureSettings))])
            }
        }

        public static func parse_passwordSettings(_ reader: BufferReader) -> PasswordSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            var _3: Api.SecureSecretSettings?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.SecureSecretSettings
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.account.PasswordSettings.passwordSettings(Cons_passwordSettings(flags: _1!, email: _2, secureSettings: _3))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription {
        public class Cons_privacyRules: TypeConstructorDescription {
            public var rules: [Api.PrivacyRule]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User]) {
                self.rules = rules
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("privacyRules", [("rules", ConstructorParameterDescription(self.rules)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case privacyRules(Cons_privacyRules)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .privacyRules(let _data):
                if boxed {
                    buffer.appendInt32(1352683077)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.rules.count))
                for item in _data.rules {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .privacyRules(let _data):
                return ("privacyRules", [("rules", ConstructorParameterDescription(_data.rules)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.PrivacyRules.privacyRules(Cons_privacyRules(rules: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription {
        public class Cons_resetPasswordFailedWait: TypeConstructorDescription {
            public var retryDate: Int32
            public init(retryDate: Int32) {
                self.retryDate = retryDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resetPasswordFailedWait", [("retryDate", ConstructorParameterDescription(self.retryDate))])
            }
        }
        public class Cons_resetPasswordRequestedWait: TypeConstructorDescription {
            public var untilDate: Int32
            public init(untilDate: Int32) {
                self.untilDate = untilDate
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resetPasswordRequestedWait", [("untilDate", ConstructorParameterDescription(self.untilDate))])
            }
        }
        case resetPasswordFailedWait(Cons_resetPasswordFailedWait)
        case resetPasswordOk
        case resetPasswordRequestedWait(Cons_resetPasswordRequestedWait)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resetPasswordFailedWait(let _data):
                if boxed {
                    buffer.appendInt32(-478701471)
                }
                serializeInt32(_data.retryDate, buffer: buffer, boxed: false)
                break
            case .resetPasswordOk:
                if boxed {
                    buffer.appendInt32(-383330754)
                }
                break
            case .resetPasswordRequestedWait(let _data):
                if boxed {
                    buffer.appendInt32(-370148227)
                }
                serializeInt32(_data.untilDate, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .resetPasswordFailedWait(let _data):
                return ("resetPasswordFailedWait", [("retryDate", ConstructorParameterDescription(_data.retryDate))])
            case .resetPasswordOk:
                return ("resetPasswordOk", [])
            case .resetPasswordRequestedWait(let _data):
                return ("resetPasswordRequestedWait", [("untilDate", ConstructorParameterDescription(_data.untilDate))])
            }
        }

        public static func parse_resetPasswordFailedWait(_ reader: BufferReader) -> ResetPasswordResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.ResetPasswordResult.resetPasswordFailedWait(Cons_resetPasswordFailedWait(retryDate: _1!))
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
                return Api.account.ResetPasswordResult.resetPasswordRequestedWait(Cons_resetPasswordRequestedWait(untilDate: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum ResolvedBusinessChatLinks: TypeConstructorDescription {
        public class Cons_resolvedBusinessChatLinks: TypeConstructorDescription {
            public var flags: Int32
            public var peer: Api.Peer
            public var message: String
            public var entities: [Api.MessageEntity]?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.peer = peer
                self.message = message
                self.entities = entities
                self.chats = chats
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("resolvedBusinessChatLinks", [("flags", ConstructorParameterDescription(self.flags)), ("peer", ConstructorParameterDescription(self.peer)), ("message", ConstructorParameterDescription(self.message)), ("entities", ConstructorParameterDescription(self.entities)), ("chats", ConstructorParameterDescription(self.chats)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .resolvedBusinessChatLinks(let _data):
                if boxed {
                    buffer.appendInt32(-1708937439)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peer.serialize(buffer, true)
                serializeString(_data.message, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.entities!.count))
                    for item in _data.entities! {
                        item.serialize(buffer, true)
                    }
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .resolvedBusinessChatLinks(let _data):
                return ("resolvedBusinessChatLinks", [("flags", ConstructorParameterDescription(_data.flags)), ("peer", ConstructorParameterDescription(_data.peer)), ("message", ConstructorParameterDescription(_data.message)), ("entities", ConstructorParameterDescription(_data.entities)), ("chats", ConstructorParameterDescription(_data.chats)), ("users", ConstructorParameterDescription(_data.users))])
            }
        }

        public static func parse_resolvedBusinessChatLinks(_ reader: BufferReader) -> ResolvedBusinessChatLinks? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.MessageEntity]?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
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
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.account.ResolvedBusinessChatLinks.resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks(flags: _1!, peer: _2!, message: _3!, entities: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum SavedMusicIds: TypeConstructorDescription {
        public class Cons_savedMusicIds: TypeConstructorDescription {
            public var ids: [Int64]
            public init(ids: [Int64]) {
                self.ids = ids
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedMusicIds", [("ids", ConstructorParameterDescription(self.ids))])
            }
        }
        case savedMusicIds(Cons_savedMusicIds)
        case savedMusicIdsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedMusicIds(let _data):
                if boxed {
                    buffer.appendInt32(-1718786506)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.ids.count))
                for item in _data.ids {
                    serializeInt64(item, buffer: buffer, boxed: false)
                }
                break
            case .savedMusicIdsNotModified:
                if boxed {
                    buffer.appendInt32(1338514798)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedMusicIds(let _data):
                return ("savedMusicIds", [("ids", ConstructorParameterDescription(_data.ids))])
            case .savedMusicIdsNotModified:
                return ("savedMusicIdsNotModified", [])
            }
        }

        public static func parse_savedMusicIds(_ reader: BufferReader) -> SavedMusicIds? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.SavedMusicIds.savedMusicIds(Cons_savedMusicIds(ids: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedMusicIdsNotModified(_ reader: BufferReader) -> SavedMusicIds? {
            return Api.account.SavedMusicIds.savedMusicIdsNotModified
        }
    }
}
public extension Api.account {
    enum SavedRingtone: TypeConstructorDescription {
        public class Cons_savedRingtoneConverted: TypeConstructorDescription {
            public var document: Api.Document
            public init(document: Api.Document) {
                self.document = document
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedRingtoneConverted", [("document", ConstructorParameterDescription(self.document))])
            }
        }
        case savedRingtone
        case savedRingtoneConverted(Cons_savedRingtoneConverted)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedRingtone:
                if boxed {
                    buffer.appendInt32(-1222230163)
                }
                break
            case .savedRingtoneConverted(let _data):
                if boxed {
                    buffer.appendInt32(523271863)
                }
                _data.document.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedRingtone:
                return ("savedRingtone", [])
            case .savedRingtoneConverted(let _data):
                return ("savedRingtoneConverted", [("document", ConstructorParameterDescription(_data.document))])
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
                return Api.account.SavedRingtone.savedRingtoneConverted(Cons_savedRingtoneConverted(document: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum SavedRingtones: TypeConstructorDescription {
        public class Cons_savedRingtones: TypeConstructorDescription {
            public var hash: Int64
            public var ringtones: [Api.Document]
            public init(hash: Int64, ringtones: [Api.Document]) {
                self.hash = hash
                self.ringtones = ringtones
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("savedRingtones", [("hash", ConstructorParameterDescription(self.hash)), ("ringtones", ConstructorParameterDescription(self.ringtones))])
            }
        }
        case savedRingtones(Cons_savedRingtones)
        case savedRingtonesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedRingtones(let _data):
                if boxed {
                    buffer.appendInt32(-1041683259)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.ringtones.count))
                for item in _data.ringtones {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .savedRingtones(let _data):
                return ("savedRingtones", [("hash", ConstructorParameterDescription(_data.hash)), ("ringtones", ConstructorParameterDescription(_data.ringtones))])
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
                return Api.account.SavedRingtones.savedRingtones(Cons_savedRingtones(hash: _1!, ringtones: _2!))
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
        public class Cons_sentEmailCode: TypeConstructorDescription {
            public var emailPattern: String
            public var length: Int32
            public init(emailPattern: String, length: Int32) {
                self.emailPattern = emailPattern
                self.length = length
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("sentEmailCode", [("emailPattern", ConstructorParameterDescription(self.emailPattern)), ("length", ConstructorParameterDescription(self.length))])
            }
        }
        case sentEmailCode(Cons_sentEmailCode)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .sentEmailCode(let _data):
                if boxed {
                    buffer.appendInt32(-2128640689)
                }
                serializeString(_data.emailPattern, buffer: buffer, boxed: false)
                serializeInt32(_data.length, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .sentEmailCode(let _data):
                return ("sentEmailCode", [("emailPattern", ConstructorParameterDescription(_data.emailPattern)), ("length", ConstructorParameterDescription(_data.length))])
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
                return Api.account.SentEmailCode.sentEmailCode(Cons_sentEmailCode(emailPattern: _1!, length: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Takeout: TypeConstructorDescription {
        public class Cons_takeout: TypeConstructorDescription {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("takeout", [("id", ConstructorParameterDescription(self.id))])
            }
        }
        case takeout(Cons_takeout)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .takeout(let _data):
                if boxed {
                    buffer.appendInt32(1304052993)
                }
                serializeInt64(_data.id, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .takeout(let _data):
                return ("takeout", [("id", ConstructorParameterDescription(_data.id))])
            }
        }

        public static func parse_takeout(_ reader: BufferReader) -> Takeout? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.account.Takeout.takeout(Cons_takeout(id: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum Themes: TypeConstructorDescription {
        public class Cons_themes: TypeConstructorDescription {
            public var hash: Int64
            public var themes: [Api.Theme]
            public init(hash: Int64, themes: [Api.Theme]) {
                self.hash = hash
                self.themes = themes
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("themes", [("hash", ConstructorParameterDescription(self.hash)), ("themes", ConstructorParameterDescription(self.themes))])
            }
        }
        case themes(Cons_themes)
        case themesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .themes(let _data):
                if boxed {
                    buffer.appendInt32(-1707242387)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.themes.count))
                for item in _data.themes {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .themes(let _data):
                return ("themes", [("hash", ConstructorParameterDescription(_data.hash)), ("themes", ConstructorParameterDescription(_data.themes))])
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
                return Api.account.Themes.themes(Cons_themes(hash: _1!, themes: _2!))
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
        public class Cons_tmpPassword: TypeConstructorDescription {
            public var tmpPassword: Buffer
            public var validUntil: Int32
            public init(tmpPassword: Buffer, validUntil: Int32) {
                self.tmpPassword = tmpPassword
                self.validUntil = validUntil
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tmpPassword", [("tmpPassword", ConstructorParameterDescription(self.tmpPassword)), ("validUntil", ConstructorParameterDescription(self.validUntil))])
            }
        }
        case tmpPassword(Cons_tmpPassword)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tmpPassword(let _data):
                if boxed {
                    buffer.appendInt32(-614138572)
                }
                serializeBytes(_data.tmpPassword, buffer: buffer, boxed: false)
                serializeInt32(_data.validUntil, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tmpPassword(let _data):
                return ("tmpPassword", [("tmpPassword", ConstructorParameterDescription(_data.tmpPassword)), ("validUntil", ConstructorParameterDescription(_data.validUntil))])
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
                return Api.account.TmpPassword.tmpPassword(Cons_tmpPassword(tmpPassword: _1!, validUntil: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum WallPapers: TypeConstructorDescription {
        public class Cons_wallPapers: TypeConstructorDescription {
            public var hash: Int64
            public var wallpapers: [Api.WallPaper]
            public init(hash: Int64, wallpapers: [Api.WallPaper]) {
                self.hash = hash
                self.wallpapers = wallpapers
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("wallPapers", [("hash", ConstructorParameterDescription(self.hash)), ("wallpapers", ConstructorParameterDescription(self.wallpapers))])
            }
        }
        case wallPapers(Cons_wallPapers)
        case wallPapersNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .wallPapers(let _data):
                if boxed {
                    buffer.appendInt32(-842824308)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.wallpapers.count))
                for item in _data.wallpapers {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .wallPapers(let _data):
                return ("wallPapers", [("hash", ConstructorParameterDescription(_data.hash)), ("wallpapers", ConstructorParameterDescription(_data.wallpapers))])
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
                return Api.account.WallPapers.wallPapers(Cons_wallPapers(hash: _1!, wallpapers: _2!))
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
        public class Cons_webAuthorizations: TypeConstructorDescription {
            public var authorizations: [Api.WebAuthorization]
            public var users: [Api.User]
            public init(authorizations: [Api.WebAuthorization], users: [Api.User]) {
                self.authorizations = authorizations
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webAuthorizations", [("authorizations", ConstructorParameterDescription(self.authorizations)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case webAuthorizations(Cons_webAuthorizations)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webAuthorizations(let _data):
                if boxed {
                    buffer.appendInt32(-313079300)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.authorizations.count))
                for item in _data.authorizations {
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

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webAuthorizations(let _data):
                return ("webAuthorizations", [("authorizations", ConstructorParameterDescription(_data.authorizations)), ("users", ConstructorParameterDescription(_data.users))])
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
                return Api.account.WebAuthorizations.webAuthorizations(Cons_webAuthorizations(authorizations: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.account {
    enum WebBrowserSettings: TypeConstructorDescription {
        public class Cons_webBrowserSettings: TypeConstructorDescription {
            public var flags: Int32
            public var externalExceptions: [Api.WebDomainException]
            public var inappExceptions: [Api.WebDomainException]
            public var hash: Int64
            public init(flags: Int32, externalExceptions: [Api.WebDomainException], inappExceptions: [Api.WebDomainException], hash: Int64) {
                self.flags = flags
                self.externalExceptions = externalExceptions
                self.inappExceptions = inappExceptions
                self.hash = hash
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("webBrowserSettings", [("flags", ConstructorParameterDescription(self.flags)), ("externalExceptions", ConstructorParameterDescription(self.externalExceptions)), ("inappExceptions", ConstructorParameterDescription(self.inappExceptions)), ("hash", ConstructorParameterDescription(self.hash))])
            }
        }
        case webBrowserSettings(Cons_webBrowserSettings)
        case webBrowserSettingsNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webBrowserSettings(let _data):
                if boxed {
                    buffer.appendInt32(2045480115)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.externalExceptions.count))
                for item in _data.externalExceptions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.inappExceptions.count))
                for item in _data.inappExceptions {
                    item.serialize(buffer, true)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                break
            case .webBrowserSettingsNotModified:
                if boxed {
                    buffer.appendInt32(-1021538482)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .webBrowserSettings(let _data):
                return ("webBrowserSettings", [("flags", ConstructorParameterDescription(_data.flags)), ("externalExceptions", ConstructorParameterDescription(_data.externalExceptions)), ("inappExceptions", ConstructorParameterDescription(_data.inappExceptions)), ("hash", ConstructorParameterDescription(_data.hash))])
            case .webBrowserSettingsNotModified:
                return ("webBrowserSettingsNotModified", [])
            }
        }

        public static func parse_webBrowserSettings(_ reader: BufferReader) -> WebBrowserSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.WebDomainException]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebDomainException.self)
            }
            var _3: [Api.WebDomainException]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebDomainException.self)
            }
            var _4: Int64?
            _4 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.account.WebBrowserSettings.webBrowserSettings(Cons_webBrowserSettings(flags: _1!, externalExceptions: _2!, inappExceptions: _3!, hash: _4!))
            }
            else {
                return nil
            }
        }
        public static func parse_webBrowserSettingsNotModified(_ reader: BufferReader) -> WebBrowserSettings? {
            return Api.account.WebBrowserSettings.webBrowserSettingsNotModified
        }
    }
}
public extension Api.aicompose {
    enum Tones: TypeConstructorDescription {
        public class Cons_tones: TypeConstructorDescription {
            public var hash: Int64
            public var tones: [Api.AiComposeTone]
            public var users: [Api.User]
            public init(hash: Int64, tones: [Api.AiComposeTone], users: [Api.User]) {
                self.hash = hash
                self.tones = tones
                self.users = users
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("tones", [("hash", ConstructorParameterDescription(self.hash)), ("tones", ConstructorParameterDescription(self.tones)), ("users", ConstructorParameterDescription(self.users))])
            }
        }
        case tones(Cons_tones)
        case tonesNotModified

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .tones(let _data):
                if boxed {
                    buffer.appendInt32(1822232318)
                }
                serializeInt64(_data.hash, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.tones.count))
                for item in _data.tones {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .tonesNotModified:
                if boxed {
                    buffer.appendInt32(-1040948989)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .tones(let _data):
                return ("tones", [("hash", ConstructorParameterDescription(_data.hash)), ("tones", ConstructorParameterDescription(_data.tones)), ("users", ConstructorParameterDescription(_data.users))])
            case .tonesNotModified:
                return ("tonesNotModified", [])
            }
        }

        public static func parse_tones(_ reader: BufferReader) -> Tones? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Api.AiComposeTone]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.AiComposeTone.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.aicompose.Tones.tones(Cons_tones(hash: _1!, tones: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_tonesNotModified(_ reader: BufferReader) -> Tones? {
            return Api.aicompose.Tones.tonesNotModified
        }
    }
}
public extension Api.auth {
    enum Authorization: TypeConstructorDescription {
        public class Cons_authorization: TypeConstructorDescription {
            public var flags: Int32
            public var otherwiseReloginDays: Int32?
            public var tmpSessions: Int32?
            public var futureAuthToken: Buffer?
            public var user: Api.User
            public init(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User) {
                self.flags = flags
                self.otherwiseReloginDays = otherwiseReloginDays
                self.tmpSessions = tmpSessions
                self.futureAuthToken = futureAuthToken
                self.user = user
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("authorization", [("flags", ConstructorParameterDescription(self.flags)), ("otherwiseReloginDays", ConstructorParameterDescription(self.otherwiseReloginDays)), ("tmpSessions", ConstructorParameterDescription(self.tmpSessions)), ("futureAuthToken", ConstructorParameterDescription(self.futureAuthToken)), ("user", ConstructorParameterDescription(self.user))])
            }
        }
        public class Cons_authorizationSignUpRequired: TypeConstructorDescription {
            public var flags: Int32
            public var termsOfService: Api.help.TermsOfService?
            public init(flags: Int32, termsOfService: Api.help.TermsOfService?) {
                self.flags = flags
                self.termsOfService = termsOfService
            }
            public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
                return ("authorizationSignUpRequired", [("flags", ConstructorParameterDescription(self.flags)), ("termsOfService", ConstructorParameterDescription(self.termsOfService))])
            }
        }
        case authorization(Cons_authorization)
        case authorizationSignUpRequired(Cons_authorizationSignUpRequired)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .authorization(let _data):
                if boxed {
                    buffer.appendInt32(782418132)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.otherwiseReloginDays!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.tmpSessions!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeBytes(_data.futureAuthToken!, buffer: buffer, boxed: false)
                }
                _data.user.serialize(buffer, true)
                break
            case .authorizationSignUpRequired(let _data):
                if boxed {
                    buffer.appendInt32(1148485274)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.termsOfService!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {
            switch self {
            case .authorization(let _data):
                return ("authorization", [("flags", ConstructorParameterDescription(_data.flags)), ("otherwiseReloginDays", ConstructorParameterDescription(_data.otherwiseReloginDays)), ("tmpSessions", ConstructorParameterDescription(_data.tmpSessions)), ("futureAuthToken", ConstructorParameterDescription(_data.futureAuthToken)), ("user", ConstructorParameterDescription(_data.user))])
            case .authorizationSignUpRequired(let _data):
                return ("authorizationSignUpRequired", [("flags", ConstructorParameterDescription(_data.flags)), ("termsOfService", ConstructorParameterDescription(_data.termsOfService))])
            }
        }

        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1 ?? 0) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Buffer?
            if Int(_1 ?? 0) & Int(1 << 2) != 0 {
                _4 = parseBytes(reader)
            }
            var _5: Api.User?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.User
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1 ?? 0) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.auth.Authorization.authorization(Cons_authorization(flags: _1!, otherwiseReloginDays: _2, tmpSessions: _3, futureAuthToken: _4, user: _5!))
            }
            else {
                return nil
            }
        }
        public static func parse_authorizationSignUpRequired(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.help.TermsOfService?
            if Int(_1 ?? 0) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1 ?? 0) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.Authorization.authorizationSignUpRequired(Cons_authorizationSignUpRequired(flags: _1!, termsOfService: _2))
            }
            else {
                return nil
            }
        }
    }
}
