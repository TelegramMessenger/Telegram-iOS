import TelegramApiObjC
public extension Api {
    enum BotInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botInfo(Cons_botInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botInfo(Cons_botInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotInfo] {
            return tlObjectsAt(object, offset).map { Api.BotInfo(tlObject: $0) }
        }

    }
}
public extension Api.BotInfo.Cons_botInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var descriptionPhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var descriptionDocument: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var commands: [Api.BotCommand]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.BotCommand.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var menuButton: Api.BotMenuButton? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.BotMenuButton(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var privacyPolicyUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var appSettings: Api.BotAppSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.BotAppSettings(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var verifierSettings: Api.BotVerifierSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.BotVerifierSettings(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    init(flags: Int32, userId: Int64?, description: String?, descriptionPhoto: Api.Photo?, descriptionDocument: Api.Document?, commands: [Api.BotCommand]?, menuButton: Api.BotMenuButton?, privacyPolicyUrl: String?, appSettings: Api.BotAppSettings?, verifierSettings: Api.BotVerifierSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(502))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = userId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, descriptionPhoto?.tlObject)
        tlStoreReference(_tlObject, 56, descriptionDocument?.tlObject)
        tlStoreReference(_tlObject, 64, commands.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, menuButton?.tlObject)
        tlStoreReference(_tlObject, 80, privacyPolicyUrl.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, appSettings?.tlObject)
        tlStoreReference(_tlObject, 96, verifierSettings?.tlObject)
        tlStore(_tlObject, 104, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotInlineMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botInlineMessageMediaAuto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageMediaContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageMediaGeo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageMediaInvoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageMediaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageMediaWebPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageRichMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineMessageText {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botInlineMessageMediaAuto(Cons_botInlineMessageMediaAuto)
        case botInlineMessageMediaContact(Cons_botInlineMessageMediaContact)
        case botInlineMessageMediaGeo(Cons_botInlineMessageMediaGeo)
        case botInlineMessageMediaInvoice(Cons_botInlineMessageMediaInvoice)
        case botInlineMessageMediaVenue(Cons_botInlineMessageMediaVenue)
        case botInlineMessageMediaWebPage(Cons_botInlineMessageMediaWebPage)
        case botInlineMessageRichMessage(Cons_botInlineMessageRichMessage)
        case botInlineMessageText(Cons_botInlineMessageText)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botInlineMessageMediaAuto(Cons_botInlineMessageMediaAuto(tlObject: object))
            case 1:
                self = .botInlineMessageMediaContact(Cons_botInlineMessageMediaContact(tlObject: object))
            case 2:
                self = .botInlineMessageMediaGeo(Cons_botInlineMessageMediaGeo(tlObject: object))
            case 3:
                self = .botInlineMessageMediaInvoice(Cons_botInlineMessageMediaInvoice(tlObject: object))
            case 4:
                self = .botInlineMessageMediaVenue(Cons_botInlineMessageMediaVenue(tlObject: object))
            case 5:
                self = .botInlineMessageMediaWebPage(Cons_botInlineMessageMediaWebPage(tlObject: object))
            case 6:
                self = .botInlineMessageRichMessage(Cons_botInlineMessageRichMessage(tlObject: object))
            case 7:
                self = .botInlineMessageText(Cons_botInlineMessageText(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botInlineMessageMediaAuto(let _data):
                return _data.tlObject
            case .botInlineMessageMediaContact(let _data):
                return _data.tlObject
            case .botInlineMessageMediaGeo(let _data):
                return _data.tlObject
            case .botInlineMessageMediaInvoice(let _data):
                return _data.tlObject
            case .botInlineMessageMediaVenue(let _data):
                return _data.tlObject
            case .botInlineMessageMediaWebPage(let _data):
                return _data.tlObject
            case .botInlineMessageRichMessage(let _data):
                return _data.tlObject
            case .botInlineMessageText(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotInlineMessage] {
            return tlObjectsAt(object, offset).map { Api.BotInlineMessage(tlObject: $0) }
        }

    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaAuto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(758))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaContact {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var phoneNumber: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var firstName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var lastName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var vcard: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, phoneNumber: String, firstName: String, lastName: String, vcard: String, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(163))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, firstName as NSString)
        tlStoreReference(_tlObject, 48, lastName as NSString)
        tlStoreReference(_tlObject, 56, vcard as NSString)
        tlStoreReference(_tlObject, 64, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaGeo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var heading: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var period: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var proximityNotificationRadius: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(37))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, geo.tlObject)
        if let _tlValue = heading { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = period { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = proximityNotificationRadius { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaInvoice {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var totalAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, currency: String, totalAmount: Int64, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(340))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        tlStoreReference(_tlObject, 56, currency as NSString)
        tlStore(_tlObject, 64, totalAmount)
        tlStoreReference(_tlObject, 72, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaVenue {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var provider: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var venueId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var venueType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(888))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, geo.tlObject)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, address as NSString)
        tlStoreReference(_tlObject, 56, provider as NSString)
        tlStoreReference(_tlObject, 64, venueId as NSString)
        tlStoreReference(_tlObject, 72, venueType as NSString)
        tlStoreReference(_tlObject, 80, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageMediaWebPage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, message: String, entities: [Api.MessageEntity]?, url: String, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(826))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, url as NSString)
        tlStoreReference(_tlObject, 56, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageRichMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.RichMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, replyMarkup: Api.ReplyMarkup?, richMessage: Api.RichMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(68))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 40, richMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineMessage.Cons_botInlineMessageText {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, message: String, entities: [Api.MessageEntity]?, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(902))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotInlineResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botInlineMediaResult {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_botInlineResult {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botInlineMediaResult(Cons_botInlineMediaResult)
        case botInlineResult(Cons_botInlineResult)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botInlineMediaResult(Cons_botInlineMediaResult(tlObject: object))
            case 1:
                self = .botInlineResult(Cons_botInlineResult(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botInlineMediaResult(let _data):
                return _data.tlObject
            case .botInlineResult(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotInlineResult] {
            return tlObjectsAt(object, offset).map { Api.BotInlineResult(tlObject: $0) }
        }

    }
}
public extension Api.BotInlineResult.Cons_botInlineMediaResult {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.BotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotInlineMessage(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, id: String, type: String, photo: Api.Photo?, document: Api.Document?, title: String?, description: String?, sendMessage: Api.BotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(153))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, type as NSString)
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        tlStoreReference(_tlObject, 56, document?.tlObject)
        tlStoreReference(_tlObject, 64, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, sendMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.BotInlineResult.Cons_botInlineResult {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var thumb: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var content: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.BotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotInlineMessage(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.WebDocument?, content: Api.WebDocument?, sendMessage: Api.BotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(108))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, type as NSString)
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, url.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, thumb?.tlObject)
        tlStoreReference(_tlObject, 80, content?.tlObject)
        tlStoreReference(_tlObject, 88, sendMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotMenuButton: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botMenuButton {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botMenuButton(Cons_botMenuButton)
        case botMenuButtonCommands
        case botMenuButtonDefault


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botMenuButton(Cons_botMenuButton(tlObject: object))
            case 1:
                self = .botMenuButtonCommands
            case 2:
                self = .botMenuButtonDefault
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botMenuButton(let _data):
                return _data.tlObject
            case .botMenuButtonCommands:
                return TLObjectSingleton(TLApiConstructorAt(432))
            case .botMenuButtonDefault:
                return TLObjectSingleton(TLApiConstructorAt(751))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotMenuButton] {
            return tlObjectsAt(object, offset).map { Api.BotMenuButton(tlObject: $0) }
        }

    }
}
public extension Api.BotMenuButton.Cons_botMenuButton {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: String, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1331))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum BotPreviewMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botPreviewMedia {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botPreviewMedia(Cons_botPreviewMedia)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botPreviewMedia(Cons_botPreviewMedia(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botPreviewMedia(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotPreviewMedia] {
            return tlObjectsAt(object, offset).map { Api.BotPreviewMedia(tlObject: $0) }
        }

    }
}
public extension Api.BotPreviewMedia.Cons_botPreviewMedia {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(date: Int32, media: Api.MessageMedia) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(244))
        tlStore(_tlObject, 24, date)
        tlStoreReference(_tlObject, 32, media.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotVerification: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botVerification {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botVerification(Cons_botVerification)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botVerification(Cons_botVerification(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botVerification(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotVerification] {
            return tlObjectsAt(object, offset).map { Api.BotVerification(tlObject: $0) }
        }

    }
}
public extension Api.BotVerification.Cons_botVerification {
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var icon: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var description: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(botId: Int64, icon: Int64, description: Api.TextWithEntities) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1639))
        tlStore(_tlObject, 24, botId)
        tlStore(_tlObject, 32, icon)
        tlStoreReference(_tlObject, 40, description.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BotVerifierSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botVerifierSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botVerifierSettings(Cons_botVerifierSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botVerifierSettings(Cons_botVerifierSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botVerifierSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BotVerifierSettings] {
            return tlObjectsAt(object, offset).map { Api.BotVerifierSettings(tlObject: $0) }
        }

    }
}
public extension Api.BotVerifierSettings.Cons_botVerifierSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var icon: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var company: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var customDescription: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, icon: Int64, company: String, customDescription: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1056))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, icon)
        tlStoreReference(_tlObject, 40, company as NSString)
        tlStoreReference(_tlObject, 48, customDescription?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessAwayMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessAwayMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessAwayMessage(Cons_businessAwayMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessAwayMessage(Cons_businessAwayMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessAwayMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessAwayMessage] {
            return tlObjectsAt(object, offset).map { Api.BusinessAwayMessage(tlObject: $0) }
        }

    }
}
public extension Api.BusinessAwayMessage.Cons_businessAwayMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var schedule: Api.BusinessAwayMessageSchedule {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessAwayMessageSchedule(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var recipients: Api.BusinessRecipients {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessRecipients(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.BusinessRecipients) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1585))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, shortcutId)
        tlStoreReference(_tlObject, 32, schedule.tlObject)
        tlStoreReference(_tlObject, 40, recipients.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessAwayMessageSchedule: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessAwayMessageScheduleCustom {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessAwayMessageScheduleAlways
        case businessAwayMessageScheduleCustom(Cons_businessAwayMessageScheduleCustom)
        case businessAwayMessageScheduleOutsideWorkHours


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessAwayMessageScheduleAlways
            case 1:
                self = .businessAwayMessageScheduleCustom(Cons_businessAwayMessageScheduleCustom(tlObject: object))
            case 2:
                self = .businessAwayMessageScheduleOutsideWorkHours
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessAwayMessageScheduleAlways:
                return TLObjectSingleton(TLApiConstructorAt(1342))
            case .businessAwayMessageScheduleCustom(let _data):
                return _data.tlObject
            case .businessAwayMessageScheduleOutsideWorkHours:
                return TLObjectSingleton(TLApiConstructorAt(1312))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessAwayMessageSchedule] {
            return tlObjectsAt(object, offset).map { Api.BusinessAwayMessageSchedule(tlObject: $0) }
        }

    }
}
public extension Api.BusinessAwayMessageSchedule.Cons_businessAwayMessageScheduleCustom {
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var endDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(startDate: Int32, endDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1363))
        tlStore(_tlObject, 24, startDate)
        tlStore(_tlObject, 28, endDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessBotRecipients: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessBotRecipients {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessBotRecipients(Cons_businessBotRecipients)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessBotRecipients(Cons_businessBotRecipients(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessBotRecipients(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessBotRecipients] {
            return tlObjectsAt(object, offset).map { Api.BusinessBotRecipients(tlObject: $0) }
        }

    }
}
public extension Api.BusinessBotRecipients.Cons_businessBotRecipients {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlInt64sAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var excludeUsers: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlInt64sAt(self.tlObject, 40) } }
    }
    init(flags: Int32, users: [Int64]?, excludeUsers: [Int64]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1212))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { value in tlPackInt64(value) as NSData })
        tlStoreReference(_tlObject, 40, excludeUsers.map { value in tlPackInt64(value) as NSData })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessBotRights: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessBotRights {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessBotRights(Cons_businessBotRights)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessBotRights(Cons_businessBotRights(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessBotRights(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessBotRights] {
            return tlObjectsAt(object, offset).map { Api.BusinessBotRights(tlObject: $0) }
        }

    }
}
public extension Api.BusinessBotRights.Cons_businessBotRights {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1051))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessChatLink: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessChatLink {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessChatLink(Cons_businessChatLink)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessChatLink(Cons_businessChatLink(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessChatLink(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessChatLink] {
            return tlObjectsAt(object, offset).map { Api.BusinessChatLink(tlObject: $0) }
        }

    }
}
public extension Api.BusinessChatLink.Cons_businessChatLink {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var link: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageEntity.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var views: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, link: String, message: String, entities: [Api.MessageEntity]?, title: String?, views: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1183))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, link as NSString)
        tlStoreReference(_tlObject, 40, message as NSString)
        tlStoreReference(_tlObject, 48, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, title.map { value in value as NSString })
        tlStore(_tlObject, 28, views)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessGreetingMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessGreetingMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessGreetingMessage(Cons_businessGreetingMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessGreetingMessage(Cons_businessGreetingMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessGreetingMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessGreetingMessage] {
            return tlObjectsAt(object, offset).map { Api.BusinessGreetingMessage(tlObject: $0) }
        }

    }
}
public extension Api.BusinessGreetingMessage.Cons_businessGreetingMessage {
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recipients: Api.BusinessRecipients {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessRecipients(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var noActivityDays: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(shortcutId: Int32, recipients: Api.BusinessRecipients, noActivityDays: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1507))
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 32, recipients.tlObject)
        tlStore(_tlObject, 28, noActivityDays)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessIntro: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessIntro {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessIntro(Cons_businessIntro)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessIntro(Cons_businessIntro(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessIntro(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessIntro] {
            return tlObjectsAt(object, offset).map { Api.BusinessIntro(tlObject: $0) }
        }

    }
}
public extension Api.BusinessIntro.Cons_businessIntro {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var sticker: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, title: String, description: String, sticker: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(585))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, sticker?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessLocation: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessLocation(Cons_businessLocation)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessLocation(Cons_businessLocation(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessLocation(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessLocation] {
            return tlObjectsAt(object, offset).map { Api.BusinessLocation(tlObject: $0) }
        }

    }
}
public extension Api.BusinessLocation.Cons_businessLocation {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geoPoint: Api.GeoPoint? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, geoPoint: Api.GeoPoint?, address: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1124))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, geoPoint?.tlObject)
        tlStoreReference(_tlObject, 40, address as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessRecipients: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessRecipients {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessRecipients(Cons_businessRecipients)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessRecipients(Cons_businessRecipients(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessRecipients(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessRecipients] {
            return tlObjectsAt(object, offset).map { Api.BusinessRecipients(tlObject: $0) }
        }

    }
}
public extension Api.BusinessRecipients.Cons_businessRecipients {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlInt64sAt(self.tlObject, 32) } }
    }
    init(flags: Int32, users: [Int64]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(228))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { value in tlPackInt64(value) as NSData })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessWeeklyOpen: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessWeeklyOpen {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessWeeklyOpen(Cons_businessWeeklyOpen)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessWeeklyOpen(Cons_businessWeeklyOpen(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessWeeklyOpen(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessWeeklyOpen] {
            return tlObjectsAt(object, offset).map { Api.BusinessWeeklyOpen(tlObject: $0) }
        }

    }
}
public extension Api.BusinessWeeklyOpen.Cons_businessWeeklyOpen {
    @_alwaysEmitIntoClient var startMinute: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var endMinute: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(startMinute: Int32, endMinute: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(111))
        tlStore(_tlObject, 24, startMinute)
        tlStore(_tlObject, 28, endMinute)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum BusinessWorkHours: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessWorkHours {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessWorkHours(Cons_businessWorkHours)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessWorkHours(Cons_businessWorkHours(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessWorkHours(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.BusinessWorkHours] {
            return tlObjectsAt(object, offset).map { Api.BusinessWorkHours(tlObject: $0) }
        }

    }
}
public extension Api.BusinessWorkHours.Cons_businessWorkHours {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var timezoneId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var weeklyOpen: [Api.BusinessWeeklyOpen] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessWeeklyOpen.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, timezoneId: String, weeklyOpen: [Api.BusinessWeeklyOpen]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(904))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, timezoneId as NSString)
        tlStoreReference(_tlObject, 40, weeklyOpen.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ButtonType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_buttonTypeRequestPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_buttonTypeRequestPoll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_buttonTypeSimpleWebView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputButtonTypeRequestPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case buttonTypeDefault
        case buttonTypeRequestGeoLocation
        case buttonTypeRequestPeer(Cons_buttonTypeRequestPeer)
        case buttonTypeRequestPhone
        case buttonTypeRequestPoll(Cons_buttonTypeRequestPoll)
        case buttonTypeSimpleWebView(Cons_buttonTypeSimpleWebView)
        case inputButtonTypeRequestPeer(Cons_inputButtonTypeRequestPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .buttonTypeDefault
            case 1:
                self = .buttonTypeRequestGeoLocation
            case 2:
                self = .buttonTypeRequestPeer(Cons_buttonTypeRequestPeer(tlObject: object))
            case 3:
                self = .buttonTypeRequestPhone
            case 4:
                self = .buttonTypeRequestPoll(Cons_buttonTypeRequestPoll(tlObject: object))
            case 5:
                self = .buttonTypeSimpleWebView(Cons_buttonTypeSimpleWebView(tlObject: object))
            case 6:
                self = .inputButtonTypeRequestPeer(Cons_inputButtonTypeRequestPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .buttonTypeDefault:
                return TLObjectSingleton(TLApiConstructorAt(1343))
            case .buttonTypeRequestGeoLocation:
                return TLObjectSingleton(TLApiConstructorAt(1011))
            case .buttonTypeRequestPeer(let _data):
                return _data.tlObject
            case .buttonTypeRequestPhone:
                return TLObjectSingleton(TLApiConstructorAt(1468))
            case .buttonTypeRequestPoll(let _data):
                return _data.tlObject
            case .buttonTypeSimpleWebView(let _data):
                return _data.tlObject
            case .inputButtonTypeRequestPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ButtonType] {
            return tlObjectsAt(object, offset).map { Api.ButtonType(tlObject: $0) }
        }

    }
}
public extension Api.ButtonType.Cons_buttonTypeRequestPeer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var buttonId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerType: Api.RequestPeerType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RequestPeerType(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var maxQuantity: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(512))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, buttonId)
        tlStoreReference(_tlObject, 40, peerType.tlObject)
        tlStore(_tlObject, 32, maxQuantity)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ButtonType.Cons_buttonTypeRequestPoll {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var quiz: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, quiz: Api.Bool?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1115))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, quiz?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ButtonType.Cons_buttonTypeSimpleWebView {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1279))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ButtonType.Cons_inputButtonTypeRequestPeer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var buttonId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerType: Api.RequestPeerType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RequestPeerType(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var maxQuantity: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, buttonId: Int32, peerType: Api.RequestPeerType, maxQuantity: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(415))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, buttonId)
        tlStoreReference(_tlObject, 40, peerType.tlObject)
        tlStore(_tlObject, 32, maxQuantity)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum CdnConfig: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_cdnConfig {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case cdnConfig(Cons_cdnConfig)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .cdnConfig(Cons_cdnConfig(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .cdnConfig(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.CdnConfig] {
            return tlObjectsAt(object, offset).map { Api.CdnConfig(tlObject: $0) }
        }

    }
}
public extension Api.CdnConfig.Cons_cdnConfig {
    @_alwaysEmitIntoClient var publicKeys: [Api.CdnPublicKey] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.CdnPublicKey.tlArray(self.tlObject, 24) } }
    }
    init(publicKeys: [Api.CdnPublicKey]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(566))
        tlStoreReference(_tlObject, 24, publicKeys.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
