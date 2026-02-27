public extension Api.account {
    enum SavedMusicIds: TypeConstructorDescription {
        public class Cons_savedMusicIds {
            public var ids: [Int64]
            public init(ids: [Int64]) {
                self.ids = ids
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedMusicIds(let _data):
                return ("savedMusicIds", [("ids", _data.ids as Any)])
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
        public class Cons_savedRingtoneConverted {
            public var document: Api.Document
            public init(document: Api.Document) {
                self.document = document
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedRingtone:
                return ("savedRingtone", [])
            case .savedRingtoneConverted(let _data):
                return ("savedRingtoneConverted", [("document", _data.document as Any)])
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
        public class Cons_savedRingtones {
            public var hash: Int64
            public var ringtones: [Api.Document]
            public init(hash: Int64, ringtones: [Api.Document]) {
                self.hash = hash
                self.ringtones = ringtones
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedRingtones(let _data):
                return ("savedRingtones", [("hash", _data.hash as Any), ("ringtones", _data.ringtones as Any)])
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
        public class Cons_sentEmailCode {
            public var emailPattern: String
            public var length: Int32
            public init(emailPattern: String, length: Int32) {
                self.emailPattern = emailPattern
                self.length = length
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sentEmailCode(let _data):
                return ("sentEmailCode", [("emailPattern", _data.emailPattern as Any), ("length", _data.length as Any)])
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
        public class Cons_takeout {
            public var id: Int64
            public init(id: Int64) {
                self.id = id
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .takeout(let _data):
                return ("takeout", [("id", _data.id as Any)])
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
        public class Cons_themes {
            public var hash: Int64
            public var themes: [Api.Theme]
            public init(hash: Int64, themes: [Api.Theme]) {
                self.hash = hash
                self.themes = themes
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .themes(let _data):
                return ("themes", [("hash", _data.hash as Any), ("themes", _data.themes as Any)])
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
        public class Cons_tmpPassword {
            public var tmpPassword: Buffer
            public var validUntil: Int32
            public init(tmpPassword: Buffer, validUntil: Int32) {
                self.tmpPassword = tmpPassword
                self.validUntil = validUntil
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .tmpPassword(let _data):
                return ("tmpPassword", [("tmpPassword", _data.tmpPassword as Any), ("validUntil", _data.validUntil as Any)])
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
        public class Cons_wallPapers {
            public var hash: Int64
            public var wallpapers: [Api.WallPaper]
            public init(hash: Int64, wallpapers: [Api.WallPaper]) {
                self.hash = hash
                self.wallpapers = wallpapers
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .wallPapers(let _data):
                return ("wallPapers", [("hash", _data.hash as Any), ("wallpapers", _data.wallpapers as Any)])
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
        public class Cons_webAuthorizations {
            public var authorizations: [Api.WebAuthorization]
            public var users: [Api.User]
            public init(authorizations: [Api.WebAuthorization], users: [Api.User]) {
                self.authorizations = authorizations
                self.users = users
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .webAuthorizations(let _data):
                return ("webAuthorizations", [("authorizations", _data.authorizations as Any), ("users", _data.users as Any)])
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
public extension Api.auth {
    enum Authorization: TypeConstructorDescription {
        public class Cons_authorization {
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
        }
        public class Cons_authorizationSignUpRequired {
            public var flags: Int32
            public var termsOfService: Api.help.TermsOfService?
            public init(flags: Int32, termsOfService: Api.help.TermsOfService?) {
                self.flags = flags
                self.termsOfService = termsOfService
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .authorization(let _data):
                return ("authorization", [("flags", _data.flags as Any), ("otherwiseReloginDays", _data.otherwiseReloginDays as Any), ("tmpSessions", _data.tmpSessions as Any), ("futureAuthToken", _data.futureAuthToken as Any), ("user", _data.user as Any)])
            case .authorizationSignUpRequired(let _data):
                return ("authorizationSignUpRequired", [("flags", _data.flags as Any), ("termsOfService", _data.termsOfService as Any)])
            }
        }

        public static func parse_authorization(_ reader: BufferReader) -> Authorization? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseBytes(reader)
            }
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
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.help.TermsOfService
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.Authorization.authorizationSignUpRequired(Cons_authorizationSignUpRequired(flags: _1!, termsOfService: _2))
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
        public class Cons_exportedAuthorization {
            public var id: Int64
            public var bytes: Buffer
            public init(id: Int64, bytes: Buffer) {
                self.id = id
                self.bytes = bytes
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .exportedAuthorization(let _data):
                return ("exportedAuthorization", [("id", _data.id as Any), ("bytes", _data.bytes as Any)])
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
    enum LoggedOut: TypeConstructorDescription {
        public class Cons_loggedOut {
            public var flags: Int32
            public var futureAuthToken: Buffer?
            public init(flags: Int32, futureAuthToken: Buffer?) {
                self.flags = flags
                self.futureAuthToken = futureAuthToken
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .loggedOut(let _data):
                return ("loggedOut", [("flags", _data.flags as Any), ("futureAuthToken", _data.futureAuthToken as Any)])
            }
        }

        public static func parse_loggedOut(_ reader: BufferReader) -> LoggedOut? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseBytes(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
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
        public class Cons_loginToken {
            public var expires: Int32
            public var token: Buffer
            public init(expires: Int32, token: Buffer) {
                self.expires = expires
                self.token = token
            }
        }
        public class Cons_loginTokenMigrateTo {
            public var dcId: Int32
            public var token: Buffer
            public init(dcId: Int32, token: Buffer) {
                self.dcId = dcId
                self.token = token
            }
        }
        public class Cons_loginTokenSuccess {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .loginToken(let _data):
                return ("loginToken", [("expires", _data.expires as Any), ("token", _data.token as Any)])
            case .loginTokenMigrateTo(let _data):
                return ("loginTokenMigrateTo", [("dcId", _data.dcId as Any), ("token", _data.token as Any)])
            case .loginTokenSuccess(let _data):
                return ("loginTokenSuccess", [("authorization", _data.authorization as Any)])
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
        public class Cons_passkeyLoginOptions {
            public var options: Api.DataJSON
            public init(options: Api.DataJSON) {
                self.options = options
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .passkeyLoginOptions(let _data):
                return ("passkeyLoginOptions", [("options", _data.options as Any)])
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
        public class Cons_passwordRecovery {
            public var emailPattern: String
            public init(emailPattern: String) {
                self.emailPattern = emailPattern
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .passwordRecovery(let _data):
                return ("passwordRecovery", [("emailPattern", _data.emailPattern as Any)])
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
        public class Cons_sentCode {
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
        }
        public class Cons_sentCodePaymentRequired {
            public var storeProduct: String
            public var phoneCodeHash: String
            public var supportEmailAddress: String
            public var supportEmailSubject: String
            public var currency: String
            public var amount: Int64
            public init(storeProduct: String, phoneCodeHash: String, supportEmailAddress: String, supportEmailSubject: String, currency: String, amount: Int64) {
                self.storeProduct = storeProduct
                self.phoneCodeHash = phoneCodeHash
                self.supportEmailAddress = supportEmailAddress
                self.supportEmailSubject = supportEmailSubject
                self.currency = currency
                self.amount = amount
            }
        }
        public class Cons_sentCodeSuccess {
            public var authorization: Api.auth.Authorization
            public init(authorization: Api.auth.Authorization) {
                self.authorization = authorization
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
                    buffer.appendInt32(-527082948)
                }
                serializeString(_data.storeProduct, buffer: buffer, boxed: false)
                serializeString(_data.phoneCodeHash, buffer: buffer, boxed: false)
                serializeString(_data.supportEmailAddress, buffer: buffer, boxed: false)
                serializeString(_data.supportEmailSubject, buffer: buffer, boxed: false)
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sentCode(let _data):
                return ("sentCode", [("flags", _data.flags as Any), ("type", _data.type as Any), ("phoneCodeHash", _data.phoneCodeHash as Any), ("nextType", _data.nextType as Any), ("timeout", _data.timeout as Any)])
            case .sentCodePaymentRequired(let _data):
                return ("sentCodePaymentRequired", [("storeProduct", _data.storeProduct as Any), ("phoneCodeHash", _data.phoneCodeHash as Any), ("supportEmailAddress", _data.supportEmailAddress as Any), ("supportEmailSubject", _data.supportEmailSubject as Any), ("currency", _data.currency as Any), ("amount", _data.amount as Any)])
            case .sentCodeSuccess(let _data):
                return ("sentCodeSuccess", [("authorization", _data.authorization as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.auth.CodeType
                }
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
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
            var _5: String?
            _5 = parseString(reader)
            var _6: Int64?
            _6 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.auth.SentCode.sentCodePaymentRequired(Cons_sentCodePaymentRequired(storeProduct: _1!, phoneCodeHash: _2!, supportEmailAddress: _3!, supportEmailSubject: _4!, currency: _5!, amount: _6!))
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
        public class Cons_sentCodeTypeApp {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeCall {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeEmailCode {
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
        }
        public class Cons_sentCodeTypeFirebaseSms {
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
        }
        public class Cons_sentCodeTypeFlashCall {
            public var pattern: String
            public init(pattern: String) {
                self.pattern = pattern
            }
        }
        public class Cons_sentCodeTypeFragmentSms {
            public var url: String
            public var length: Int32
            public init(url: String, length: Int32) {
                self.url = url
                self.length = length
            }
        }
        public class Cons_sentCodeTypeMissedCall {
            public var prefix: String
            public var length: Int32
            public init(prefix: String, length: Int32) {
                self.prefix = prefix
                self.length = length
            }
        }
        public class Cons_sentCodeTypeSetUpEmailRequired {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        public class Cons_sentCodeTypeSms {
            public var length: Int32
            public init(length: Int32) {
                self.length = length
            }
        }
        public class Cons_sentCodeTypeSmsPhrase {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
            }
        }
        public class Cons_sentCodeTypeSmsWord {
            public var flags: Int32
            public var beginning: String?
            public init(flags: Int32, beginning: String?) {
                self.flags = flags
                self.beginning = beginning
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

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .sentCodeTypeApp(let _data):
                return ("sentCodeTypeApp", [("length", _data.length as Any)])
            case .sentCodeTypeCall(let _data):
                return ("sentCodeTypeCall", [("length", _data.length as Any)])
            case .sentCodeTypeEmailCode(let _data):
                return ("sentCodeTypeEmailCode", [("flags", _data.flags as Any), ("emailPattern", _data.emailPattern as Any), ("length", _data.length as Any), ("resetAvailablePeriod", _data.resetAvailablePeriod as Any), ("resetPendingDate", _data.resetPendingDate as Any)])
            case .sentCodeTypeFirebaseSms(let _data):
                return ("sentCodeTypeFirebaseSms", [("flags", _data.flags as Any), ("nonce", _data.nonce as Any), ("playIntegrityProjectId", _data.playIntegrityProjectId as Any), ("playIntegrityNonce", _data.playIntegrityNonce as Any), ("receipt", _data.receipt as Any), ("pushTimeout", _data.pushTimeout as Any), ("length", _data.length as Any)])
            case .sentCodeTypeFlashCall(let _data):
                return ("sentCodeTypeFlashCall", [("pattern", _data.pattern as Any)])
            case .sentCodeTypeFragmentSms(let _data):
                return ("sentCodeTypeFragmentSms", [("url", _data.url as Any), ("length", _data.length as Any)])
            case .sentCodeTypeMissedCall(let _data):
                return ("sentCodeTypeMissedCall", [("prefix", _data.prefix as Any), ("length", _data.length as Any)])
            case .sentCodeTypeSetUpEmailRequired(let _data):
                return ("sentCodeTypeSetUpEmailRequired", [("flags", _data.flags as Any)])
            case .sentCodeTypeSms(let _data):
                return ("sentCodeTypeSms", [("length", _data.length as Any)])
            case .sentCodeTypeSmsPhrase(let _data):
                return ("sentCodeTypeSmsPhrase", [("flags", _data.flags as Any), ("beginning", _data.beginning as Any)])
            case .sentCodeTypeSmsWord(let _data):
                return ("sentCodeTypeSmsWord", [("flags", _data.flags as Any), ("beginning", _data.beginning as Any)])
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
            if Int(_1!) & Int(1 << 3) != 0 {
                _4 = reader.readInt32()
            }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _5 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseBytes(reader)
            }
            var _3: Int64?
            if Int(_1!) & Int(1 << 2) != 0 {
                _3 = reader.readInt64()
            }
            var _4: Buffer?
            if Int(_1!) & Int(1 << 2) != 0 {
                _4 = parseBytes(reader)
            }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {
                _5 = parseString(reader)
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
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
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.auth.SentCodeType.sentCodeTypeSmsWord(Cons_sentCodeTypeSmsWord(flags: _1!, beginning: _2))
            }
            else {
                return nil
            }
        }
    }
}
