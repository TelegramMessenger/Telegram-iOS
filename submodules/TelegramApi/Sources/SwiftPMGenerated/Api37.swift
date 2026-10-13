import TelegramApiObjC
public extension Api.fragment {
    enum CollectibleInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_collectibleInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case collectibleInfo(Cons_collectibleInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .collectibleInfo(Cons_collectibleInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .collectibleInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.fragment.CollectibleInfo] {
            return tlObjectsAt(object, offset).map { Api.fragment.CollectibleInfo(tlObject: $0) }
        }

    }
}
public extension Api.fragment.CollectibleInfo.Cons_collectibleInfo {
    @_alwaysEmitIntoClient var purchaseDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var cryptoCurrency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var cryptoAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    init(purchaseDate: Int32, currency: String, amount: Int64, cryptoCurrency: String, cryptoAmount: Int64, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(704))
        tlStore(_tlObject, 24, purchaseDate)
        tlStoreReference(_tlObject, 32, currency as NSString)
        tlStore(_tlObject, 40, amount)
        tlStoreReference(_tlObject, 48, cryptoCurrency as NSString)
        tlStore(_tlObject, 56, cryptoAmount)
        tlStoreReference(_tlObject, 64, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum AppConfig: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_appConfig {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case appConfig(Cons_appConfig)
        case appConfigNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .appConfig(Cons_appConfig(tlObject: object))
            case 1:
                self = .appConfigNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .appConfig(let _data):
                return _data.tlObject
            case .appConfigNotModified:
                return TLObjectSingleton(TLApiConstructorAt(804))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.AppConfig] {
            return tlObjectsAt(object, offset).map { Api.help.AppConfig(tlObject: $0) }
        }

    }
}
public extension Api.help.AppConfig.Cons_appConfig {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var config: Api.JSONValue {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.JSONValue(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(hash: Int32, config: Api.JSONValue) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1455))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, config.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum AppUpdate: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_appUpdate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case appUpdate(Cons_appUpdate)
        case noAppUpdate


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .appUpdate(Cons_appUpdate(tlObject: object))
            case 1:
                self = .noAppUpdate
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .appUpdate(let _data):
                return _data.tlObject
            case .noAppUpdate:
                return TLObjectSingleton(TLApiConstructorAt(1315))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.AppUpdate] {
            return tlObjectsAt(object, offset).map { Api.help.AppUpdate(tlObject: $0) }
        }

    }
}
public extension Api.help.AppUpdate.Cons_appUpdate {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var version: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageEntity.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var sticker: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, id: Int32, version: String, text: String, entities: [Api.MessageEntity], document: Api.Document?, url: String?, sticker: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1365))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 32, version as NSString)
        tlStoreReference(_tlObject, 40, text as NSString)
        tlStoreReference(_tlObject, 48, entities.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, document?.tlObject)
        tlStoreReference(_tlObject, 64, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, sticker?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum CountriesList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_countriesList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case countriesList(Cons_countriesList)
        case countriesListNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .countriesList(Cons_countriesList(tlObject: object))
            case 1:
                self = .countriesListNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .countriesList(let _data):
                return _data.tlObject
            case .countriesListNotModified:
                return TLObjectSingleton(TLApiConstructorAt(946))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.CountriesList] {
            return tlObjectsAt(object, offset).map { Api.help.CountriesList(tlObject: $0) }
        }

    }
}
public extension Api.help.CountriesList.Cons_countriesList {
    @_alwaysEmitIntoClient var countries: [Api.help.Country] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.help.Country.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(countries: [Api.help.Country], hash: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(869))
        tlStoreReference(_tlObject, 32, countries.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum Country: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_country {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case country(Cons_country)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .country(Cons_country(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .country(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.Country] {
            return tlObjectsAt(object, offset).map { Api.help.Country(tlObject: $0) }
        }

    }
}
public extension Api.help.Country.Cons_country {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var iso2: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var defaultName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var name: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var countryCodes: [Api.help.CountryCode] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.help.CountryCode.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, iso2: String, defaultName: String, name: String?, countryCodes: [Api.help.CountryCode]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1305))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, iso2 as NSString)
        tlStoreReference(_tlObject, 40, defaultName as NSString)
        tlStoreReference(_tlObject, 48, name.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, countryCodes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum CountryCode: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_countryCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case countryCode(Cons_countryCode)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .countryCode(Cons_countryCode(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .countryCode(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.CountryCode] {
            return tlObjectsAt(object, offset).map { Api.help.CountryCode(tlObject: $0) }
        }

    }
}
public extension Api.help.CountryCode.Cons_countryCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var countryCode: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var prefixes: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringsAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var patterns: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringsAt(self.tlObject, 48) } }
    }
    init(flags: Int32, countryCode: String, prefixes: [String]?, patterns: [String]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(431))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, countryCode as NSString)
        tlStoreReference(_tlObject, 40, prefixes.map { value in value as NSArray })
        tlStoreReference(_tlObject, 48, patterns.map { value in value as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum DeepLinkInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_deepLinkInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case deepLinkInfo(Cons_deepLinkInfo)
        case deepLinkInfoEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .deepLinkInfo(Cons_deepLinkInfo(tlObject: object))
            case 1:
                self = .deepLinkInfoEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .deepLinkInfo(let _data):
                return _data.tlObject
            case .deepLinkInfoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(659))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.DeepLinkInfo] {
            return tlObjectsAt(object, offset).map { Api.help.DeepLinkInfo(tlObject: $0) }
        }

    }
}
public extension Api.help.DeepLinkInfo.Cons_deepLinkInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, message: String, entities: [Api.MessageEntity]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(682))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum InviteText: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inviteText {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inviteText(Cons_inviteText)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inviteText(Cons_inviteText(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inviteText(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.InviteText] {
            return tlObjectsAt(object, offset).map { Api.help.InviteText(tlObject: $0) }
        }

    }
}
public extension Api.help.InviteText.Cons_inviteText {
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(message: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(162))
        tlStoreReference(_tlObject, 24, message as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PassportConfig: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passportConfig {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passportConfig(Cons_passportConfig)
        case passportConfigNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passportConfig(Cons_passportConfig(tlObject: object))
            case 1:
                self = .passportConfigNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passportConfig(let _data):
                return _data.tlObject
            case .passportConfigNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1274))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PassportConfig] {
            return tlObjectsAt(object, offset).map { Api.help.PassportConfig(tlObject: $0) }
        }

    }
}
public extension Api.help.PassportConfig.Cons_passportConfig {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var countriesLangs: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(hash: Int32, countriesLangs: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1052))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, countriesLangs.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PeerColorOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerColorOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerColorOption(Cons_peerColorOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerColorOption(Cons_peerColorOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerColorOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PeerColorOption] {
            return tlObjectsAt(object, offset).map { Api.help.PeerColorOption(tlObject: $0) }
        }

    }
}
public extension Api.help.PeerColorOption.Cons_peerColorOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var colorId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var colors: Api.help.PeerColorSet? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.help.PeerColorSet(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var darkColors: Api.help.PeerColorSet? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.help.PeerColorSet(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var channelMinLevel: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var groupMinLevel: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, colorId: Int32, colors: Api.help.PeerColorSet?, darkColors: Api.help.PeerColorSet?, channelMinLevel: Int32?, groupMinLevel: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1133))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, colorId)
        tlStoreReference(_tlObject, 40, colors?.tlObject)
        tlStoreReference(_tlObject, 48, darkColors?.tlObject)
        if let _tlValue = channelMinLevel { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = groupMinLevel { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PeerColorSet: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerColorProfileSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_peerColorSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerColorProfileSet(Cons_peerColorProfileSet)
        case peerColorSet(Cons_peerColorSet)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerColorProfileSet(Cons_peerColorProfileSet(tlObject: object))
            case 1:
                self = .peerColorSet(Cons_peerColorSet(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerColorProfileSet(let _data):
                return _data.tlObject
            case .peerColorSet(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PeerColorSet] {
            return tlObjectsAt(object, offset).map { Api.help.PeerColorSet(tlObject: $0) }
        }

    }
}
public extension Api.help.PeerColorSet.Cons_peerColorProfileSet {
    @_alwaysEmitIntoClient var paletteColors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var bgColors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var storyColors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 40) } }
    }
    init(paletteColors: [Int32], bgColors: [Int32], storyColors: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(760))
        tlStoreReference(_tlObject, 24, tlPackInt32(paletteColors) as NSData)
        tlStoreReference(_tlObject, 32, tlPackInt32(bgColors) as NSData)
        tlStoreReference(_tlObject, 40, tlPackInt32(storyColors) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help.PeerColorSet.Cons_peerColorSet {
    @_alwaysEmitIntoClient var colors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 24) } }
    }
    init(colors: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(252))
        tlStoreReference(_tlObject, 24, tlPackInt32(colors) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PeerColors: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerColors {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerColors(Cons_peerColors)
        case peerColorsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerColors(Cons_peerColors(tlObject: object))
            case 1:
                self = .peerColorsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerColors(let _data):
                return _data.tlObject
            case .peerColorsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(276))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PeerColors] {
            return tlObjectsAt(object, offset).map { Api.help.PeerColors(tlObject: $0) }
        }

    }
}
public extension Api.help.PeerColors.Cons_peerColors {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var colors: [Api.help.PeerColorOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.help.PeerColorOption.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int32, colors: [Api.help.PeerColorOption]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(8))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, colors.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PremiumPromo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_premiumPromo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case premiumPromo(Cons_premiumPromo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .premiumPromo(Cons_premiumPromo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .premiumPromo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PremiumPromo] {
            return tlObjectsAt(object, offset).map { Api.help.PremiumPromo(tlObject: $0) }
        }

    }
}
public extension Api.help.PremiumPromo.Cons_premiumPromo {
    @_alwaysEmitIntoClient var statusText: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var statusEntities: [Api.MessageEntity] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageEntity.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var videoSections: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var videos: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var periodOptions: [Api.PremiumSubscriptionOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PremiumSubscriptionOption.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(statusText: String, statusEntities: [Api.MessageEntity], videoSections: [String], videos: [Api.Document], periodOptions: [Api.PremiumSubscriptionOption], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(540))
        tlStoreReference(_tlObject, 24, statusText as NSString)
        tlStoreReference(_tlObject, 32, statusEntities.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, videoSections as NSArray)
        tlStoreReference(_tlObject, 48, videos.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, periodOptions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum PromoData: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_promoData {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_promoDataEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case promoData(Cons_promoData)
        case promoDataEmpty(Cons_promoDataEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .promoData(Cons_promoData(tlObject: object))
            case 1:
                self = .promoDataEmpty(Cons_promoDataEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .promoData(let _data):
                return _data.tlObject
            case .promoDataEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.PromoData] {
            return tlObjectsAt(object, offset).map { Api.help.PromoData(tlObject: $0) }
        }

    }
}
public extension Api.help.PromoData.Cons_promoData {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var psaType: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var psaMessage: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var pendingSuggestions: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var dismissedSuggestions: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var customPendingSuggestion: Api.PendingSuggestion? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.PendingSuggestion(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 88) } }
    }
    init(flags: Int32, expires: Int32, peer: Api.Peer?, psaType: String?, psaMessage: String?, pendingSuggestions: [String], dismissedSuggestions: [String], customPendingSuggestion: Api.PendingSuggestion?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(56))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, expires)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStoreReference(_tlObject, 40, psaType.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, psaMessage.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, pendingSuggestions as NSArray)
        tlStoreReference(_tlObject, 64, dismissedSuggestions as NSArray)
        tlStoreReference(_tlObject, 72, customPendingSuggestion?.tlObject)
        tlStoreReference(_tlObject, 80, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 88, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help.PromoData.Cons_promoDataEmpty {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(985))
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum RecentMeUrls: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_recentMeUrls {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case recentMeUrls(Cons_recentMeUrls)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .recentMeUrls(Cons_recentMeUrls(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .recentMeUrls(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.RecentMeUrls] {
            return tlObjectsAt(object, offset).map { Api.help.RecentMeUrls(tlObject: $0) }
        }

    }
}
public extension Api.help.RecentMeUrls.Cons_recentMeUrls {
    @_alwaysEmitIntoClient var urls: [Api.RecentMeUrl] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RecentMeUrl.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(urls: [Api.RecentMeUrl], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(88))
        tlStoreReference(_tlObject, 24, urls.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum Support: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_support {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case support(Cons_support)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .support(Cons_support(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .support(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.Support] {
            return tlObjectsAt(object, offset).map { Api.help.Support(tlObject: $0) }
        }

    }
}
public extension Api.help.Support.Cons_support {
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var user: Api.User {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(phoneNumber: String, user: Api.User) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(149))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, user.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum SupportName: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_supportName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case supportName(Cons_supportName)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .supportName(Cons_supportName(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .supportName(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.SupportName] {
            return tlObjectsAt(object, offset).map { Api.help.SupportName(tlObject: $0) }
        }

    }
}
public extension Api.help.SupportName.Cons_supportName {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(name: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(897))
        tlStoreReference(_tlObject, 24, name as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum TermsOfService: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_termsOfService {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case termsOfService(Cons_termsOfService)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .termsOfService(Cons_termsOfService(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .termsOfService(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.TermsOfService] {
            return tlObjectsAt(object, offset).map { Api.help.TermsOfService(tlObject: $0) }
        }

    }
}
public extension Api.help.TermsOfService.Cons_termsOfService {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageEntity.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var minAgeConfirm: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Api.DataJSON, text: String, entities: [Api.MessageEntity], minAgeConfirm: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(777))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        tlStoreReference(_tlObject, 40, text as NSString)
        tlStoreReference(_tlObject, 48, entities.map { item in item.tlObject } as NSArray)
        if let _tlValue = minAgeConfirm { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum TermsOfServiceUpdate: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_termsOfServiceUpdate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_termsOfServiceUpdateEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case termsOfServiceUpdate(Cons_termsOfServiceUpdate)
        case termsOfServiceUpdateEmpty(Cons_termsOfServiceUpdateEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .termsOfServiceUpdate(Cons_termsOfServiceUpdate(tlObject: object))
            case 1:
                self = .termsOfServiceUpdateEmpty(Cons_termsOfServiceUpdateEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .termsOfServiceUpdate(let _data):
                return _data.tlObject
            case .termsOfServiceUpdateEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.TermsOfServiceUpdate] {
            return tlObjectsAt(object, offset).map { Api.help.TermsOfServiceUpdate(tlObject: $0) }
        }

    }
}
public extension Api.help.TermsOfServiceUpdate.Cons_termsOfServiceUpdate {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var termsOfService: Api.help.TermsOfService {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.help.TermsOfService(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(expires: Int32, termsOfService: Api.help.TermsOfService) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(264))
        tlStore(_tlObject, 24, expires)
        tlStoreReference(_tlObject, 32, termsOfService.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help.TermsOfServiceUpdate.Cons_termsOfServiceUpdateEmpty {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1495))
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum TimezonesList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_timezonesList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case timezonesList(Cons_timezonesList)
        case timezonesListNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .timezonesList(Cons_timezonesList(tlObject: object))
            case 1:
                self = .timezonesListNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .timezonesList(let _data):
                return _data.tlObject
            case .timezonesListNotModified:
                return TLObjectSingleton(TLApiConstructorAt(970))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.TimezonesList] {
            return tlObjectsAt(object, offset).map { Api.help.TimezonesList(tlObject: $0) }
        }

    }
}
public extension Api.help.TimezonesList.Cons_timezonesList {
    @_alwaysEmitIntoClient var timezones: [Api.Timezone] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Timezone.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(timezones: [Api.Timezone], hash: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(795))
        tlStoreReference(_tlObject, 32, timezones.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.help {
    enum UserInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userInfo(Cons_userInfo)
        case userInfoEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userInfo(Cons_userInfo(tlObject: object))
            case 1:
                self = .userInfoEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userInfo(let _data):
                return _data.tlObject
            case .userInfoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1621))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.help.UserInfo] {
            return tlObjectsAt(object, offset).map { Api.help.UserInfo(tlObject: $0) }
        }

    }
}
public extension Api.help.UserInfo.Cons_userInfo {
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var author: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(message: String, entities: [Api.MessageEntity], author: String, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(13))
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, author as NSString)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum AffectedFoundMessages: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_affectedFoundMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case affectedFoundMessages(Cons_affectedFoundMessages)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .affectedFoundMessages(Cons_affectedFoundMessages(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .affectedFoundMessages(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AffectedFoundMessages] {
            return tlObjectsAt(object, offset).map { Api.messages.AffectedFoundMessages(tlObject: $0) }
        }

    }
}
public extension Api.messages.AffectedFoundMessages.Cons_affectedFoundMessages {
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var messages: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 40) } }
    }
    init(pts: Int32, ptsCount: Int32, offset: Int32, messages: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1588))
        tlStore(_tlObject, 24, pts)
        tlStore(_tlObject, 28, ptsCount)
        tlStore(_tlObject, 32, offset)
        tlStoreReference(_tlObject, 40, tlPackInt32(messages) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum AffectedHistory: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_affectedHistory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case affectedHistory(Cons_affectedHistory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .affectedHistory(Cons_affectedHistory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .affectedHistory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AffectedHistory] {
            return tlObjectsAt(object, offset).map { Api.messages.AffectedHistory(tlObject: $0) }
        }

    }
}
public extension Api.messages.AffectedHistory.Cons_affectedHistory {
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(pts: Int32, ptsCount: Int32, offset: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1180))
        tlStore(_tlObject, 24, pts)
        tlStore(_tlObject, 28, ptsCount)
        tlStore(_tlObject, 32, offset)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum AffectedMessages: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_affectedMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case affectedMessages(Cons_affectedMessages)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .affectedMessages(Cons_affectedMessages(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .affectedMessages(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AffectedMessages] {
            return tlObjectsAt(object, offset).map { Api.messages.AffectedMessages(tlObject: $0) }
        }

    }
}
public extension Api.messages.AffectedMessages.Cons_affectedMessages {
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(pts: Int32, ptsCount: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(853))
        tlStore(_tlObject, 24, pts)
        tlStore(_tlObject, 28, ptsCount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum AllStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_allStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case allStickers(Cons_allStickers)
        case allStickersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .allStickers(Cons_allStickers(tlObject: object))
            case 1:
                self = .allStickersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .allStickers(let _data):
                return _data.tlObject
            case .allStickersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1530))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AllStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.AllStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.AllStickers.Cons_allStickers {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var sets: [Api.StickerSet] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, sets: [Api.StickerSet]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1368))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, sets.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ArchivedStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_archivedStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case archivedStickers(Cons_archivedStickers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .archivedStickers(Cons_archivedStickers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .archivedStickers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ArchivedStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.ArchivedStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.ArchivedStickers.Cons_archivedStickers {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sets: [Api.StickerSetCovered] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, sets: [Api.StickerSetCovered]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(516))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, sets.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum AvailableEffects: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_availableEffects {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case availableEffects(Cons_availableEffects)
        case availableEffectsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .availableEffects(Cons_availableEffects(tlObject: object))
            case 1:
                self = .availableEffectsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .availableEffects(let _data):
                return _data.tlObject
            case .availableEffectsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1389))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AvailableEffects] {
            return tlObjectsAt(object, offset).map { Api.messages.AvailableEffects(tlObject: $0) }
        }

    }
}
public extension Api.messages.AvailableEffects.Cons_availableEffects {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var effects: [Api.AvailableEffect] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AvailableEffect.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 40) } }
    }
    init(hash: Int32, effects: [Api.AvailableEffect], documents: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1258))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, effects.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, documents.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
