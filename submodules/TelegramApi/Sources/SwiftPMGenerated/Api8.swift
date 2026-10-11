import TelegramApiObjC
public extension Api {
    indirect enum InlineButtonType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inlineButtonTypeCallback {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeCopy {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeSwitchInline {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeUrlAuth {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeUserProfile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inlineButtonTypeWebView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInlineButtonTypeUrlAuth {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputInlineButtonTypeUserProfile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inlineButtonTypeBuy
        case inlineButtonTypeCallback(Cons_inlineButtonTypeCallback)
        case inlineButtonTypeCopy(Cons_inlineButtonTypeCopy)
        case inlineButtonTypeDisabled
        case inlineButtonTypeGame
        case inlineButtonTypeSwitchInline(Cons_inlineButtonTypeSwitchInline)
        case inlineButtonTypeUrl(Cons_inlineButtonTypeUrl)
        case inlineButtonTypeUrlAuth(Cons_inlineButtonTypeUrlAuth)
        case inlineButtonTypeUserProfile(Cons_inlineButtonTypeUserProfile)
        case inlineButtonTypeWebView(Cons_inlineButtonTypeWebView)
        case inputInlineButtonTypeUrlAuth(Cons_inputInlineButtonTypeUrlAuth)
        case inputInlineButtonTypeUserProfile(Cons_inputInlineButtonTypeUserProfile)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inlineButtonTypeBuy
            case 1:
                self = .inlineButtonTypeCallback(Cons_inlineButtonTypeCallback(tlObject: object))
            case 2:
                self = .inlineButtonTypeCopy(Cons_inlineButtonTypeCopy(tlObject: object))
            case 3:
                self = .inlineButtonTypeDisabled
            case 4:
                self = .inlineButtonTypeGame
            case 5:
                self = .inlineButtonTypeSwitchInline(Cons_inlineButtonTypeSwitchInline(tlObject: object))
            case 6:
                self = .inlineButtonTypeUrl(Cons_inlineButtonTypeUrl(tlObject: object))
            case 7:
                self = .inlineButtonTypeUrlAuth(Cons_inlineButtonTypeUrlAuth(tlObject: object))
            case 8:
                self = .inlineButtonTypeUserProfile(Cons_inlineButtonTypeUserProfile(tlObject: object))
            case 9:
                self = .inlineButtonTypeWebView(Cons_inlineButtonTypeWebView(tlObject: object))
            case 10:
                self = .inputInlineButtonTypeUrlAuth(Cons_inputInlineButtonTypeUrlAuth(tlObject: object))
            case 11:
                self = .inputInlineButtonTypeUserProfile(Cons_inputInlineButtonTypeUserProfile(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inlineButtonTypeBuy:
                return TLObjectSingleton(TLApiConstructorAt(467))
            case .inlineButtonTypeCallback(let _data):
                return _data.tlObject
            case .inlineButtonTypeCopy(let _data):
                return _data.tlObject
            case .inlineButtonTypeDisabled:
                return TLObjectSingleton(TLApiConstructorAt(1063))
            case .inlineButtonTypeGame:
                return TLObjectSingleton(TLApiConstructorAt(594))
            case .inlineButtonTypeSwitchInline(let _data):
                return _data.tlObject
            case .inlineButtonTypeUrl(let _data):
                return _data.tlObject
            case .inlineButtonTypeUrlAuth(let _data):
                return _data.tlObject
            case .inlineButtonTypeUserProfile(let _data):
                return _data.tlObject
            case .inlineButtonTypeWebView(let _data):
                return _data.tlObject
            case .inputInlineButtonTypeUrlAuth(let _data):
                return _data.tlObject
            case .inputInlineButtonTypeUserProfile(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InlineButtonType] {
            return tlObjectsAt(object, offset).map { Api.InlineButtonType(tlObject: $0) }
        }

    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeCallback {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var data: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(flags: Int32, data: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(265))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, data.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeCopy {
    @_alwaysEmitIntoClient var copyText: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(copyText: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1165))
        tlStoreReference(_tlObject, 24, copyText as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeSwitchInline {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var query: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var peerTypes: [Api.InlineQueryPeerType]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InlineQueryPeerType.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, query: String, peerTypes: [Api.InlineQueryPeerType]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(932))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, query as NSString)
        tlStoreReference(_tlObject, 40, peerTypes.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1550))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeUrlAuth {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fwdText: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var buttonId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, fwdText: String?, url: String, buttonId: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1264))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, fwdText.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStore(_tlObject, 28, buttonId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeUserProfile {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(412))
        tlStore(_tlObject, 24, userId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inlineButtonTypeWebView {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(378))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inputInlineButtonTypeUrlAuth {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fwdText: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var bot: Api.InputUser? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InputUser(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, fwdText: String?, url: String, bot: Api.InputUser?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(977))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, fwdText.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, url as NSString)
        tlStoreReference(_tlObject, 48, bot?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InlineButtonType.Cons_inputInlineButtonTypeUserProfile {
    @_alwaysEmitIntoClient var userId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(userId: Api.InputUser) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(547))
        tlStoreReference(_tlObject, 24, userId.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InlineQueryPeerType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case inlineQueryPeerTypeBotPM
        case inlineQueryPeerTypeBroadcast
        case inlineQueryPeerTypeChat
        case inlineQueryPeerTypeMegagroup
        case inlineQueryPeerTypePM
        case inlineQueryPeerTypeSameBotPM


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inlineQueryPeerTypeBotPM
            case 1:
                self = .inlineQueryPeerTypeBroadcast
            case 2:
                self = .inlineQueryPeerTypeChat
            case 3:
                self = .inlineQueryPeerTypeMegagroup
            case 4:
                self = .inlineQueryPeerTypePM
            case 5:
                self = .inlineQueryPeerTypeSameBotPM
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inlineQueryPeerTypeBotPM:
                return TLObjectSingleton(TLApiConstructorAt(93))
            case .inlineQueryPeerTypeBroadcast:
                return TLObjectSingleton(TLApiConstructorAt(630))
            case .inlineQueryPeerTypeChat:
                return TLObjectSingleton(TLApiConstructorAt(1404))
            case .inlineQueryPeerTypeMegagroup:
                return TLObjectSingleton(TLApiConstructorAt(605))
            case .inlineQueryPeerTypePM:
                return TLObjectSingleton(TLApiConstructorAt(836))
            case .inlineQueryPeerTypeSameBotPM:
                return TLObjectSingleton(TLApiConstructorAt(306))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InlineQueryPeerType] {
            return tlObjectsAt(object, offset).map { Api.InlineQueryPeerType(tlObject: $0) }
        }

    }
}
public extension Api {
    enum InputAiComposeTone: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputAiComposeToneDefault {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputAiComposeToneID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputAiComposeToneSingleUse {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputAiComposeToneSlug {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputAiComposeToneDefault(Cons_inputAiComposeToneDefault)
        case inputAiComposeToneID(Cons_inputAiComposeToneID)
        case inputAiComposeToneSingleUse(Cons_inputAiComposeToneSingleUse)
        case inputAiComposeToneSlug(Cons_inputAiComposeToneSlug)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputAiComposeToneDefault(Cons_inputAiComposeToneDefault(tlObject: object))
            case 1:
                self = .inputAiComposeToneID(Cons_inputAiComposeToneID(tlObject: object))
            case 2:
                self = .inputAiComposeToneSingleUse(Cons_inputAiComposeToneSingleUse(tlObject: object))
            case 3:
                self = .inputAiComposeToneSlug(Cons_inputAiComposeToneSlug(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputAiComposeToneDefault(let _data):
                return _data.tlObject
            case .inputAiComposeToneID(let _data):
                return _data.tlObject
            case .inputAiComposeToneSingleUse(let _data):
                return _data.tlObject
            case .inputAiComposeToneSlug(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputAiComposeTone] {
            return tlObjectsAt(object, offset).map { Api.InputAiComposeTone(tlObject: $0) }
        }

    }
}
public extension Api.InputAiComposeTone.Cons_inputAiComposeToneDefault {
    @_alwaysEmitIntoClient var tone: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(tone: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(216))
        tlStoreReference(_tlObject, 24, tone as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputAiComposeTone.Cons_inputAiComposeToneID {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(52))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputAiComposeTone.Cons_inputAiComposeToneSingleUse {
    @_alwaysEmitIntoClient var customPrompt: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(customPrompt: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(90))
        tlStoreReference(_tlObject, 24, customPrompt as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputAiComposeTone.Cons_inputAiComposeToneSlug {
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(slug: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(213))
        tlStoreReference(_tlObject, 24, slug as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputAppEvent: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputAppEvent {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputAppEvent(Cons_inputAppEvent)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputAppEvent(Cons_inputAppEvent(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputAppEvent(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputAppEvent] {
            return tlObjectsAt(object, offset).map { Api.InputAppEvent(tlObject: $0) }
        }

    }
}
public extension Api.InputAppEvent.Cons_inputAppEvent {
    @_alwaysEmitIntoClient var time: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Double.self) } }
    }
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var peer: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var data: Api.JSONValue {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.JSONValue(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(time: Double, type: String, peer: Int64, data: Api.JSONValue) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(193))
        tlStore(_tlObject, 24, time)
        tlStoreReference(_tlObject, 32, type as NSString)
        tlStore(_tlObject, 40, peer)
        tlStoreReference(_tlObject, 48, data.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum InputBotApp: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBotAppID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotAppShortName {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBotAppID(Cons_inputBotAppID)
        case inputBotAppShortName(Cons_inputBotAppShortName)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBotAppID(Cons_inputBotAppID(tlObject: object))
            case 1:
                self = .inputBotAppShortName(Cons_inputBotAppShortName(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBotAppID(let _data):
                return _data.tlObject
            case .inputBotAppShortName(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBotApp] {
            return tlObjectsAt(object, offset).map { Api.InputBotApp(tlObject: $0) }
        }

    }
}
public extension Api.InputBotApp.Cons_inputBotAppID {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1094))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 32, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotApp.Cons_inputBotAppShortName {
    @_alwaysEmitIntoClient var botId: Api.InputUser {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputUser(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(botId: Api.InputUser, shortName: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(918))
        tlStoreReference(_tlObject, 24, botId.tlObject)
        tlStoreReference(_tlObject, 32, shortName as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBotInlineMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBotInlineMessageGame {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaAuto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaContact {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaGeo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaInvoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaVenue {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageMediaWebPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageRichMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageText {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBotInlineMessageGame(Cons_inputBotInlineMessageGame)
        case inputBotInlineMessageMediaAuto(Cons_inputBotInlineMessageMediaAuto)
        case inputBotInlineMessageMediaContact(Cons_inputBotInlineMessageMediaContact)
        case inputBotInlineMessageMediaGeo(Cons_inputBotInlineMessageMediaGeo)
        case inputBotInlineMessageMediaInvoice(Cons_inputBotInlineMessageMediaInvoice)
        case inputBotInlineMessageMediaVenue(Cons_inputBotInlineMessageMediaVenue)
        case inputBotInlineMessageMediaWebPage(Cons_inputBotInlineMessageMediaWebPage)
        case inputBotInlineMessageRichMessage(Cons_inputBotInlineMessageRichMessage)
        case inputBotInlineMessageText(Cons_inputBotInlineMessageText)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBotInlineMessageGame(Cons_inputBotInlineMessageGame(tlObject: object))
            case 1:
                self = .inputBotInlineMessageMediaAuto(Cons_inputBotInlineMessageMediaAuto(tlObject: object))
            case 2:
                self = .inputBotInlineMessageMediaContact(Cons_inputBotInlineMessageMediaContact(tlObject: object))
            case 3:
                self = .inputBotInlineMessageMediaGeo(Cons_inputBotInlineMessageMediaGeo(tlObject: object))
            case 4:
                self = .inputBotInlineMessageMediaInvoice(Cons_inputBotInlineMessageMediaInvoice(tlObject: object))
            case 5:
                self = .inputBotInlineMessageMediaVenue(Cons_inputBotInlineMessageMediaVenue(tlObject: object))
            case 6:
                self = .inputBotInlineMessageMediaWebPage(Cons_inputBotInlineMessageMediaWebPage(tlObject: object))
            case 7:
                self = .inputBotInlineMessageRichMessage(Cons_inputBotInlineMessageRichMessage(tlObject: object))
            case 8:
                self = .inputBotInlineMessageText(Cons_inputBotInlineMessageText(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBotInlineMessageGame(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaAuto(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaContact(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaGeo(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaInvoice(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaVenue(let _data):
                return _data.tlObject
            case .inputBotInlineMessageMediaWebPage(let _data):
                return _data.tlObject
            case .inputBotInlineMessageRichMessage(let _data):
                return _data.tlObject
            case .inputBotInlineMessageText(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBotInlineMessage] {
            return tlObjectsAt(object, offset).map { Api.InputBotInlineMessage(tlObject: $0) }
        }

    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageGame {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(486))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaAuto {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(326))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaContact {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1080))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, phoneNumber as NSString)
        tlStoreReference(_tlObject, 40, firstName as NSString)
        tlStoreReference(_tlObject, 48, lastName as NSString)
        tlStoreReference(_tlObject, 56, vcard as NSString)
        tlStoreReference(_tlObject, 64, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaGeo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 40)) } }
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
    init(flags: Int32, geoPoint: Api.InputGeoPoint, heading: Int32?, period: Int32?, proximityNotificationRadius: Int32?, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(959))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, geoPoint.tlObject)
        if let _tlValue = heading { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = period { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = proximityNotificationRadius { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaInvoice {
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
    @_alwaysEmitIntoClient var provider: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var providerData: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, title: String, description: String, photo: Api.InputWebDocument?, invoice: Api.Invoice, payload: Buffer, provider: String, providerData: Api.DataJSON, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1406))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title as NSString)
        tlStoreReference(_tlObject, 40, description as NSString)
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        tlStoreReference(_tlObject, 56, invoice.tlObject)
        tlStoreReference(_tlObject, 64, payload.makeData() as NSData)
        tlStoreReference(_tlObject, 72, provider as NSString)
        tlStoreReference(_tlObject, 80, providerData.tlObject)
        tlStoreReference(_tlObject, 88, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaVenue {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var geoPoint: Api.InputGeoPoint {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputGeoPoint(tlObject: tlObjectAt(self.tlObject, 32)) } }
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
    init(flags: Int32, geoPoint: Api.InputGeoPoint, title: String, address: String, provider: String, venueId: String, venueType: String, replyMarkup: Api.ReplyMarkup?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(425))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, geoPoint.tlObject)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, address as NSString)
        tlStoreReference(_tlObject, 56, provider as NSString)
        tlStoreReference(_tlObject, 64, venueId as NSString)
        tlStoreReference(_tlObject, 72, venueType as NSString)
        tlStoreReference(_tlObject, 80, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageMediaWebPage {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1248))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, url as NSString)
        tlStoreReference(_tlObject, 56, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageRichMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var replyMarkup: Api.ReplyMarkup? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.ReplyMarkup(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var richMessage: Api.InputRichMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputRichMessage(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, replyMarkup: Api.ReplyMarkup?, richMessage: Api.InputRichMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1168))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, replyMarkup?.tlObject)
        tlStoreReference(_tlObject, 40, richMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessage.Cons_inputBotInlineMessageText {
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(395))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, replyMarkup?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBotInlineMessageID: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBotInlineMessageID {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineMessageID64 {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBotInlineMessageID(Cons_inputBotInlineMessageID)
        case inputBotInlineMessageID64(Cons_inputBotInlineMessageID64)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBotInlineMessageID(Cons_inputBotInlineMessageID(tlObject: object))
            case 1:
                self = .inputBotInlineMessageID64(Cons_inputBotInlineMessageID64(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBotInlineMessageID(let _data):
                return _data.tlObject
            case .inputBotInlineMessageID64(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBotInlineMessageID] {
            return tlObjectsAt(object, offset).map { Api.InputBotInlineMessageID(tlObject: $0) }
        }

    }
}
public extension Api.InputBotInlineMessageID.Cons_inputBotInlineMessageID {
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(dcId: Int32, id: Int64, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(870))
        tlStore(_tlObject, 24, dcId)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineMessageID.Cons_inputBotInlineMessageID64 {
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var ownerId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(dcId: Int32, ownerId: Int64, id: Int32, accessHash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1194))
        tlStore(_tlObject, 24, dcId)
        tlStore(_tlObject, 32, ownerId)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 40, accessHash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBotInlineResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBotInlineResult {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineResultDocument {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineResultGame {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_inputBotInlineResultPhoto {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBotInlineResult(Cons_inputBotInlineResult)
        case inputBotInlineResultDocument(Cons_inputBotInlineResultDocument)
        case inputBotInlineResultGame(Cons_inputBotInlineResultGame)
        case inputBotInlineResultPhoto(Cons_inputBotInlineResultPhoto)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBotInlineResult(Cons_inputBotInlineResult(tlObject: object))
            case 1:
                self = .inputBotInlineResultDocument(Cons_inputBotInlineResultDocument(tlObject: object))
            case 2:
                self = .inputBotInlineResultGame(Cons_inputBotInlineResultGame(tlObject: object))
            case 3:
                self = .inputBotInlineResultPhoto(Cons_inputBotInlineResultPhoto(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBotInlineResult(let _data):
                return _data.tlObject
            case .inputBotInlineResultDocument(let _data):
                return _data.tlObject
            case .inputBotInlineResultGame(let _data):
                return _data.tlObject
            case .inputBotInlineResultPhoto(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBotInlineResult] {
            return tlObjectsAt(object, offset).map { Api.InputBotInlineResult(tlObject: $0) }
        }

    }
}
public extension Api.InputBotInlineResult.Cons_inputBotInlineResult {
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
    @_alwaysEmitIntoClient var thumb: Api.InputWebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.InputWebDocument(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var content: Api.InputWebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.InputWebDocument(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.InputBotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBotInlineMessage(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    init(flags: Int32, id: String, type: String, title: String?, description: String?, url: String?, thumb: Api.InputWebDocument?, content: Api.InputWebDocument?, sendMessage: Api.InputBotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(866))
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
public extension Api.InputBotInlineResult.Cons_inputBotInlineResultDocument {
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
    @_alwaysEmitIntoClient var document: Api.InputDocument {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputDocument(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.InputBotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBotInlineMessage(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    init(flags: Int32, id: String, type: String, title: String?, description: String?, document: Api.InputDocument, sendMessage: Api.InputBotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1698))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, type as NSString)
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, document.tlObject)
        tlStoreReference(_tlObject, 72, sendMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineResult.Cons_inputBotInlineResultGame {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var shortName: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.InputBotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBotInlineMessage(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(id: String, shortName: String, sendMessage: Api.InputBotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(515))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, shortName as NSString)
        tlStoreReference(_tlObject, 40, sendMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.InputBotInlineResult.Cons_inputBotInlineResultPhoto {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var type: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var photo: Api.InputPhoto {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputPhoto(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var sendMessage: Api.InputBotInlineMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBotInlineMessage(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(id: String, type: String, photo: Api.InputPhoto, sendMessage: Api.InputBotInlineMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1092))
        tlStoreReference(_tlObject, 24, id as NSString)
        tlStoreReference(_tlObject, 32, type as NSString)
        tlStoreReference(_tlObject, 40, photo.tlObject)
        tlStoreReference(_tlObject, 48, sendMessage.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBusinessAwayMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessAwayMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessAwayMessage(Cons_inputBusinessAwayMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessAwayMessage(Cons_inputBusinessAwayMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessAwayMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessAwayMessage] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessAwayMessage(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessAwayMessage.Cons_inputBusinessAwayMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var schedule: Api.BusinessAwayMessageSchedule {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BusinessAwayMessageSchedule(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var recipients: Api.InputBusinessRecipients {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InputBusinessRecipients(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, shortcutId: Int32, schedule: Api.BusinessAwayMessageSchedule, recipients: Api.InputBusinessRecipients) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(833))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, shortcutId)
        tlStoreReference(_tlObject, 32, schedule.tlObject)
        tlStoreReference(_tlObject, 40, recipients.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum InputBusinessBotRecipients: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inputBusinessBotRecipients {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inputBusinessBotRecipients(Cons_inputBusinessBotRecipients)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputBusinessBotRecipients(Cons_inputBusinessBotRecipients(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputBusinessBotRecipients(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.InputBusinessBotRecipients] {
            return tlObjectsAt(object, offset).map { Api.InputBusinessBotRecipients(tlObject: $0) }
        }

    }
}
public extension Api.InputBusinessBotRecipients.Cons_inputBusinessBotRecipients {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.InputUser]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.InputUser.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var excludeUsers: [Api.InputUser]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.InputUser.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, users: [Api.InputUser]?, excludeUsers: [Api.InputUser]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1306))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, users.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 40, excludeUsers.map { value in value.map { item in item.tlObject } as NSArray })
        self.init(tlObject: _tlObject)
    }
}
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(108))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message as NSString)
        tlStoreReference(_tlObject, 40, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 48, title.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
