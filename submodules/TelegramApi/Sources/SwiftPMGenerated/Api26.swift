import TelegramApiObjC
public extension Api {
    enum ShippingOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_shippingOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case shippingOption(Cons_shippingOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .shippingOption(Cons_shippingOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .shippingOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ShippingOption] {
            return tlObjectsAt(object, offset).map { Api.ShippingOption(tlObject: $0) }
        }

    }
}
public extension Api.ShippingOption.Cons_shippingOption {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var prices: [Api.LabeledPrice] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.LabeledPrice.tlArray(self.tlObject, 40) } }
    }
    init(id: String, title: String, prices: [Api.LabeledPrice]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1196))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, prices.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SmsJob: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_smsJob {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case smsJob(Cons_smsJob)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .smsJob(Cons_smsJob(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .smsJob(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SmsJob] {
            return tlObjectsAt(object, offset).map { Api.SmsJob(tlObject: $0) }
        }

    }
}
public extension Api.SmsJob.Cons_smsJob {
    @_alwaysEmitIntoClient var jobId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(jobId: String, phoneNumber: String, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1519))
        tlStoreReference(_tlObject, 24, jobId as NSString)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum SponsoredMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredMessage(Cons_sponsoredMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredMessage(Cons_sponsoredMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SponsoredMessage] {
            return tlObjectsAt(object, offset).map { Api.SponsoredMessage(tlObject: $0) }
        }

    }
}
public extension Api.SponsoredMessage.Cons_sponsoredMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var randomId: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.MessageEntity.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var color: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var buttonText: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var sponsorInfo: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlStringAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var additionalInfo: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var minDisplayDuration: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 128, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var maxDisplayDuration: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 128, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, randomId: Buffer, url: String, title: String, message: String, entities: [Api.MessageEntity]?, photo: Api.Photo?, media: Api.MessageMedia?, color: Api.PeerColor?, buttonText: String, sponsorInfo: String?, additionalInfo: String?, minDisplayDuration: Int32?, maxDisplayDuration: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(813))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, randomId.makeData() as NSData)
        tlStoreReference(_tlObject, 48, url as NSString)
        tlStoreReference(_tlObject, 56, title as NSString)
        tlStoreReference(_tlObject, 64, message as NSString)
        tlStoreReference(_tlObject, 72, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, photo?.tlObject)
        tlStoreReference(_tlObject, 88, media?.tlObject)
        tlStoreReference(_tlObject, 96, color?.tlObject)
        tlStoreReference(_tlObject, 104, buttonText as NSString)
        tlStoreReference(_tlObject, 112, sponsorInfo.map { value in value as NSString })
        tlStoreReference(_tlObject, 120, additionalInfo.map { value in value as NSString })
        if let _tlValue = minDisplayDuration { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = maxDisplayDuration { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 128, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SponsoredMessageReportOption: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredMessageReportOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredMessageReportOption(Cons_sponsoredMessageReportOption)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredMessageReportOption(Cons_sponsoredMessageReportOption(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredMessageReportOption(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SponsoredMessageReportOption] {
            return tlObjectsAt(object, offset).map { Api.SponsoredMessageReportOption(tlObject: $0) }
        }

    }
}
public extension Api.SponsoredMessageReportOption.Cons_sponsoredMessageReportOption {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(text: String, option: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(436))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, option.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SponsoredPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredPeer(Cons_sponsoredPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredPeer(Cons_sponsoredPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SponsoredPeer] {
            return tlObjectsAt(object, offset).map { Api.SponsoredPeer(tlObject: $0) }
        }

    }
}
public extension Api.SponsoredPeer.Cons_sponsoredPeer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var randomId: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var sponsorInfo: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var additionalInfo: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, randomId: Buffer, peer: Api.Peer, sponsorInfo: String?, additionalInfo: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1326))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, randomId.makeData() as NSData)
        tlStoreReference(_tlObject, 40, peer.tlObject)
        tlStoreReference(_tlObject, 48, sponsorInfo.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, additionalInfo.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGift: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftUnique {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGift(Cons_starGift)
        case starGiftUnique(Cons_starGiftUnique)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGift(Cons_starGift(tlObject: object))
            case 1:
                self = .starGiftUnique(Cons_starGiftUnique(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGift(let _data):
                return _data.tlObject
            case .starGiftUnique(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGift] {
            return tlObjectsAt(object, offset).map { Api.StarGift(tlObject: $0) }
        }

    }
}
public extension Api.StarGift.Cons_starGift {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var sticker: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var availabilityRemains: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var availabilityTotal: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var availabilityResale: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 2) ? tlBase(self.tlObject).load(fromByteOffset: 96, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var convertStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 104, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var firstSaleDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 3) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var lastSaleDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 4) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var upgradeStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 5) ? tlBase(self.tlObject).load(fromByteOffset: 112, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var resellMinStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 6) ? tlBase(self.tlObject).load(fromByteOffset: 120, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : tlStringAt(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var releasedBy: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var perUserTotal: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 7) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var perUserRemains: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 8) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var lockedUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 9) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var auctionSlug: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : tlStringAt(self.tlObject, 144) } }
    }
    @_alwaysEmitIntoClient var giftsPerRound: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 10) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var auctionStartDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 11) ? tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var upgradeVariants: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 12) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var background: Api.StarGiftBackground? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.StarGiftBackground(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    init(flags: Int32, id: Int64, sticker: Api.Document, stars: Int64, availabilityRemains: Int32?, availabilityTotal: Int32?, availabilityResale: Int64?, convertStars: Int64, firstSaleDate: Int32?, lastSaleDate: Int32?, upgradeStars: Int64?, resellMinStars: Int64?, title: String?, releasedBy: Api.Peer?, perUserTotal: Int32?, perUserRemains: Int32?, lockedUntilDate: Int32?, auctionSlug: String?, giftsPerRound: Int32?, auctionStartDate: Int32?, upgradeVariants: Int32?, background: Api.StarGiftBackground?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(312))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 72, id)
        tlStoreReference(_tlObject, 80, sticker.tlObject)
        tlStore(_tlObject, 88, stars)
        if let _tlValue = availabilityRemains { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = availabilityTotal { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = availabilityResale { tlStore(_tlObject, 96, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 104, convertStars)
        if let _tlValue = firstSaleDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = lastSaleDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = upgradeStars { tlStore(_tlObject, 112, _tlValue); _tlPresent |= 1 << 5 }
        if let _tlValue = resellMinStars { tlStore(_tlObject, 120, _tlValue); _tlPresent |= 1 << 6 }
        tlStoreReference(_tlObject, 128, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 136, releasedBy?.tlObject)
        if let _tlValue = perUserTotal { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 7 }
        if let _tlValue = perUserRemains { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 8 }
        if let _tlValue = lockedUntilDate { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 9 }
        tlStoreReference(_tlObject, 144, auctionSlug.map { value in value as NSString })
        if let _tlValue = giftsPerRound { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 10 }
        if let _tlValue = auctionStartDate { tlStore(_tlObject, 60, _tlValue); _tlPresent |= 1 << 11 }
        if let _tlValue = upgradeVariants { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 12 }
        tlStoreReference(_tlObject, 152, background?.tlObject)
        tlStore(_tlObject, 160, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGift.Cons_starGiftUnique {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var giftId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var num: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ownerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var ownerName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var ownerAddress: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.StarGiftAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttribute.tlArray(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var availabilityIssued: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var availabilityTotal: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var giftAddress: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlStringAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var resellAmount: [Api.StarsAmount]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.StarsAmount.tlArray(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var releasedBy: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var valueAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 184, 0) ? tlBase(self.tlObject).load(fromByteOffset: 136, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var valueCurrency: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : tlStringAt(self.tlObject, 144) } }
    }
    @_alwaysEmitIntoClient var valueUsdAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 184, 1) ? tlBase(self.tlObject).load(fromByteOffset: 152, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var themePeer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 160) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var peerColor: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 168) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 168)) } }
    }
    @_alwaysEmitIntoClient var hostId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 176) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 176)) } }
    }
    @_alwaysEmitIntoClient var offerMinStars: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 184, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var craftChancePermille: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 184, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, giftId: Int64, title: String, slug: String, num: Int32, ownerId: Api.Peer?, ownerName: String?, ownerAddress: String?, attributes: [Api.StarGiftAttribute], availabilityIssued: Int32, availabilityTotal: Int32, giftAddress: String?, resellAmount: [Api.StarsAmount]?, releasedBy: Api.Peer?, valueAmount: Int64?, valueCurrency: String?, valueUsdAmount: Int64?, themePeer: Api.Peer?, peerColor: Api.PeerColor?, hostId: Api.Peer?, offerMinStars: Int32?, craftChancePermille: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(857))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 48, id)
        tlStore(_tlObject, 56, giftId)
        tlStoreReference(_tlObject, 64, title as NSString)
        tlStoreReference(_tlObject, 72, slug as NSString)
        tlStore(_tlObject, 28, num)
        tlStoreReference(_tlObject, 80, ownerId?.tlObject)
        tlStoreReference(_tlObject, 88, ownerName.map { value in value as NSString })
        tlStoreReference(_tlObject, 96, ownerAddress.map { value in value as NSString })
        tlStoreReference(_tlObject, 104, attributes.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 32, availabilityIssued)
        tlStore(_tlObject, 36, availabilityTotal)
        tlStoreReference(_tlObject, 112, giftAddress.map { value in value as NSString })
        tlStoreReference(_tlObject, 120, resellAmount.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 128, releasedBy?.tlObject)
        if let _tlValue = valueAmount { tlStore(_tlObject, 136, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 144, valueCurrency.map { value in value as NSString })
        if let _tlValue = valueUsdAmount { tlStore(_tlObject, 152, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 160, themePeer?.tlObject)
        tlStoreReference(_tlObject, 168, peerColor?.tlObject)
        tlStoreReference(_tlObject, 176, hostId?.tlObject)
        if let _tlValue = offerMinStars { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = craftChancePermille { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 184, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftActiveAuctionState: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftActiveAuctionState {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftActiveAuctionState(Cons_starGiftActiveAuctionState)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftActiveAuctionState(Cons_starGiftActiveAuctionState(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftActiveAuctionState(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftActiveAuctionState] {
            return tlObjectsAt(object, offset).map { Api.StarGiftActiveAuctionState(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftActiveAuctionState.Cons_starGiftActiveAuctionState {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var state: Api.StarGiftAuctionState {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionState(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var userState: Api.StarGiftAuctionUserState {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionUserState(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1393))
        tlStoreReference(_tlObject, 24, gift.tlObject)
        tlStoreReference(_tlObject, 32, state.tlObject)
        tlStoreReference(_tlObject, 40, userState.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAttribute: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAttributeBackdrop {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAttributeModel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAttributeOriginalDetails {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAttributePattern {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop)
        case starGiftAttributeModel(Cons_starGiftAttributeModel)
        case starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails)
        case starGiftAttributePattern(Cons_starGiftAttributePattern)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAttributeBackdrop(Cons_starGiftAttributeBackdrop(tlObject: object))
            case 1:
                self = .starGiftAttributeModel(Cons_starGiftAttributeModel(tlObject: object))
            case 2:
                self = .starGiftAttributeOriginalDetails(Cons_starGiftAttributeOriginalDetails(tlObject: object))
            case 3:
                self = .starGiftAttributePattern(Cons_starGiftAttributePattern(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAttributeBackdrop(let _data):
                return _data.tlObject
            case .starGiftAttributeModel(let _data):
                return _data.tlObject
            case .starGiftAttributeOriginalDetails(let _data):
                return _data.tlObject
            case .starGiftAttributePattern(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAttribute] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAttribute(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAttribute.Cons_starGiftAttributeBackdrop {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var backdropId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var centerColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var edgeColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var patternColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var textColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rarity: Api.StarGiftAttributeRarity {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttributeRarity(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(name: String, backdropId: Int32, centerColor: Int32, edgeColor: Int32, patternColor: Int32, textColor: Int32, rarity: Api.StarGiftAttributeRarity) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1037))
        tlStoreReference(_tlObject, 48, name as NSString)
        tlStore(_tlObject, 24, backdropId)
        tlStore(_tlObject, 28, centerColor)
        tlStore(_tlObject, 32, edgeColor)
        tlStore(_tlObject, 36, patternColor)
        tlStore(_tlObject, 40, textColor)
        tlStoreReference(_tlObject, 56, rarity.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAttribute.Cons_starGiftAttributeModel {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var rarity: Api.StarGiftAttributeRarity {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttributeRarity(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(558))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, name as NSString)
        tlStoreReference(_tlObject, 40, document.tlObject)
        tlStoreReference(_tlObject, 48, rarity.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAttribute.Cons_starGiftAttributeOriginalDetails {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var senderId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var recipientId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, senderId: Api.Peer?, recipientId: Api.Peer, date: Int32, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1479))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, senderId?.tlObject)
        tlStoreReference(_tlObject, 40, recipientId.tlObject)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 48, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAttribute.Cons_starGiftAttributePattern {
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var rarity: Api.StarGiftAttributeRarity {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttributeRarity(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(name: String, document: Api.Document, rarity: Api.StarGiftAttributeRarity) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(507))
        tlStoreReference(_tlObject, 24, name as NSString)
        tlStoreReference(_tlObject, 32, document.tlObject)
        tlStoreReference(_tlObject, 40, rarity.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAttributeCounter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAttributeCounter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAttributeCounter(Cons_starGiftAttributeCounter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAttributeCounter(Cons_starGiftAttributeCounter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAttributeCounter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAttributeCounter] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAttributeCounter(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAttributeCounter.Cons_starGiftAttributeCounter {
    @_alwaysEmitIntoClient var attribute: Api.StarGiftAttributeId {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttributeId(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(attribute: Api.StarGiftAttributeId, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(292))
        tlStoreReference(_tlObject, 32, attribute.tlObject)
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAttributeId: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAttributeIdBackdrop {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAttributeIdModel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAttributeIdPattern {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop)
        case starGiftAttributeIdModel(Cons_starGiftAttributeIdModel)
        case starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAttributeIdBackdrop(Cons_starGiftAttributeIdBackdrop(tlObject: object))
            case 1:
                self = .starGiftAttributeIdModel(Cons_starGiftAttributeIdModel(tlObject: object))
            case 2:
                self = .starGiftAttributeIdPattern(Cons_starGiftAttributeIdPattern(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAttributeIdBackdrop(let _data):
                return _data.tlObject
            case .starGiftAttributeIdModel(let _data):
                return _data.tlObject
            case .starGiftAttributeIdPattern(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAttributeId] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAttributeId(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAttributeId.Cons_starGiftAttributeIdBackdrop {
    @_alwaysEmitIntoClient var backdropId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(backdropId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(209))
        tlStore(_tlObject, 24, backdropId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAttributeId.Cons_starGiftAttributeIdModel {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(documentId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(465))
        tlStore(_tlObject, 24, documentId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAttributeId.Cons_starGiftAttributeIdPattern {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(documentId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(475))
        tlStore(_tlObject, 24, documentId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAttributeRarity: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAttributeRarity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAttributeRarity(Cons_starGiftAttributeRarity)
        case starGiftAttributeRarityEpic
        case starGiftAttributeRarityLegendary
        case starGiftAttributeRarityRare
        case starGiftAttributeRarityUncommon


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAttributeRarity(Cons_starGiftAttributeRarity(tlObject: object))
            case 1:
                self = .starGiftAttributeRarityEpic
            case 2:
                self = .starGiftAttributeRarityLegendary
            case 3:
                self = .starGiftAttributeRarityRare
            case 4:
                self = .starGiftAttributeRarityUncommon
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAttributeRarity(let _data):
                return _data.tlObject
            case .starGiftAttributeRarityEpic:
                return TLObjectSingleton(TLApiConstructorAt(779))
            case .starGiftAttributeRarityLegendary:
                return TLObjectSingleton(TLApiConstructorAt(1374))
            case .starGiftAttributeRarityRare:
                return TLObjectSingleton(TLApiConstructorAt(1594))
            case .starGiftAttributeRarityUncommon:
                return TLObjectSingleton(TLApiConstructorAt(1444))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAttributeRarity] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAttributeRarity(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAttributeRarity.Cons_starGiftAttributeRarity {
    @_alwaysEmitIntoClient var permille: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(permille: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(346))
        tlStore(_tlObject, 24, permille)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAuctionAcquiredGift: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionAcquiredGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionAcquiredGift(Cons_starGiftAuctionAcquiredGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionAcquiredGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAuctionAcquiredGift] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAuctionAcquiredGift(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAuctionAcquiredGift.Cons_starGiftAuctionAcquiredGift {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bidAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var round: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pos: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var giftNum: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, peer: Api.Peer, date: Int32, bidAmount: Int64, round: Int32, pos: Int32, message: Api.TextWithEntities?, giftNum: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(433))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 56, bidAmount)
        tlStore(_tlObject, 32, round)
        tlStore(_tlObject, 36, pos)
        tlStoreReference(_tlObject, 64, message?.tlObject)
        if let _tlValue = giftNum { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAuctionRound: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionRound {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAuctionRoundExtendable {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionRound(Cons_starGiftAuctionRound)
        case starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionRound(Cons_starGiftAuctionRound(tlObject: object))
            case 1:
                self = .starGiftAuctionRoundExtendable(Cons_starGiftAuctionRoundExtendable(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionRound(let _data):
                return _data.tlObject
            case .starGiftAuctionRoundExtendable(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAuctionRound] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAuctionRound(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAuctionRound.Cons_starGiftAuctionRound {
    @_alwaysEmitIntoClient var num: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var duration: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(num: Int32, duration: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(374))
        tlStore(_tlObject, 24, num)
        tlStore(_tlObject, 28, duration)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAuctionRound.Cons_starGiftAuctionRoundExtendable {
    @_alwaysEmitIntoClient var num: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var duration: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var extendTop: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var extendWindow: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(num: Int32, duration: Int32, extendTop: Int32, extendWindow: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(70))
        tlStore(_tlObject, 24, num)
        tlStore(_tlObject, 28, duration)
        tlStore(_tlObject, 32, extendTop)
        tlStore(_tlObject, 36, extendWindow)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAuctionState: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionState {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starGiftAuctionStateFinished {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)
        case starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished)
        case starGiftAuctionStateNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionState(Cons_starGiftAuctionState(tlObject: object))
            case 1:
                self = .starGiftAuctionStateFinished(Cons_starGiftAuctionStateFinished(tlObject: object))
            case 2:
                self = .starGiftAuctionStateNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionState(let _data):
                return _data.tlObject
            case .starGiftAuctionStateFinished(let _data):
                return _data.tlObject
            case .starGiftAuctionStateNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1699))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAuctionState] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAuctionState(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAuctionState.Cons_starGiftAuctionState {
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var endDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var minBidAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var bidLevels: [Api.AuctionBidLevel] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AuctionBidLevel.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var topBidders: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var nextRoundAt: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var lastGiftNum: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var giftsLeft: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currentRound: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var totalRounds: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rounds: [Api.StarGiftAuctionRound] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionRound.tlArray(self.tlObject, 80) } }
    }
    init(version: Int32, startDate: Int32, endDate: Int32, minBidAmount: Int64, bidLevels: [Api.AuctionBidLevel], topBidders: [Int64], nextRoundAt: Int32, lastGiftNum: Int32, giftsLeft: Int32, currentRound: Int32, totalRounds: Int32, rounds: [Api.StarGiftAuctionRound]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(765))
        tlStore(_tlObject, 24, version)
        tlStore(_tlObject, 28, startDate)
        tlStore(_tlObject, 32, endDate)
        tlStore(_tlObject, 56, minBidAmount)
        tlStoreReference(_tlObject, 64, bidLevels.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, tlPackInt64(topBidders) as NSData)
        tlStore(_tlObject, 36, nextRoundAt)
        tlStore(_tlObject, 40, lastGiftNum)
        tlStore(_tlObject, 44, giftsLeft)
        tlStore(_tlObject, 48, currentRound)
        tlStore(_tlObject, 52, totalRounds)
        tlStoreReference(_tlObject, 80, rounds.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarGiftAuctionState.Cons_starGiftAuctionStateFinished {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var endDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var averagePrice: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var listedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fragmentListedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fragmentListedUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, startDate: Int32, endDate: Int32, averagePrice: Int64, listedCount: Int32?, fragmentListedCount: Int32?, fragmentListedUrl: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(972))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, startDate)
        tlStore(_tlObject, 32, endDate)
        tlStore(_tlObject, 48, averagePrice)
        if let _tlValue = listedCount { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = fragmentListedCount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 56, fragmentListedUrl.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftAuctionUserState: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionUserState {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionUserState(Cons_starGiftAuctionUserState)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionUserState(Cons_starGiftAuctionUserState(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionUserState(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftAuctionUserState] {
            return tlObjectsAt(object, offset).map { Api.StarGiftAuctionUserState(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftAuctionUserState.Cons_starGiftAuctionUserState {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bidAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var bidDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var minBidAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 2) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var bidPeer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var acquiredCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, bidAmount: Int64?, bidDate: Int32?, minBidAmount: Int64?, bidPeer: Api.Peer?, acquiredCount: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(295))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = bidAmount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = bidDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = minBidAmount { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 56, bidPeer?.tlObject)
        tlStore(_tlObject, 32, acquiredCount)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftBackground: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftBackground {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftBackground(Cons_starGiftBackground)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftBackground(Cons_starGiftBackground(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftBackground(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftBackground] {
            return tlObjectsAt(object, offset).map { Api.StarGiftBackground(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftBackground.Cons_starGiftBackground {
    @_alwaysEmitIntoClient var centerColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var edgeColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var textColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(centerColor: Int32, edgeColor: Int32, textColor: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1147))
        tlStore(_tlObject, 24, centerColor)
        tlStore(_tlObject, 28, edgeColor)
        tlStore(_tlObject, 32, textColor)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftCollection: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftCollection {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftCollection(Cons_starGiftCollection)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftCollection(Cons_starGiftCollection(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftCollection(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftCollection] {
            return tlObjectsAt(object, offset).map { Api.StarGiftCollection(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftCollection.Cons_starGiftCollection {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var collectionId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var icon: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var giftsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(flags: Int32, collectionId: Int32, title: String, icon: Api.Document?, giftsCount: Int32, hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1022))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, collectionId)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, icon?.tlObject)
        tlStore(_tlObject, 32, giftsCount)
        tlStore(_tlObject, 56, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarGiftUpgradePrice: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftUpgradePrice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftUpgradePrice(Cons_starGiftUpgradePrice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftUpgradePrice(Cons_starGiftUpgradePrice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftUpgradePrice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarGiftUpgradePrice] {
            return tlObjectsAt(object, offset).map { Api.StarGiftUpgradePrice(tlObject: $0) }
        }

    }
}
public extension Api.StarGiftUpgradePrice.Cons_starGiftUpgradePrice {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var upgradeStars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(date: Int32, upgradeStars: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(994))
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 32, upgradeStars)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarRefProgram: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starRefProgram {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starRefProgram(Cons_starRefProgram)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starRefProgram(Cons_starRefProgram(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starRefProgram(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarRefProgram] {
            return tlObjectsAt(object, offset).map { Api.StarRefProgram(tlObject: $0) }
        }

    }
}
public extension Api.StarRefProgram.Cons_starRefProgram {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var commissionPermille: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var durationMonths: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var endDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var dailyRevenuePerUser: Api.StarsAmount? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, botId: Int64, commissionPermille: Int32, durationMonths: Int32?, endDate: Int32?, dailyRevenuePerUser: Api.StarsAmount?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1454))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, botId)
        tlStore(_tlObject, 28, commissionPermille)
        if let _tlValue = durationMonths { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = endDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, dailyRevenuePerUser?.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StarsAmount: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsAmount {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_starsTonAmount {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsAmount(Cons_starsAmount)
        case starsTonAmount(Cons_starsTonAmount)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsAmount(Cons_starsAmount(tlObject: object))
            case 1:
                self = .starsTonAmount(Cons_starsTonAmount(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsAmount(let _data):
                return _data.tlObject
            case .starsTonAmount(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StarsAmount] {
            return tlObjectsAt(object, offset).map { Api.StarsAmount(tlObject: $0) }
        }

    }
}
public extension Api.StarsAmount.Cons_starsAmount {
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var nanos: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(amount: Int64, nanos: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1239))
        tlStore(_tlObject, 32, amount)
        tlStore(_tlObject, 24, nanos)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StarsAmount.Cons_starsTonAmount {
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(746))
        tlStore(_tlObject, 24, amount)
        self.init(tlObject: _tlObject)
    }
}
