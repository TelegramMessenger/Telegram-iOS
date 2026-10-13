import TelegramApiObjC
public extension Api {
    indirect enum MessageExtendedMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageExtendedMedia {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageExtendedMediaPreview {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageExtendedMedia(Cons_messageExtendedMedia)
        case messageExtendedMediaPreview(Cons_messageExtendedMediaPreview)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageExtendedMedia(Cons_messageExtendedMedia(tlObject: object))
            case 1:
                self = .messageExtendedMediaPreview(Cons_messageExtendedMediaPreview(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageExtendedMedia(let _data):
                return _data.tlObject
            case .messageExtendedMediaPreview(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageExtendedMedia] {
            return tlObjectsAt(object, offset).map { Api.MessageExtendedMedia(tlObject: $0) }
        }

    }
}
public extension Api.MessageExtendedMedia.Cons_messageExtendedMedia {
    @_alwaysEmitIntoClient var media: Api.MessageMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(media: Api.MessageMedia) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1580))
        tlStoreReference(_tlObject, 24, media.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageExtendedMedia.Cons_messageExtendedMediaPreview {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var w: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var h: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var thumb: Api.PhotoSize? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.PhotoSize(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var videoDuration: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, w: Int32?, h: Int32?, thumb: Api.PhotoSize?, videoDuration: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1131))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = w { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = h { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 40, thumb?.tlObject)
        if let _tlValue = videoDuration { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageFwdHeader: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageFwdHeader {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageFwdHeader(Cons_messageFwdHeader)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageFwdHeader(Cons_messageFwdHeader(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageFwdHeader(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageFwdHeader] {
            return tlObjectsAt(object, offset).map { Api.MessageFwdHeader(tlObject: $0) }
        }

    }
}
public extension Api.MessageFwdHeader.Cons_messageFwdHeader {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var fromName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelPost: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var postAuthor: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var savedFromPeer: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var savedFromMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var savedFromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var savedFromName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var savedDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var psaType: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    init(flags: Int32, fromId: Api.Peer?, fromName: String?, date: Int32, channelPost: Int32?, postAuthor: String?, savedFromPeer: Api.Peer?, savedFromMsgId: Int32?, savedFromId: Api.Peer?, savedFromName: String?, savedDate: Int32?, psaType: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(504))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, fromId?.tlObject)
        tlStoreReference(_tlObject, 56, fromName.map { value in value as NSString })
        tlStore(_tlObject, 28, date)
        if let _tlValue = channelPost { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, postAuthor.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, savedFromPeer?.tlObject)
        if let _tlValue = savedFromMsgId { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 80, savedFromId?.tlObject)
        tlStoreReference(_tlObject, 88, savedFromName.map { value in value as NSString })
        if let _tlValue = savedDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 96, psaType.map { value in value as NSString })
        tlStore(_tlObject, 104, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum MessageMedia: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageMediaContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaDice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaGame {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaGeo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaGeoLive {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaGiveaway {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaGiveawayResults {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaInvoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaPaidMedia {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaPoll {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaToDo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaVideoStream {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messageMediaWebPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageMediaContact(Cons_messageMediaContact)
        case messageMediaDice(Cons_messageMediaDice)
        case messageMediaDocument(Cons_messageMediaDocument)
        case messageMediaEmpty
        case messageMediaGame(Cons_messageMediaGame)
        case messageMediaGeo(Cons_messageMediaGeo)
        case messageMediaGeoLive(Cons_messageMediaGeoLive)
        case messageMediaGiveaway(Cons_messageMediaGiveaway)
        case messageMediaGiveawayResults(Cons_messageMediaGiveawayResults)
        case messageMediaInvoice(Cons_messageMediaInvoice)
        case messageMediaPaidMedia(Cons_messageMediaPaidMedia)
        case messageMediaPhoto(Cons_messageMediaPhoto)
        case messageMediaPoll(Cons_messageMediaPoll)
        case messageMediaStory(Cons_messageMediaStory)
        case messageMediaToDo(Cons_messageMediaToDo)
        case messageMediaUnsupported
        case messageMediaVenue(Cons_messageMediaVenue)
        case messageMediaVideoStream(Cons_messageMediaVideoStream)
        case messageMediaWebPage(Cons_messageMediaWebPage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageMediaContact(Cons_messageMediaContact(tlObject: object))
            case 1:
                self = .messageMediaDice(Cons_messageMediaDice(tlObject: object))
            case 2:
                self = .messageMediaDocument(Cons_messageMediaDocument(tlObject: object))
            case 3:
                self = .messageMediaEmpty
            case 4:
                self = .messageMediaGame(Cons_messageMediaGame(tlObject: object))
            case 5:
                self = .messageMediaGeo(Cons_messageMediaGeo(tlObject: object))
            case 6:
                self = .messageMediaGeoLive(Cons_messageMediaGeoLive(tlObject: object))
            case 7:
                self = .messageMediaGiveaway(Cons_messageMediaGiveaway(tlObject: object))
            case 8:
                self = .messageMediaGiveawayResults(Cons_messageMediaGiveawayResults(tlObject: object))
            case 9:
                self = .messageMediaInvoice(Cons_messageMediaInvoice(tlObject: object))
            case 10:
                self = .messageMediaPaidMedia(Cons_messageMediaPaidMedia(tlObject: object))
            case 11:
                self = .messageMediaPhoto(Cons_messageMediaPhoto(tlObject: object))
            case 12:
                self = .messageMediaPoll(Cons_messageMediaPoll(tlObject: object))
            case 13:
                self = .messageMediaStory(Cons_messageMediaStory(tlObject: object))
            case 14:
                self = .messageMediaToDo(Cons_messageMediaToDo(tlObject: object))
            case 15:
                self = .messageMediaUnsupported
            case 16:
                self = .messageMediaVenue(Cons_messageMediaVenue(tlObject: object))
            case 17:
                self = .messageMediaVideoStream(Cons_messageMediaVideoStream(tlObject: object))
            case 18:
                self = .messageMediaWebPage(Cons_messageMediaWebPage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageMediaContact(let _data):
                return _data.tlObject
            case .messageMediaDice(let _data):
                return _data.tlObject
            case .messageMediaDocument(let _data):
                return _data.tlObject
            case .messageMediaEmpty:
                return TLObjectSingleton(TLApiConstructorAt(396))
            case .messageMediaGame(let _data):
                return _data.tlObject
            case .messageMediaGeo(let _data):
                return _data.tlObject
            case .messageMediaGeoLive(let _data):
                return _data.tlObject
            case .messageMediaGiveaway(let _data):
                return _data.tlObject
            case .messageMediaGiveawayResults(let _data):
                return _data.tlObject
            case .messageMediaInvoice(let _data):
                return _data.tlObject
            case .messageMediaPaidMedia(let _data):
                return _data.tlObject
            case .messageMediaPhoto(let _data):
                return _data.tlObject
            case .messageMediaPoll(let _data):
                return _data.tlObject
            case .messageMediaStory(let _data):
                return _data.tlObject
            case .messageMediaToDo(let _data):
                return _data.tlObject
            case .messageMediaUnsupported:
                return TLObjectSingleton(TLApiConstructorAt(1040))
            case .messageMediaVenue(let _data):
                return _data.tlObject
            case .messageMediaVideoStream(let _data):
                return _data.tlObject
            case .messageMediaWebPage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageMedia] {
            return tlObjectsAt(object, offset).map { Api.MessageMedia(tlObject: $0) }
        }

    }
}
public extension Api.MessageMedia.Cons_messageMediaContact {
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
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    init(phoneNumber: String, firstName: String, lastName: String, vcard: String, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(714))
        tlStoreReference(_tlObject, 24, phoneNumber as NSString)
        tlStoreReference(_tlObject, 32, firstName as NSString)
        tlStoreReference(_tlObject, 40, lastName as NSString)
        tlStoreReference(_tlObject, 48, vcard as NSString)
        tlStore(_tlObject, 56, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaDice {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var value: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var gameOutcome: Api.messages.EmojiGameOutcome? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.messages.EmojiGameOutcome(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, value: Int32, emoticon: String, gameOutcome: Api.messages.EmojiGameOutcome?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(57))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, value)
        tlStoreReference(_tlObject, 32, emoticon as NSString)
        tlStoreReference(_tlObject, 40, gameOutcome?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaDocument {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var altDocuments: [Api.Document]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Document.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var videoCover: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var videoTimestamp: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, document: Api.Document?, altDocuments: [Api.Document]?, videoCover: Api.Photo?, videoTimestamp: Int32?, ttlSeconds: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(538))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, document?.tlObject)
        tlStoreReference(_tlObject, 48, altDocuments.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, videoCover?.tlObject)
        if let _tlValue = videoTimestamp { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaGame {
    @_alwaysEmitIntoClient var game: Api.Game {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Game(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(game: Api.Game) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1697))
        tlStoreReference(_tlObject, 24, game.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaGeo {
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(geo: Api.GeoPoint) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(561))
        tlStoreReference(_tlObject, 24, geo.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaGeoLive {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var heading: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var period: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var proximityNotificationRadius: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, geo: Api.GeoPoint, heading: Int32?, period: Int32, proximityNotificationRadius: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1220))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, geo.tlObject)
        if let _tlValue = heading { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, period)
        if let _tlValue = proximityNotificationRadius { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaGiveaway {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channels: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var countriesIso2: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringsAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var prizeDescription: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var quantity: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var months: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(flags: Int32, channels: [Int64], countriesIso2: [String]?, prizeDescription: String?, quantity: Int32, months: Int32?, stars: Int64?, untilDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1110))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, tlPackInt64(channels) as NSData)
        tlStoreReference(_tlObject, 48, countriesIso2.map { value in value as NSArray })
        tlStoreReference(_tlObject, 56, prizeDescription.map { value in value as NSString })
        tlStore(_tlObject, 28, quantity)
        if let _tlValue = months { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = stars { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 36, untilDate)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaGiveawayResults {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var additionalPeersCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var launchMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var winnersCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unclaimedCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var winners: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var months: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 1) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 2) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var prizeDescription: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    init(flags: Int32, channelId: Int64, additionalPeersCount: Int32?, launchMsgId: Int32, winnersCount: Int32, unclaimedCount: Int32, winners: [Int64], months: Int32?, stars: Int64?, prizeDescription: String?, untilDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1373))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 56, channelId)
        if let _tlValue = additionalPeersCount { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, launchMsgId)
        tlStore(_tlObject, 36, winnersCount)
        tlStore(_tlObject, 40, unclaimedCount)
        tlStoreReference(_tlObject, 64, tlPackInt64(winners) as NSData)
        if let _tlValue = months { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = stars { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 80, prizeDescription.map { value in value as NSString })
        tlStore(_tlObject, 48, untilDate)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaInvoice {
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
    @_alwaysEmitIntoClient var receiptMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var totalAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var startParam: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var extendedMedia: Api.MessageExtendedMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MessageExtendedMedia(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, title: String, description: String, photo: Api.WebDocument?, receiptMsgId: Int32?, currency: String, totalAmount: Int64, startParam: String, extendedMedia: Api.MessageExtendedMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1637))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        if let _tlValue = receiptMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, currency as NSString)
        tlStore(_tlObject, 64, totalAmount)
        tlStoreReference(_tlObject, 72, startParam as NSString)
        tlStoreReference(_tlObject, 80, extendedMedia?.tlObject)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaPaidMedia {
    @_alwaysEmitIntoClient var starsAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var extendedMedia: [Api.MessageExtendedMedia] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageExtendedMedia.tlArray(self.tlObject, 32) } }
    }
    init(starsAmount: Int64, extendedMedia: [Api.MessageExtendedMedia]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1099))
        tlStore(_tlObject, 24, starsAmount)
        tlStoreReference(_tlObject, 32, extendedMedia.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var ttlSeconds: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var video: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, photo: Api.Photo?, ttlSeconds: Int32?, video: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1490))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, photo?.tlObject)
        if let _tlValue = ttlSeconds { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, video?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaPoll {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var poll: Api.Poll {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Poll(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var results: Api.PollResults {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PollResults(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var attachedMedia: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, poll: Api.Poll, results: Api.PollResults, attachedMedia: Api.MessageMedia?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(765))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, poll.tlObject)
        tlStoreReference(_tlObject, 40, results.tlObject)
        tlStoreReference(_tlObject, 48, attachedMedia?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaStory {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var story: Api.StoryItem? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.StoryItem(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, peer: Api.Peer, id: Int32, story: Api.StoryItem?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(669))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, story?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaToDo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var todo: Api.TodoList {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TodoList(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var completions: [Api.TodoCompletion]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.TodoCompletion.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, todo: Api.TodoList, completions: [Api.TodoCompletion]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(886))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, todo.tlObject)
        tlStoreReference(_tlObject, 40, completions.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaVenue {
    @_alwaysEmitIntoClient var geo: Api.GeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GeoPoint(tlObject: tlObjectAt(self.tlObject, 24)) } }
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
    init(geo: Api.GeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(293))
        tlStoreReference(_tlObject, 24, geo.tlObject)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, address as NSString)
        tlStoreReference(_tlObject, 48, provider as NSString)
        tlStoreReference(_tlObject, 56, venueId as NSString)
        tlStoreReference(_tlObject, 64, venueType as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaVideoStream {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var call: Api.InputGroupCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, call: Api.InputGroupCall) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1346))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, call.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessageMedia.Cons_messageMediaWebPage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var webpage: Api.WebPage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WebPage(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, webpage: Api.WebPage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1460))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, webpage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessagePeerReaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messagePeerReaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messagePeerReaction(Cons_messagePeerReaction)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messagePeerReaction(Cons_messagePeerReaction(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messagePeerReaction(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessagePeerReaction] {
            return tlObjectsAt(object, offset).map { Api.MessagePeerReaction(tlObject: $0) }
        }

    }
}
public extension Api.MessagePeerReaction.Cons_messagePeerReaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(900))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peerId.tlObject)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 40, reaction.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessagePeerVote: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messagePeerVote {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messagePeerVoteInputOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messagePeerVoteMultiple {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messagePeerVote(Cons_messagePeerVote)
        case messagePeerVoteInputOption(Cons_messagePeerVoteInputOption)
        case messagePeerVoteMultiple(Cons_messagePeerVoteMultiple)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messagePeerVote(Cons_messagePeerVote(tlObject: object))
            case 1:
                self = .messagePeerVoteInputOption(Cons_messagePeerVoteInputOption(tlObject: object))
            case 2:
                self = .messagePeerVoteMultiple(Cons_messagePeerVoteMultiple(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messagePeerVote(let _data):
                return _data.tlObject
            case .messagePeerVoteInputOption(let _data):
                return _data.tlObject
            case .messagePeerVoteMultiple(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessagePeerVote] {
            return tlObjectsAt(object, offset).map { Api.MessagePeerVote(tlObject: $0) }
        }

    }
}
public extension Api.MessagePeerVote.Cons_messagePeerVote {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, option: Buffer, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1203))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, option.makeData() as NSData)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessagePeerVote.Cons_messagePeerVoteInputOption {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(746))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.MessagePeerVote.Cons_messagePeerVoteMultiple {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var options: [Buffer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBuffersAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, options: [Buffer], date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(450))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, options.map { item in item.makeData() } as NSArray)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageRange: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageRange {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageRange(Cons_messageRange)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageRange(Cons_messageRange(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageRange(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageRange] {
            return tlObjectsAt(object, offset).map { Api.MessageRange(tlObject: $0) }
        }

    }
}
public extension Api.MessageRange.Cons_messageRange {
    @_alwaysEmitIntoClient var minId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var maxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(minId: Int32, maxId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(73))
        tlStore(_tlObject, 24, minId)
        tlStore(_tlObject, 28, maxId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageReactions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReactions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReactions(Cons_messageReactions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReactions(Cons_messageReactions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReactions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageReactions] {
            return tlObjectsAt(object, offset).map { Api.MessageReactions(tlObject: $0) }
        }

    }
}
public extension Api.MessageReactions.Cons_messageReactions {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var results: [Api.ReactionCount] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ReactionCount.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var recentReactions: [Api.MessagePeerReaction]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessagePeerReaction.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var topReactors: [Api.MessageReactor]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageReactor.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?, topReactors: [Api.MessageReactor]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(66))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, results.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, recentReactions.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, topReactors.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageReactor: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReactor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReactor(Cons_messageReactor)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReactor(Cons_messageReactor(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReactor(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageReactor] {
            return tlObjectsAt(object, offset).map { Api.MessageReactor(tlObject: $0) }
        }

    }
}
public extension Api.MessageReactor.Cons_messageReactor {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, peerId: Api.Peer?, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(487))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peerId?.tlObject)
        tlStore(_tlObject, 28, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum MessageReplies: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReplies {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReplies(Cons_messageReplies)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReplies(Cons_messageReplies(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReplies(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.MessageReplies] {
            return tlObjectsAt(object, offset).map { Api.MessageReplies(tlObject: $0) }
        }

    }
}
public extension Api.MessageReplies.Cons_messageReplies {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replies: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var repliesPts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recentRepliers: [Api.Peer]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Peer.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var maxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var readMaxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, replies: Int32, repliesPts: Int32, recentRepliers: [Api.Peer]?, channelId: Int64?, maxId: Int32?, readMaxId: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(846))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, replies)
        tlStore(_tlObject, 32, repliesPts)
        tlStoreReference(_tlObject, 48, recentRepliers.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = channelId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = maxId { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = readMaxId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
