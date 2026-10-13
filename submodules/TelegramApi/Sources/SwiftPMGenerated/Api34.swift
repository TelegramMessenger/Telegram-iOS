import TelegramApiObjC
public extension Api {
    indirect enum WebPageAttribute: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webPageAttributeAiComposeTone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeStarGiftAuction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeStarGiftCollection {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeStickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeTheme {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_webPageAttributeUniqueStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webPageAttributeAiComposeTone(Cons_webPageAttributeAiComposeTone)
        case webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction)
        case webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection)
        case webPageAttributeStickerSet(Cons_webPageAttributeStickerSet)
        case webPageAttributeStory(Cons_webPageAttributeStory)
        case webPageAttributeTheme(Cons_webPageAttributeTheme)
        case webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webPageAttributeAiComposeTone(Cons_webPageAttributeAiComposeTone(tlObject: object))
            case 1:
                self = .webPageAttributeStarGiftAuction(Cons_webPageAttributeStarGiftAuction(tlObject: object))
            case 2:
                self = .webPageAttributeStarGiftCollection(Cons_webPageAttributeStarGiftCollection(tlObject: object))
            case 3:
                self = .webPageAttributeStickerSet(Cons_webPageAttributeStickerSet(tlObject: object))
            case 4:
                self = .webPageAttributeStory(Cons_webPageAttributeStory(tlObject: object))
            case 5:
                self = .webPageAttributeTheme(Cons_webPageAttributeTheme(tlObject: object))
            case 6:
                self = .webPageAttributeUniqueStarGift(Cons_webPageAttributeUniqueStarGift(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webPageAttributeAiComposeTone(let _data):
                return _data.tlObject
            case .webPageAttributeStarGiftAuction(let _data):
                return _data.tlObject
            case .webPageAttributeStarGiftCollection(let _data):
                return _data.tlObject
            case .webPageAttributeStickerSet(let _data):
                return _data.tlObject
            case .webPageAttributeStory(let _data):
                return _data.tlObject
            case .webPageAttributeTheme(let _data):
                return _data.tlObject
            case .webPageAttributeUniqueStarGift(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebPageAttribute] {
            return tlObjectsAt(object, offset).map { Api.WebPageAttribute(tlObject: $0) }
        }

    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeAiComposeTone {
    @_alwaysEmitIntoClient var emojiId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(emojiId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(770))
        tlStore(_tlObject, 24, emojiId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeStarGiftAuction {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var endDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(gift: Api.StarGift, endDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(12))
        tlStoreReference(_tlObject, 32, gift.tlObject)
        tlStore(_tlObject, 24, endDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeStarGiftCollection {
    @_alwaysEmitIntoClient var icons: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 24) } }
    }
    init(icons: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(319))
        tlStoreReference(_tlObject, 24, icons.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeStickerSet {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, stickers: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(525))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, stickers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeStory {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(290))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStore(_tlObject, 28, id)
        tlStoreReference(_tlObject, 40, story?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeTheme {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Document.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var settings: Api.ThemeSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ThemeSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, documents: [Api.Document]?, settings: Api.ThemeSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(550))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, documents.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 40, settings?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.WebPageAttribute.Cons_webPageAttributeUniqueStarGift {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(gift: Api.StarGift) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1375))
        tlStoreReference(_tlObject, 24, gift.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebViewMessageSent: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webViewMessageSent {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webViewMessageSent(Cons_webViewMessageSent)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webViewMessageSent(Cons_webViewMessageSent(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webViewMessageSent(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebViewMessageSent] {
            return tlObjectsAt(object, offset).map { Api.WebViewMessageSent(tlObject: $0) }
        }

    }
}
public extension Api.WebViewMessageSent.Cons_webViewMessageSent {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var msgId: Api.InputBotInlineMessageID? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputBotInlineMessageID(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, msgId: Api.InputBotInlineMessageID?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(80))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, msgId?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum WebViewResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webViewResultUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webViewResultUrl(Cons_webViewResultUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webViewResultUrl(Cons_webViewResultUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webViewResultUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.WebViewResult] {
            return tlObjectsAt(object, offset).map { Api.WebViewResult(tlObject: $0) }
        }

    }
}
public extension Api.WebViewResult.Cons_webViewResultUrl {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var queryId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, queryId: Int64?, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(496))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = queryId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum AuthorizationForm: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_authorizationForm {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case authorizationForm(Cons_authorizationForm)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .authorizationForm(Cons_authorizationForm(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .authorizationForm(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.AuthorizationForm] {
            return tlObjectsAt(object, offset).map { Api.account.AuthorizationForm(tlObject: $0) }
        }

    }
}
public extension Api.account.AuthorizationForm.Cons_authorizationForm {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var requiredTypes: [Api.SecureRequiredType] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureRequiredType.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var values: [Api.SecureValue] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValue.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var errors: [Api.SecureValueError] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecureValueError.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var privacyPolicyUrl: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, requiredTypes: [Api.SecureRequiredType], values: [Api.SecureValue], errors: [Api.SecureValueError], users: [Api.User], privacyPolicyUrl: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1130))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, requiredTypes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, values.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, errors.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, privacyPolicyUrl.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum Authorizations: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_authorizations {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case authorizations(Cons_authorizations)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .authorizations(Cons_authorizations(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .authorizations(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.Authorizations] {
            return tlObjectsAt(object, offset).map { Api.account.Authorizations(tlObject: $0) }
        }

    }
}
public extension Api.account.Authorizations.Cons_authorizations {
    @_alwaysEmitIntoClient var authorizationTtlDays: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var authorizations: [Api.Authorization] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Authorization.tlArray(self.tlObject, 32) } }
    }
    init(authorizationTtlDays: Int32, authorizations: [Api.Authorization]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(490))
        tlStore(_tlObject, 24, authorizationTtlDays)
        tlStoreReference(_tlObject, 32, authorizations.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum AutoDownloadSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_autoDownloadSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case autoDownloadSettings(Cons_autoDownloadSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .autoDownloadSettings(Cons_autoDownloadSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .autoDownloadSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.AutoDownloadSettings] {
            return tlObjectsAt(object, offset).map { Api.account.AutoDownloadSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.AutoDownloadSettings.Cons_autoDownloadSettings {
    @_alwaysEmitIntoClient var low: Api.AutoDownloadSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoDownloadSettings(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var medium: Api.AutoDownloadSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoDownloadSettings(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var high: Api.AutoDownloadSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoDownloadSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(low: Api.AutoDownloadSettings, medium: Api.AutoDownloadSettings, high: Api.AutoDownloadSettings) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(639))
        tlStoreReference(_tlObject, 24, low.tlObject)
        tlStoreReference(_tlObject, 32, medium.tlObject)
        tlStoreReference(_tlObject, 40, high.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum AutoSaveSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_autoSaveSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case autoSaveSettings(Cons_autoSaveSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .autoSaveSettings(Cons_autoSaveSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .autoSaveSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.AutoSaveSettings] {
            return tlObjectsAt(object, offset).map { Api.account.AutoSaveSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.AutoSaveSettings.Cons_autoSaveSettings {
    @_alwaysEmitIntoClient var usersSettings: Api.AutoSaveSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoSaveSettings(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chatsSettings: Api.AutoSaveSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoSaveSettings(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var broadcastsSettings: Api.AutoSaveSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoSaveSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var exceptions: [Api.AutoSaveException] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AutoSaveException.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(usersSettings: Api.AutoSaveSettings, chatsSettings: Api.AutoSaveSettings, broadcastsSettings: Api.AutoSaveSettings, exceptions: [Api.AutoSaveException], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(493))
        tlStoreReference(_tlObject, 24, usersSettings.tlObject)
        tlStoreReference(_tlObject, 32, chatsSettings.tlObject)
        tlStoreReference(_tlObject, 40, broadcastsSettings.tlObject)
        tlStoreReference(_tlObject, 48, exceptions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum BusinessChatLinks: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_businessChatLinks {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case businessChatLinks(Cons_businessChatLinks)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .businessChatLinks(Cons_businessChatLinks(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .businessChatLinks(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.BusinessChatLinks] {
            return tlObjectsAt(object, offset).map { Api.account.BusinessChatLinks(tlObject: $0) }
        }

    }
}
public extension Api.account.BusinessChatLinks.Cons_businessChatLinks {
    @_alwaysEmitIntoClient var links: [Api.BusinessChatLink] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessChatLink.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(links: [Api.BusinessChatLink], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1562))
        tlStoreReference(_tlObject, 24, links.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum ChatThemes: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatThemes {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatThemes(Cons_chatThemes)
        case chatThemesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatThemes(Cons_chatThemes(tlObject: object))
            case 1:
                self = .chatThemesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatThemes(let _data):
                return _data.tlObject
            case .chatThemesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1472))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.ChatThemes] {
            return tlObjectsAt(object, offset).map { Api.account.ChatThemes(tlObject: $0) }
        }

    }
}
public extension Api.account.ChatThemes.Cons_chatThemes {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var themes: [Api.ChatTheme] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatTheme.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, hash: Int64, themes: [Api.ChatTheme], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1263))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, hash)
        tlStoreReference(_tlObject, 40, themes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum ConnectedBots: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_connectedBots {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case connectedBots(Cons_connectedBots)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .connectedBots(Cons_connectedBots(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .connectedBots(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.ConnectedBots] {
            return tlObjectsAt(object, offset).map { Api.account.ConnectedBots(tlObject: $0) }
        }

    }
}
public extension Api.account.ConnectedBots.Cons_connectedBots {
    @_alwaysEmitIntoClient var connectedBots: [Api.ConnectedBot] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ConnectedBot.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(connectedBots: [Api.ConnectedBot], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(152))
        tlStoreReference(_tlObject, 24, connectedBots.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum ContentSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_contentSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case contentSettings(Cons_contentSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .contentSettings(Cons_contentSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .contentSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.ContentSettings] {
            return tlObjectsAt(object, offset).map { Api.account.ContentSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.ContentSettings.Cons_contentSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(572))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum EmailVerified: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emailVerified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_emailVerifiedLogin {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emailVerified(Cons_emailVerified)
        case emailVerifiedLogin(Cons_emailVerifiedLogin)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emailVerified(Cons_emailVerified(tlObject: object))
            case 1:
                self = .emailVerifiedLogin(Cons_emailVerifiedLogin(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emailVerified(let _data):
                return _data.tlObject
            case .emailVerifiedLogin(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.EmailVerified] {
            return tlObjectsAt(object, offset).map { Api.account.EmailVerified(tlObject: $0) }
        }

    }
}
public extension Api.account.EmailVerified.Cons_emailVerified {
    @_alwaysEmitIntoClient var email: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(email: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(275))
        tlStoreReference(_tlObject, 24, email as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account.EmailVerified.Cons_emailVerifiedLogin {
    @_alwaysEmitIntoClient var email: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var sentCode: Api.auth.SentCode {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.auth.SentCode(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(email: String, sentCode: Api.auth.SentCode) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1487))
        tlStoreReference(_tlObject, 24, email as NSString)
        tlStoreReference(_tlObject, 32, sentCode.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum EmojiStatuses: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiStatuses {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiStatuses(Cons_emojiStatuses)
        case emojiStatusesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiStatuses(Cons_emojiStatuses(tlObject: object))
            case 1:
                self = .emojiStatusesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiStatuses(let _data):
                return _data.tlObject
            case .emojiStatusesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1382))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.EmojiStatuses] {
            return tlObjectsAt(object, offset).map { Api.account.EmojiStatuses(tlObject: $0) }
        }

    }
}
public extension Api.account.EmojiStatuses.Cons_emojiStatuses {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var statuses: [Api.EmojiStatus] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EmojiStatus.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, statuses: [Api.EmojiStatus]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(930))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, statuses.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum PaidMessagesRevenue: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paidMessagesRevenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paidMessagesRevenue(Cons_paidMessagesRevenue)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paidMessagesRevenue(Cons_paidMessagesRevenue(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paidMessagesRevenue(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.PaidMessagesRevenue] {
            return tlObjectsAt(object, offset).map { Api.account.PaidMessagesRevenue(tlObject: $0) }
        }

    }
}
public extension Api.account.PaidMessagesRevenue.Cons_paidMessagesRevenue {
    @_alwaysEmitIntoClient var starsAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(starsAmount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(199))
        tlStore(_tlObject, 24, starsAmount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum PasskeyRegistrationOptions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passkeyRegistrationOptions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passkeyRegistrationOptions(Cons_passkeyRegistrationOptions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passkeyRegistrationOptions(Cons_passkeyRegistrationOptions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passkeyRegistrationOptions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.PasskeyRegistrationOptions] {
            return tlObjectsAt(object, offset).map { Api.account.PasskeyRegistrationOptions(tlObject: $0) }
        }

    }
}
public extension Api.account.PasskeyRegistrationOptions.Cons_passkeyRegistrationOptions {
    @_alwaysEmitIntoClient var options: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(options: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1483))
        tlStoreReference(_tlObject, 24, options.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum Passkeys: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passkeys {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passkeys(Cons_passkeys)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passkeys(Cons_passkeys(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passkeys(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.Passkeys] {
            return tlObjectsAt(object, offset).map { Api.account.Passkeys(tlObject: $0) }
        }

    }
}
public extension Api.account.Passkeys.Cons_passkeys {
    @_alwaysEmitIntoClient var passkeys: [Api.Passkey] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Passkey.tlArray(self.tlObject, 24) } }
    }
    init(passkeys: [Api.Passkey]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1653))
        tlStoreReference(_tlObject, 24, passkeys.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum Password: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_password {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case password(Cons_password)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .password(Cons_password(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .password(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.Password] {
            return tlObjectsAt(object, offset).map { Api.account.Password(tlObject: $0) }
        }

    }
}
public extension Api.account.Password.Cons_password {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var currentAlgo: Api.PasswordKdfAlgo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.PasswordKdfAlgo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var srpB: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var srpId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 0) ? tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var hint: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var emailUnconfirmedPattern: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var newAlgo: Api.PasswordKdfAlgo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PasswordKdfAlgo(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var newSecureAlgo: Api.SecurePasswordKdfAlgo {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SecurePasswordKdfAlgo(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var secureRandom: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var pendingResetDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 104, 1) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var loginEmailPattern: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    init(flags: Int32, currentAlgo: Api.PasswordKdfAlgo?, srpB: Buffer?, srpId: Int64?, hint: String?, emailUnconfirmedPattern: String?, newAlgo: Api.PasswordKdfAlgo, newSecureAlgo: Api.SecurePasswordKdfAlgo, secureRandom: Buffer, pendingResetDate: Int32?, loginEmailPattern: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(953))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, currentAlgo?.tlObject)
        tlStoreReference(_tlObject, 40, srpB.map { value in value.makeData() as NSData })
        if let _tlValue = srpId { tlStore(_tlObject, 48, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 56, hint.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, emailUnconfirmedPattern.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, newAlgo.tlObject)
        tlStoreReference(_tlObject, 80, newSecureAlgo.tlObject)
        tlStoreReference(_tlObject, 88, secureRandom.makeData() as NSData)
        if let _tlValue = pendingResetDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 96, loginEmailPattern.map { value in value as NSString })
        tlStore(_tlObject, 104, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum PasswordInputSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passwordInputSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passwordInputSettings(Cons_passwordInputSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passwordInputSettings(Cons_passwordInputSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passwordInputSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.PasswordInputSettings] {
            return tlObjectsAt(object, offset).map { Api.account.PasswordInputSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.PasswordInputSettings.Cons_passwordInputSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var newAlgo: Api.PasswordKdfAlgo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.PasswordKdfAlgo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var newPasswordHash: Buffer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var hint: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var email: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var newSecureSettings: Api.SecureSecretSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.SecureSecretSettings(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, newAlgo: Api.PasswordKdfAlgo?, newPasswordHash: Buffer?, hint: String?, email: String?, newSecureSettings: Api.SecureSecretSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1297))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, newAlgo?.tlObject)
        tlStoreReference(_tlObject, 40, newPasswordHash.map { value in value.makeData() as NSData })
        tlStoreReference(_tlObject, 48, hint.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, email.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, newSecureSettings?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum PasswordSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_passwordSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case passwordSettings(Cons_passwordSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .passwordSettings(Cons_passwordSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .passwordSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.PasswordSettings] {
            return tlObjectsAt(object, offset).map { Api.account.PasswordSettings(tlObject: $0) }
        }

    }
}
public extension Api.account.PasswordSettings.Cons_passwordSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var email: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var secureSettings: Api.SecureSecretSettings? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.SecureSecretSettings(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, email: String?, secureSettings: Api.SecureSecretSettings?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1001))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, email.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, secureSettings?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum PrivacyRules: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_privacyRules {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case privacyRules(Cons_privacyRules)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .privacyRules(Cons_privacyRules(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .privacyRules(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.PrivacyRules] {
            return tlObjectsAt(object, offset).map { Api.account.PrivacyRules(tlObject: $0) }
        }

    }
}
public extension Api.account.PrivacyRules.Cons_privacyRules {
    @_alwaysEmitIntoClient var rules: [Api.PrivacyRule] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PrivacyRule.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(rules: [Api.PrivacyRule], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(522))
        tlStoreReference(_tlObject, 24, rules.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum ResetPasswordResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_resetPasswordFailedWait {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_resetPasswordRequestedWait {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case resetPasswordFailedWait(Cons_resetPasswordFailedWait)
        case resetPasswordOk
        case resetPasswordRequestedWait(Cons_resetPasswordRequestedWait)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .resetPasswordFailedWait(Cons_resetPasswordFailedWait(tlObject: object))
            case 1:
                self = .resetPasswordOk
            case 2:
                self = .resetPasswordRequestedWait(Cons_resetPasswordRequestedWait(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .resetPasswordFailedWait(let _data):
                return _data.tlObject
            case .resetPasswordOk:
                return TLObjectSingleton(TLApiConstructorAt(1537))
            case .resetPasswordRequestedWait(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.ResetPasswordResult] {
            return tlObjectsAt(object, offset).map { Api.account.ResetPasswordResult(tlObject: $0) }
        }

    }
}
public extension Api.account.ResetPasswordResult.Cons_resetPasswordFailedWait {
    @_alwaysEmitIntoClient var retryDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(retryDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1496))
        tlStore(_tlObject, 24, retryDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account.ResetPasswordResult.Cons_resetPasswordRequestedWait {
    @_alwaysEmitIntoClient var untilDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(untilDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1544))
        tlStore(_tlObject, 24, untilDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum ResolvedBusinessChatLinks: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_resolvedBusinessChatLinks {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .resolvedBusinessChatLinks(Cons_resolvedBusinessChatLinks(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .resolvedBusinessChatLinks(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.ResolvedBusinessChatLinks] {
            return tlObjectsAt(object, offset).map { Api.account.ResolvedBusinessChatLinks(tlObject: $0) }
        }

    }
}
public extension Api.account.ResolvedBusinessChatLinks.Cons_resolvedBusinessChatLinks {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var message: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.MessageEntity.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, peer: Api.Peer, message: String, entities: [Api.MessageEntity]?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(996))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peer.tlObject)
        tlStoreReference(_tlObject, 40, message as NSString)
        tlStoreReference(_tlObject, 48, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum SavedMusicIds: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedMusicIds {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedMusicIds(Cons_savedMusicIds)
        case savedMusicIdsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedMusicIds(Cons_savedMusicIds(tlObject: object))
            case 1:
                self = .savedMusicIdsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedMusicIds(let _data):
                return _data.tlObject
            case .savedMusicIdsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(514))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.SavedMusicIds] {
            return tlObjectsAt(object, offset).map { Api.account.SavedMusicIds(tlObject: $0) }
        }

    }
}
public extension Api.account.SavedMusicIds.Cons_savedMusicIds {
    @_alwaysEmitIntoClient var ids: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(ids: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(989))
        tlStoreReference(_tlObject, 24, tlPackInt64(ids) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum SavedRingtone: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedRingtoneConverted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedRingtone
        case savedRingtoneConverted(Cons_savedRingtoneConverted)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedRingtone
            case 1:
                self = .savedRingtoneConverted(Cons_savedRingtoneConverted(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedRingtone:
                return TLObjectSingleton(TLApiConstructorAt(1206))
            case .savedRingtoneConverted(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.SavedRingtone] {
            return tlObjectsAt(object, offset).map { Api.account.SavedRingtone(tlObject: $0) }
        }

    }
}
public extension Api.account.SavedRingtone.Cons_savedRingtoneConverted {
    @_alwaysEmitIntoClient var document: Api.Document {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(document: Api.Document) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(212))
        tlStoreReference(_tlObject, 24, document.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum SavedRingtones: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedRingtones {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedRingtones(Cons_savedRingtones)
        case savedRingtonesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedRingtones(Cons_savedRingtones(tlObject: object))
            case 1:
                self = .savedRingtonesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedRingtones(let _data):
                return _data.tlObject
            case .savedRingtonesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1683))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.SavedRingtones] {
            return tlObjectsAt(object, offset).map { Api.account.SavedRingtones(tlObject: $0) }
        }

    }
}
public extension Api.account.SavedRingtones.Cons_savedRingtones {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var ringtones: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, ringtones: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1292))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, ringtones.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.account {
    enum SentEmailCode: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sentEmailCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sentEmailCode(Cons_sentEmailCode)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sentEmailCode(Cons_sentEmailCode(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sentEmailCode(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.account.SentEmailCode] {
            return tlObjectsAt(object, offset).map { Api.account.SentEmailCode(tlObject: $0) }
        }

    }
}
public extension Api.account.SentEmailCode.Cons_sentEmailCode {
    @_alwaysEmitIntoClient var emailPattern: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var length: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(emailPattern: String, length: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(830))
        tlStoreReference(_tlObject, 32, emailPattern as NSString)
        tlStore(_tlObject, 24, length)
        self.init(tlObject: _tlObject)
    }
}
