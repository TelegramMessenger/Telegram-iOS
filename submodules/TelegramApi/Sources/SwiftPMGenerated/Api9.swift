import TelegramApiObjC
public extension Api {
    enum InputBusinessChatLink: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessChatLink {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessChatLink(Cons_inputBusinessChatLink)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessChatLink(Cons_inputBusinessChatLink(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessChatLink(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessChatLink] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessChatLink(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessChatLink.Cons_inputBusinessChatLink {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.MessageEntity.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, message: String, entities: [Api.MessageEntity]?, title: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(107))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBusinessGreetingMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessGreetingMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessGreetingMessage(Cons_inputBusinessGreetingMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessGreetingMessage(Cons_inputBusinessGreetingMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessGreetingMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessGreetingMessage] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessGreetingMessage(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessGreetingMessage.Cons_inputBusinessGreetingMessage {
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var recipients: Api.InputBusinessRecipients {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBusinessRecipients(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var noActivityDays: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(shortcutId: Int32, recipients: Api.InputBusinessRecipients, noActivityDays: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(10))
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 32, recipients.tlObject)
        tlStore(_tlObject, 28, noActivityDays)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBusinessIntro: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessIntro {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessIntro(Cons_inputBusinessIntro)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessIntro(Cons_inputBusinessIntro(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessIntro(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessIntro] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessIntro(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessIntro.Cons_inputBusinessIntro {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var sticker: Api.InputDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, title: String, description: String, sticker: Api.InputDocument?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(62))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, sticker?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBusinessRecipients: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessRecipients {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessRecipients(Cons_inputBusinessRecipients)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessRecipients(Cons_inputBusinessRecipients(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessRecipients(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessRecipients] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessRecipients(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessRecipients.Cons_inputBusinessRecipients {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.InputUser]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputUser.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, users: [Api.InputUser]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(712))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputChannel: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputChannelFromMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputChannel(Cons_inputChannel)
        case inputChannelEmpty
        case inputChannelFromMessage(Cons_inputChannelFromMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputChannel(Cons_inputChannel(tlObject: object))
            case 1:
                self = .inputChannelEmpty
            case 2:
                self = .inputChannelFromMessage(Cons_inputChannelFromMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputChannel(let _data):
                return _data.tlObject
            case .inputChannelEmpty:
                return TLObjectSingleton(TLApiConstructorAt(1582))
            case .inputChannelFromMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputChannel] {
            return tlObjectsAt(object, offset).map { Api.InputChannel(tlObject: $0) }
        }

    }
}
public extension Api.InputChannel.Cons_inputChannel {
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(channelId: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1617))
        tlStore(_tlObject, 24, channelId)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputChannel.Cons_inputChannelFromMessage {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(peer: Api.InputPeer, msgId: Int32, channelId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(592))
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 24, msgId)
        tlStore(_tlObject, 40, channelId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputChatPhoto: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputChatPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputChatUploadedPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputChatPhoto(Cons_inputChatPhoto)
        case inputChatPhotoEmpty
        case inputChatUploadedPhoto(Cons_inputChatUploadedPhoto)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputChatPhoto(Cons_inputChatPhoto(tlObject: object))
            case 1:
                self = .inputChatPhotoEmpty
            case 2:
                self = .inputChatUploadedPhoto(Cons_inputChatUploadedPhoto(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputChatPhoto(let _data):
                return _data.tlObject
            case .inputChatPhotoEmpty:
                return TLObjectSingleton(TLApiConstructorAt(188))
            case .inputChatUploadedPhoto(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputChatPhoto] {
            return tlObjectsAt(object, offset).map { Api.InputChatPhoto(tlObject: $0) }
        }

    }
}
public extension Api.InputChatPhoto.Cons_inputChatPhoto {
    @_alwaysEmitIntoClient var id: Api.InputPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(id: Api.InputPhoto) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(883))
        tlStoreReference(_tlObject, 24, id.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputChatPhoto.Cons_inputChatUploadedPhoto {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var file: Api.InputFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputFile(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var video: Api.InputFile? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputFile(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var videoStartTs: Double? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Double.self) : nil } }
    }
    @_alwaysEmitIntoClient var videoEmojiMarkup: Api.VideoSize? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.VideoSize(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, file: Api.InputFile?, video: Api.InputFile?, videoStartTs: Double?, videoEmojiMarkup: Api.VideoSize?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1257))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, file?.tlObject)
        tlStoreReference(_tlObject, 40, video?.tlObject)
        if let _tlValue = videoStartTs { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, videoEmojiMarkup?.tlObject)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputChatTheme: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputChatTheme {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputChatThemeUniqueGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputChatTheme(Cons_inputChatTheme)
        case inputChatThemeEmpty
        case inputChatThemeUniqueGift(Cons_inputChatThemeUniqueGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputChatTheme(Cons_inputChatTheme(tlObject: object))
            case 1:
                self = .inputChatThemeEmpty
            case 2:
                self = .inputChatThemeUniqueGift(Cons_inputChatThemeUniqueGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputChatTheme(let _data):
                return _data.tlObject
            case .inputChatThemeEmpty:
                return TLObjectSingleton(TLApiConstructorAt(843))
            case .inputChatThemeUniqueGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputChatTheme] {
            return tlObjectsAt(object, offset).map { Api.InputChatTheme(tlObject: $0) }
        }

    }
}
public extension Api.InputChatTheme.Cons_inputChatTheme {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1337))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputChatTheme.Cons_inputChatThemeUniqueGift {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(871))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputChatlist: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputChatlistDialogFilter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputChatlistDialogFilter(Cons_inputChatlistDialogFilter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputChatlistDialogFilter(Cons_inputChatlistDialogFilter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputChatlistDialogFilter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputChatlist] {
            return tlObjectsAt(object, offset).map { Api.InputChatlist(tlObject: $0) }
        }

    }
}
public extension Api.InputChatlist.Cons_inputChatlistDialogFilter {
    @_alwaysEmitIntoClient var filterId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(filterId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1622))
        tlStore(_tlObject, 24, filterId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputCheckPasswordSRP: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputCheckPasswordSRP {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputCheckPasswordEmpty
        case inputCheckPasswordSRP(Cons_inputCheckPasswordSRP)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputCheckPasswordEmpty
            case 1:
                self = .inputCheckPasswordSRP(Cons_inputCheckPasswordSRP(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputCheckPasswordEmpty:
                return TLObjectSingleton(TLApiConstructorAt(980))
            case .inputCheckPasswordSRP(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputCheckPasswordSRP] {
            return tlObjectsAt(object, offset).map { Api.InputCheckPasswordSRP(tlObject: $0) }
        }

    }
}
public extension Api.InputCheckPasswordSRP.Cons_inputCheckPasswordSRP {
    @_alwaysEmitIntoClient var srpId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var A: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var M1: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(srpId: Int64, A: Buffer, M1: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1391))
        tlStore(_tlObject, 24, srpId)
        tlStoreReference(_tlObject, 32, A.makeData() as NSData)
        tlStoreReference(_tlObject, 40, M1.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputClientProxy: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputClientProxy {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputClientProxy(Cons_inputClientProxy)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputClientProxy(Cons_inputClientProxy(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputClientProxy(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputClientProxy] {
            return tlObjectsAt(object, offset).map { Api.InputClientProxy(tlObject: $0) }
        }

    }
}
public extension Api.InputClientProxy.Cons_inputClientProxy {
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var port: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(address: String, port: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(752))
        tlStoreReference(_tlObject, 32, address as NSString)
        tlStore(_tlObject, 24, port)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputCollectible: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputCollectiblePhone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputCollectibleUsername {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputCollectiblePhone(Cons_inputCollectiblePhone)
        case inputCollectibleUsername(Cons_inputCollectibleUsername)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputCollectiblePhone(Cons_inputCollectiblePhone(tlObject: object))
            case 1:
                self = .inputCollectibleUsername(Cons_inputCollectibleUsername(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputCollectiblePhone(let _data):
                return _data.tlObject
            case .inputCollectibleUsername(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputCollectible] {
            return tlObjectsAt(object, offset).map { Api.InputCollectible(tlObject: $0) }
        }

    }
}
public extension Api.InputCollectible.Cons_inputCollectiblePhone {
    @_alwaysEmitIntoClient var phone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(phone: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1066))
        tlStoreReference(_tlObject, 24, phone as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputCollectible.Cons_inputCollectibleUsername {
    @_alwaysEmitIntoClient var username: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(username: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1498))
        tlStoreReference(_tlObject, 24, username as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputContact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputPhoneContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputPhoneContact(Cons_inputPhoneContact)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputPhoneContact(Cons_inputPhoneContact(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputPhoneContact(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputContact] {
            return tlObjectsAt(object, offset).map { Api.InputContact(tlObject: $0) }
        }

    }
}
public extension Api.InputContact.Cons_inputPhoneContact {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var clientId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var phone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var firstName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var lastName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var note: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, clientId: Int64, phone: String, firstName: String, lastName: String, note: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(680))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, clientId)
        tlStoreReference(_tlObject, 40, phone as NSString)
        tlStoreReference(_tlObject, 48, firstName as NSString)
        tlStoreReference(_tlObject, 56, lastName as NSString)
        tlStoreReference(_tlObject, 64, note?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputDialogPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputDialogPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputDialogPeerCommunity {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputDialogPeerFolder {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputDialogPeer(Cons_inputDialogPeer)
        case inputDialogPeerCommunity(Cons_inputDialogPeerCommunity)
        case inputDialogPeerFolder(Cons_inputDialogPeerFolder)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputDialogPeer(Cons_inputDialogPeer(tlObject: object))
            case 1:
                self = .inputDialogPeerCommunity(Cons_inputDialogPeerCommunity(tlObject: object))
            case 2:
                self = .inputDialogPeerFolder(Cons_inputDialogPeerFolder(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputDialogPeer(let _data):
                return _data.tlObject
            case .inputDialogPeerCommunity(let _data):
                return _data.tlObject
            case .inputDialogPeerFolder(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputDialogPeer] {
            return tlObjectsAt(object, offset).map { Api.InputDialogPeer(tlObject: $0) }
        }

    }
}
public extension Api.InputDialogPeer.Cons_inputDialogPeer {
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(peer: Api.InputPeer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1688))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputDialogPeer.Cons_inputDialogPeerCommunity {
    @_alwaysEmitIntoClient var community: Api.InputChannel {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputChannel(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(community: Api.InputChannel) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(678))
        tlStoreReference(_tlObject, 24, community.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputDialogPeer.Cons_inputDialogPeerFolder {
    @_alwaysEmitIntoClient var folderId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(folderId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(644))
        tlStore(_tlObject, 24, folderId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputDocument: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputDocument(Cons_inputDocument)
        case inputDocumentEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputDocument(Cons_inputDocument(tlObject: object))
            case 1:
                self = .inputDocumentEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputDocument(let _data):
                return _data.tlObject
            case .inputDocumentEmpty:
                return TLObjectSingleton(TLApiConstructorAt(735))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputDocument] {
            return tlObjectsAt(object, offset).map { Api.InputDocument(tlObject: $0) }
        }

    }
}
public extension Api.InputDocument.Cons_inputDocument {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(id: Int64, accessHash: Int64, fileReference: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(173))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStoreReference(_tlObject, 40, fileReference.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputEncryptedChat: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputEncryptedChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputEncryptedChat(Cons_inputEncryptedChat)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputEncryptedChat(Cons_inputEncryptedChat(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputEncryptedChat(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputEncryptedChat] {
            return tlObjectsAt(object, offset).map { Api.InputEncryptedChat(tlObject: $0) }
        }

    }
}
public extension Api.InputEncryptedChat.Cons_inputEncryptedChat {
    @_alwaysEmitIntoClient var chatId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(chatId: Int32, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1601))
        tlStore(_tlObject, 24, chatId)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputEncryptedFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputEncryptedFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputEncryptedFileBigUploaded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputEncryptedFileUploaded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputEncryptedFile(Cons_inputEncryptedFile)
        case inputEncryptedFileBigUploaded(Cons_inputEncryptedFileBigUploaded)
        case inputEncryptedFileEmpty
        case inputEncryptedFileUploaded(Cons_inputEncryptedFileUploaded)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputEncryptedFile(Cons_inputEncryptedFile(tlObject: object))
            case 1:
                self = .inputEncryptedFileBigUploaded(Cons_inputEncryptedFileBigUploaded(tlObject: object))
            case 2:
                self = .inputEncryptedFileEmpty
            case 3:
                self = .inputEncryptedFileUploaded(Cons_inputEncryptedFileUploaded(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputEncryptedFile(let _data):
                return _data.tlObject
            case .inputEncryptedFileBigUploaded(let _data):
                return _data.tlObject
            case .inputEncryptedFileEmpty:
                return TLObjectSingleton(TLApiConstructorAt(156))
            case .inputEncryptedFileUploaded(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputEncryptedFile] {
            return tlObjectsAt(object, offset).map { Api.InputEncryptedFile(tlObject: $0) }
        }

    }
}
public extension Api.InputEncryptedFile.Cons_inputEncryptedFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(586))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputEncryptedFile.Cons_inputEncryptedFileBigUploaded {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var parts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var keyFingerprint: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(id: Int64, parts: Int32, keyFingerprint: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(284))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, parts)
        tlStore(_tlObject, 28, keyFingerprint)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputEncryptedFile.Cons_inputEncryptedFileUploaded {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var parts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var md5Checksum: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var keyFingerprint: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(id: Int64, parts: Int32, md5Checksum: String, keyFingerprint: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(646))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, parts)
        tlStoreReference(_tlObject, 40, md5Checksum as NSString)
        tlStore(_tlObject, 28, keyFingerprint)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputFileBig {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputFileStoryDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputFile(Cons_inputFile)
        case inputFileBig(Cons_inputFileBig)
        case inputFileStoryDocument(Cons_inputFileStoryDocument)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputFile(Cons_inputFile(tlObject: object))
            case 1:
                self = .inputFileBig(Cons_inputFileBig(tlObject: object))
            case 2:
                self = .inputFileStoryDocument(Cons_inputFileStoryDocument(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputFile(let _data):
                return _data.tlObject
            case .inputFileBig(let _data):
                return _data.tlObject
            case .inputFileStoryDocument(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputFile] {
            return tlObjectsAt(object, offset).map { Api.InputFile(tlObject: $0) }
        }

    }
}
public extension Api.InputFile.Cons_inputFile {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var parts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var md5Checksum: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(id: Int64, parts: Int32, name: String, md5Checksum: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1632))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, parts)
        tlStoreReference(_tlObject, 40, name as NSString)
        tlStoreReference(_tlObject, 48, md5Checksum as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFile.Cons_inputFileBig {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var parts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(id: Int64, parts: Int32, name: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1667))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 24, parts)
        tlStoreReference(_tlObject, 40, name as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFile.Cons_inputFileStoryDocument {
    @_alwaysEmitIntoClient var id: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(id: Api.InputDocument) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(632))
        tlStoreReference(_tlObject, 24, id.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputFileLocation: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputDocumentFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputEncryptedFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputGroupCallStream {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPeerPhotoFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPhotoFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputPhotoLegacyFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputSecureFileLocation {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputStickerSetThumb {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputDocumentFileLocation(Cons_inputDocumentFileLocation)
        case inputEncryptedFileLocation(Cons_inputEncryptedFileLocation)
        case inputFileLocation(Cons_inputFileLocation)
        case inputGroupCallStream(Cons_inputGroupCallStream)
        case inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation)
        case inputPhotoFileLocation(Cons_inputPhotoFileLocation)
        case inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation)
        case inputSecureFileLocation(Cons_inputSecureFileLocation)
        case inputStickerSetThumb(Cons_inputStickerSetThumb)
        case inputTakeoutFileLocation


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputDocumentFileLocation(Cons_inputDocumentFileLocation(tlObject: object))
            case 1:
                self = .inputEncryptedFileLocation(Cons_inputEncryptedFileLocation(tlObject: object))
            case 2:
                self = .inputFileLocation(Cons_inputFileLocation(tlObject: object))
            case 3:
                self = .inputGroupCallStream(Cons_inputGroupCallStream(tlObject: object))
            case 4:
                self = .inputPeerPhotoFileLocation(Cons_inputPeerPhotoFileLocation(tlObject: object))
            case 5:
                self = .inputPhotoFileLocation(Cons_inputPhotoFileLocation(tlObject: object))
            case 6:
                self = .inputPhotoLegacyFileLocation(Cons_inputPhotoLegacyFileLocation(tlObject: object))
            case 7:
                self = .inputSecureFileLocation(Cons_inputSecureFileLocation(tlObject: object))
            case 8:
                self = .inputStickerSetThumb(Cons_inputStickerSetThumb(tlObject: object))
            case 9:
                self = .inputTakeoutFileLocation
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputDocumentFileLocation(let _data):
                return _data.tlObject
            case .inputEncryptedFileLocation(let _data):
                return _data.tlObject
            case .inputFileLocation(let _data):
                return _data.tlObject
            case .inputGroupCallStream(let _data):
                return _data.tlObject
            case .inputPeerPhotoFileLocation(let _data):
                return _data.tlObject
            case .inputPhotoFileLocation(let _data):
                return _data.tlObject
            case .inputPhotoLegacyFileLocation(let _data):
                return _data.tlObject
            case .inputSecureFileLocation(let _data):
                return _data.tlObject
            case .inputStickerSetThumb(let _data):
                return _data.tlObject
            case .inputTakeoutFileLocation:
                return TLObjectSingleton(TLApiConstructorAt(269))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputFileLocation] {
            return tlObjectsAt(object, offset).map { Api.InputFileLocation(tlObject: $0) }
        }

    }
}
public extension Api.InputFileLocation.Cons_inputDocumentFileLocation {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var thumbSize: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1231))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStoreReference(_tlObject, 40, fileReference.makeData() as NSData)
        tlStoreReference(_tlObject, 48, thumbSize as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputEncryptedFileLocation {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1631))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputFileLocation {
    @_alwaysEmitIntoClient var volumeId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var localId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var secret: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    init(volumeId: Int64, localId: Int32, secret: Int64, fileReference: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1471))
        tlStore(_tlObject, 32, volumeId)
        tlStore(_tlObject, 24, localId)
        tlStore(_tlObject, 40, secret)
        tlStoreReference(_tlObject, 48, fileReference.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputGroupCallStream {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var call: Api.InputGroupCall {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGroupCall(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var timeMs: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var scale: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var videoChannel: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var videoQuality: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    init(flags: Int32, call: Api.InputGroupCall, timeMs: Int64, scale: Int32, videoChannel: Int32?, videoQuality: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(40))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, call.tlObject)
        tlStore(_tlObject, 48, timeMs)
        tlStore(_tlObject, 28, scale)
        if let _tlValue = videoChannel { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = videoQuality { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputPeerPhotoFileLocation {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.InputPeer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPeer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var photoId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(flags: Int32, peer: Api.InputPeer, photoId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(353))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 40, photoId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputPhotoFileLocation {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var thumbSize: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    init(id: Int64, accessHash: Int64, fileReference: Buffer, thumbSize: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(416))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        tlStoreReference(_tlObject, 40, fileReference.makeData() as NSData)
        tlStoreReference(_tlObject, 48, thumbSize as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputPhotoLegacyFileLocation {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var fileReference: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var volumeId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var localId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var secret: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 64, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64, fileReference: Buffer, volumeId: Int64, localId: Int32, secret: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1422))
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, fileReference.makeData() as NSData)
        tlStore(_tlObject, 56, volumeId)
        tlStore(_tlObject, 24, localId)
        tlStore(_tlObject, 64, secret)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputSecureFileLocation {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1358))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputFileLocation.Cons_inputStickerSetThumb {
    @_alwaysEmitIntoClient var stickerset: Api.InputStickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputStickerSet(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var thumbVersion: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(stickerset: Api.InputStickerSet, thumbVersion: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1023))
        tlStoreReference(_tlObject, 32, stickerset.tlObject)
        tlStore(_tlObject, 24, thumbVersion)
        self.init(tlObject: _tlObject)
    }
}
