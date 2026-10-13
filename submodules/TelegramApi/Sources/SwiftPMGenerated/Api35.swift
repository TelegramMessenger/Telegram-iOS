import TelegramApiObjC
public extension Api.account {
    enum Takeout: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_takeout {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case takeout(Cons_takeout)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .takeout(Cons_takeout(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .takeout(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.Takeout] {
            return tlObjectsAt(object, offset).map { Api.account.Takeout(tlObject: $0) }
        }

    }
}
public extension Api.account.Takeout.Cons_takeout {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(503))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum Themes: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_themes {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case themes(Cons_themes)
        case themesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .themes(Cons_themes(tlObject: object))
            case 1:
                self = .themesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .themes(let _data):
                return _data.tlObject
            case .themesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1624))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.Themes] {
            return tlObjectsAt(object, offset).map { Api.account.Themes(tlObject: $0) }
        }

    }
}
public extension Api.account.Themes.Cons_themes {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var themes: [Api.Theme] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Theme.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, themes: [Api.Theme]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(999))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, themes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum TmpPassword: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tmpPassword {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tmpPassword(Cons_tmpPassword)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tmpPassword(Cons_tmpPassword(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tmpPassword(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.TmpPassword] {
            return tlObjectsAt(object, offset).map { Api.account.TmpPassword(tlObject: $0) }
        }

    }
}
public extension Api.account.TmpPassword.Cons_tmpPassword {
    @_alwaysEmitIntoClient var tmpPassword: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var validUntil: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(tmpPassword: Buffer, validUntil: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1438))
        tlStoreReference(_tlObject, 32, tmpPassword.makeData() as NSData)
        tlStore(_tlObject, 24, validUntil)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum WallPapers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_wallPapers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case wallPapers(Cons_wallPapers)
        case wallPapersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .wallPapers(Cons_wallPapers(tlObject: object))
            case 1:
                self = .wallPapersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .wallPapers(let _data):
                return _data.tlObject
            case .wallPapersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(185))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.WallPapers] {
            return tlObjectsAt(object, offset).map { Api.account.WallPapers(tlObject: $0) }
        }

    }
}
public extension Api.account.WallPapers.Cons_wallPapers {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var wallpapers: [Api.WallPaper] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WallPaper.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, wallpapers: [Api.WallPaper]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1370))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, wallpapers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum WebAuthorizations: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webAuthorizations {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webAuthorizations(Cons_webAuthorizations)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webAuthorizations(Cons_webAuthorizations(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webAuthorizations(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.WebAuthorizations] {
            return tlObjectsAt(object, offset).map { Api.account.WebAuthorizations(tlObject: $0) }
        }

    }
}
public extension Api.account.WebAuthorizations.Cons_webAuthorizations {
    @_alwaysEmitIntoClient var authorizations: [Api.WebAuthorization] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WebAuthorization.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(authorizations: [Api.WebAuthorization], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1570))
        tlStoreReference(_tlObject, 24, authorizations.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum WebBrowserSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webBrowserSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webBrowserSettings(Cons_webBrowserSettings)
        case webBrowserSettingsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webBrowserSettings(Cons_webBrowserSettings(tlObject: object))
            case 1:
                self = .webBrowserSettingsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webBrowserSettings(let _data):
                return _data.tlObject
            case .webBrowserSettingsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1299))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.WebBrowserSettings] {
            return tlObjectsAt(object, offset).map { Api.account.WebBrowserSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.WebBrowserSettings.Cons_webBrowserSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var externalExceptions: [Api.WebDomainException] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WebDomainException.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var inappExceptions: [Api.WebDomainException] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WebDomainException.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    init(flags: Int32, externalExceptions: [Api.WebDomainException], inappExceptions: [Api.WebDomainException], hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(783))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, externalExceptions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, inappExceptions.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 48, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.aicompose {
    enum Tones: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tones {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tones(Cons_tones)
        case tonesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tones(Cons_tones(tlObject: object))
            case 1:
                self = .tonesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tones(let _data):
                return _data.tlObject
            case .tonesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1293))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.aicompose.Tones] {
            return tlObjectsAt(object, offset).map { Api.aicompose.Tones(tlObject: $0) }
        }

    }
}
public extension Api.aicompose.Tones.Cons_tones {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var tones: [Api.AiComposeTone] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AiComposeTone.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(hash: Int64, tones: [Api.AiComposeTone], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(697))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, tones.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum Authorization: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_authorization {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_authorizationSignUpRequired {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case authorization(Cons_authorization)
        case authorizationSignUpRequired(Cons_authorizationSignUpRequired)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .authorization(Cons_authorization(tlObject: object))
            case 1:
                self = .authorizationSignUpRequired(Cons_authorizationSignUpRequired(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .authorization(let _data):
                return _data.tlObject
            case .authorizationSignUpRequired(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.Authorization] {
            return tlObjectsAt(object, offset).map { Api.auth.Authorization(tlObject: $0) }
        }

    }
}
public extension Api.auth.Authorization.Cons_authorization {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var otherwiseReloginDays: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var tmpSessions: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var futureAuthToken: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var user: Api.User {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, otherwiseReloginDays: Int32?, tmpSessions: Int32?, futureAuthToken: Buffer?, user: Api.User) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(291))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = otherwiseReloginDays { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = tmpSessions { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 40, futureAuthToken.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, user.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.Authorization.Cons_authorizationSignUpRequired {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var termsOfService: Api.help.TermsOfService? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.help.TermsOfService(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, termsOfService: Api.help.TermsOfService?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(444))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, termsOfService?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum CodeType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case codeTypeCall
        case codeTypeFlashCall
        case codeTypeFragmentSms
        case codeTypeMissedCall
        case codeTypeSms


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .codeTypeCall
            case 1:
                self = .codeTypeFlashCall
            case 2:
                self = .codeTypeFragmentSms
            case 3:
                self = .codeTypeMissedCall
            case 4:
                self = .codeTypeSms
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .codeTypeCall:
                return TLObjectSingleton(TLApiConstructorAt(741))
            case .codeTypeFlashCall:
                return TLObjectSingleton(TLApiConstructorAt(236))
            case .codeTypeFragmentSms:
                return TLObjectSingleton(TLApiConstructorAt(49))
            case .codeTypeMissedCall:
                return TLObjectSingleton(TLApiConstructorAt(1408))
            case .codeTypeSms:
                return TLObjectSingleton(TLApiConstructorAt(733))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.CodeType] {
            return tlObjectsAt(object, offset).map { Api.auth.CodeType(tlObject: $0) }
        }

    }
}
public extension Api.auth {
    enum ExportedAuthorization: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedAuthorization {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedAuthorization(Cons_exportedAuthorization)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedAuthorization(Cons_exportedAuthorization(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedAuthorization(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.ExportedAuthorization] {
            return tlObjectsAt(object, offset).map { Api.auth.ExportedAuthorization(tlObject: $0) }
        }

    }
}
public extension Api.auth.ExportedAuthorization.Cons_exportedAuthorization {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(id: Int64, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1177))
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 32, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum FirebasePnvIntent: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_firebasePnvIntent {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case firebasePnvIntent(Cons_firebasePnvIntent)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .firebasePnvIntent(Cons_firebasePnvIntent(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .firebasePnvIntent(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.FirebasePnvIntent] {
            return tlObjectsAt(object, offset).map { Api.auth.FirebasePnvIntent(tlObject: $0) }
        }

    }
}
public extension Api.auth.FirebasePnvIntent.Cons_firebasePnvIntent {
    @_alwaysEmitIntoClient var nonce: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var digitalCredentialPayload: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(nonce: String, digitalCredentialPayload: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1469))
        tlStoreReference(_tlObject, 24, nonce as NSString)
        tlStoreReference(_tlObject, 32, digitalCredentialPayload as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum LoggedOut: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_loggedOut {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case loggedOut(Cons_loggedOut)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .loggedOut(Cons_loggedOut(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .loggedOut(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.LoggedOut] {
            return tlObjectsAt(object, offset).map { Api.auth.LoggedOut(tlObject: $0) }
        }

    }
}
public extension Api.auth.LoggedOut.Cons_loggedOut {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var futureAuthToken: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlBufferAt(self.tlObject, 32) } }
    }
    init(flags: Int32, futureAuthToken: Buffer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1310))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, futureAuthToken.map { value in value.makeData() as NSData })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum LoginToken: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_loginToken {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_loginTokenMigrateTo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_loginTokenSuccess {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case loginToken(Cons_loginToken)
        case loginTokenMigrateTo(Cons_loginTokenMigrateTo)
        case loginTokenSuccess(Cons_loginTokenSuccess)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .loginToken(Cons_loginToken(tlObject: object))
            case 1:
                self = .loginTokenMigrateTo(Cons_loginTokenMigrateTo(tlObject: object))
            case 2:
                self = .loginTokenSuccess(Cons_loginTokenSuccess(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .loginToken(let _data):
                return _data.tlObject
            case .loginTokenMigrateTo(let _data):
                return _data.tlObject
            case .loginTokenSuccess(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.LoginToken] {
            return tlObjectsAt(object, offset).map { Api.auth.LoginToken(tlObject: $0) }
        }

    }
}
public extension Api.auth.LoginToken.Cons_loginToken {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var token: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(expires: Int32, token: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(628))
        tlStore(_tlObject, 24, expires)
        tlStoreReference(_tlObject, 32, token.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.LoginToken.Cons_loginTokenMigrateTo {
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var token: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(dcId: Int32, token: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(45))
        tlStore(_tlObject, 24, dcId)
        tlStoreReference(_tlObject, 32, token.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.LoginToken.Cons_loginTokenSuccess {
    @_alwaysEmitIntoClient var authorization: Api.auth.Authorization {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.auth.Authorization(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(authorization: Api.auth.Authorization) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(364))
        tlStoreReference(_tlObject, 24, authorization.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum PasskeyLoginOptions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passkeyLoginOptions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passkeyLoginOptions(Cons_passkeyLoginOptions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passkeyLoginOptions(Cons_passkeyLoginOptions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passkeyLoginOptions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.PasskeyLoginOptions] {
            return tlObjectsAt(object, offset).map { Api.auth.PasskeyLoginOptions(tlObject: $0) }
        }

    }
}
public extension Api.auth.PasskeyLoginOptions.Cons_passkeyLoginOptions {
    @_alwaysEmitIntoClient var options: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(options: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1489))
        tlStoreReference(_tlObject, 24, options.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum PasswordRecovery: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passwordRecovery {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passwordRecovery(Cons_passwordRecovery)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passwordRecovery(Cons_passwordRecovery(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passwordRecovery(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.PasswordRecovery] {
            return tlObjectsAt(object, offset).map { Api.auth.PasswordRecovery(tlObject: $0) }
        }

    }
}
public extension Api.auth.PasswordRecovery.Cons_passwordRecovery {
    @_alwaysEmitIntoClient var emailPattern: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emailPattern: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(120))
        tlStoreReference(_tlObject, 24, emailPattern as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum SentCode: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sentCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodePaymentRequired {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeSuccess {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sentCode(Cons_sentCode)
        case sentCodePaymentRequired(Cons_sentCodePaymentRequired)
        case sentCodeSuccess(Cons_sentCodeSuccess)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sentCode(Cons_sentCode(tlObject: object))
            case 1:
                self = .sentCodePaymentRequired(Cons_sentCodePaymentRequired(tlObject: object))
            case 2:
                self = .sentCodeSuccess(Cons_sentCodeSuccess(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sentCode(let _data):
                return _data.tlObject
            case .sentCodePaymentRequired(let _data):
                return _data.tlObject
            case .sentCodeSuccess(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.SentCode] {
            return tlObjectsAt(object, offset).map { Api.auth.SentCode(tlObject: $0) }
        }

    }
}
public extension Api.auth.SentCode.Cons_sentCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var type: Api.auth.SentCodeType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.auth.SentCodeType(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var phoneCodeHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var nextType: Api.auth.CodeType? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.auth.CodeType(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var timeout: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, type: Api.auth.SentCodeType, phoneCodeHash: String, nextType: Api.auth.CodeType?, timeout: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(604))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, type.tlObject)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, nextType?.tlObject)
        if let _tlValue = timeout { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCode.Cons_sentCodePaymentRequired {
    @_alwaysEmitIntoClient var storeProduct: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var phoneCodeHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var supportEmailAddress: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var supportEmailSubject: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var premiumDays: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) } }
    }
    init(storeProduct: String, phoneCodeHash: String, supportEmailAddress: String, supportEmailSubject: String, premiumDays: Int32, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1648))
        tlStoreReference(_tlObject, 32, storeProduct as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStoreReference(_tlObject, 48, supportEmailAddress as NSString)
        tlStoreReference(_tlObject, 56, supportEmailSubject as NSString)
        tlStore(_tlObject, 24, premiumDays)
        tlStoreReference(_tlObject, 64, currency as NSString)
        tlStore(_tlObject, 72, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCode.Cons_sentCodeSuccess {
    @_alwaysEmitIntoClient var authorization: Api.auth.Authorization {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.auth.Authorization(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(authorization: Api.auth.Authorization) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(243))
        tlStoreReference(_tlObject, 24, authorization.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth {
    enum SentCodeType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sentCodeTypeApp {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeEmailCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeFirebaseSms {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeFlashCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeFragmentSms {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeMissedCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeSetUpEmailRequired {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeSms {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeSmsPhrase {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentCodeTypeSmsWord {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
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


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sentCodeTypeApp(Cons_sentCodeTypeApp(tlObject: object))
            case 1:
                self = .sentCodeTypeCall(Cons_sentCodeTypeCall(tlObject: object))
            case 2:
                self = .sentCodeTypeEmailCode(Cons_sentCodeTypeEmailCode(tlObject: object))
            case 3:
                self = .sentCodeTypeFirebaseSms(Cons_sentCodeTypeFirebaseSms(tlObject: object))
            case 4:
                self = .sentCodeTypeFlashCall(Cons_sentCodeTypeFlashCall(tlObject: object))
            case 5:
                self = .sentCodeTypeFragmentSms(Cons_sentCodeTypeFragmentSms(tlObject: object))
            case 6:
                self = .sentCodeTypeMissedCall(Cons_sentCodeTypeMissedCall(tlObject: object))
            case 7:
                self = .sentCodeTypeSetUpEmailRequired(Cons_sentCodeTypeSetUpEmailRequired(tlObject: object))
            case 8:
                self = .sentCodeTypeSms(Cons_sentCodeTypeSms(tlObject: object))
            case 9:
                self = .sentCodeTypeSmsPhrase(Cons_sentCodeTypeSmsPhrase(tlObject: object))
            case 10:
                self = .sentCodeTypeSmsWord(Cons_sentCodeTypeSmsWord(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sentCodeTypeApp(let _data):
                return _data.tlObject
            case .sentCodeTypeCall(let _data):
                return _data.tlObject
            case .sentCodeTypeEmailCode(let _data):
                return _data.tlObject
            case .sentCodeTypeFirebaseSms(let _data):
                return _data.tlObject
            case .sentCodeTypeFlashCall(let _data):
                return _data.tlObject
            case .sentCodeTypeFragmentSms(let _data):
                return _data.tlObject
            case .sentCodeTypeMissedCall(let _data):
                return _data.tlObject
            case .sentCodeTypeSetUpEmailRequired(let _data):
                return _data.tlObject
            case .sentCodeTypeSms(let _data):
                return _data.tlObject
            case .sentCodeTypeSmsPhrase(let _data):
                return _data.tlObject
            case .sentCodeTypeSmsWord(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.auth.SentCodeType] {
            return tlObjectsAt(object, offset).map { Api.auth.SentCodeType(tlObject: $0) }
        }

    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeApp {
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(393))
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeCall {
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(541))
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeEmailCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var emailPattern: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var resetAvailablePeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var resetPendingDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, emailPattern: String, length: Int32, resetAvailablePeriod: Int32?, resetPendingDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1625))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, emailPattern as NSString)
        tlStore(_tlObject, 28, length)
        if let _tlValue = resetAvailablePeriod { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = resetPendingDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeFirebaseSms {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nonce: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var playIntegrityProjectId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var playIntegrityNonce: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlBufferAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var receipt: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var pushTimeout: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, nonce: Buffer?, playIntegrityProjectId: Int64?, playIntegrityNonce: Buffer?, receipt: String?, pushTimeout: Int32?, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(5))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, nonce.map { value in value.makeData() as NSData })
        if let _tlValue = playIntegrityProjectId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, playIntegrityNonce.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 64, receipt.map { value in value as NSString })
        if let _tlValue = pushTimeout { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 32, length)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeFlashCall {
    @_alwaysEmitIntoClient var pattern: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(pattern: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1116))
        tlStoreReference(_tlObject, 24, pattern as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeFragmentSms {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(url: String, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1428))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeMissedCall {
    @_alwaysEmitIntoClient var prefix: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(prefix: String, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(834))
        tlStoreReference(_tlObject, 32, prefix as NSString)
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeSetUpEmailRequired {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1081))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeSms {
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1277))
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeSmsPhrase {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var beginning: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, beginning: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1169))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, beginning.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.auth.SentCodeType.Cons_sentCodeTypeSmsWord {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var beginning: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, beginning: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1071))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, beginning.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.bots {
    enum AccessSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_accessSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case accessSettings(Cons_accessSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .accessSettings(Cons_accessSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .accessSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.bots.AccessSettings] {
            return tlObjectsAt(object, offset).map { Api.bots.AccessSettings(tlObject: $0) }
        }

    }
}
public extension Api.bots.AccessSettings.Cons_accessSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var addUsers: [Api.User]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.User.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, addUsers: [Api.User]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1456))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, addUsers.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
