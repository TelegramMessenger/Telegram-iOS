import TelegramApiObjC
public extension Api {
    indirect enum Updates: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_updateShort {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_updateShortChatMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_updateShortMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_updateShortSentMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_updates {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_updatesCombined {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case updateShort(Cons_updateShort)
        case updateShortChatMessage(Cons_updateShortChatMessage)
        case updateShortMessage(Cons_updateShortMessage)
        case updateShortSentMessage(Cons_updateShortSentMessage)
        case updates(Cons_updates)
        case updatesCombined(Cons_updatesCombined)
        case updatesTooLong


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .updateShort(Cons_updateShort(tlObject: object))
            case 1:
                self = .updateShortChatMessage(Cons_updateShortChatMessage(tlObject: object))
            case 2:
                self = .updateShortMessage(Cons_updateShortMessage(tlObject: object))
            case 3:
                self = .updateShortSentMessage(Cons_updateShortSentMessage(tlObject: object))
            case 4:
                self = .updates(Cons_updates(tlObject: object))
            case 5:
                self = .updatesCombined(Cons_updatesCombined(tlObject: object))
            case 6:
                self = .updatesTooLong
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .updateShort(let _data):
                return _data.tlObject
            case .updateShortChatMessage(let _data):
                return _data.tlObject
            case .updateShortMessage(let _data):
                return _data.tlObject
            case .updateShortSentMessage(let _data):
                return _data.tlObject
            case .updates(let _data):
                return _data.tlObject
            case .updatesCombined(let _data):
                return _data.tlObject
            case .updatesTooLong:
                return TLObjectSingleton(TLApiConstructorAt(1492))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Updates] {
            return tlObjectsAt(object, offset).map { Api.Updates(tlObject: $0) }
        }

    }
}
public extension Api.Updates.Cons_updateShort {
    @_alwaysEmitIntoClient var update: Api.Update {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(update: Api.Update, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(777))
        tlStoreReference(_tlObject, 32, update.tlObject)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Updates.Cons_updateShortChatMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fwdFrom: Api.MessageFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.MessageFwdHeader(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var viaBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 0) ? tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.MessageReplyHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.MessageReplyHeader(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.MessageEntity.tlArray(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 1) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int32, fromId: Int64, chatId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(498))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 48, fromId)
        tlStore(_tlObject, 56, chatId)
        tlStoreReference(_tlObject, 64, message as NSString)
        tlStore(_tlObject, 32, pts)
        tlStore(_tlObject, 36, ptsCount)
        tlStore(_tlObject, 40, date)
        tlStoreReference(_tlObject, 72, fwdFrom?.tlObject)
        if let _tlValue = viaBotId { tlStore(_tlObject, 80, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 88, replyTo?.tlObject)
        tlStoreReference(_tlObject, 96, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 104, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Updates.Cons_updateShortMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fwdFrom: Api.MessageFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageFwdHeader(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var viaBotId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 72, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.MessageReplyHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MessageReplyHeader(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.MessageEntity.tlArray(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int32, userId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(312))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 48, userId)
        tlStoreReference(_tlObject, 56, message as NSString)
        tlStore(_tlObject, 32, pts)
        tlStore(_tlObject, 36, ptsCount)
        tlStore(_tlObject, 40, date)
        tlStoreReference(_tlObject, 64, fwdFrom?.tlObject)
        if let _tlValue = viaBotId { tlStore(_tlObject, 72, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 80, replyTo?.tlObject)
        tlStoreReference(_tlObject, 88, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Updates.Cons_updateShortSentMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ptsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.MessageEntity.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(923))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, pts)
        tlStore(_tlObject, 36, ptsCount)
        tlStore(_tlObject, 40, date)
        tlStoreReference(_tlObject, 48, media?.tlObject)
        tlStoreReference(_tlObject, 56, entities.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Updates.Cons_updates {
    @_alwaysEmitIntoClient var updates: [Api.Update] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seq: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(744))
        tlStoreReference(_tlObject, 32, updates.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 28, seq)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Updates.Cons_updatesCombined {
    @_alwaysEmitIntoClient var updates: [Api.Update] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seqStart: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seq: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(730))
        tlStoreReference(_tlObject, 40, updates.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 28, seqStart)
        tlStore(_tlObject, 32, seq)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum UrlAuthResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_urlAuthResultAccepted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_urlAuthResultRequest {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case urlAuthResultAccepted(Cons_urlAuthResultAccepted)
        case urlAuthResultDefault
        case urlAuthResultRequest(Cons_urlAuthResultRequest)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .urlAuthResultAccepted(Cons_urlAuthResultAccepted(tlObject: object))
            case 1:
                self = .urlAuthResultDefault
            case 2:
                self = .urlAuthResultRequest(Cons_urlAuthResultRequest(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .urlAuthResultAccepted(let _data):
                return _data.tlObject
            case .urlAuthResultDefault:
                return TLObjectSingleton(TLApiConstructorAt(1109))
            case .urlAuthResultRequest(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.UrlAuthResult] {
            return tlObjectsAt(object, offset).map { Api.UrlAuthResult(tlObject: $0) }
        }

    }
}
public extension Api.UrlAuthResult.Cons_urlAuthResultAccepted {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, url: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(624))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.UrlAuthResult.Cons_urlAuthResultRequest {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bot: Api.User {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var domain: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var browser: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var platform: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var ip: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var region: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var matchCodes: [String]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringsAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var userIdHint: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 120, 0) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var verifiedAppName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var tcSessionId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 120, 1) ? tlBase(self.tlObject).load(fromByteOffset: 104, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var tcClientId: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlStringAt(self.tlObject, 112) } }
    }
    init(flags: Int32, bot: Api.User, domain: String, browser: String?, platform: String?, ip: String?, region: String?, matchCodes: [String]?, userIdHint: Int64?, verifiedAppName: String?, tcSessionId: Int64?, tcClientId: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1256))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot.tlObject)
        tlStoreReference(_tlObject, 40, domain as NSString)
        tlStoreReference(_tlObject, 48, browser.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, platform.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, ip.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, region.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, matchCodes.map { value in value as NSArray })
        if let _tlValue = userIdHint { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 96, verifiedAppName.map { value in value as NSString })
        if let _tlValue = tcSessionId { tlStore(_tlObject, 104, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 112, tcClientId.map { value in value as NSString })
        tlStore(_tlObject, 120, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum User: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_user {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_userEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case user(Cons_user)
        case userEmpty(Cons_userEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .user(Cons_user(tlObject: object))
            case 1:
                self = .userEmpty(Cons_userEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .user(let _data):
                return _data.tlObject
            case .userEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.User] {
            return tlObjectsAt(object, offset).map { Api.User(tlObject: $0) }
        }

    }
}
public extension Api.User.Cons_user {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var firstName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var lastName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var username: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var phone: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var photo: Api.UserProfilePhoto? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.UserProfilePhoto(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var status: Api.UserStatus? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.UserStatus(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var botInfoVersion: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var restrictionReason: [Api.RestrictionReason]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.RestrictionReason.tlArray(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var botInlinePlaceholder: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlStringAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var langCode: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var emojiStatus: Api.EmojiStatus? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.EmojiStatus(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var usernames: [Api.Username]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.Username.tlArray(self.tlObject, 136) } }
    }
    @_alwaysEmitIntoClient var storiesMaxId: Api.RecentStory? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : Api.RecentStory(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var color: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var profileColor: Api.PeerColor? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 160) ? nil : Api.PeerColor(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var botActiveUsers: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var botVerificationIcon: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 3) ? tlBase(self.tlObject).load(fromByteOffset: 168, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var sendPaidMessagesStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 4) ? tlBase(self.tlObject).load(fromByteOffset: 176, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var linkedCommunityId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 192, 5) ? tlBase(self.tlObject).load(fromByteOffset: 184, as: Int64.self) : nil } }
    }
    init(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?, emojiStatus: Api.EmojiStatus?, usernames: [Api.Username]?, storiesMaxId: Api.RecentStory?, color: Api.PeerColor?, profileColor: Api.PeerColor?, botActiveUsers: Int32?, botVerificationIcon: Int64?, sendPaidMessagesStars: Int64?, linkedCommunityId: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1156))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 40, id)
        if let _tlValue = accessHash { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, firstName.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, lastName.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, username.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, phone.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, photo?.tlObject)
        tlStoreReference(_tlObject, 96, status?.tlObject)
        if let _tlValue = botInfoVersion { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 104, restrictionReason.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 112, botInlinePlaceholder.map { value in value as NSString })
        tlStoreReference(_tlObject, 120, langCode.map { value in value as NSString })
        tlStoreReference(_tlObject, 128, emojiStatus?.tlObject)
        tlStoreReference(_tlObject, 136, usernames.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 144, storiesMaxId?.tlObject)
        tlStoreReference(_tlObject, 152, color?.tlObject)
        tlStoreReference(_tlObject, 160, profileColor?.tlObject)
        if let _tlValue = botActiveUsers { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = botVerificationIcon { tlStore(_tlObject, 168, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 176, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = linkedCommunityId { tlStore(_tlObject, 184, _tlValue); _tlPresent |= 1 << 5 }
        tlStore(_tlObject, 192, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.User.Cons_userEmpty {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1396))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum UserFull: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userFull(Cons_userFull)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userFull(Cons_userFull(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userFull(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.UserFull] {
            return tlObjectsAt(object, offset).map { Api.UserFull(tlObject: $0) }
        }

    }
}
public extension Api.UserFull.Cons_userFull {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags2: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var about: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var settings: Api.PeerSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerSettings(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var personalPhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var profilePhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var fallbackPhoto: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var botInfo: Api.BotInfo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.BotInfo(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    @_alwaysEmitIntoClient var pinnedMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var commonChatsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var folderId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 1) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var ttlPeriod: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 2) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var theme: Api.ChatTheme? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.ChatTheme(tlObject: tlObjectAt(self.tlObject, 128)) } }
    }
    @_alwaysEmitIntoClient var privateForwardName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : tlStringAt(self.tlObject, 136) } }
    }
    @_alwaysEmitIntoClient var botGroupAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var botBroadcastAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 152)) } }
    }
    @_alwaysEmitIntoClient var wallpaper: Api.WallPaper? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 160) ? nil : Api.WallPaper(tlObject: tlObjectAt(self.tlObject, 160)) } }
    }
    @_alwaysEmitIntoClient var stories: Api.PeerStories? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 168) ? nil : Api.PeerStories(tlObject: tlObjectAt(self.tlObject, 168)) } }
    }
    @_alwaysEmitIntoClient var businessWorkHours: Api.BusinessWorkHours? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 176) ? nil : Api.BusinessWorkHours(tlObject: tlObjectAt(self.tlObject, 176)) } }
    }
    @_alwaysEmitIntoClient var businessLocation: Api.BusinessLocation? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 184) ? nil : Api.BusinessLocation(tlObject: tlObjectAt(self.tlObject, 184)) } }
    }
    @_alwaysEmitIntoClient var businessGreetingMessage: Api.BusinessGreetingMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 192) ? nil : Api.BusinessGreetingMessage(tlObject: tlObjectAt(self.tlObject, 192)) } }
    }
    @_alwaysEmitIntoClient var businessAwayMessage: Api.BusinessAwayMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 200) ? nil : Api.BusinessAwayMessage(tlObject: tlObjectAt(self.tlObject, 200)) } }
    }
    @_alwaysEmitIntoClient var businessIntro: Api.BusinessIntro? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 208) ? nil : Api.BusinessIntro(tlObject: tlObjectAt(self.tlObject, 208)) } }
    }
    @_alwaysEmitIntoClient var birthday: Api.Birthday? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 216) ? nil : Api.Birthday(tlObject: tlObjectAt(self.tlObject, 216)) } }
    }
    @_alwaysEmitIntoClient var personalChannelId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 3) ? tlBase(self.tlObject).load(fromByteOffset: 224, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var personalChannelMessage: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 4) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var stargiftsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 5) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var starrefProgram: Api.StarRefProgram? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 232) ? nil : Api.StarRefProgram(tlObject: tlObjectAt(self.tlObject, 232)) } }
    }
    @_alwaysEmitIntoClient var botVerification: Api.BotVerification? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 240) ? nil : Api.BotVerification(tlObject: tlObjectAt(self.tlObject, 240)) } }
    }
    @_alwaysEmitIntoClient var sendPaidMessagesStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 6) ? tlBase(self.tlObject).load(fromByteOffset: 248, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var disallowedGifts: Api.DisallowedGiftsSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 256) ? nil : Api.DisallowedGiftsSettings(tlObject: tlObjectAt(self.tlObject, 256)) } }
    }
    @_alwaysEmitIntoClient var starsRating: Api.StarsRating? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 264) ? nil : Api.StarsRating(tlObject: tlObjectAt(self.tlObject, 264)) } }
    }
    @_alwaysEmitIntoClient var starsMyPendingRating: Api.StarsRating? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 272) ? nil : Api.StarsRating(tlObject: tlObjectAt(self.tlObject, 272)) } }
    }
    @_alwaysEmitIntoClient var starsMyPendingRatingDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 7) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var mainTab: Api.ProfileTab? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 280) ? nil : Api.ProfileTab(tlObject: tlObjectAt(self.tlObject, 280)) } }
    }
    @_alwaysEmitIntoClient var savedMusic: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 288) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 288)) } }
    }
    @_alwaysEmitIntoClient var note: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 296) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 296)) } }
    }
    @_alwaysEmitIntoClient var botManagerId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 320, 8) ? tlBase(self.tlObject).load(fromByteOffset: 304, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var walletCard: Api.wallet.Card? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 312) ? nil : Api.wallet.Card(tlObject: tlObjectAt(self.tlObject, 312)) } }
    }
    init(flags: Int32, flags2: Int32, id: Int64, about: String?, settings: Api.PeerSettings, personalPhoto: Api.Photo?, profilePhoto: Api.Photo?, fallbackPhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?, ttlPeriod: Int32?, theme: Api.ChatTheme?, privateForwardName: String?, botGroupAdminRights: Api.ChatAdminRights?, botBroadcastAdminRights: Api.ChatAdminRights?, wallpaper: Api.WallPaper?, stories: Api.PeerStories?, businessWorkHours: Api.BusinessWorkHours?, businessLocation: Api.BusinessLocation?, businessGreetingMessage: Api.BusinessGreetingMessage?, businessAwayMessage: Api.BusinessAwayMessage?, businessIntro: Api.BusinessIntro?, birthday: Api.Birthday?, personalChannelId: Int64?, personalChannelMessage: Int32?, stargiftsCount: Int32?, starrefProgram: Api.StarRefProgram?, botVerification: Api.BotVerification?, sendPaidMessagesStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?, starsRating: Api.StarsRating?, starsMyPendingRating: Api.StarsRating?, starsMyPendingRatingDate: Int32?, mainTab: Api.ProfileTab?, savedMusic: Api.Document?, note: Api.TextWithEntities?, botManagerId: Int64?, walletCard: Api.wallet.Card?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(590))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, flags2)
        tlStore(_tlObject, 64, id)
        tlStoreReference(_tlObject, 72, about.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, settings.tlObject)
        tlStoreReference(_tlObject, 88, personalPhoto?.tlObject)
        tlStoreReference(_tlObject, 96, profilePhoto?.tlObject)
        tlStoreReference(_tlObject, 104, fallbackPhoto?.tlObject)
        tlStoreReference(_tlObject, 112, notifySettings.tlObject)
        tlStoreReference(_tlObject, 120, botInfo?.tlObject)
        if let _tlValue = pinnedMsgId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 36, commonChatsCount)
        if let _tlValue = folderId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = ttlPeriod { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 128, theme?.tlObject)
        tlStoreReference(_tlObject, 136, privateForwardName.map { value in value as NSString })
        tlStoreReference(_tlObject, 144, botGroupAdminRights?.tlObject)
        tlStoreReference(_tlObject, 152, botBroadcastAdminRights?.tlObject)
        tlStoreReference(_tlObject, 160, wallpaper?.tlObject)
        tlStoreReference(_tlObject, 168, stories?.tlObject)
        tlStoreReference(_tlObject, 176, businessWorkHours?.tlObject)
        tlStoreReference(_tlObject, 184, businessLocation?.tlObject)
        tlStoreReference(_tlObject, 192, businessGreetingMessage?.tlObject)
        tlStoreReference(_tlObject, 200, businessAwayMessage?.tlObject)
        tlStoreReference(_tlObject, 208, businessIntro?.tlObject)
        tlStoreReference(_tlObject, 216, birthday?.tlObject)
        if let _tlValue = personalChannelId { tlStore(_tlObject, 224, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = personalChannelMessage { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = stargiftsCount { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 232, starrefProgram?.tlObject)
        tlStoreReference(_tlObject, 240, botVerification?.tlObject)
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 248, _tlValue); _tlPresent |= 1 << 6 }
        tlStoreReference(_tlObject, 256, disallowedGifts?.tlObject)
        tlStoreReference(_tlObject, 264, starsRating?.tlObject)
        tlStoreReference(_tlObject, 272, starsMyPendingRating?.tlObject)
        if let _tlValue = starsMyPendingRatingDate { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 7 }
        tlStoreReference(_tlObject, 280, mainTab?.tlObject)
        tlStoreReference(_tlObject, 288, savedMusic?.tlObject)
        tlStoreReference(_tlObject, 296, note?.tlObject)
        if let _tlValue = botManagerId { tlStore(_tlObject, 304, _tlValue); _tlPresent |= 1 << 8 }
        tlStoreReference(_tlObject, 312, walletCard?.tlObject)
        tlStore(_tlObject, 320, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum UserProfilePhoto: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userProfilePhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userProfilePhoto(Cons_userProfilePhoto)
        case userProfilePhotoEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userProfilePhoto(Cons_userProfilePhoto(tlObject: object))
            case 1:
                self = .userProfilePhotoEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userProfilePhoto(let _data):
                return _data.tlObject
            case .userProfilePhotoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(509))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.UserProfilePhoto] {
            return tlObjectsAt(object, offset).map { Api.UserProfilePhoto(tlObject: $0) }
        }

    }
}
public extension Api.UserProfilePhoto.Cons_userProfilePhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var photoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var strippedThumb: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(838))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, photoId)
        tlStoreReference(_tlObject, 40, strippedThumb.map { value in value.makeData() as NSData })
        tlStore(_tlObject, 28, dcId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum UserStatus: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userStatusLastMonth {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_userStatusLastWeek {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_userStatusOffline {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_userStatusOnline {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_userStatusRecently {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userStatusEmpty
        case userStatusLastMonth(Cons_userStatusLastMonth)
        case userStatusLastWeek(Cons_userStatusLastWeek)
        case userStatusOffline(Cons_userStatusOffline)
        case userStatusOnline(Cons_userStatusOnline)
        case userStatusRecently(Cons_userStatusRecently)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userStatusEmpty
            case 1:
                self = .userStatusLastMonth(Cons_userStatusLastMonth(tlObject: object))
            case 2:
                self = .userStatusLastWeek(Cons_userStatusLastWeek(tlObject: object))
            case 3:
                self = .userStatusOffline(Cons_userStatusOffline(tlObject: object))
            case 4:
                self = .userStatusOnline(Cons_userStatusOnline(tlObject: object))
            case 5:
                self = .userStatusRecently(Cons_userStatusRecently(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userStatusEmpty:
                return TLObjectSingleton(TLApiConstructorAt(64))
            case .userStatusLastMonth(let _data):
                return _data.tlObject
            case .userStatusLastWeek(let _data):
                return _data.tlObject
            case .userStatusOffline(let _data):
                return _data.tlObject
            case .userStatusOnline(let _data):
                return _data.tlObject
            case .userStatusRecently(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.UserStatus] {
            return tlObjectsAt(object, offset).map { Api.UserStatus(tlObject: $0) }
        }

    }
}
public extension Api.UserStatus.Cons_userStatusLastMonth {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(650))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.UserStatus.Cons_userStatusLastWeek {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(548))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.UserStatus.Cons_userStatusOffline {
    @_alwaysEmitIntoClient var wasOnline: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(wasOnline: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(4))
        tlStore(_tlObject, 24, wasOnline)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.UserStatus.Cons_userStatusOnline {
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1574))
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.UserStatus.Cons_userStatusRecently {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(792))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Username: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_username {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case username(Cons_username)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .username(Cons_username(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .username(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Username] {
            return tlObjectsAt(object, offset).map { Api.Username(tlObject: $0) }
        }

    }
}
public extension Api.Username.Cons_username {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var username: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, username: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1174))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, username as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum VideoSize: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_videoSize {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_videoSizeEmojiMarkup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_videoSizeStickerMarkup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case videoSize(Cons_videoSize)
        case videoSizeEmojiMarkup(Cons_videoSizeEmojiMarkup)
        case videoSizeStickerMarkup(Cons_videoSizeStickerMarkup)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .videoSize(Cons_videoSize(tlObject: object))
            case 1:
                self = .videoSizeEmojiMarkup(Cons_videoSizeEmojiMarkup(tlObject: object))
            case 2:
                self = .videoSizeStickerMarkup(Cons_videoSizeStickerMarkup(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .videoSize(let _data):
                return _data.tlObject
            case .videoSizeEmojiMarkup(let _data):
                return _data.tlObject
            case .videoSizeStickerMarkup(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.VideoSize] {
            return tlObjectsAt(object, offset).map { Api.VideoSize(tlObject: $0) }
        }

    }
}
public extension Api.VideoSize.Cons_videoSize {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var w: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var h: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var size: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var videoStartTs: Double? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) : nil } }
    }
    init(flags: Int32, type: String, w: Int32, h: Int32, size: Int32, videoStartTs: Double?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1462))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, type as NSString)
        tlStore(_tlObject, 28, w)
        tlStore(_tlObject, 32, h)
        tlStore(_tlObject, 36, size)
        if let _tlValue = videoStartTs { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.VideoSize.Cons_videoSizeEmojiMarkup {
    @_alwaysEmitIntoClient var emojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var backgroundColors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 32) } }
    }
    init(emojiId: Int64, backgroundColors: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1647))
        tlStore(_tlObject, 24, emojiId)
        tlStoreReference(_tlObject, 32, tlPackInt32(backgroundColors) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.VideoSize.Cons_videoSizeStickerMarkup {
    @_alwaysEmitIntoClient var stickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var stickerId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var backgroundColors: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 40) } }
    }
    init(stickerset: Api.InputStickerSet, stickerId: Int64, backgroundColors: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(86))
        tlStoreReference(_tlObject, 24, stickerset.tlObject)
        tlStore(_tlObject, 32, stickerId)
        tlStoreReference(_tlObject, 40, tlPackInt32(backgroundColors) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WallPaper: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_wallPaper {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_wallPaperNoFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case wallPaper(Cons_wallPaper)
        case wallPaperNoFile(Cons_wallPaperNoFile)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .wallPaper(Cons_wallPaper(tlObject: object))
            case 1:
                self = .wallPaperNoFile(Cons_wallPaperNoFile(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .wallPaper(let _data):
                return _data.tlObject
            case .wallPaperNoFile(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WallPaper] {
            return tlObjectsAt(object, offset).map { Api.WallPaper(tlObject: $0) }
        }

    }
}
public extension Api.WallPaper.Cons_wallPaper {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var settings: Api.WallPaperSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.WallPaperSettings(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1072))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, slug as NSString)
        tlStoreReference(_tlObject, 56, document.tlObject)
        tlStoreReference(_tlObject, 64, settings?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WallPaper.Cons_wallPaperNoFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var settings: Api.WallPaperSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.WallPaperSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(id: Int64, flags: Int32, settings: Api.WallPaperSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1476))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, settings?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WallPaperSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_wallPaperSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case wallPaperSettings(Cons_wallPaperSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .wallPaperSettings(Cons_wallPaperSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .wallPaperSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WallPaperSettings] {
            return tlObjectsAt(object, offset).map { Api.WallPaperSettings(tlObject: $0) }
        }

    }
}
public extension Api.WallPaperSettings.Cons_wallPaperSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var backgroundColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var secondBackgroundColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var thirdBackgroundColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var fourthBackgroundColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 3) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var intensity: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 4) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var rotation: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 5) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var emoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, thirdBackgroundColor: Int32?, fourthBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?, emoticon: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(353))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = backgroundColor { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = secondBackgroundColor { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = thirdBackgroundColor { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = fourthBackgroundColor { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = intensity { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = rotation { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 56, emoticon.map { value in value as NSString })
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WalletOwnershipProof: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_walletOwnershipProof {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case walletOwnershipProof(Cons_walletOwnershipProof)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .walletOwnershipProof(Cons_walletOwnershipProof(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .walletOwnershipProof(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WalletOwnershipProof] {
            return tlObjectsAt(object, offset).map { Api.WalletOwnershipProof(tlObject: $0) }
        }

    }
}
public extension Api.WalletOwnershipProof.Cons_walletOwnershipProof {
    @_alwaysEmitIntoClient var timestamp: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var signature: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(timestamp: Int32, signature: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(618))
        tlStore(_tlObject, 24, timestamp)
        tlStoreReference(_tlObject, 32, signature.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WalletState: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_walletState {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_walletStateEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case walletState(Cons_walletState)
        case walletStateEmpty(Cons_walletStateEmpty)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .walletState(Cons_walletState(tlObject: object))
            case 1:
                self = .walletStateEmpty(Cons_walletStateEmpty(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .walletState(let _data):
                return _data.tlObject
            case .walletStateEmpty(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WalletState] {
            return tlObjectsAt(object, offset).map { Api.WalletState(tlObject: $0) }
        }

    }
}
public extension Api.WalletState.Cons_walletState {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var publicKey: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var balance: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    init(flags: Int32, address: String, publicKey: Buffer, balance: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(954))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, address as NSString)
        tlStoreReference(_tlObject, 40, publicKey.makeData() as NSData)
        tlStore(_tlObject, 48, balance)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WalletState.Cons_walletStateEmpty {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1014))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WalletTransaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_walletTransaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case walletTransaction(Cons_walletTransaction)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .walletTransaction(Cons_walletTransaction(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .walletTransaction(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WalletTransaction] {
            return tlObjectsAt(object, offset).map { Api.WalletTransaction(tlObject: $0) }
        }

    }
}
public extension Api.WalletTransaction.Cons_walletTransaction {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var amount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fee: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.WalletTransactionPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WalletTransactionPeer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var comment: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var txHash: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var nft: Api.wallet.NftItem? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.wallet.NftItem(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, id: String, amount: Int64, fee: Int64, date: Int32, peer: Api.WalletTransactionPeer, comment: String?, txHash: String?, nft: Api.wallet.NftItem?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(952))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStore(_tlObject, 40, amount)
        tlStore(_tlObject, 48, fee)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 56, peer.tlObject)
        tlStoreReference(_tlObject, 64, comment.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, txHash.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, nft?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WalletTransactionPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_walletTransactionPeerAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_walletTransactionPeerOnramp {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_walletTransactionPeerUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case walletTransactionPeerAddress(Cons_walletTransactionPeerAddress)
        case walletTransactionPeerOnramp(Cons_walletTransactionPeerOnramp)
        case walletTransactionPeerUnsupported
        case walletTransactionPeerUser(Cons_walletTransactionPeerUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .walletTransactionPeerAddress(Cons_walletTransactionPeerAddress(tlObject: object))
            case 1:
                self = .walletTransactionPeerOnramp(Cons_walletTransactionPeerOnramp(tlObject: object))
            case 2:
                self = .walletTransactionPeerUnsupported
            case 3:
                self = .walletTransactionPeerUser(Cons_walletTransactionPeerUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .walletTransactionPeerAddress(let _data):
                return _data.tlObject
            case .walletTransactionPeerOnramp(let _data):
                return _data.tlObject
            case .walletTransactionPeerUnsupported:
                return TLObjectSingleton(TLApiConstructorAt(731))
            case .walletTransactionPeerUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WalletTransactionPeer] {
            return tlObjectsAt(object, offset).map { Api.WalletTransactionPeer(tlObject: $0) }
        }

    }
}
public extension Api.WalletTransactionPeer.Cons_walletTransactionPeerAddress {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var domain: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, address: String, domain: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(41))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, address as NSString)
        tlStoreReference(_tlObject, 40, domain.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WalletTransactionPeer.Cons_walletTransactionPeerOnramp {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var domain: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var providerName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, address: String, domain: String?, providerName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1511))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, address as NSString)
        tlStoreReference(_tlObject, 40, domain.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, providerName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WalletTransactionPeer.Cons_walletTransactionPeerUser {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var domain: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64, address: String, domain: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1400))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStoreReference(_tlObject, 40, address as NSString)
        tlStoreReference(_tlObject, 48, domain.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WalletUserAddress: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_walletUserAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case walletUserAddress(Cons_walletUserAddress)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .walletUserAddress(Cons_walletUserAddress(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .walletUserAddress(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WalletUserAddress] {
            return tlObjectsAt(object, offset).map { Api.WalletUserAddress(tlObject: $0) }
        }

    }
}
public extension Api.WalletUserAddress.Cons_walletUserAddress {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var publicKey: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    init(flags: Int32, userId: Int64?, address: String, publicKey: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1701))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = userId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, address as NSString)
        tlStoreReference(_tlObject, 48, publicKey.makeData() as NSData)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webAuthorization {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webAuthorization(Cons_webAuthorization)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webAuthorization(Cons_webAuthorization(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webAuthorization(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebAuthorization] {
            return tlObjectsAt(object, offset).map { Api.WebAuthorization(tlObject: $0) }
        }

    }
}
public extension Api.WebAuthorization.Cons_webAuthorization {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var domain: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var browser: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var platform: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var dateCreated: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var dateActive: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ip: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var region: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    init(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1091))
        tlStore(_tlObject, 32, hash)
        tlStore(_tlObject, 40, botId)
        tlStoreReference(_tlObject, 48, domain as NSString)
        tlStoreReference(_tlObject, 56, browser as NSString)
        tlStoreReference(_tlObject, 64, platform as NSString)
        tlStore(_tlObject, 24, dateCreated)
        tlStore(_tlObject, 28, dateActive)
        tlStoreReference(_tlObject, 72, ip as NSString)
        tlStoreReference(_tlObject, 80, region as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webDocumentNoProxy {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webDocument(Cons_webDocument)
        case webDocumentNoProxy(Cons_webDocumentNoProxy)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webDocument(Cons_webDocument(tlObject: object))
            case 1:
                self = .webDocumentNoProxy(Cons_webDocumentNoProxy(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webDocument(let _data):
                return _data.tlObject
            case .webDocumentNoProxy(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebDocument] {
            return tlObjectsAt(object, offset).map { Api.WebDocument(tlObject: $0) }
        }

    }
}
public extension Api.WebDocument.Cons_webDocument {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var size: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var mimeType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.DocumentAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DocumentAttribute.tlArray(self.tlObject, 56) } }
    }
    init(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(186))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 24, size)
        tlStoreReference(_tlObject, 48, mimeType as NSString)
        tlStoreReference(_tlObject, 56, attributes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebDocument.Cons_webDocumentNoProxy {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1661))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, size)
        tlStoreReference(_tlObject, 40, mimeType as NSString)
        tlStoreReference(_tlObject, 48, attributes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebDomainException: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webDomainException {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webDomainException(Cons_webDomainException)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webDomainException(Cons_webDomainException(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webDomainException(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebDomainException] {
            return tlObjectsAt(object, offset).map { Api.WebDomainException(tlObject: $0) }
        }

    }
}
public extension Api.WebDomainException.Cons_webDomainException {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var domain: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var favicon: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    init(flags: Int32, domain: String, url: String, title: String, favicon: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(939))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, domain as NSString)
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStoreReference(_tlObject, 48, title as NSString)
        if let _tlValue = favicon { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPagePending {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webPage(Cons_webPage)
        case webPageEmpty(Cons_webPageEmpty)
        case webPageNotModified(Cons_webPageNotModified)
        case webPagePending(Cons_webPagePending)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webPage(Cons_webPage(tlObject: object))
            case 1:
                self = .webPageEmpty(Cons_webPageEmpty(tlObject: object))
            case 2:
                self = .webPageNotModified(Cons_webPageNotModified(tlObject: object))
            case 3:
                self = .webPagePending(Cons_webPagePending(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webPage(let _data):
                return _data.tlObject
            case .webPageEmpty(let _data):
                return _data.tlObject
            case .webPageNotModified(let _data):
                return _data.tlObject
            case .webPagePending(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebPage] {
            return tlObjectsAt(object, offset).map { Api.WebPage(tlObject: $0) }
        }

    }
}
public extension Api.WebPage.Cons_webPage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var displayUrl: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var type: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var siteName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var embedUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlStringAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var embedType: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var embedWidth: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var embedHeight: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var duration: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 160, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var author: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : tlStringAt(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 136) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 136)) } }
    }
    @_alwaysEmitIntoClient var cachedPage: Api.Page? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 144) ? nil : Api.Page(tlObject: tlObjectAt(self.tlObject, 144)) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.WebPageAttribute]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 152) ? nil : Api.WebPageAttribute.tlArray(self.tlObject, 152) } }
    }
    init(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1532))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 48, id)
        tlStoreReference(_tlObject, 56, url as NSString)
        tlStoreReference(_tlObject, 64, displayUrl as NSString)
        tlStore(_tlObject, 28, hash)
        tlStoreReference(_tlObject, 72, type.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, siteName.map { value in value as NSString })
        tlStoreReference(_tlObject, 88, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 96, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 104, photo?.tlObject)
        tlStoreReference(_tlObject, 112, embedUrl.map { value in value as NSString })
        tlStoreReference(_tlObject, 120, embedType.map { value in value as NSString })
        if let _tlValue = embedWidth { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = embedHeight { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = duration { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 128, author.map { value in value as NSString })
        tlStoreReference(_tlObject, 136, document?.tlObject)
        tlStoreReference(_tlObject, 144, cachedPage?.tlObject)
        tlStoreReference(_tlObject, 152, attributes.map { value in value.map { item in item.tlObject } as NSArray })
        tlStore(_tlObject, 160, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPage.Cons_webPageEmpty {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, id: Int64, url: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(229))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPage.Cons_webPageNotModified {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var cachedPageViews: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 32, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, cachedPageViews: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(736))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = cachedPageViews { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPage.Cons_webPagePending {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, id: Int64, url: String?, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1153))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        tlStore(_tlObject, 28, date)
        self.init(tlObject: _tlObject)
    }
}
