import TelegramApiObjC
public extension Api {
    enum StarsGiftOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsGiftOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsGiftOption(Cons_starsGiftOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsGiftOption(Cons_starsGiftOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsGiftOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsGiftOption] {
            return tlObjectsAt(object, offset).map { Api.StarsGiftOption(tlObject: $0) }
        }

    }
}
public extension Api.StarsGiftOption.Cons_starsGiftOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var storeProduct: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(604))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, stars)
        tlStoreReference(_tlObject, 40, storeProduct.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsGiveawayOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsGiveawayOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsGiveawayOption(Cons_starsGiveawayOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsGiveawayOption(Cons_starsGiveawayOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsGiveawayOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsGiveawayOption] {
            return tlObjectsAt(object, offset).map { Api.StarsGiveawayOption(tlObject: $0) }
        }

    }
}
public extension Api.StarsGiveawayOption.Cons_starsGiveawayOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var yearlyBoosts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var storeProduct: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var winners: [Api.StarsGiveawayWinnersOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsGiveawayWinnersOption.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, stars: Int64, yearlyBoosts: Int32, storeProduct: String?, currency: String, amount: Int64, winners: [Api.StarsGiveawayWinnersOption]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(950))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, stars)
        tlStore(_tlObject, 28, yearlyBoosts)
        tlStoreReference(_tlObject, 40, storeProduct.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        tlStoreReference(_tlObject, 64, winners.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsGiveawayWinnersOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsGiveawayWinnersOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsGiveawayWinnersOption(Cons_starsGiveawayWinnersOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsGiveawayWinnersOption(Cons_starsGiveawayWinnersOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsGiveawayWinnersOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsGiveawayWinnersOption] {
            return tlObjectsAt(object, offset).map { Api.StarsGiveawayWinnersOption(tlObject: $0) }
        }

    }
}
public extension Api.StarsGiveawayWinnersOption.Cons_starsGiveawayWinnersOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var perUserStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(flags: Int32, users: Int32, perUserStars: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(549))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, users)
        tlStore(_tlObject, 32, perUserStars)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsRating: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsRating {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsRating(Cons_starsRating)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsRating(Cons_starsRating(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsRating(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsRating] {
            return tlObjectsAt(object, offset).map { Api.StarsRating(tlObject: $0) }
        }

    }
}
public extension Api.StarsRating.Cons_starsRating {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var level: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currentLevelStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var nextLevelStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    init(flags: Int32, level: Int32, currentLevelStars: Int64, stars: Int64, nextLevelStars: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(176))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, level)
        tlStore(_tlObject, 32, currentLevelStars)
        tlStore(_tlObject, 40, stars)
        if let _tlValue = nextLevelStars { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsRevenueStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsRevenueStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsRevenueStatus(Cons_starsRevenueStatus)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsRevenueStatus(Cons_starsRevenueStatus(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsRevenueStatus(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsRevenueStatus] {
            return tlObjectsAt(object, offset).map { Api.StarsRevenueStatus(tlObject: $0) }
        }

    }
}
public extension Api.StarsRevenueStatus.Cons_starsRevenueStatus {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currentBalance: Api.StarsAmount {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var availableBalance: Api.StarsAmount {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var overallRevenue: Api.StarsAmount {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var nextWithdrawalAt: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, currentBalance: Api.StarsAmount, availableBalance: Api.StarsAmount, overallRevenue: Api.StarsAmount, nextWithdrawalAt: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1703))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, currentBalance.tlObject)
        tlStoreReference(_tlObject, 40, availableBalance.tlObject)
        tlStoreReference(_tlObject, 48, overallRevenue.tlObject)
        if let _tlValue = nextWithdrawalAt { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsSubscription: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsSubscription {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsSubscription(Cons_starsSubscription)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsSubscription(Cons_starsSubscription(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsSubscription(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsSubscription] {
            return tlObjectsAt(object, offset).map { Api.StarsSubscription(tlObject: $0) }
        }

    }
}
public extension Api.StarsSubscription.Cons_starsSubscription {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pricing: Api.StarsSubscriptionPricing {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsSubscriptionPricing(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var chatInviteHash: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var invoiceSlug: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    init(flags: Int32, id: String, peer: Api.Peer, untilDate: Int32, pricing: Api.StarsSubscriptionPricing, chatInviteHash: String?, title: String?, photo: Api.WebDocument?, invoiceSlug: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(289))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStore(_tlObject, 28, untilDate)
        tlStoreReference(_tlObject, 48, pricing.tlObject)
        tlStoreReference(_tlObject, 56, chatInviteHash.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, photo?.tlObject)
        tlStoreReference(_tlObject, 80, invoiceSlug.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsSubscriptionPricing: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsSubscriptionPricing {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsSubscriptionPricing(Cons_starsSubscriptionPricing)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsSubscriptionPricing(Cons_starsSubscriptionPricing(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsSubscriptionPricing(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsSubscriptionPricing] {
            return tlObjectsAt(object, offset).map { Api.StarsSubscriptionPricing(tlObject: $0) }
        }

    }
}
public extension Api.StarsSubscriptionPricing.Cons_starsSubscriptionPricing {
    @_alwaysEmitIntoClient var period: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(period: Int32, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(38))
        tlStore(_tlObject, 24, period)
        tlStore(_tlObject, 32, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsTopupOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsTopupOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsTopupOption(Cons_starsTopupOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsTopupOption(Cons_starsTopupOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsTopupOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsTopupOption] {
            return tlObjectsAt(object, offset).map { Api.StarsTopupOption(tlObject: $0) }
        }

    }
}
public extension Api.StarsTopupOption.Cons_starsTopupOption {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var storeProduct: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(flags: Int32, stars: Int64, storeProduct: String?, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(78))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, stars)
        tlStoreReference(_tlObject, 40, storeProduct.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsTransaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsTransaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsTransaction(Cons_starsTransaction)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsTransaction(Cons_starsTransaction(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsTransaction(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsTransaction] {
            return tlObjectsAt(object, offset).map { Api.StarsTransaction(tlObject: $0) }
        }

    }
}
public extension Api.StarsTransaction.Cons_starsTransaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var amount: Api.StarsAmount {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.StarsTransactionPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsTransactionPeer(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : tlStringAt(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var transactionDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var transactionUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var botPayload: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : tlBufferAt(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var extendedMedia: [Api.MessageMedia]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.MessageMedia.tlArray(self.tlObject, 136) } }
    }
    @_alwaysEmitIntoClient var subscriptionPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var giveawayPostId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stargift: Api.StarGift? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : Api.StarGift(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var floodskipNumber: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 4) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var starrefCommissionPermille: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 5) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var starrefPeer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var starrefAmount: Api.StarsAmount? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 160) ? nil : Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var paidMessages: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 6) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var premiumGiftMonths: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 7) ? tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var adsProceedsFromDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 8) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var adsProceedsToDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 168, 9) ? tlBase(self.tlObject).load(fromByteOffset: 68, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: String, amount: Api.StarsAmount, date: Int32, peer: Api.StarsTransactionPeer, title: String?, description: String?, photo: Api.WebDocument?, transactionDate: Int32?, transactionUrl: String?, botPayload: Buffer?, msgId: Int32?, extendedMedia: [Api.MessageMedia]?, subscriptionPeriod: Int32?, giveawayPostId: Int32?, stargift: Api.StarGift?, floodskipNumber: Int32?, starrefCommissionPermille: Int32?, starrefPeer: Api.Peer?, starrefAmount: Api.StarsAmount?, paidMessages: Int32?, premiumGiftMonths: Int32?, adsProceedsFromDate: Int32?, adsProceedsToDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(119))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 72, id as NSString)
        tlStoreReference(_tlObject, 80, amount.tlObject)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 88, peer.tlObject)
        tlStoreReference(_tlObject, 96, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 104, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 112, photo?.tlObject)
        if let _tlValue = transactionDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 120, transactionUrl.map { value in value as NSString })
        tlStoreReference(_tlObject, 128, botPayload.map { value in value.makeData() as NSData })
        if let _tlValue = msgId { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 136, extendedMedia.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = subscriptionPeriod { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = giveawayPostId { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        tlStoreReference(_tlObject, 144, stargift?.tlObject)
        if let _tlValue = floodskipNumber { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = starrefCommissionPermille { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 152, starrefPeer?.tlObject)
        tlStoreReference(_tlObject, 160, starrefAmount?.tlObject)
        if let _tlValue = paidMessages { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 6 }
        if let _tlValue = premiumGiftMonths { tlStore(_tlObject, 60, _tlValue); _tlPresent |= 1 << 7 }
        if let _tlValue = adsProceedsFromDate { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 8 }
        if let _tlValue = adsProceedsToDate { tlStore(_tlObject, 68, _tlValue); _tlPresent |= 1 << 9 }
        tlStore(_tlObject, 168, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsTransactionPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsTransactionPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsTransactionPeer(Cons_starsTransactionPeer)
        case starsTransactionPeerAPI
        case starsTransactionPeerAds
        case starsTransactionPeerAppStore
        case starsTransactionPeerFragment
        case starsTransactionPeerPlayMarket
        case starsTransactionPeerPremiumBot
        case starsTransactionPeerUnsupported


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsTransactionPeer(Cons_starsTransactionPeer(tlObject: object))
            case 1:
                self = .starsTransactionPeerAPI
            case 2:
                self = .starsTransactionPeerAds
            case 3:
                self = .starsTransactionPeerAppStore
            case 4:
                self = .starsTransactionPeerFragment
            case 5:
                self = .starsTransactionPeerPlayMarket
            case 6:
                self = .starsTransactionPeerPremiumBot
            case 7:
                self = .starsTransactionPeerUnsupported
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsTransactionPeer(let _data):
                return _data.tlObject
            case .starsTransactionPeerAPI:
                return TLObjectSingleton(TLApiConstructorAt(1657))
            case .starsTransactionPeerAds:
                return TLObjectSingleton(TLApiConstructorAt(615))
            case .starsTransactionPeerAppStore:
                return TLObjectSingleton(TLApiConstructorAt(1179))
            case .starsTransactionPeerFragment:
                return TLObjectSingleton(TLApiConstructorAt(1538))
            case .starsTransactionPeerPlayMarket:
                return TLObjectSingleton(TLApiConstructorAt(793))
            case .starsTransactionPeerPremiumBot:
                return TLObjectSingleton(TLApiConstructorAt(248))
            case .starsTransactionPeerUnsupported:
                return TLObjectSingleton(TLApiConstructorAt(958))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsTransactionPeer] {
            return tlObjectsAt(object, offset).map { Api.StarsTransactionPeer(tlObject: $0) }
        }

    }
}
public extension Api.StarsTransactionPeer.Cons_starsTransactionPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.Peer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1419))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsAbsValueAndPrev: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsAbsValueAndPrev {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsAbsValueAndPrev(Cons_statsAbsValueAndPrev)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsAbsValueAndPrev(Cons_statsAbsValueAndPrev(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsAbsValueAndPrev(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsAbsValueAndPrev] {
            return tlObjectsAt(object, offset).map { Api.StatsAbsValueAndPrev(tlObject: $0) }
        }

    }
}
public extension Api.StatsAbsValueAndPrev.Cons_statsAbsValueAndPrev {
    @_alwaysEmitIntoClient var current: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var previous: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    init(current: Double, previous: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1354))
        tlStore(_tlObject, 24, current)
        tlStore(_tlObject, 32, previous)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsDateRangeDays: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsDateRangeDays {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsDateRangeDays(Cons_statsDateRangeDays)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsDateRangeDays(Cons_statsDateRangeDays(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsDateRangeDays(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsDateRangeDays] {
            return tlObjectsAt(object, offset).map { Api.StatsDateRangeDays(tlObject: $0) }
        }

    }
}
public extension Api.StatsDateRangeDays.Cons_statsDateRangeDays {
    @_alwaysEmitIntoClient var minDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var maxDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(minDate: Int32, maxDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1197))
        tlStore(_tlObject, 24, minDate)
        tlStore(_tlObject, 28, maxDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsGraph: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsGraph {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_statsGraphAsync {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_statsGraphError {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsGraph(Cons_statsGraph)
        case statsGraphAsync(Cons_statsGraphAsync)
        case statsGraphError(Cons_statsGraphError)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsGraph(Cons_statsGraph(tlObject: object))
            case 1:
                self = .statsGraphAsync(Cons_statsGraphAsync(tlObject: object))
            case 2:
                self = .statsGraphError(Cons_statsGraphError(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsGraph(let _data):
                return _data.tlObject
            case .statsGraphAsync(let _data):
                return _data.tlObject
            case .statsGraphError(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsGraph] {
            return tlObjectsAt(object, offset).map { Api.StatsGraph(tlObject: $0) }
        }

    }
}
public extension Api.StatsGraph.Cons_statsGraph {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var json: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var zoomToken: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, json: Api.DataJSON, zoomToken: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(913))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, json.tlObject)
        tlStoreReference(_tlObject, 40, zoomToken.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StatsGraph.Cons_statsGraphAsync {
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(token: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(475))
        tlStoreReference(_tlObject, 24, token as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StatsGraph.Cons_statsGraphError {
    @_alwaysEmitIntoClient var error: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(error: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1269))
        tlStoreReference(_tlObject, 24, error as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsGroupTopAdmin: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsGroupTopAdmin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsGroupTopAdmin(Cons_statsGroupTopAdmin)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsGroupTopAdmin(Cons_statsGroupTopAdmin(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsGroupTopAdmin(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsGroupTopAdmin] {
            return tlObjectsAt(object, offset).map { Api.StatsGroupTopAdmin(tlObject: $0) }
        }

    }
}
public extension Api.StatsGroupTopAdmin.Cons_statsGroupTopAdmin {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var deleted: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var kicked: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var banned: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(userId: Int64, deleted: Int32, kicked: Int32, banned: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1415))
        tlStore(_tlObject, 40, userId)
        tlStore(_tlObject, 24, deleted)
        tlStore(_tlObject, 28, kicked)
        tlStore(_tlObject, 32, banned)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsGroupTopInviter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsGroupTopInviter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsGroupTopInviter(Cons_statsGroupTopInviter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsGroupTopInviter(Cons_statsGroupTopInviter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsGroupTopInviter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsGroupTopInviter] {
            return tlObjectsAt(object, offset).map { Api.StatsGroupTopInviter(tlObject: $0) }
        }

    }
}
public extension Api.StatsGroupTopInviter.Cons_statsGroupTopInviter {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var invitations: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(userId: Int64, invitations: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(541))
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 24, invitations)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsGroupTopPoster: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsGroupTopPoster {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsGroupTopPoster(Cons_statsGroupTopPoster)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsGroupTopPoster(Cons_statsGroupTopPoster(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsGroupTopPoster(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsGroupTopPoster] {
            return tlObjectsAt(object, offset).map { Api.StatsGroupTopPoster(tlObject: $0) }
        }

    }
}
public extension Api.StatsGroupTopPoster.Cons_statsGroupTopPoster {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var messages: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var avgChars: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(userId: Int64, messages: Int32, avgChars: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1017))
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 24, messages)
        tlStore(_tlObject, 28, avgChars)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsPercentValue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsPercentValue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsPercentValue(Cons_statsPercentValue)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsPercentValue(Cons_statsPercentValue(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsPercentValue(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsPercentValue] {
            return tlObjectsAt(object, offset).map { Api.StatsPercentValue(tlObject: $0) }
        }

    }
}
public extension Api.StatsPercentValue.Cons_statsPercentValue {
    @_alwaysEmitIntoClient var part: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var total: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    init(part: Double, total: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1359))
        tlStore(_tlObject, 24, part)
        tlStore(_tlObject, 32, total)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StatsURL: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_statsURL {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case statsURL(Cons_statsURL)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .statsURL(Cons_statsURL(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .statsURL(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StatsURL] {
            return tlObjectsAt(object, offset).map { Api.StatsURL(tlObject: $0) }
        }

    }
}
public extension Api.StatsURL.Cons_statsURL {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(457))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StickerKeyword: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerKeyword {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerKeyword(Cons_stickerKeyword)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerKeyword(Cons_stickerKeyword(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerKeyword(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StickerKeyword] {
            return tlObjectsAt(object, offset).map { Api.StickerKeyword(tlObject: $0) }
        }

    }
}
public extension Api.StickerKeyword.Cons_stickerKeyword {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var keyword: [String] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringsAt(self.tlObject, 32) } }
    }
    init(documentId: Int64, keyword: [String]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1690))
        tlStore(_tlObject, 24, documentId)
        tlStoreReference(_tlObject, 32, keyword as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StickerPack: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerPack {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerPack(Cons_stickerPack)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerPack(Cons_stickerPack(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerPack(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StickerPack] {
            return tlObjectsAt(object, offset).map { Api.StickerPack(tlObject: $0) }
        }

    }
}
public extension Api.StickerPack.Cons_stickerPack {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var documents: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 32) } }
    }
    init(emoticon: String, documents: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(114))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        tlStoreReference(_tlObject, 32, tlPackInt64(documents) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StickerSet: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerSet(Cons_stickerSet)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerSet(Cons_stickerSet(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerSet(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StickerSet] {
            return tlObjectsAt(object, offset).map { Api.StickerSet(tlObject: $0) }
        }

    }
}
public extension Api.StickerSet.Cons_stickerSet {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var installedDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var thumbs: [Api.PhotoSize]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.PhotoSize.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var thumbDcId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var thumbVersion: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var thumbDocumentId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 3) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    init(flags: Int32, installedDate: Int32?, id: Int64, accessHash: Int64, title: String, shortName: String, thumbs: [Api.PhotoSize]?, thumbDcId: Int32?, thumbVersion: Int32?, thumbDocumentId: Int64?, count: Int32, hash: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(285))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = installedDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, id)
        tlStore(_tlObject, 56, accessHash)
        tlStoreReference(_tlObject, 64, title as NSString)
        tlStoreReference(_tlObject, 72, shortName as NSString)
        tlStoreReference(_tlObject, 80, thumbs.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = thumbDcId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = thumbVersion { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = thumbDocumentId { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 40, count)
        tlStore(_tlObject, 44, hash)
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StickerSetCovered: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerSetCovered {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_stickerSetFullCovered {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_stickerSetMultiCovered {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_stickerSetNoCovered {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerSetCovered(Cons_stickerSetCovered)
        case stickerSetFullCovered(Cons_stickerSetFullCovered)
        case stickerSetMultiCovered(Cons_stickerSetMultiCovered)
        case stickerSetNoCovered(Cons_stickerSetNoCovered)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerSetCovered(Cons_stickerSetCovered(tlObject: object))
            case 1:
                self = .stickerSetFullCovered(Cons_stickerSetFullCovered(tlObject: object))
            case 2:
                self = .stickerSetMultiCovered(Cons_stickerSetMultiCovered(tlObject: object))
            case 3:
                self = .stickerSetNoCovered(Cons_stickerSetNoCovered(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerSetCovered(let _data):
                return _data.tlObject
            case .stickerSetFullCovered(let _data):
                return _data.tlObject
            case .stickerSetMultiCovered(let _data):
                return _data.tlObject
            case .stickerSetNoCovered(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StickerSetCovered] {
            return tlObjectsAt(object, offset).map { Api.StickerSetCovered(tlObject: $0) }
        }

    }
}
public extension Api.StickerSetCovered.Cons_stickerSetCovered {
    @_alwaysEmitIntoClient var set: Api.StickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var cover: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(set: Api.StickerSet, cover: Api.Document) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(640))
        tlStoreReference(_tlObject, 24, set.tlObject)
        tlStoreReference(_tlObject, 32, cover.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StickerSetCovered.Cons_stickerSetFullCovered {
    @_alwaysEmitIntoClient var set: Api.StickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var packs: [Api.StickerPack] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerPack.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var keywords: [Api.StickerKeyword] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerKeyword.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 48) } }
    }
    init(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(419))
        tlStoreReference(_tlObject, 24, set.tlObject)
        tlStoreReference(_tlObject, 32, packs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, keywords.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, documents.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StickerSetCovered.Cons_stickerSetMultiCovered {
    @_alwaysEmitIntoClient var set: Api.StickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var covers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(set: Api.StickerSet, covers: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(330))
        tlStoreReference(_tlObject, 24, set.tlObject)
        tlStoreReference(_tlObject, 32, covers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StickerSetCovered.Cons_stickerSetNoCovered {
    @_alwaysEmitIntoClient var set: Api.StickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(set: Api.StickerSet) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(773))
        tlStoreReference(_tlObject, 24, set.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StoriesStealthMode: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storiesStealthMode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storiesStealthMode(Cons_storiesStealthMode)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storiesStealthMode(Cons_storiesStealthMode(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storiesStealthMode(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoriesStealthMode] {
            return tlObjectsAt(object, offset).map { Api.StoriesStealthMode(tlObject: $0) }
        }

    }
}
public extension Api.StoriesStealthMode.Cons_storiesStealthMode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var activeUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var cooldownUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, activeUntilDate: Int32?, cooldownUntilDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(722))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = activeUntilDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = cooldownUntilDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StoryAlbum: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyAlbum {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyAlbum(Cons_storyAlbum)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyAlbum(Cons_storyAlbum(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyAlbum(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryAlbum] {
            return tlObjectsAt(object, offset).map { Api.StoryAlbum(tlObject: $0) }
        }

    }
}
public extension Api.StoryAlbum.Cons_storyAlbum {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var albumId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var iconPhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var iconVideo: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, albumId: Int32, title: String, iconPhoto: Api.Photo?, iconVideo: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(937))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, albumId)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, iconPhoto?.tlObject)
        tlStoreReference(_tlObject, 48, iconVideo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StoryFwdHeader: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyFwdHeader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyFwdHeader(Cons_storyFwdHeader)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyFwdHeader(Cons_storyFwdHeader(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyFwdHeader(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryFwdHeader] {
            return tlObjectsAt(object, offset).map { Api.StoryFwdHeader(tlObject: $0) }
        }

    }
}
public extension Api.StoryFwdHeader.Cons_storyFwdHeader {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var from: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var fromName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var storyId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1211))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, from?.tlObject)
        tlStoreReference(_tlObject, 40, fromName.map { value in value as NSString })
        if let _tlValue = storyId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyItem {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyItemDeleted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyItemSkipped {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyItem(Cons_storyItem)
        case storyItemDeleted(Cons_storyItemDeleted)
        case storyItemSkipped(Cons_storyItemSkipped)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyItem(Cons_storyItem(tlObject: object))
            case 1:
                self = .storyItemDeleted(Cons_storyItemDeleted(tlObject: object))
            case 2:
                self = .storyItemSkipped(Cons_storyItemSkipped(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyItem(let _data):
                return _data.tlObject
            case .storyItemDeleted(let _data):
                return _data.tlObject
            case .storyItemSkipped(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryItem] {
            return tlObjectsAt(object, offset).map { Api.StoryItem(tlObject: $0) }
        }

    }
}
public extension Api.StoryItem.Cons_storyItem {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var fwdFrom: Api.StoryFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.StoryFwdHeader(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var caption: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageEntity.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var mediaAreas: [Api.MediaArea]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MediaArea.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var privacy: [Api.PrivacyRule]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.PrivacyRule.tlArray(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var views: Api.StoryViews? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.StoryViews(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var sentReaction: Api.Reaction? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.Reaction(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var albums: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlInt32sAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var music: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    init(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?, music: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(141))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 40, fromId?.tlObject)
        tlStoreReference(_tlObject, 48, fwdFrom?.tlObject)
        tlStore(_tlObject, 36, expireDate)
        tlStoreReference(_tlObject, 56, caption.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, media.tlObject)
        tlStoreReference(_tlObject, 80, mediaAreas.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, privacy.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 96, views?.tlObject)
        tlStoreReference(_tlObject, 104, sentReaction?.tlObject)
        tlStoreReference(_tlObject, 112, albums.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 120, music?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryItem.Cons_storyItemDeleted {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(531))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryItem.Cons_storyItemSkipped {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(flags: Int32, id: Int32, date: Int32, expireDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1710))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, expireDate)
        self.init(tlObject: _tlObject)
    }
}
