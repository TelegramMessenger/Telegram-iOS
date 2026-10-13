import TelegramApiObjC
public extension Api {
    enum InputStickerSet: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStickerSetDice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStickerSetID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStickerSetShortName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStickerSetAnimatedEmoji
        case inputStickerSetAnimatedEmojiAnimations
        case inputStickerSetDice(Cons_inputStickerSetDice)
        case inputStickerSetEmojiChannelDefaultStatuses
        case inputStickerSetEmojiDefaultStatuses
        case inputStickerSetEmojiDefaultTopicIcons
        case inputStickerSetEmojiGenericAnimations
        case inputStickerSetEmpty
        case inputStickerSetID(Cons_inputStickerSetID)
        case inputStickerSetPremiumGifts
        case inputStickerSetShortName(Cons_inputStickerSetShortName)
        case inputStickerSetTonGifts


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStickerSetAnimatedEmoji
            case 1:
                self = .inputStickerSetAnimatedEmojiAnimations
            case 2:
                self = .inputStickerSetDice(Cons_inputStickerSetDice(tlObject: object))
            case 3:
                self = .inputStickerSetEmojiChannelDefaultStatuses
            case 4:
                self = .inputStickerSetEmojiDefaultStatuses
            case 5:
                self = .inputStickerSetEmojiDefaultTopicIcons
            case 6:
                self = .inputStickerSetEmojiGenericAnimations
            case 7:
                self = .inputStickerSetEmpty
            case 8:
                self = .inputStickerSetID(Cons_inputStickerSetID(tlObject: object))
            case 9:
                self = .inputStickerSetPremiumGifts
            case 10:
                self = .inputStickerSetShortName(Cons_inputStickerSetShortName(tlObject: object))
            case 11:
                self = .inputStickerSetTonGifts
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStickerSetAnimatedEmoji:
                return TLObjectSingleton(TLApiConstructorAt(18))
            case .inputStickerSetAnimatedEmojiAnimations:
                return TLObjectSingleton(TLApiConstructorAt(82))
            case .inputStickerSetDice(let _data):
                return _data.tlObject
            case .inputStickerSetEmojiChannelDefaultStatuses:
                return TLObjectSingleton(TLApiConstructorAt(471))
            case .inputStickerSetEmojiDefaultStatuses:
                return TLObjectSingleton(TLApiConstructorAt(270))
            case .inputStickerSetEmojiDefaultTopicIcons:
                return TLObjectSingleton(TLApiConstructorAt(445))
            case .inputStickerSetEmojiGenericAnimations:
                return TLObjectSingleton(TLApiConstructorAt(33))
            case .inputStickerSetEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1711))
            case .inputStickerSetID(let _data):
                return _data.tlObject
            case .inputStickerSetPremiumGifts:
                return TLObjectSingleton(TLApiConstructorAt(1335))
            case .inputStickerSetShortName(let _data):
                return _data.tlObject
            case .inputStickerSetTonGifts:
                return TLObjectSingleton(TLApiConstructorAt(192))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStickerSet] {
            return tlObjectsAt(object, offset).map { Api.InputStickerSet(tlObject: $0) }
        }

    }
}
public extension Api.InputStickerSet.Cons_inputStickerSetDice {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1518))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStickerSet.Cons_inputStickerSetID {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1026))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStickerSet.Cons_inputStickerSetShortName {
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(shortName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(858))
        tlStoreReference(_tlObject, 24, shortName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputStickerSetItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStickerSetItem {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStickerSetItem(Cons_inputStickerSetItem)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStickerSetItem(Cons_inputStickerSetItem(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStickerSetItem(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStickerSetItem] {
            return tlObjectsAt(object, offset).map { Api.InputStickerSetItem(tlObject: $0) }
        }

    }
}
public extension Api.InputStickerSetItem.Cons_inputStickerSetItem {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var document: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var emoji: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var maskCoords: Api.MaskCoords? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MaskCoords(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var keywords: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, document: Api.InputDocument, emoji: String, maskCoords: Api.MaskCoords?, keywords: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(322))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, document.tlObject)
        tlStoreReference(_tlObject, 40, emoji as NSString)
        tlStoreReference(_tlObject, 48, maskCoords?.tlObject)
        tlStoreReference(_tlObject, 56, keywords.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputStickeredMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStickeredMediaDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStickeredMediaPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStickeredMediaDocument(Cons_inputStickeredMediaDocument)
        case inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStickeredMediaDocument(Cons_inputStickeredMediaDocument(tlObject: object))
            case 1:
                self = .inputStickeredMediaPhoto(Cons_inputStickeredMediaPhoto(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStickeredMediaDocument(let _data):
                return _data.tlObject
            case .inputStickeredMediaPhoto(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStickeredMedia] {
            return tlObjectsAt(object, offset).map { Api.InputStickeredMedia(tlObject: $0) }
        }

    }
}
public extension Api.InputStickeredMedia.Cons_inputStickeredMediaDocument {
    @_alwaysEmitIntoClient var id: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(id: Api.InputDocument) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(31))
        tlStoreReference(_tlObject, 24, id.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStickeredMedia.Cons_inputStickeredMediaPhoto {
    @_alwaysEmitIntoClient var id: Api.InputPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(id: Api.InputPhoto) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(480))
        tlStoreReference(_tlObject, 24, id.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputStorePaymentPurpose: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputStorePaymentAuthCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentGiftPremium {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentPremiumGiftCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentPremiumGiveaway {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentPremiumSubscription {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentStarsGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentStarsGiveaway {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStorePaymentStarsTopup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode)
        case inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium)
        case inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode)
        case inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway)
        case inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription)
        case inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift)
        case inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway)
        case inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputStorePaymentAuthCode(Cons_inputStorePaymentAuthCode(tlObject: object))
            case 1:
                self = .inputStorePaymentGiftPremium(Cons_inputStorePaymentGiftPremium(tlObject: object))
            case 2:
                self = .inputStorePaymentPremiumGiftCode(Cons_inputStorePaymentPremiumGiftCode(tlObject: object))
            case 3:
                self = .inputStorePaymentPremiumGiveaway(Cons_inputStorePaymentPremiumGiveaway(tlObject: object))
            case 4:
                self = .inputStorePaymentPremiumSubscription(Cons_inputStorePaymentPremiumSubscription(tlObject: object))
            case 5:
                self = .inputStorePaymentStarsGift(Cons_inputStorePaymentStarsGift(tlObject: object))
            case 6:
                self = .inputStorePaymentStarsGiveaway(Cons_inputStorePaymentStarsGiveaway(tlObject: object))
            case 7:
                self = .inputStorePaymentStarsTopup(Cons_inputStorePaymentStarsTopup(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputStorePaymentAuthCode(let _data):
                return _data.tlObject
            case .inputStorePaymentGiftPremium(let _data):
                return _data.tlObject
            case .inputStorePaymentPremiumGiftCode(let _data):
                return _data.tlObject
            case .inputStorePaymentPremiumGiveaway(let _data):
                return _data.tlObject
            case .inputStorePaymentPremiumSubscription(let _data):
                return _data.tlObject
            case .inputStorePaymentStarsGift(let _data):
                return _data.tlObject
            case .inputStorePaymentStarsGiveaway(let _data):
                return _data.tlObject
            case .inputStorePaymentStarsTopup(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputStorePaymentPurpose] {
            return tlObjectsAt(object, offset).map { Api.InputStorePaymentPurpose(tlObject: $0) }
        }

    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentAuthCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var phoneCodeHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var premiumDays: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(flags: Int32, phoneNumber: String, phoneCodeHash: String, premiumDays: Int32, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(411))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, phoneCodeHash as NSString)
        tlStore(_tlObject, 28, premiumDays)
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentGiftPremium {
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(userId: Api.InputUser, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(621))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStoreReference(_tlObject, 32, currency as NSString)
        tlStore(_tlObject, 40, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentPremiumGiftCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.InputUser] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var boostPeer: Api.InputPeer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, users: [Api.InputUser], boostPeer: Api.InputPeer?, currency: String, amount: Int64, message: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1676))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, boostPeer?.tlObject)
        tlStoreReference(_tlObject, 48, currency as NSString)
        tlStore(_tlObject, 56, amount)
        tlStoreReference(_tlObject, 64, message?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentPremiumGiveaway {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var boostPeer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var additionalPeers: [Api.InputPeer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputPeer.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var countriesIso2: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringsAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var prizeDescription: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    init(flags: Int32, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(136))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, boostPeer.tlObject)
        tlStoreReference(_tlObject, 40, additionalPeers.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, countriesIso2.map { value in value as NSArray })
        tlStoreReference(_tlObject, 56, prizeDescription.map { value in value as NSString })
        tlStore(_tlObject, 64, randomId)
        tlStore(_tlObject, 28, untilDate)
        tlStoreReference(_tlObject, 72, currency as NSString)
        tlStore(_tlObject, 80, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentPremiumSubscription {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1088))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentStarsGift {
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    init(userId: Api.InputUser, stars: Int64, currency: String, amount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(195))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        tlStore(_tlObject, 32, stars)
        tlStoreReference(_tlObject, 40, currency as NSString)
        tlStore(_tlObject, 48, amount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentStarsGiveaway {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var boostPeer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var additionalPeers: [Api.InputPeer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputPeer.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var countriesIso2: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringsAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var prizeDescription: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 96, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var users: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, stars: Int64, boostPeer: Api.InputPeer, additionalPeers: [Api.InputPeer]?, countriesIso2: [String]?, prizeDescription: String?, randomId: Int64, untilDate: Int32, currency: String, amount: Int64, users: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(748))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, stars)
        tlStoreReference(_tlObject, 48, boostPeer.tlObject)
        tlStoreReference(_tlObject, 56, additionalPeers.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 64, countriesIso2.map { value in value as NSArray })
        tlStoreReference(_tlObject, 72, prizeDescription.map { value in value as NSString })
        tlStore(_tlObject, 80, randomId)
        tlStore(_tlObject, 28, untilDate)
        tlStoreReference(_tlObject, 88, currency as NSString)
        tlStore(_tlObject, 96, amount)
        tlStore(_tlObject, 32, users)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputStorePaymentPurpose.Cons_inputStorePaymentStarsTopup {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var spendPurposePeer: Api.InputPeer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, stars: Int64, currency: String, amount: Int64, spendPurposePeer: Api.InputPeer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1658))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, stars)
        tlStoreReference(_tlObject, 40, currency as NSString)
        tlStore(_tlObject, 48, amount)
        tlStoreReference(_tlObject, 56, spendPurposePeer?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputTheme: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputTheme {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputThemeSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputTheme(Cons_inputTheme)
        case inputThemeSlug(Cons_inputThemeSlug)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputTheme(Cons_inputTheme(tlObject: object))
            case 1:
                self = .inputThemeSlug(Cons_inputThemeSlug(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputTheme(let _data):
                return _data.tlObject
            case .inputThemeSlug(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputTheme] {
            return tlObjectsAt(object, offset).map { Api.InputTheme(tlObject: $0) }
        }

    }
}
public extension Api.InputTheme.Cons_inputTheme {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(386))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputTheme.Cons_inputThemeSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1635))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputThemeSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputThemeSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputThemeSettings(Cons_inputThemeSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputThemeSettings(Cons_inputThemeSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputThemeSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputThemeSettings] {
            return tlObjectsAt(object, offset).map { Api.InputThemeSettings(tlObject: $0) }
        }

    }
}
public extension Api.InputThemeSettings.Cons_inputThemeSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var baseTheme: Api.BaseTheme {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BaseTheme(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var accentColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var outboxAccentColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var messageColors: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlInt32sAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var wallpaper: Api.InputWallPaper? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InputWallPaper(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var wallpaperSettings: Api.WallPaperSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.WallPaperSettings(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.InputWallPaper?, wallpaperSettings: Api.WallPaperSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(919))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, baseTheme.tlObject)
        tlStore(_tlObject, 28, accentColor)
        if let _tlValue = outboxAccentColor { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, messageColors.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 56, wallpaper?.tlObject)
        tlStoreReference(_tlObject, 64, wallpaperSettings?.tlObject)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputTonConnectOauthSession: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputTonConnectOauthSession {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputTonConnectOauthSession(Cons_inputTonConnectOauthSession)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputTonConnectOauthSession(Cons_inputTonConnectOauthSession(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputTonConnectOauthSession(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputTonConnectOauthSession] {
            return tlObjectsAt(object, offset).map { Api.InputTonConnectOauthSession(tlObject: $0) }
        }

    }
}
public extension Api.InputTonConnectOauthSession.Cons_inputTonConnectOauthSession {
    @_alwaysEmitIntoClient var sessionId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var challengeAnswer: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var body: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var proof: Api.WalletOwnershipProof {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WalletOwnershipProof(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(sessionId: Int64, challengeAnswer: Buffer, body: Buffer, proof: Api.WalletOwnershipProof) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(628))
        tlStore(_tlObject, 24, sessionId)
        tlStoreReference(_tlObject, 32, challengeAnswer.makeData() as NSData)
        tlStoreReference(_tlObject, 40, body.makeData() as NSData)
        tlStoreReference(_tlObject, 48, proof.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputUser: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputUserFromMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputUser(Cons_inputUser)
        case inputUserEmpty
        case inputUserFromMessage(Cons_inputUserFromMessage)
        case inputUserSelf


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputUser(Cons_inputUser(tlObject: object))
            case 1:
                self = .inputUserEmpty
            case 2:
                self = .inputUserFromMessage(Cons_inputUserFromMessage(tlObject: object))
            case 3:
                self = .inputUserSelf
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputUser(let _data):
                return _data.tlObject
            case .inputUserEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1222))
            case .inputUserFromMessage(let _data):
                return _data.tlObject
            case .inputUserSelf:
                return TLObjectSingleton(TLApiConstructorAt(1643))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputUser] {
            return tlObjectsAt(object, offset).map { Api.InputUser(tlObject: $0) }
        }

    }
}
public extension Api.InputUser.Cons_inputUser {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(userId: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1609))
        tlStore(_tlObject, 24, userId)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputUser.Cons_inputUserFromMessage {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(peer: Api.InputPeer, msgId: Int32, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(197))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputWallPaper: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputWallPaper {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputWallPaperNoFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputWallPaperSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputWallPaper(Cons_inputWallPaper)
        case inputWallPaperNoFile(Cons_inputWallPaperNoFile)
        case inputWallPaperSlug(Cons_inputWallPaperSlug)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputWallPaper(Cons_inputWallPaper(tlObject: object))
            case 1:
                self = .inputWallPaperNoFile(Cons_inputWallPaperNoFile(tlObject: object))
            case 2:
                self = .inputWallPaperSlug(Cons_inputWallPaperSlug(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputWallPaper(let _data):
                return _data.tlObject
            case .inputWallPaperNoFile(let _data):
                return _data.tlObject
            case .inputWallPaperSlug(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputWallPaper] {
            return tlObjectsAt(object, offset).map { Api.InputWallPaper(tlObject: $0) }
        }

    }
}
public extension Api.InputWallPaper.Cons_inputWallPaper {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1515))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputWallPaper.Cons_inputWallPaperNoFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(966))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputWallPaper.Cons_inputWallPaperSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(729))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputWalletCardSticker: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputWalletCardSticker {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputWalletCardSticker(Cons_inputWalletCardSticker)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputWalletCardSticker(Cons_inputWalletCardSticker(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputWalletCardSticker(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputWalletCardSticker] {
            return tlObjectsAt(object, offset).map { Api.InputWalletCardSticker(tlObject: $0) }
        }

    }
}
public extension Api.InputWalletCardSticker.Cons_inputWalletCardSticker {
    @_alwaysEmitIntoClient var coordinates: Api.MediaAreaCoordinates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MediaAreaCoordinates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var nftAddress: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(coordinates: Api.MediaAreaCoordinates, nftAddress: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(571))
        tlStoreReference(_tlObject, 24, coordinates.tlObject)
        tlStoreReference(_tlObject, 32, nftAddress as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputWalletReplacement: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputWalletImported {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputWalletImported(Cons_inputWalletImported)
        case inputWalletNew


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputWalletImported(Cons_inputWalletImported(tlObject: object))
            case 1:
                self = .inputWalletNew
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputWalletImported(let _data):
                return _data.tlObject
            case .inputWalletNew:
                return TLObjectSingleton(TLApiConstructorAt(636))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputWalletReplacement] {
            return tlObjectsAt(object, offset).map { Api.InputWalletReplacement(tlObject: $0) }
        }

    }
}
public extension Api.InputWalletReplacement.Cons_inputWalletImported {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var publicKey: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var anchorPublicKey: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var proof: Api.WalletOwnershipProof {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WalletOwnershipProof(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, publicKey: Buffer, anchorPublicKey: Buffer?, proof: Api.WalletOwnershipProof) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(657))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, publicKey.makeData() as NSData)
        tlStoreReference(_tlObject, 40, anchorPublicKey.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, proof.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputWebDocument: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputWebDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputWebDocument(Cons_inputWebDocument)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputWebDocument(Cons_inputWebDocument(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputWebDocument(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputWebDocument] {
            return tlObjectsAt(object, offset).map { Api.InputWebDocument(tlObject: $0) }
        }

    }
}
public extension Api.InputWebDocument.Cons_inputWebDocument {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var size: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var mimeType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.DocumentAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DocumentAttribute.tlArray(self.tlObject, 48) } }
    }
    init(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1010))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, size)
        tlStoreReference(_tlObject, 40, mimeType as NSString)
        tlStoreReference(_tlObject, 48, attributes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputWebFileLocation: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputWebFileAudioAlbumThumbLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputWebFileGeoPointLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputWebFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation)
        case inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation)
        case inputWebFileLocation(Cons_inputWebFileLocation)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputWebFileAudioAlbumThumbLocation(Cons_inputWebFileAudioAlbumThumbLocation(tlObject: object))
            case 1:
                self = .inputWebFileGeoPointLocation(Cons_inputWebFileGeoPointLocation(tlObject: object))
            case 2:
                self = .inputWebFileLocation(Cons_inputWebFileLocation(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputWebFileAudioAlbumThumbLocation(let _data):
                return _data.tlObject
            case .inputWebFileGeoPointLocation(let _data):
                return _data.tlObject
            case .inputWebFileLocation(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputWebFileLocation] {
            return tlObjectsAt(object, offset).map { Api.InputWebFileLocation(tlObject: $0) }
        }

    }
}
public extension Api.InputWebFileLocation.Cons_inputWebFileAudioAlbumThumbLocation {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var document: Api.InputDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var performer: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, document: Api.InputDocument?, title: String?, performer: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1626))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, document?.tlObject)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, performer.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputWebFileLocation.Cons_inputWebFileGeoPointLocation {
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var zoom: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var scale: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(geoPoint: Api.InputGeoPoint, accessHash: Int64, w: Int32, h: Int32, zoom: Int32, scale: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1036))
        tlStoreReference(_tlObject, 40, geoPoint.tlObject)
        tlStore(_tlObject, 48, accessHash)
        tlStore(_tlObject, 24, w)
        tlStore(_tlObject, 28, h)
        tlStore(_tlObject, 32, zoom)
        tlStore(_tlObject, 36, scale)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputWebFileLocation.Cons_inputWebFileLocation {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(url: String, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1298))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Invoice: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_invoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case invoice(Cons_invoice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .invoice(Cons_invoice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .invoice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Invoice] {
            return tlObjectsAt(object, offset).map { Api.Invoice(tlObject: $0) }
        }

    }
}
public extension Api.Invoice.Cons_invoice {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var prices: [Api.LabeledPrice] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.LabeledPrice.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var maxTipAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var suggestedTipAmounts: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlInt64sAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var termsUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var subscriptionPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, currency: String, prices: [Api.LabeledPrice], maxTipAmount: Int64?, suggestedTipAmounts: [Int64]?, termsUrl: String?, subscriptionPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(32))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, currency as NSString)
        tlStoreReference(_tlObject, 40, prices.map { item in item.tlObject } as NSArray)
        if let _tlValue = maxTipAmount { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, suggestedTipAmounts.map { value in tlPackInt64(value) as NSData })
        tlStoreReference(_tlObject, 64, termsUrl.map { value in value as NSString })
        if let _tlValue = subscriptionPeriod { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
