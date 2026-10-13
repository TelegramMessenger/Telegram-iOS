import TelegramApiObjC
public extension Api {
    indirect enum InputFolderPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputFolderPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputFolderPeer(Cons_inputFolderPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputFolderPeer(Cons_inputFolderPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputFolderPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputFolderPeer] {
            return tlObjectsAt(object, offset).map { Api.InputFolderPeer(tlObject: $0) }
        }

    }
}
public extension Api.InputFolderPeer.Cons_inputFolderPeer {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var folderId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.InputPeer, folderId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1680))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, folderId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputGame: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputGameID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputGameShortName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputGameID(Cons_inputGameID)
        case inputGameShortName(Cons_inputGameShortName)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputGameID(Cons_inputGameID(tlObject: object))
            case 1:
                self = .inputGameShortName(Cons_inputGameShortName(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputGameID(let _data):
                return _data.tlObject
            case .inputGameShortName(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputGame] {
            return tlObjectsAt(object, offset).map { Api.InputGame(tlObject: $0) }
        }

    }
}
public extension Api.InputGame.Cons_inputGameID {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(24))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputGame.Cons_inputGameShortName {
    @_alwaysEmitIntoClient var botId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(botId: Api.InputUser, shortName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1304))
        tlStoreReference(_tlObject, 24, botId.tlObject)
        tlStoreReference(_tlObject, 32, shortName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputGeoPoint: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputGeoPoint {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputGeoPoint(Cons_inputGeoPoint)
        case inputGeoPointEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputGeoPoint(Cons_inputGeoPoint(tlObject: object))
            case 1:
                self = .inputGeoPointEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputGeoPoint(let _data):
                return _data.tlObject
            case .inputGeoPointEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1503))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputGeoPoint] {
            return tlObjectsAt(object, offset).map { Api.InputGeoPoint(tlObject: $0) }
        }

    }
}
public extension Api.InputGeoPoint.Cons_inputGeoPoint {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var lat: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var long: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var accuracyRadius: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(461))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, lat)
        tlStore(_tlObject, 40, long)
        if let _tlValue = accuracyRadius { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputGroupCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputGroupCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputGroupCallInviteMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputGroupCallSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputGroupCall(Cons_inputGroupCall)
        case inputGroupCallInviteMessage(Cons_inputGroupCallInviteMessage)
        case inputGroupCallSlug(Cons_inputGroupCallSlug)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputGroupCall(Cons_inputGroupCall(tlObject: object))
            case 1:
                self = .inputGroupCallInviteMessage(Cons_inputGroupCallInviteMessage(tlObject: object))
            case 2:
                self = .inputGroupCallSlug(Cons_inputGroupCallSlug(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputGroupCall(let _data):
                return _data.tlObject
            case .inputGroupCallInviteMessage(let _data):
                return _data.tlObject
            case .inputGroupCallSlug(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputGroupCall] {
            return tlObjectsAt(object, offset).map { Api.InputGroupCall(tlObject: $0) }
        }

    }
}
public extension Api.InputGroupCall.Cons_inputGroupCall {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1424))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputGroupCall.Cons_inputGroupCallInviteMessage {
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(msgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(899))
        tlStore(_tlObject, 24, msgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputGroupCall.Cons_inputGroupCallSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1698))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputInvoice: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputInvoiceBusinessBotTransferStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceChatInviteSubscription {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoicePremiumAuthCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoicePremiumGiftCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoicePremiumGiftStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftAuctionBid {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftDropOriginalDetails {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftPrepaidUpgrade {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftResale {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftTransfer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStarGiftUpgrade {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInvoiceStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputInvoiceBusinessBotTransferStars(Cons_inputInvoiceBusinessBotTransferStars)
        case inputInvoiceChatInviteSubscription(Cons_inputInvoiceChatInviteSubscription)
        case inputInvoiceMessage(Cons_inputInvoiceMessage)
        case inputInvoicePremiumAuthCode(Cons_inputInvoicePremiumAuthCode)
        case inputInvoicePremiumGiftCode(Cons_inputInvoicePremiumGiftCode)
        case inputInvoicePremiumGiftStars(Cons_inputInvoicePremiumGiftStars)
        case inputInvoiceSlug(Cons_inputInvoiceSlug)
        case inputInvoiceStarGift(Cons_inputInvoiceStarGift)
        case inputInvoiceStarGiftAuctionBid(Cons_inputInvoiceStarGiftAuctionBid)
        case inputInvoiceStarGiftDropOriginalDetails(Cons_inputInvoiceStarGiftDropOriginalDetails)
        case inputInvoiceStarGiftPrepaidUpgrade(Cons_inputInvoiceStarGiftPrepaidUpgrade)
        case inputInvoiceStarGiftResale(Cons_inputInvoiceStarGiftResale)
        case inputInvoiceStarGiftTransfer(Cons_inputInvoiceStarGiftTransfer)
        case inputInvoiceStarGiftUpgrade(Cons_inputInvoiceStarGiftUpgrade)
        case inputInvoiceStars(Cons_inputInvoiceStars)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputInvoiceBusinessBotTransferStars(Cons_inputInvoiceBusinessBotTransferStars(tlObject: object))
            case 1:
                self = .inputInvoiceChatInviteSubscription(Cons_inputInvoiceChatInviteSubscription(tlObject: object))
            case 2:
                self = .inputInvoiceMessage(Cons_inputInvoiceMessage(tlObject: object))
            case 3:
                self = .inputInvoicePremiumAuthCode(Cons_inputInvoicePremiumAuthCode(tlObject: object))
            case 4:
                self = .inputInvoicePremiumGiftCode(Cons_inputInvoicePremiumGiftCode(tlObject: object))
            case 5:
                self = .inputInvoicePremiumGiftStars(Cons_inputInvoicePremiumGiftStars(tlObject: object))
            case 6:
                self = .inputInvoiceSlug(Cons_inputInvoiceSlug(tlObject: object))
            case 7:
                self = .inputInvoiceStarGift(Cons_inputInvoiceStarGift(tlObject: object))
            case 8:
                self = .inputInvoiceStarGiftAuctionBid(Cons_inputInvoiceStarGiftAuctionBid(tlObject: object))
            case 9:
                self = .inputInvoiceStarGiftDropOriginalDetails(Cons_inputInvoiceStarGiftDropOriginalDetails(tlObject: object))
            case 10:
                self = .inputInvoiceStarGiftPrepaidUpgrade(Cons_inputInvoiceStarGiftPrepaidUpgrade(tlObject: object))
            case 11:
                self = .inputInvoiceStarGiftResale(Cons_inputInvoiceStarGiftResale(tlObject: object))
            case 12:
                self = .inputInvoiceStarGiftTransfer(Cons_inputInvoiceStarGiftTransfer(tlObject: object))
            case 13:
                self = .inputInvoiceStarGiftUpgrade(Cons_inputInvoiceStarGiftUpgrade(tlObject: object))
            case 14:
                self = .inputInvoiceStars(Cons_inputInvoiceStars(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputInvoiceBusinessBotTransferStars(let _data):
                return _data.tlObject
            case .inputInvoiceChatInviteSubscription(let _data):
                return _data.tlObject
            case .inputInvoiceMessage(let _data):
                return _data.tlObject
            case .inputInvoicePremiumAuthCode(let _data):
                return _data.tlObject
            case .inputInvoicePremiumGiftCode(let _data):
                return _data.tlObject
            case .inputInvoicePremiumGiftStars(let _data):
                return _data.tlObject
            case .inputInvoiceSlug(let _data):
                return _data.tlObject
            case .inputInvoiceStarGift(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftAuctionBid(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftDropOriginalDetails(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftPrepaidUpgrade(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftResale(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftTransfer(let _data):
                return _data.tlObject
            case .inputInvoiceStarGiftUpgrade(let _data):
                return _data.tlObject
            case .inputInvoiceStars(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputInvoice] {
            return tlObjectsAt(object, offset).map { Api.InputInvoice(tlObject: $0) }
        }

    }
}
public extension Api.InputInvoice.Cons_inputInvoiceBusinessBotTransferStars {
    @_alwaysEmitIntoClient var bot: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(bot: Api.InputUser, stars: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1630))
        tlStoreReference(_tlObject, 24, bot.tlObject)
        tlStore(_tlObject, 32, stars)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceChatInviteSubscription {
    @_alwaysEmitIntoClient var hash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(hash: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(338))
        tlStoreReference(_tlObject, 24, hash as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceMessage {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.InputPeer, msgId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1323))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoicePremiumAuthCode {
    @_alwaysEmitIntoClient var purpose: Api.InputStorePaymentPurpose {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStorePaymentPurpose(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(purpose: Api.InputStorePaymentPurpose) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(405))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoicePremiumGiftCode {
    @_alwaysEmitIntoClient var purpose: Api.InputStorePaymentPurpose {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStorePaymentPurpose(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var option: Api.PremiumGiftCodeOption {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PremiumGiftCodeOption(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(purpose: Api.InputStorePaymentPurpose, option: Api.PremiumGiftCodeOption) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(981))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        tlStoreReference(_tlObject, 32, option.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoicePremiumGiftStars {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var months: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, userId: Api.InputUser, months: Int32, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1431))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, userId.tlObject)
        tlStore(_tlObject, 28, months)
        tlStoreReference(_tlObject, 40, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1301))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGift {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var giftId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, peer: Api.InputPeer, giftId: Int64, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1529))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, giftId)
        tlStoreReference(_tlObject, 48, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftAuctionBid {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.InputPeer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var giftId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var bidAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, peer: Api.InputPeer?, giftId: Int64, bidAmount: Int64, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(208))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer?.tlObject)
        tlStore(_tlObject, 40, giftId)
        tlStore(_tlObject, 48, bidAmount)
        tlStoreReference(_tlObject, 56, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftDropOriginalDetails {
    @_alwaysEmitIntoClient var stargift: Api.InputSavedStarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputSavedStarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(stargift: Api.InputSavedStarGift) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(58))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftPrepaidUpgrade {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var hash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(peer: Api.InputPeer, hash: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(995))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, hash as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftResale {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var toId: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, slug: String, toId: Api.InputPeer, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1541))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, slug as NSString)
        tlStoreReference(_tlObject, 40, toId.tlObject)
        tlStoreReference(_tlObject, 48, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftTransfer {
    @_alwaysEmitIntoClient var stargift: Api.InputSavedStarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputSavedStarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var toId: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(stargift: Api.InputSavedStarGift, toId: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(478))
        tlStoreReference(_tlObject, 24, stargift.tlObject)
        tlStoreReference(_tlObject, 32, toId.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStarGiftUpgrade {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stargift: Api.InputSavedStarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputSavedStarGift(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, stargift: Api.InputSavedStarGift) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(501))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stargift.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputInvoice.Cons_inputInvoiceStars {
    @_alwaysEmitIntoClient var purpose: Api.InputStorePaymentPurpose {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStorePaymentPurpose(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(purpose: Api.InputStorePaymentPurpose) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(655))
        tlStoreReference(_tlObject, 24, purpose.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputMediaContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaDice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaDocumentExternal {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaGame {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaGeoLive {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaGeoPoint {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaInvoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaPaidMedia {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaPhotoExternal {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaPoll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaStakeDice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaTodo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaUploadedDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaUploadedPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputMediaWebPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputMediaContact(Cons_inputMediaContact)
        case inputMediaDice(Cons_inputMediaDice)
        case inputMediaDocument(Cons_inputMediaDocument)
        case inputMediaDocumentExternal(Cons_inputMediaDocumentExternal)
        case inputMediaEmpty
        case inputMediaGame(Cons_inputMediaGame)
        case inputMediaGeoLive(Cons_inputMediaGeoLive)
        case inputMediaGeoPoint(Cons_inputMediaGeoPoint)
        case inputMediaInvoice(Cons_inputMediaInvoice)
        case inputMediaPaidMedia(Cons_inputMediaPaidMedia)
        case inputMediaPhoto(Cons_inputMediaPhoto)
        case inputMediaPhotoExternal(Cons_inputMediaPhotoExternal)
        case inputMediaPoll(Cons_inputMediaPoll)
        case inputMediaStakeDice(Cons_inputMediaStakeDice)
        case inputMediaStory(Cons_inputMediaStory)
        case inputMediaTodo(Cons_inputMediaTodo)
        case inputMediaUploadedDocument(Cons_inputMediaUploadedDocument)
        case inputMediaUploadedPhoto(Cons_inputMediaUploadedPhoto)
        case inputMediaVenue(Cons_inputMediaVenue)
        case inputMediaWebPage(Cons_inputMediaWebPage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputMediaContact(Cons_inputMediaContact(tlObject: object))
            case 1:
                self = .inputMediaDice(Cons_inputMediaDice(tlObject: object))
            case 2:
                self = .inputMediaDocument(Cons_inputMediaDocument(tlObject: object))
            case 3:
                self = .inputMediaDocumentExternal(Cons_inputMediaDocumentExternal(tlObject: object))
            case 4:
                self = .inputMediaEmpty
            case 5:
                self = .inputMediaGame(Cons_inputMediaGame(tlObject: object))
            case 6:
                self = .inputMediaGeoLive(Cons_inputMediaGeoLive(tlObject: object))
            case 7:
                self = .inputMediaGeoPoint(Cons_inputMediaGeoPoint(tlObject: object))
            case 8:
                self = .inputMediaInvoice(Cons_inputMediaInvoice(tlObject: object))
            case 9:
                self = .inputMediaPaidMedia(Cons_inputMediaPaidMedia(tlObject: object))
            case 10:
                self = .inputMediaPhoto(Cons_inputMediaPhoto(tlObject: object))
            case 11:
                self = .inputMediaPhotoExternal(Cons_inputMediaPhotoExternal(tlObject: object))
            case 12:
                self = .inputMediaPoll(Cons_inputMediaPoll(tlObject: object))
            case 13:
                self = .inputMediaStakeDice(Cons_inputMediaStakeDice(tlObject: object))
            case 14:
                self = .inputMediaStory(Cons_inputMediaStory(tlObject: object))
            case 15:
                self = .inputMediaTodo(Cons_inputMediaTodo(tlObject: object))
            case 16:
                self = .inputMediaUploadedDocument(Cons_inputMediaUploadedDocument(tlObject: object))
            case 17:
                self = .inputMediaUploadedPhoto(Cons_inputMediaUploadedPhoto(tlObject: object))
            case 18:
                self = .inputMediaVenue(Cons_inputMediaVenue(tlObject: object))
            case 19:
                self = .inputMediaWebPage(Cons_inputMediaWebPage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputMediaContact(let _data):
                return _data.tlObject
            case .inputMediaDice(let _data):
                return _data.tlObject
            case .inputMediaDocument(let _data):
                return _data.tlObject
            case .inputMediaDocumentExternal(let _data):
                return _data.tlObject
            case .inputMediaEmpty:
                return TLObjectSingleton(TLApiConstructorAt(964))
            case .inputMediaGame(let _data):
                return _data.tlObject
            case .inputMediaGeoLive(let _data):
                return _data.tlObject
            case .inputMediaGeoPoint(let _data):
                return _data.tlObject
            case .inputMediaInvoice(let _data):
                return _data.tlObject
            case .inputMediaPaidMedia(let _data):
                return _data.tlObject
            case .inputMediaPhoto(let _data):
                return _data.tlObject
            case .inputMediaPhotoExternal(let _data):
                return _data.tlObject
            case .inputMediaPoll(let _data):
                return _data.tlObject
            case .inputMediaStakeDice(let _data):
                return _data.tlObject
            case .inputMediaStory(let _data):
                return _data.tlObject
            case .inputMediaTodo(let _data):
                return _data.tlObject
            case .inputMediaUploadedDocument(let _data):
                return _data.tlObject
            case .inputMediaUploadedPhoto(let _data):
                return _data.tlObject
            case .inputMediaVenue(let _data):
                return _data.tlObject
            case .inputMediaWebPage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputMedia] {
            return tlObjectsAt(object, offset).map { Api.InputMedia(tlObject: $0) }
        }

    }
}
public extension Api.InputMedia.Cons_inputMediaContact {
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var firstName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var lastName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var vcard: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(phoneNumber: String, firstName: String, lastName: String, vcard: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1652))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, firstName as NSString)
        tlStoreReference(_tlObject, 40, lastName as NSString)
        tlStoreReference(_tlObject, 48, vcard as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaDice {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1517))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaDocument {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var videoCover: Api.InputPhoto? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var videoTimestamp: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var query: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, id: Api.InputDocument, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?, query: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1097))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, id.tlObject)
        tlStoreReference(_tlObject, 48, videoCover?.tlObject)
        if let _tlValue = videoTimestamp { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 56, query.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaDocumentExternal {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var videoCover: Api.InputPhoto? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var videoTimestamp: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, url: String, ttlSeconds: Int32?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(772))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, url as NSString)
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, videoCover?.tlObject)
        if let _tlValue = videoTimestamp { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaGame {
    @_alwaysEmitIntoClient var id: Api.InputGame {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGame(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(id: Api.InputGame) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1394))
        tlStoreReference(_tlObject, 24, id.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaGeoLive {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var heading: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var period: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var proximityNotificationRadius: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(971))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, geoPoint.tlObject)
        if let _tlValue = heading { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = period { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = proximityNotificationRadius { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaGeoPoint {
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(geoPoint: Api.InputGeoPoint) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1659))
        tlStoreReference(_tlObject, 24, geoPoint.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaInvoice {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var photo: Api.InputWebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputWebDocument(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var payload: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var provider: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var providerData: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var startParam: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var extendedMedia: Api.InputMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String?, providerData: Api.DataJSON, startParam: String?, extendedMedia: Api.InputMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(418))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        tlStoreReference(_tlObject, 56, invoice.tlObject)
        tlStoreReference(_tlObject, 64, payload.makeData() as NSData)
        tlStoreReference(_tlObject, 72, provider.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, providerData.tlObject)
        tlStoreReference(_tlObject, 88, startParam.map { value in value as NSString })
        tlStoreReference(_tlObject, 96, extendedMedia?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaPaidMedia {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var starsAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var extendedMedia: [Api.InputMedia] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputMedia.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var payload: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, starsAmount: Int64, extendedMedia: [Api.InputMedia], payload: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1313))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, starsAmount)
        tlStoreReference(_tlObject, 40, extendedMedia.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, payload.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Api.InputPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var video: Api.InputDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, id: Api.InputPhoto, ttlSeconds: Int32?, video: Api.InputDocument?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1499))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id.tlObject)
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, video?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaPhotoExternal {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, url: String, ttlSeconds: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1512))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaPoll {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var poll: Api.Poll {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Poll(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var correctAnswers: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlInt32sAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var attachedMedia: Api.InputMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var solution: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var solutionEntities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageEntity.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var solutionMedia: Api.InputMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.InputMedia(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, poll: Api.Poll, correctAnswers: [Int32]?, attachedMedia: Api.InputMedia?, solution: String?, solutionEntities: [Api.MessageEntity]?, solutionMedia: Api.InputMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(873))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, poll.tlObject)
        tlStoreReference(_tlObject, 40, correctAnswers.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 48, attachedMedia?.tlObject)
        tlStoreReference(_tlObject, 56, solution.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, solutionEntities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, solutionMedia?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaStakeDice {
    @_alwaysEmitIntoClient var gameHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var tonAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var clientSeed: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(gameHash: String, tonAmount: Int64, clientSeed: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1620))
        tlStoreReference(_tlObject, 24, gameHash as NSString)
        tlStore(_tlObject, 32, tonAmount)
        tlStoreReference(_tlObject, 40, clientSeed.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaStory {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.InputPeer, id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(884))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaTodo {
    @_alwaysEmitIntoClient var todo: Api.TodoList {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TodoList(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(todo: Api.TodoList) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1044))
        tlStoreReference(_tlObject, 24, todo.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaUploadedDocument {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var file: Api.InputFile {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputFile(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var thumb: Api.InputFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputFile(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var mimeType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.DocumentAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DocumentAttribute.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.InputDocument]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.InputDocument.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var videoCover: Api.InputPhoto? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var videoTimestamp: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, file: Api.InputFile, thumb: Api.InputFile?, mimeType: String, attributes: [Api.DocumentAttribute], stickers: [Api.InputDocument]?, videoCover: Api.InputPhoto?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(29))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, file.tlObject)
        tlStoreReference(_tlObject, 48, thumb?.tlObject)
        tlStoreReference(_tlObject, 56, mimeType as NSString)
        tlStoreReference(_tlObject, 64, attributes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, stickers.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, videoCover?.tlObject)
        if let _tlValue = videoTimestamp { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaUploadedPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var file: Api.InputFile {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputFile(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.InputDocument]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputDocument.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var video: Api.InputDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, file: Api.InputFile, stickers: [Api.InputDocument]?, ttlSeconds: Int32?, video: Api.InputDocument?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(811))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, file.tlObject)
        tlStoreReference(_tlObject, 40, stickers.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, video?.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaVenue {
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var provider: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var venueId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var venueType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    init(geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1288))
        tlStoreReference(_tlObject, 24, geoPoint.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, address as NSString)
        tlStoreReference(_tlObject, 48, provider as NSString)
        tlStoreReference(_tlObject, 56, venueId as NSString)
        tlStoreReference(_tlObject, 64, venueType as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputMedia.Cons_inputMediaWebPage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1295))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
