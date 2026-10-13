import TelegramApiObjC
public extension Api.payments {
    enum StarsStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsStatus(Cons_starsStatus)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsStatus(Cons_starsStatus(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsStatus(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarsStatus] {
            return tlObjectsAt(object, offset).map { Api.payments.StarsStatus(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarsStatus.Cons_starsStatus {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var balance: Api.StarsAmount {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var subscriptions: [Api.StarsSubscription]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.StarsSubscription.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var subscriptionsNextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var subscriptionsMissingBalance: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var history: [Api.StarsTransaction]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.StarsTransaction.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 88) } }
    }
    init(flags: Int32, balance: Api.StarsAmount, subscriptions: [Api.StarsSubscription]?, subscriptionsNextOffset: String?, subscriptionsMissingBalance: Int64?, history: [Api.StarsTransaction]?, nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(694))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, balance.tlObject)
        tlStoreReference(_tlObject, 40, subscriptions.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, subscriptionsNextOffset.map { value in value as NSString })
        if let _tlValue = subscriptionsMissingBalance { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, history.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 88, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum SuggestedStarRefBots: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_suggestedStarRefBots {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case suggestedStarRefBots(Cons_suggestedStarRefBots)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .suggestedStarRefBots(Cons_suggestedStarRefBots(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .suggestedStarRefBots(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.SuggestedStarRefBots] {
            return tlObjectsAt(object, offset).map { Api.payments.SuggestedStarRefBots(tlObject: $0) }
        }

    }
}
public extension Api.payments.SuggestedStarRefBots.Cons_suggestedStarRefBots {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var suggestedBots: [Api.StarRefProgram] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarRefProgram.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, count: Int32, suggestedBots: [Api.StarRefProgram], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1185))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, suggestedBots.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum UniqueStarGift: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_uniqueStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case uniqueStarGift(Cons_uniqueStarGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .uniqueStarGift(Cons_uniqueStarGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .uniqueStarGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.UniqueStarGift] {
            return tlObjectsAt(object, offset).map { Api.payments.UniqueStarGift(tlObject: $0) }
        }

    }
}
public extension Api.payments.UniqueStarGift.Cons_uniqueStarGift {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(gift: Api.StarGift, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(423))
        tlStoreReference(_tlObject, 24, gift.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum UniqueStarGiftValueInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_uniqueStarGiftValueInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case uniqueStarGiftValueInfo(Cons_uniqueStarGiftValueInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .uniqueStarGiftValueInfo(Cons_uniqueStarGiftValueInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .uniqueStarGiftValueInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.UniqueStarGiftValueInfo] {
            return tlObjectsAt(object, offset).map { Api.payments.UniqueStarGiftValueInfo(tlObject: $0) }
        }

    }
}
public extension Api.payments.UniqueStarGiftValueInfo.Cons_uniqueStarGiftValueInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var value: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var initialSaleDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var initialSaleStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var initialSalePrice: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var lastSaleDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var lastSalePrice: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 1) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var floorPrice: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 2) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var averagePrice: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 3) ? tlBase(self.tlObject).load(fromByteOffset: 96, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var listedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 4) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fragmentListedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 112, 5) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fragmentListedUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : tlStringAt(self.tlObject, 104) } }
    }
    init(flags: Int32, currency: String, value: Int64, initialSaleDate: Int32, initialSaleStars: Int64, initialSalePrice: Int64, lastSaleDate: Int32?, lastSalePrice: Int64?, floorPrice: Int64?, averagePrice: Int64?, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(529))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, value)
        tlStore(_tlObject, 28, initialSaleDate)
        tlStore(_tlObject, 64, initialSaleStars)
        tlStore(_tlObject, 72, initialSalePrice)
        if let _tlValue = lastSaleDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = lastSalePrice { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = floorPrice { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = averagePrice { tlStore(_tlObject, 96, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = listedCount { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = fragmentListedCount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 104, fragmentListedUrl.map { value in value as NSString })
        tlStore(_tlObject, 112, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum ValidatedRequestedInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_validatedRequestedInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case validatedRequestedInfo(Cons_validatedRequestedInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .validatedRequestedInfo(Cons_validatedRequestedInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .validatedRequestedInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.ValidatedRequestedInfo] {
            return tlObjectsAt(object, offset).map { Api.payments.ValidatedRequestedInfo(tlObject: $0) }
        }

    }
}
public extension Api.payments.ValidatedRequestedInfo.Cons_validatedRequestedInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var shippingOptions: [Api.ShippingOption]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ShippingOption.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, id: String?, shippingOptions: [Api.ShippingOption]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1383))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, shippingOptions.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum ExportedGroupCallInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedGroupCallInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedGroupCallInvite(Cons_exportedGroupCallInvite)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedGroupCallInvite(Cons_exportedGroupCallInvite(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedGroupCallInvite(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.ExportedGroupCallInvite] {
            return tlObjectsAt(object, offset).map { Api.phone.ExportedGroupCallInvite(tlObject: $0) }
        }

    }
}
public extension Api.phone.ExportedGroupCallInvite.Cons_exportedGroupCallInvite {
    @_alwaysEmitIntoClient var link: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(link: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(219))
        tlStoreReference(_tlObject, 24, link as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum GroupCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCall(Cons_groupCall)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCall(Cons_groupCall(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCall(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.GroupCall] {
            return tlObjectsAt(object, offset).map { Api.phone.GroupCall(tlObject: $0) }
        }

    }
}
public extension Api.phone.GroupCall.Cons_groupCall {
    @_alwaysEmitIntoClient var call: Api.GroupCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCall(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var participants: [Api.GroupCallParticipant] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipant.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var participantsNextOffset: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(call: Api.GroupCall, participants: [Api.GroupCallParticipant], participantsNextOffset: String, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1025))
        tlStoreReference(_tlObject, 24, call.tlObject)
        tlStoreReference(_tlObject, 32, participants.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, participantsNextOffset as NSString)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum GroupCallStars: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallStars(Cons_groupCallStars)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallStars(Cons_groupCallStars(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallStars(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.GroupCallStars] {
            return tlObjectsAt(object, offset).map { Api.phone.GroupCallStars(tlObject: $0) }
        }

    }
}
public extension Api.phone.GroupCallStars.Cons_groupCallStars {
    @_alwaysEmitIntoClient var totalStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var topDonors: [Api.GroupCallDonor] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallDonor.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(totalStars: Int64, topDonors: [Api.GroupCallDonor], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1016))
        tlStore(_tlObject, 24, totalStars)
        tlStoreReference(_tlObject, 32, topDonors.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum GroupCallStreamChannels: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallStreamChannels {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallStreamChannels(Cons_groupCallStreamChannels)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallStreamChannels(Cons_groupCallStreamChannels(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallStreamChannels(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.GroupCallStreamChannels] {
            return tlObjectsAt(object, offset).map { Api.phone.GroupCallStreamChannels(tlObject: $0) }
        }

    }
}
public extension Api.phone.GroupCallStreamChannels.Cons_groupCallStreamChannels {
    @_alwaysEmitIntoClient var channels: [Api.GroupCallStreamChannel] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallStreamChannel.tlArray(self.tlObject, 24) } }
    }
    init(channels: [Api.GroupCallStreamChannel]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1381))
        tlStoreReference(_tlObject, 24, channels.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum GroupCallStreamRtmpUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallStreamRtmpUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallStreamRtmpUrl(Cons_groupCallStreamRtmpUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallStreamRtmpUrl(Cons_groupCallStreamRtmpUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallStreamRtmpUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.GroupCallStreamRtmpUrl] {
            return tlObjectsAt(object, offset).map { Api.phone.GroupCallStreamRtmpUrl(tlObject: $0) }
        }

    }
}
public extension Api.phone.GroupCallStreamRtmpUrl.Cons_groupCallStreamRtmpUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var key: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(url: String, key: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(283))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, key as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum GroupParticipants: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupParticipants(Cons_groupParticipants)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupParticipants(Cons_groupParticipants(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupParticipants(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.GroupParticipants] {
            return tlObjectsAt(object, offset).map { Api.phone.GroupParticipants(tlObject: $0) }
        }

    }
}
public extension Api.phone.GroupParticipants.Cons_groupParticipants {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var participants: [Api.GroupCallParticipant] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipant.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(count: Int32, participants: [Api.GroupCallParticipant], nextOffset: String, chats: [Api.Chat], users: [Api.User], version: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1625))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, participants.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset as NSString)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 28, version)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum JoinAsPeers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_joinAsPeers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case joinAsPeers(Cons_joinAsPeers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .joinAsPeers(Cons_joinAsPeers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .joinAsPeers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.JoinAsPeers] {
            return tlObjectsAt(object, offset).map { Api.phone.JoinAsPeers(tlObject: $0) }
        }

    }
}
public extension Api.phone.JoinAsPeers.Cons_joinAsPeers {
    @_alwaysEmitIntoClient var peers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(peers: [Api.Peer], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1144))
        tlStoreReference(_tlObject, 24, peers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.phone {
    enum PhoneCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_phoneCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case phoneCall(Cons_phoneCall)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .phoneCall(Cons_phoneCall(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .phoneCall(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.phone.PhoneCall] {
            return tlObjectsAt(object, offset).map { Api.phone.PhoneCall(tlObject: $0) }
        }

    }
}
public extension Api.phone.PhoneCall.Cons_phoneCall {
    @_alwaysEmitIntoClient var phoneCall: Api.PhoneCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PhoneCall(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(phoneCall: Api.PhoneCall, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1561))
        tlStoreReference(_tlObject, 24, phoneCall.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.photos {
    enum Photo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_photo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case photo(Cons_photo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .photo(Cons_photo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .photo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.photos.Photo] {
            return tlObjectsAt(object, offset).map { Api.photos.Photo(tlObject: $0) }
        }

    }
}
public extension Api.photos.Photo.Cons_photo {
    @_alwaysEmitIntoClient var photo: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(photo: Api.Photo, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(218))
        tlStoreReference(_tlObject, 24, photo.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.photos {
    enum Photos: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_photos {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_photosSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case photos(Cons_photos)
        case photosSlice(Cons_photosSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .photos(Cons_photos(tlObject: object))
            case 1:
                self = .photosSlice(Cons_photosSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .photos(let _data):
                return _data.tlObject
            case .photosSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.photos.Photos] {
            return tlObjectsAt(object, offset).map { Api.photos.Photos(tlObject: $0) }
        }

    }
}
public extension Api.photos.Photos.Cons_photos {
    @_alwaysEmitIntoClient var photos: [Api.Photo] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(photos: [Api.Photo], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(908))
        tlStoreReference(_tlObject, 24, photos.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.photos.Photos.Cons_photosSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photos: [Api.Photo] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(count: Int32, photos: [Api.Photo], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(131))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, photos.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.premium {
    enum BoostsList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_boostsList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case boostsList(Cons_boostsList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .boostsList(Cons_boostsList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .boostsList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.premium.BoostsList] {
            return tlObjectsAt(object, offset).map { Api.premium.BoostsList(tlObject: $0) }
        }

    }
}
public extension Api.premium.BoostsList.Cons_boostsList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var boosts: [Api.Boost] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Boost.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, count: Int32, boosts: [Api.Boost], nextOffset: String?, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(863))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, boosts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.premium {
    enum BoostsStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_boostsStatus {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case boostsStatus(Cons_boostsStatus)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .boostsStatus(Cons_boostsStatus(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .boostsStatus(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.premium.BoostsStatus] {
            return tlObjectsAt(object, offset).map { Api.premium.BoostsStatus(tlObject: $0) }
        }

    }
}
public extension Api.premium.BoostsStatus.Cons_boostsStatus {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var level: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currentLevelBoosts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var boosts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var giftBoosts: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var nextLevelBoosts: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var premiumAudience: Api.StatsPercentValue? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.StatsPercentValue(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var boostUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var prepaidGiveaways: [Api.PrepaidGiveaway]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.PrepaidGiveaway.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var myBoostSlots: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlInt32sAt(self.tlObject, 72) } }
    }
    init(flags: Int32, level: Int32, currentLevelBoosts: Int32, boosts: Int32, giftBoosts: Int32?, nextLevelBoosts: Int32?, premiumAudience: Api.StatsPercentValue?, boostUrl: String, prepaidGiveaways: [Api.PrepaidGiveaway]?, myBoostSlots: [Int32]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(470))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, level)
        tlStore(_tlObject, 32, currentLevelBoosts)
        tlStore(_tlObject, 36, boosts)
        if let _tlValue = giftBoosts { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = nextLevelBoosts { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, premiumAudience?.tlObject)
        tlStoreReference(_tlObject, 56, boostUrl as NSString)
        tlStoreReference(_tlObject, 64, prepaidGiveaways.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, myBoostSlots.map { value in tlPackInt32(value) as NSData })
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.premium {
    enum MyBoosts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_myBoosts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case myBoosts(Cons_myBoosts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .myBoosts(Cons_myBoosts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .myBoosts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.premium.MyBoosts] {
            return tlObjectsAt(object, offset).map { Api.premium.MyBoosts(tlObject: $0) }
        }

    }
}
public extension Api.premium.MyBoosts.Cons_myBoosts {
    @_alwaysEmitIntoClient var myBoosts: [Api.MyBoost] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MyBoost.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(myBoosts: [Api.MyBoost], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1002))
        tlStoreReference(_tlObject, 24, myBoosts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.smsjobs {
    enum EligibilityToJoin: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_eligibleToJoin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case eligibleToJoin(Cons_eligibleToJoin)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .eligibleToJoin(Cons_eligibleToJoin(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .eligibleToJoin(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.smsjobs.EligibilityToJoin] {
            return tlObjectsAt(object, offset).map { Api.smsjobs.EligibilityToJoin(tlObject: $0) }
        }

    }
}
public extension Api.smsjobs.EligibilityToJoin.Cons_eligibleToJoin {
    @_alwaysEmitIntoClient var termsUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var monthlySentSms: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(termsUrl: String, monthlySentSms: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1449))
        tlStoreReference(_tlObject, 32, termsUrl as NSString)
        tlStore(_tlObject, 24, monthlySentSms)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.smsjobs {
    enum Status: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_status {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case status(Cons_status)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .status(Cons_status(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .status(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.smsjobs.Status] {
            return tlObjectsAt(object, offset).map { Api.smsjobs.Status(tlObject: $0) }
        }

    }
}
public extension Api.smsjobs.Status.Cons_status {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recentSent: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recentSince: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recentRemains: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var totalSent: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var totalSince: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var lastGiftSlug: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var termsUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, recentSent: Int32, recentSince: Int32, recentRemains: Int32, totalSent: Int32, totalSince: Int32, lastGiftSlug: String?, termsUrl: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(274))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, recentSent)
        tlStore(_tlObject, 32, recentSince)
        tlStore(_tlObject, 36, recentRemains)
        tlStore(_tlObject, 40, totalSent)
        tlStore(_tlObject, 44, totalSince)
        tlStoreReference(_tlObject, 48, lastGiftSlug.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, termsUrl as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum BroadcastStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_broadcastStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case broadcastStats(Cons_broadcastStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .broadcastStats(Cons_broadcastStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .broadcastStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.BroadcastStats] {
            return tlObjectsAt(object, offset).map { Api.stats.BroadcastStats(tlObject: $0) }
        }

    }
}
public extension Api.stats.BroadcastStats.Cons_broadcastStats {
    @_alwaysEmitIntoClient var period: Api.StatsDateRangeDays {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsDateRangeDays(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var followers: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var viewsPerPost: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var sharesPerPost: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var reactionsPerPost: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var viewsPerStory: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var sharesPerStory: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var reactionsPerStory: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var enabledNotifications: Api.StatsPercentValue {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsPercentValue(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var growthGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var followersGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var muteGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var topHoursGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    @_alwaysEmitIntoClient var interactionsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var ivInteractionsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var viewsBySourceGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var newFollowersBySourceGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var languagesGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var reactionsByEmotionGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 168)) } }
    }
    @_alwaysEmitIntoClient var storyInteractionsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 176)) } }
    }
    @_alwaysEmitIntoClient var storyReactionsByEmotionGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 184)) } }
    }
    @_alwaysEmitIntoClient var recentPostsInteractions: [Api.PostInteractionCounters] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PostInteractionCounters.tlArray(self.tlObject, 192) } }
    }
    init(period: Api.StatsDateRangeDays, followers: Api.StatsAbsValueAndPrev, viewsPerPost: Api.StatsAbsValueAndPrev, sharesPerPost: Api.StatsAbsValueAndPrev, reactionsPerPost: Api.StatsAbsValueAndPrev, viewsPerStory: Api.StatsAbsValueAndPrev, sharesPerStory: Api.StatsAbsValueAndPrev, reactionsPerStory: Api.StatsAbsValueAndPrev, enabledNotifications: Api.StatsPercentValue, growthGraph: Api.StatsGraph, followersGraph: Api.StatsGraph, muteGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, interactionsGraph: Api.StatsGraph, ivInteractionsGraph: Api.StatsGraph, viewsBySourceGraph: Api.StatsGraph, newFollowersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph, storyInteractionsGraph: Api.StatsGraph, storyReactionsByEmotionGraph: Api.StatsGraph, recentPostsInteractions: [Api.PostInteractionCounters]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(367))
        tlStoreReference(_tlObject, 24, period.tlObject)
        tlStoreReference(_tlObject, 32, followers.tlObject)
        tlStoreReference(_tlObject, 40, viewsPerPost.tlObject)
        tlStoreReference(_tlObject, 48, sharesPerPost.tlObject)
        tlStoreReference(_tlObject, 56, reactionsPerPost.tlObject)
        tlStoreReference(_tlObject, 64, viewsPerStory.tlObject)
        tlStoreReference(_tlObject, 72, sharesPerStory.tlObject)
        tlStoreReference(_tlObject, 80, reactionsPerStory.tlObject)
        tlStoreReference(_tlObject, 88, enabledNotifications.tlObject)
        tlStoreReference(_tlObject, 96, growthGraph.tlObject)
        tlStoreReference(_tlObject, 104, followersGraph.tlObject)
        tlStoreReference(_tlObject, 112, muteGraph.tlObject)
        tlStoreReference(_tlObject, 120, topHoursGraph.tlObject)
        tlStoreReference(_tlObject, 128, interactionsGraph.tlObject)
        tlStoreReference(_tlObject, 136, ivInteractionsGraph.tlObject)
        tlStoreReference(_tlObject, 144, viewsBySourceGraph.tlObject)
        tlStoreReference(_tlObject, 152, newFollowersBySourceGraph.tlObject)
        tlStoreReference(_tlObject, 160, languagesGraph.tlObject)
        tlStoreReference(_tlObject, 168, reactionsByEmotionGraph.tlObject)
        tlStoreReference(_tlObject, 176, storyInteractionsGraph.tlObject)
        tlStoreReference(_tlObject, 184, storyReactionsByEmotionGraph.tlObject)
        tlStoreReference(_tlObject, 192, recentPostsInteractions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum MegagroupStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_megagroupStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case megagroupStats(Cons_megagroupStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .megagroupStats(Cons_megagroupStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .megagroupStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.MegagroupStats] {
            return tlObjectsAt(object, offset).map { Api.stats.MegagroupStats(tlObject: $0) }
        }

    }
}
public extension Api.stats.MegagroupStats.Cons_megagroupStats {
    @_alwaysEmitIntoClient var period: Api.StatsDateRangeDays {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsDateRangeDays(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var members: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var messages: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var viewers: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var posters: Api.StatsAbsValueAndPrev {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsAbsValueAndPrev(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var growthGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var membersGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var newMembersBySourceGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var languagesGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var messagesGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var actionsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var topHoursGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var weekdaysGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    @_alwaysEmitIntoClient var topPosters: [Api.StatsGroupTopPoster] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGroupTopPoster.tlArray(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var topAdmins: [Api.StatsGroupTopAdmin] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGroupTopAdmin.tlArray(self.tlObject, 136) } }
    }
    @_alwaysEmitIntoClient var topInviters: [Api.StatsGroupTopInviter] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGroupTopInviter.tlArray(self.tlObject, 144) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 152) } }
    }
    init(period: Api.StatsDateRangeDays, members: Api.StatsAbsValueAndPrev, messages: Api.StatsAbsValueAndPrev, viewers: Api.StatsAbsValueAndPrev, posters: Api.StatsAbsValueAndPrev, growthGraph: Api.StatsGraph, membersGraph: Api.StatsGraph, newMembersBySourceGraph: Api.StatsGraph, languagesGraph: Api.StatsGraph, messagesGraph: Api.StatsGraph, actionsGraph: Api.StatsGraph, topHoursGraph: Api.StatsGraph, weekdaysGraph: Api.StatsGraph, topPosters: [Api.StatsGroupTopPoster], topAdmins: [Api.StatsGroupTopAdmin], topInviters: [Api.StatsGroupTopInviter], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1585))
        tlStoreReference(_tlObject, 24, period.tlObject)
        tlStoreReference(_tlObject, 32, members.tlObject)
        tlStoreReference(_tlObject, 40, messages.tlObject)
        tlStoreReference(_tlObject, 48, viewers.tlObject)
        tlStoreReference(_tlObject, 56, posters.tlObject)
        tlStoreReference(_tlObject, 64, growthGraph.tlObject)
        tlStoreReference(_tlObject, 72, membersGraph.tlObject)
        tlStoreReference(_tlObject, 80, newMembersBySourceGraph.tlObject)
        tlStoreReference(_tlObject, 88, languagesGraph.tlObject)
        tlStoreReference(_tlObject, 96, messagesGraph.tlObject)
        tlStoreReference(_tlObject, 104, actionsGraph.tlObject)
        tlStoreReference(_tlObject, 112, topHoursGraph.tlObject)
        tlStoreReference(_tlObject, 120, weekdaysGraph.tlObject)
        tlStoreReference(_tlObject, 128, topPosters.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 136, topAdmins.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 144, topInviters.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 152, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum MessageStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageStats(Cons_messageStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageStats(Cons_messageStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.MessageStats] {
            return tlObjectsAt(object, offset).map { Api.stats.MessageStats(tlObject: $0) }
        }

    }
}
public extension Api.stats.MessageStats.Cons_messageStats {
    @_alwaysEmitIntoClient var viewsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var reactionsByEmotionGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(822))
        tlStoreReference(_tlObject, 24, viewsGraph.tlObject)
        tlStoreReference(_tlObject, 32, reactionsByEmotionGraph.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum PollStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_pollStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case pollStats(Cons_pollStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .pollStats(Cons_pollStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .pollStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.PollStats] {
            return tlObjectsAt(object, offset).map { Api.stats.PollStats(tlObject: $0) }
        }

    }
}
public extension Api.stats.PollStats.Cons_pollStats {
    @_alwaysEmitIntoClient var votesGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(votesGraph: Api.StatsGraph) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(268))
        tlStoreReference(_tlObject, 24, votesGraph.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum PublicForwards: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_publicForwards {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case publicForwards(Cons_publicForwards)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .publicForwards(Cons_publicForwards(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .publicForwards(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.PublicForwards] {
            return tlObjectsAt(object, offset).map { Api.stats.PublicForwards(tlObject: $0) }
        }

    }
}
public extension Api.stats.PublicForwards.Cons_publicForwards {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwards: [Api.PublicForward] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PublicForward.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, count: Int32, forwards: [Api.PublicForward], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(934))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, forwards.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stats {
    enum StoryStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyStats(Cons_storyStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyStats(Cons_storyStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stats.StoryStats] {
            return tlObjectsAt(object, offset).map { Api.stats.StoryStats(tlObject: $0) }
        }

    }
}
public extension Api.stats.StoryStats.Cons_storyStats {
    @_alwaysEmitIntoClient var viewsGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var reactionsByEmotionGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(viewsGraph: Api.StatsGraph, reactionsByEmotionGraph: Api.StatsGraph) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(527))
        tlStoreReference(_tlObject, 24, viewsGraph.tlObject)
        tlStoreReference(_tlObject, 32, reactionsByEmotionGraph.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stickers {
    enum SuggestedShortName: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_suggestedShortName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case suggestedShortName(Cons_suggestedShortName)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .suggestedShortName(Cons_suggestedShortName(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .suggestedShortName(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stickers.SuggestedShortName] {
            return tlObjectsAt(object, offset).map { Api.stickers.SuggestedShortName(tlObject: $0) }
        }

    }
}
public extension Api.stickers.SuggestedShortName.Cons_suggestedShortName {
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(shortName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(856))
        tlStoreReference(_tlObject, 24, shortName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.storage {
    enum FileType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case fileGif
        case fileJpeg
        case fileMov
        case fileMp3
        case fileMp4
        case filePartial
        case filePdf
        case filePng
        case fileUnknown
        case fileWebp


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .fileGif
            case 1:
                self = .fileJpeg
            case 2:
                self = .fileMov
            case 3:
                self = .fileMp3
            case 4:
                self = .fileMp4
            case 5:
                self = .filePartial
            case 6:
                self = .filePdf
            case 7:
                self = .filePng
            case 8:
                self = .fileUnknown
            case 9:
                self = .fileWebp
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .fileGif:
                return TLObjectSingleton(TLApiConstructorAt(1348))
            case .fileJpeg:
                return TLObjectSingleton(TLApiConstructorAt(2))
            case .fileMov:
                return TLObjectSingleton(TLApiConstructorAt(483))
            case .fileMp3:
                return TLObjectSingleton(TLApiConstructorAt(537))
            case .fileMp4:
                return TLObjectSingleton(TLApiConstructorAt(1170))
            case .filePartial:
                return TLObjectSingleton(TLApiConstructorAt(419))
            case .filePdf:
                return TLObjectSingleton(TLApiConstructorAt(1135))
            case .filePng:
                return TLObjectSingleton(TLApiConstructorAt(68))
            case .fileUnknown:
                return TLObjectSingleton(TLApiConstructorAt(1112))
            case .fileWebp:
                return TLObjectSingleton(TLApiConstructorAt(100))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.storage.FileType] {
            return tlObjectsAt(object, offset).map { Api.storage.FileType(tlObject: $0) }
        }

    }
}
public extension Api.stories {
    enum Albums: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_albums {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case albums(Cons_albums)
        case albumsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .albums(Cons_albums(tlObject: object))
            case 1:
                self = .albumsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .albums(let _data):
                return _data.tlObject
            case .albumsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(556))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.Albums] {
            return tlObjectsAt(object, offset).map { Api.stories.Albums(tlObject: $0) }
        }

    }
}
public extension Api.stories.Albums.Cons_albums {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var albums: [Api.StoryAlbum] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryAlbum.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, albums: [Api.StoryAlbum]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1305))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, albums.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum AllStories: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_allStories {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_allStoriesNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case allStories(Cons_allStories)
        case allStoriesNotModified(Cons_allStoriesNotModified)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .allStories(Cons_allStories(tlObject: object))
            case 1:
                self = .allStoriesNotModified(Cons_allStoriesNotModified(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .allStories(let _data):
                return _data.tlObject
            case .allStoriesNotModified(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.AllStories] {
            return tlObjectsAt(object, offset).map { Api.stories.AllStories(tlObject: $0) }
        }

    }
}
public extension Api.stories.AllStories.Cons_allStories {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var state: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var peerStories: [Api.PeerStories] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerStories.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var stealthMode: Api.StoriesStealthMode {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoriesStealthMode(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, count: Int32, state: String, peerStories: [Api.PeerStories], chats: [Api.Chat], users: [Api.User], stealthMode: Api.StoriesStealthMode) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(704))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, state as NSString)
        tlStoreReference(_tlObject, 40, peerStories.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, stealthMode.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories.AllStories.Cons_allStoriesNotModified {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var state: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var stealthMode: Api.StoriesStealthMode {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoriesStealthMode(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, state: String, stealthMode: Api.StoriesStealthMode) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(107))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, state as NSString)
        tlStoreReference(_tlObject, 40, stealthMode.tlObject)
        self.init(tlObject: _tlObject)
    }
}
