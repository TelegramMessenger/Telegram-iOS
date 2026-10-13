import TelegramApiObjC
public extension Api {
    enum EncryptedFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_encryptedFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case encryptedFile(Cons_encryptedFile)
        case encryptedFileEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .encryptedFile(Cons_encryptedFile(tlObject: object))
            case 1:
                self = .encryptedFileEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .encryptedFile(let _data):
                return _data.tlObject
            case .encryptedFileEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1294))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EncryptedFile] {
            return tlObjectsAt(object, offset).map { Api.EncryptedFile(tlObject: $0) }
        }

    }
}
public extension Api.EncryptedFile.Cons_encryptedFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var size: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var keyFingerprint: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(id: Int64, accessHash: Int64, size: Int64, dcId: Int32, keyFingerprint: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1091))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 48, size)
        tlStore(_tlObject, 24, dcId)
        tlStore(_tlObject, 28, keyFingerprint)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum EncryptedMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_encryptedMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_encryptedMessageService {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case encryptedMessage(Cons_encryptedMessage)
        case encryptedMessageService(Cons_encryptedMessageService)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .encryptedMessage(Cons_encryptedMessage(tlObject: object))
            case 1:
                self = .encryptedMessageService(Cons_encryptedMessageService(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .encryptedMessage(let _data):
                return _data.tlObject
            case .encryptedMessageService(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EncryptedMessage] {
            return tlObjectsAt(object, offset).map { Api.EncryptedMessage(tlObject: $0) }
        }

    }
}
public extension Api.EncryptedMessage.Cons_encryptedMessage {
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var chatId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var file: Api.EncryptedFile {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EncryptedFile(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer, file: Api.EncryptedFile) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1566))
        tlStore(_tlObject, 32, randomId)
        tlStore(_tlObject, 24, chatId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        tlStoreReference(_tlObject, 48, file.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.EncryptedMessage.Cons_encryptedMessageService {
    @_alwaysEmitIntoClient var randomId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var chatId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(randomId: Int64, chatId: Int32, date: Int32, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(242))
        tlStore(_tlObject, 32, randomId)
        tlStore(_tlObject, 24, chatId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum EphemeralMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_ephemeralMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case ephemeralMessage(Cons_ephemeralMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .ephemeralMessage(Cons_ephemeralMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .ephemeralMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.EphemeralMessage] {
            return tlObjectsAt(object, offset).map { Api.EphemeralMessage(tlObject: $0) }
        }

    }
}
public extension Api.EphemeralMessage.Cons_ephemeralMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var receiverId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var topMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 128, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MessageEntity.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var replyTo: Api.MessageReplyHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.MessageReplyHeader(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.RichMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    @_alwaysEmitIntoClient var chatInstance: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 128, 1) ? tlBase(self.tlObject).load(fromByteOffset: 120, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var anchorMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 128, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int32, fromId: Api.Peer, peerId: Api.Peer?, receiverId: Int64, topMsgId: Int32?, date: Int32, message: String, entities: [Api.MessageEntity]?, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, replyTo: Api.MessageReplyHeader?, richMessage: Api.RichMessage?, chatInstance: Int64?, anchorMsgId: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1455))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 48, fromId.tlObject)
        tlStoreReference(_tlObject, 56, peerId?.tlObject)
        tlStore(_tlObject, 64, receiverId)
        if let _tlValue = topMsgId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 36, date)
        tlStoreReference(_tlObject, 72, message as NSString)
        tlStoreReference(_tlObject, 80, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, media?.tlObject)
        tlStoreReference(_tlObject, 96, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 104, replyTo?.tlObject)
        tlStoreReference(_tlObject, 112, richMessage?.tlObject)
        if let _tlValue = chatInstance { tlStore(_tlObject, 120, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = anchorMsgId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 128, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedChatInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatInviteExported {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatInviteExported(Cons_chatInviteExported)
        case chatInvitePublicJoinRequests


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatInviteExported(Cons_chatInviteExported(tlObject: object))
            case 1:
                self = .chatInvitePublicJoinRequests
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatInviteExported(let _data):
                return _data.tlObject
            case .chatInvitePublicJoinRequests:
                return TLObjectSingleton(TLApiConstructorAt(1565))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedChatInvite] {
            return tlObjectsAt(object, offset).map { Api.ExportedChatInvite(tlObject: $0) }
        }

    }
}
public extension Api.ExportedChatInvite.Cons_chatInviteExported {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var link: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var adminId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var usageLimit: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var usage: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var requested: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 4) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var subscriptionExpired: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 5) ? tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var subscriptionPricing: Api.StarsSubscriptionPricing? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.StarsSubscriptionPricing(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, link: String, adminId: Int64, date: Int32, startDate: Int32?, expireDate: Int32?, usageLimit: Int32?, usage: Int32?, requested: Int32?, subscriptionExpired: Int32?, title: String?, subscriptionPricing: Api.StarsSubscriptionPricing?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1059))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 56, link as NSString)
        tlStore(_tlObject, 64, adminId)
        tlStore(_tlObject, 28, date)
        if let _tlValue = startDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = expireDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = usageLimit { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = usage { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        if let _tlValue = requested { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 4 }
        if let _tlValue = subscriptionExpired { tlStore(_tlObject, 52, _tlValue); _tlPresent |= 1 << 5 }
        tlStoreReference(_tlObject, 72, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, subscriptionPricing?.tlObject)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedChatlistInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedChatlistInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedChatlistInvite(Cons_exportedChatlistInvite)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedChatlistInvite(Cons_exportedChatlistInvite(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedChatlistInvite(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedChatlistInvite] {
            return tlObjectsAt(object, offset).map { Api.ExportedChatlistInvite(tlObject: $0) }
        }

    }
}
public extension Api.ExportedChatlistInvite.Cons_exportedChatlistInvite {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var peers: [Api.Peer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, title: String, url: String, peers: [Api.Peer]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(80))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStoreReference(_tlObject, 48, peers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedContactToken: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedContactToken {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedContactToken(Cons_exportedContactToken)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedContactToken(Cons_exportedContactToken(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedContactToken(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedContactToken] {
            return tlObjectsAt(object, offset).map { Api.ExportedContactToken(tlObject: $0) }
        }

    }
}
public extension Api.ExportedContactToken.Cons_exportedContactToken {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(url: String, expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(426))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedMessageLink: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedMessageLink {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedMessageLink(Cons_exportedMessageLink)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedMessageLink(Cons_exportedMessageLink(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedMessageLink(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedMessageLink] {
            return tlObjectsAt(object, offset).map { Api.ExportedMessageLink(tlObject: $0) }
        }

    }
}
public extension Api.ExportedMessageLink.Cons_exportedMessageLink {
    @_alwaysEmitIntoClient var link: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var html: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(link: String, html: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(601))
        tlStoreReference(_tlObject, 24, link as NSString)
        tlStoreReference(_tlObject, 32, html as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedNoPaidMessagesToken: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedNoPaidMessagesToken {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedNoPaidMessagesToken(Cons_exportedNoPaidMessagesToken)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedNoPaidMessagesToken(Cons_exportedNoPaidMessagesToken(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedNoPaidMessagesToken(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedNoPaidMessagesToken] {
            return tlObjectsAt(object, offset).map { Api.ExportedNoPaidMessagesToken(tlObject: $0) }
        }

    }
}
public extension Api.ExportedNoPaidMessagesToken.Cons_exportedNoPaidMessagesToken {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, token: String, url: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1026))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, token as NSString)
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ExportedStoryLink: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedStoryLink {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedStoryLink(Cons_exportedStoryLink)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedStoryLink(Cons_exportedStoryLink(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedStoryLink(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ExportedStoryLink] {
            return tlObjectsAt(object, offset).map { Api.ExportedStoryLink(tlObject: $0) }
        }

    }
}
public extension Api.ExportedStoryLink.Cons_exportedStoryLink {
    @_alwaysEmitIntoClient var link: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(link: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(413))
        tlStoreReference(_tlObject, 24, link as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum FactCheck: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_factCheck {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case factCheck(Cons_factCheck)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .factCheck(Cons_factCheck(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .factCheck(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FactCheck] {
            return tlObjectsAt(object, offset).map { Api.FactCheck(tlObject: $0) }
        }

    }
}
public extension Api.FactCheck.Cons_factCheck {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var country: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    init(flags: Int32, country: String?, text: Api.TextWithEntities?, hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1212))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, country.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, text?.tlObject)
        tlStore(_tlObject, 48, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum FeedItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_feedItemMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case feedItemInterestCategories
        case feedItemMessage(Cons_feedItemMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .feedItemInterestCategories
            case 1:
                self = .feedItemMessage(Cons_feedItemMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .feedItemInterestCategories:
                return TLObjectSingleton(TLApiConstructorAt(685))
            case .feedItemMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FeedItem] {
            return tlObjectsAt(object, offset).map { Api.FeedItem(tlObject: $0) }
        }

    }
}
public extension Api.FeedItem.Cons_feedItemMessage {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(814))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum FeedPosition: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_feedPosition {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case feedPosition(Cons_feedPosition)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .feedPosition(Cons_feedPosition(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .feedPosition(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FeedPosition] {
            return tlObjectsAt(object, offset).map { Api.FeedPosition(tlObject: $0) }
        }

    }
}
public extension Api.FeedPosition.Cons_feedPosition {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(date: Int32, peer: Api.Peer, id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(521))
        tlStore(_tlObject, 24, date)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum FileHash: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_fileHash {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case fileHash(Cons_fileHash)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .fileHash(Cons_fileHash(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .fileHash(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FileHash] {
            return tlObjectsAt(object, offset).map { Api.FileHash(tlObject: $0) }
        }

    }
}
public extension Api.FileHash.Cons_fileHash {
    @_alwaysEmitIntoClient var offset: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var limit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(offset: Int64, limit: Int32, hash: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1616))
        tlStore(_tlObject, 32, offset)
        tlStore(_tlObject, 24, limit)
        tlStoreReference(_tlObject, 40, hash.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Folder: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_folder {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case folder(Cons_folder)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .folder(Cons_folder(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .folder(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Folder] {
            return tlObjectsAt(object, offset).map { Api.Folder(tlObject: $0) }
        }

    }
}
public extension Api.Folder.Cons_folder {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var photo: Api.ChatPhoto? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ChatPhoto(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, id: Int32, title: String, photo: Api.ChatPhoto?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1701))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, photo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum FolderPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_folderPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case folderPeer(Cons_folderPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .folderPeer(Cons_folderPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .folderPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FolderPeer] {
            return tlObjectsAt(object, offset).map { Api.FolderPeer(tlObject: $0) }
        }

    }
}
public extension Api.FolderPeer.Cons_folderPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var folderId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(peer: Api.Peer, folderId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1540))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, folderId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum ForumTopic: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_forumTopic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_forumTopicDeleted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case forumTopic(Cons_forumTopic)
        case forumTopicDeleted(Cons_forumTopicDeleted)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .forumTopic(Cons_forumTopic(tlObject: object))
            case 1:
                self = .forumTopicDeleted(Cons_forumTopicDeleted(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .forumTopic(let _data):
                return _data.tlObject
            case .forumTopicDeleted(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ForumTopic] {
            return tlObjectsAt(object, offset).map { Api.ForumTopic(tlObject: $0) }
        }

    }
}
public extension Api.ForumTopic.Cons_forumTopic {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var iconColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var iconEmojiId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 120, 0) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var topMessage: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var readInboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var readOutboxMaxId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadMentionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadReactionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 60, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadPollVotesCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var notifySettings: Api.PeerNotifySettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerNotifySettings(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var draft: Api.DraftMessage? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.DraftMessage(tlObject: tlObjectAt(self.tlObject, 112)) } }
    }
    init(flags: Int32, id: Int32, date: Int32, peer: Api.Peer, title: String, iconColor: Int32, iconEmojiId: Int64?, topMessage: Int32, readInboxMaxId: Int32, readOutboxMaxId: Int32, unreadCount: Int32, unreadMentionsCount: Int32, unreadReactionsCount: Int32, unreadPollVotesCount: Int32, fromId: Api.Peer, notifySettings: Api.PeerNotifySettings, draft: Api.DraftMessage?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1686))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 72, peer.tlObject)
        tlStoreReference(_tlObject, 80, title as NSString)
        tlStore(_tlObject, 36, iconColor)
        if let _tlValue = iconEmojiId { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, topMessage)
        tlStore(_tlObject, 44, readInboxMaxId)
        tlStore(_tlObject, 48, readOutboxMaxId)
        tlStore(_tlObject, 52, unreadCount)
        tlStore(_tlObject, 56, unreadMentionsCount)
        tlStore(_tlObject, 60, unreadReactionsCount)
        tlStore(_tlObject, 64, unreadPollVotesCount)
        tlStoreReference(_tlObject, 96, fromId.tlObject)
        tlStoreReference(_tlObject, 104, notifySettings.tlObject)
        tlStoreReference(_tlObject, 112, draft?.tlObject)
        tlStore(_tlObject, 120, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ForumTopic.Cons_forumTopicDeleted {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(16))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum FoundStory: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_foundStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case foundStory(Cons_foundStory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .foundStory(Cons_foundStory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .foundStory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.FoundStory] {
            return tlObjectsAt(object, offset).map { Api.FoundStory(tlObject: $0) }
        }

    }
}
public extension Api.FoundStory.Cons_foundStory {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var story: Api.StoryItem {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(peer: Api.Peer, story: Api.StoryItem) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1529))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, story.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Game: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_game {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case game(Cons_game)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .game(Cons_game(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .game(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Game] {
            return tlObjectsAt(object, offset).map { Api.Game(tlObject: $0) }
        }

    }
}
public extension Api.Game.Cons_game {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, shortName: String, title: String, description: String, photo: Api.Photo, document: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1259))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, shortName as NSString)
        tlStoreReference(_tlObject, 56, title as NSString)
        tlStoreReference(_tlObject, 64, description as NSString)
        tlStoreReference(_tlObject, 72, photo.tlObject)
        tlStoreReference(_tlObject, 80, document?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GeoPoint: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_geoPoint {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case geoPoint(Cons_geoPoint)
        case geoPointEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .geoPoint(Cons_geoPoint(tlObject: object))
            case 1:
                self = .geoPointEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .geoPoint(let _data):
                return _data.tlObject
            case .geoPointEmpty:
                return TLObjectSingleton(TLApiConstructorAt(104))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GeoPoint] {
            return tlObjectsAt(object, offset).map { Api.GeoPoint(tlObject: $0) }
        }

    }
}
public extension Api.GeoPoint.Cons_geoPoint {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var long: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var lat: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accuracyRadius: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, long: Double, lat: Double, accessHash: Int64, accuracyRadius: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1161))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, long)
        tlStore(_tlObject, 40, lat)
        tlStore(_tlObject, 48, accessHash)
        if let _tlValue = accuracyRadius { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GeoPointAddress: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_geoPointAddress {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case geoPointAddress(Cons_geoPointAddress)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .geoPointAddress(Cons_geoPointAddress(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .geoPointAddress(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GeoPointAddress] {
            return tlObjectsAt(object, offset).map { Api.GeoPointAddress(tlObject: $0) }
        }

    }
}
public extension Api.GeoPointAddress.Cons_geoPointAddress {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var countryIso2: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var state: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var city: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var street: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, countryIso2: String, state: String?, city: String?, street: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1462))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, countryIso2 as NSString)
        tlStoreReference(_tlObject, 40, state.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, city.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, street.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GlobalPrivacySettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_globalPrivacySettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case globalPrivacySettings(Cons_globalPrivacySettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .globalPrivacySettings(Cons_globalPrivacySettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .globalPrivacySettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GlobalPrivacySettings] {
            return tlObjectsAt(object, offset).map { Api.GlobalPrivacySettings(tlObject: $0) }
        }

    }
}
public extension Api.GlobalPrivacySettings.Cons_globalPrivacySettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var noncontactPeersPaidStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var disallowedGifts: Api.DisallowedGiftsSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.DisallowedGiftsSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, noncontactPeersPaidStars: Int64?, disallowedGifts: Api.DisallowedGiftsSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1697))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = noncontactPeersPaidStars { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, disallowedGifts?.tlObject)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCall: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCall {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_groupCallDiscarded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCall(Cons_groupCall)
        case groupCallDiscarded(Cons_groupCallDiscarded)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCall(Cons_groupCall(tlObject: object))
            case 1:
                self = .groupCallDiscarded(Cons_groupCallDiscarded(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCall(let _data):
                return _data.tlObject
            case .groupCallDiscarded(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCall] {
            return tlObjectsAt(object, offset).map { Api.GroupCall(tlObject: $0) }
        }

    }
}
public extension Api.GroupCall.Cons_groupCall {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var participantsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var streamDcId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recordStartDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var scheduleDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var unmutedVideoCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 3) ? tlBase(self.tlObject).load(fromByteOffset: 44, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var unmutedVideoLimit: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 52, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var inviteLink: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var sendPaidMessagesStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 4) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var defaultSendAs: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, participantsCount: Int32, title: String?, streamDcId: Int32?, recordStartDate: Int32?, scheduleDate: Int32?, unmutedVideoCount: Int32?, unmutedVideoLimit: Int32, version: Int32, inviteLink: String?, sendPaidMessagesStars: Int64?, defaultSendAs: Api.Peer?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1587))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 56, id)
        tlStore(_tlObject, 64, accessHash)
        tlStore(_tlObject, 28, participantsCount)
        tlStoreReference(_tlObject, 72, title.map { value in value as NSString })
        if let _tlValue = streamDcId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = recordStartDate { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = scheduleDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        if let _tlValue = unmutedVideoCount { tlStore(_tlObject, 44, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 48, unmutedVideoLimit)
        tlStore(_tlObject, 52, version)
        tlStoreReference(_tlObject, 80, inviteLink.map { value in value as NSString })
        if let _tlValue = sendPaidMessagesStars { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 4 }
        tlStoreReference(_tlObject, 96, defaultSendAs?.tlObject)
        tlStore(_tlObject, 104, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.GroupCall.Cons_groupCallDiscarded {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var duration: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int64, accessHash: Int64, duration: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(768))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStore(_tlObject, 24, duration)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallDonor: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallDonor {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallDonor(Cons_groupCallDonor)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallDonor(Cons_groupCallDonor(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallDonor(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallDonor] {
            return tlObjectsAt(object, offset).map { Api.GroupCallDonor(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallDonor.Cons_groupCallDonor {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var stars: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(flags: Int32, peerId: Api.Peer?, stars: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1577))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peerId?.tlObject)
        tlStore(_tlObject, 40, stars)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallMessage(Cons_groupCallMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallMessage(Cons_groupCallMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallMessage] {
            return tlObjectsAt(object, offset).map { Api.GroupCallMessage(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallMessage.Cons_groupCallMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var paidMessageStars: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    init(flags: Int32, id: Int32, fromId: Api.Peer, date: Int32, message: Api.TextWithEntities, paidMessageStars: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(172))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, fromId.tlObject)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 48, message.tlObject)
        if let _tlValue = paidMessageStars { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallParticipant: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallParticipant {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallParticipant(Cons_groupCallParticipant)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallParticipant(Cons_groupCallParticipant(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallParticipant(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallParticipant] {
            return tlObjectsAt(object, offset).map { Api.GroupCallParticipant(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallParticipant.Cons_groupCallParticipant {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var activeDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var source: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var volume: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 1) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var about: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var raiseHandRating: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 2) ? tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var video: Api.GroupCallParticipantVideo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.GroupCallParticipantVideo(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var presentation: Api.GroupCallParticipantVideo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.GroupCallParticipantVideo(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var paidStarsTotal: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 96, 3) ? tlBase(self.tlObject).load(fromByteOffset: 88, as: Int64.self) : nil } }
    }
    init(flags: Int32, peer: Api.Peer, date: Int32, activeDate: Int32?, source: Int32, volume: Int32?, about: String?, raiseHandRating: Int64?, video: Api.GroupCallParticipantVideo?, presentation: Api.GroupCallParticipantVideo?, paidStarsTotal: Int64?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(272))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, peer.tlObject)
        tlStore(_tlObject, 28, date)
        if let _tlValue = activeDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 36, source)
        if let _tlValue = volume { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 56, about.map { value in value as NSString })
        if let _tlValue = raiseHandRating { tlStore(_tlObject, 64, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 72, video?.tlObject)
        tlStoreReference(_tlObject, 80, presentation?.tlObject)
        if let _tlValue = paidStarsTotal { tlStore(_tlObject, 88, _tlValue); _tlPresent |= 1 << 3 }
        tlStore(_tlObject, 96, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallParticipantVideo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallParticipantVideo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallParticipantVideo(Cons_groupCallParticipantVideo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallParticipantVideo(Cons_groupCallParticipantVideo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallParticipantVideo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallParticipantVideo] {
            return tlObjectsAt(object, offset).map { Api.GroupCallParticipantVideo(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallParticipantVideo.Cons_groupCallParticipantVideo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var endpoint: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var sourceGroups: [Api.GroupCallParticipantVideoSourceGroup] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.GroupCallParticipantVideoSourceGroup.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var audioSource: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, endpoint: String, sourceGroups: [Api.GroupCallParticipantVideoSourceGroup], audioSource: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(661))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, endpoint as NSString)
        tlStoreReference(_tlObject, 40, sourceGroups.map { item in item.tlObject } as NSArray)
        if let _tlValue = audioSource { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallParticipantVideoSourceGroup: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallParticipantVideoSourceGroup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallParticipantVideoSourceGroup(Cons_groupCallParticipantVideoSourceGroup(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallParticipantVideoSourceGroup(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallParticipantVideoSourceGroup] {
            return tlObjectsAt(object, offset).map { Api.GroupCallParticipantVideoSourceGroup(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallParticipantVideoSourceGroup.Cons_groupCallParticipantVideoSourceGroup {
    @_alwaysEmitIntoClient var semantics: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var sources: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 32) } }
    }
    init(semantics: String, sources: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1450))
        tlStoreReference(_tlObject, 24, semantics as NSString)
        tlStoreReference(_tlObject, 32, tlPackInt32(sources) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum GroupCallStreamChannel: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_groupCallStreamChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case groupCallStreamChannel(Cons_groupCallStreamChannel)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .groupCallStreamChannel(Cons_groupCallStreamChannel(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .groupCallStreamChannel(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.GroupCallStreamChannel] {
            return tlObjectsAt(object, offset).map { Api.GroupCallStreamChannel(tlObject: $0) }
        }

    }
}
public extension Api.GroupCallStreamChannel.Cons_groupCallStreamChannel {
    @_alwaysEmitIntoClient var channel: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var scale: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var lastTimestampMs: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(channel: Int32, scale: Int32, lastTimestampMs: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(828))
        tlStore(_tlObject, 24, channel)
        tlStore(_tlObject, 28, scale)
        tlStore(_tlObject, 32, lastTimestampMs)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum HighScore: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_highScore {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case highScore(Cons_highScore)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .highScore(Cons_highScore(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .highScore(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.HighScore] {
            return tlObjectsAt(object, offset).map { Api.HighScore(tlObject: $0) }
        }

    }
}
public extension Api.HighScore.Cons_highScore {
    @_alwaysEmitIntoClient var pos: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var score: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(pos: Int32, userId: Int64, score: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(737))
        tlStore(_tlObject, 24, pos)
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 28, score)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ImportedContact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_importedContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case importedContact(Cons_importedContact)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .importedContact(Cons_importedContact(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .importedContact(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ImportedContact] {
            return tlObjectsAt(object, offset).map { Api.ImportedContact(tlObject: $0) }
        }

    }
}
public extension Api.ImportedContact.Cons_importedContact {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var clientId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(userId: Int64, clientId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1287))
        tlStore(_tlObject, 24, userId)
        tlStore(_tlObject, 32, clientId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InlineBotSwitchPM: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inlineBotSwitchPM {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inlineBotSwitchPM(Cons_inlineBotSwitchPM)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inlineBotSwitchPM(Cons_inlineBotSwitchPM(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inlineBotSwitchPM(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InlineBotSwitchPM] {
            return tlObjectsAt(object, offset).map { Api.InlineBotSwitchPM(tlObject: $0) }
        }

    }
}
public extension Api.InlineBotSwitchPM.Cons_inlineBotSwitchPM {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var startParam: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: String, startParam: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(381))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, startParam as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InlineBotWebView: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inlineBotWebView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inlineBotWebView(Cons_inlineBotWebView)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inlineBotWebView(Cons_inlineBotWebView(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inlineBotWebView(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InlineBotWebView] {
            return tlObjectsAt(object, offset).map { Api.InlineBotWebView(tlObject: $0) }
        }

    }
}
public extension Api.InlineBotWebView.Cons_inlineBotWebView {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(text: String, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1191))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
