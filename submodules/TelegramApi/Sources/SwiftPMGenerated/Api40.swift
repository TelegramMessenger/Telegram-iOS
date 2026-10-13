import TelegramApiObjC
public extension Api.messages {
    enum Stickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickers(Cons_stickers)
        case stickersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickers(Cons_stickers(tlObject: object))
            case 1:
                self = .stickersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickers(let _data):
                return _data.tlObject
            case .stickersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1602))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.Stickers] {
            return tlObjectsAt(object, offset).map { Api.messages.Stickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.Stickers.Cons_stickers {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, stickers: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(307))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, stickers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum TranscribedAudio: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_transcribedAudio {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case transcribedAudio(Cons_transcribedAudio)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .transcribedAudio(Cons_transcribedAudio(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .transcribedAudio(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.TranscribedAudio] {
            return tlObjectsAt(object, offset).map { Api.messages.TranscribedAudio(tlObject: $0) }
        }

    }
}
public extension Api.messages.TranscribedAudio.Cons_transcribedAudio {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var transcriptionId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var trialRemainsNum: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var trialRemainsUntilDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, transcriptionId: Int64, text: String, trialRemainsNum: Int32?, trialRemainsUntilDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1374))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, transcriptionId)
        tlStoreReference(_tlObject, 48, text as NSString)
        if let _tlValue = trialRemainsNum { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = trialRemainsUntilDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum TranslatedRichMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_translatedRichMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case translatedRichMessage(Cons_translatedRichMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .translatedRichMessage(Cons_translatedRichMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .translatedRichMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.TranslatedRichMessage] {
            return tlObjectsAt(object, offset).map { Api.messages.TranslatedRichMessage(tlObject: $0) }
        }

    }
}
public extension Api.messages.TranslatedRichMessage.Cons_translatedRichMessage {
    @_alwaysEmitIntoClient var result: [Api.RichMessage] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichMessage.tlArray(self.tlObject, 24) } }
    }
    init(result: [Api.RichMessage]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(430))
        tlStoreReference(_tlObject, 24, result.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum TranslatedText: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_translateResult {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case translateResult(Cons_translateResult)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .translateResult(Cons_translateResult(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .translateResult(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.TranslatedText] {
            return tlObjectsAt(object, offset).map { Api.messages.TranslatedText(tlObject: $0) }
        }

    }
}
public extension Api.messages.TranslatedText.Cons_translateResult {
    @_alwaysEmitIntoClient var result: [Api.TextWithEntities] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities.tlArray(self.tlObject, 24) } }
    }
    init(result: [Api.TextWithEntities]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(328))
        tlStoreReference(_tlObject, 24, result.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum VotesList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_votesList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case votesList(Cons_votesList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .votesList(Cons_votesList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .votesList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.VotesList] {
            return tlObjectsAt(object, offset).map { Api.messages.VotesList(tlObject: $0) }
        }

    }
}
public extension Api.messages.VotesList.Cons_votesList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var votes: [Api.MessagePeerVote] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessagePeerVote.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    init(flags: Int32, count: Int32, votes: [Api.MessagePeerVote], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(464))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, votes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum WebPage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webPage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webPage(Cons_webPage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webPage(Cons_webPage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webPage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.WebPage] {
            return tlObjectsAt(object, offset).map { Api.messages.WebPage(tlObject: $0) }
        }

    }
}
public extension Api.messages.WebPage.Cons_webPage {
    @_alwaysEmitIntoClient var webpage: Api.WebPage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WebPage(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(webpage: Api.WebPage, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1690))
        tlStoreReference(_tlObject, 24, webpage.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    indirect enum WebPagePreview: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webPagePreview {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webPagePreview(Cons_webPagePreview)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webPagePreview(Cons_webPagePreview(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webPagePreview(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.WebPagePreview] {
            return tlObjectsAt(object, offset).map { Api.messages.WebPagePreview(tlObject: $0) }
        }

    }
}
public extension Api.messages.WebPagePreview.Cons_webPagePreview {
    @_alwaysEmitIntoClient var media: Api.MessageMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(media: Api.MessageMedia, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(903))
        tlStoreReference(_tlObject, 24, media.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum BankCardData: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_bankCardData {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case bankCardData(Cons_bankCardData)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .bankCardData(Cons_bankCardData(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .bankCardData(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.BankCardData] {
            return tlObjectsAt(object, offset).map { Api.payments.BankCardData(tlObject: $0) }
        }

    }
}
public extension Api.payments.BankCardData.Cons_bankCardData {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var openUrls: [Api.BankCardOpenUrl] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BankCardOpenUrl.tlArray(self.tlObject, 32) } }
    }
    init(title: String, openUrls: [Api.BankCardOpenUrl]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(401))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStoreReference(_tlObject, 32, openUrls.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum CheckCanSendGiftResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_checkCanSendGiftResultFail {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case checkCanSendGiftResultFail(Cons_checkCanSendGiftResultFail)
        case checkCanSendGiftResultOk


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .checkCanSendGiftResultFail(Cons_checkCanSendGiftResultFail(tlObject: object))
            case 1:
                self = .checkCanSendGiftResultOk
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .checkCanSendGiftResultFail(let _data):
                return _data.tlObject
            case .checkCanSendGiftResultOk:
                return TLObjectSingleton(TLApiConstructorAt(356))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.CheckCanSendGiftResult] {
            return tlObjectsAt(object, offset).map { Api.payments.CheckCanSendGiftResult(tlObject: $0) }
        }

    }
}
public extension Api.payments.CheckCanSendGiftResult.Cons_checkCanSendGiftResultFail {
    @_alwaysEmitIntoClient var reason: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(reason: Api.TextWithEntities) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1403))
        tlStoreReference(_tlObject, 24, reason.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum CheckedGiftCode: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_checkedGiftCode {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case checkedGiftCode(Cons_checkedGiftCode)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .checkedGiftCode(Cons_checkedGiftCode(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .checkedGiftCode(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.CheckedGiftCode] {
            return tlObjectsAt(object, offset).map { Api.payments.CheckedGiftCode(tlObject: $0) }
        }

    }
}
public extension Api.payments.CheckedGiftCode.Cons_checkedGiftCode {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var giveawayMsgId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var toId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var days: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var usedDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 2) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 72) } }
    }
    init(flags: Int32, fromId: Api.Peer?, giveawayMsgId: Int32?, toId: Int64?, date: Int32, days: Int32, usedDate: Int32?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1555))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, fromId?.tlObject)
        if let _tlValue = giveawayMsgId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = toId { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, days)
        if let _tlValue = usedDate { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 64, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum ConnectedStarRefBots: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_connectedStarRefBots {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case connectedStarRefBots(Cons_connectedStarRefBots)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .connectedStarRefBots(Cons_connectedStarRefBots(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .connectedStarRefBots(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.ConnectedStarRefBots] {
            return tlObjectsAt(object, offset).map { Api.payments.ConnectedStarRefBots(tlObject: $0) }
        }

    }
}
public extension Api.payments.ConnectedStarRefBots.Cons_connectedStarRefBots {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var connectedBots: [Api.ConnectedBotStarRef] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ConnectedBotStarRef.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(count: Int32, connectedBots: [Api.ConnectedBotStarRef], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(981))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, connectedBots.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum CurrencyRates: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_currencyRates {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case currencyRates(Cons_currencyRates)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .currencyRates(Cons_currencyRates(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .currencyRates(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.CurrencyRates] {
            return tlObjectsAt(object, offset).map { Api.payments.CurrencyRates(tlObject: $0) }
        }

    }
}
public extension Api.payments.CurrencyRates.Cons_currencyRates {
    @_alwaysEmitIntoClient var rates: [Api.CurrencyRate] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.CurrencyRate.tlArray(self.tlObject, 24) } }
    }
    init(rates: [Api.CurrencyRate]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1238))
        tlStoreReference(_tlObject, 24, rates.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum ExportedInvoice: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedInvoice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedInvoice(Cons_exportedInvoice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedInvoice(Cons_exportedInvoice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedInvoice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.ExportedInvoice] {
            return tlObjectsAt(object, offset).map { Api.payments.ExportedInvoice(tlObject: $0) }
        }

    }
}
public extension Api.payments.ExportedInvoice.Cons_exportedInvoice {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1138))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum GiveawayInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_giveawayInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_giveawayInfoResults {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case giveawayInfo(Cons_giveawayInfo)
        case giveawayInfoResults(Cons_giveawayInfoResults)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .giveawayInfo(Cons_giveawayInfo(tlObject: object))
            case 1:
                self = .giveawayInfoResults(Cons_giveawayInfoResults(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .giveawayInfo(let _data):
                return _data.tlObject
            case .giveawayInfoResults(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.GiveawayInfo] {
            return tlObjectsAt(object, offset).map { Api.payments.GiveawayInfo(tlObject: $0) }
        }

    }
}
public extension Api.payments.GiveawayInfo.Cons_giveawayInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var joinedTooEarlyDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var adminDisallowedChatId: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var disallowedCountry: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    init(flags: Int32, startDate: Int32, joinedTooEarlyDate: Int32?, adminDisallowedChatId: Int64?, disallowedCountry: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(440))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, startDate)
        if let _tlValue = joinedTooEarlyDate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = adminDisallowedChatId { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, disallowedCountry.map { value in value as NSString })
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments.GiveawayInfo.Cons_giveawayInfoResults {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var startDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var giftCodeSlug: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var starsPrize: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var finishDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var winnersCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var activatedCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    init(flags: Int32, startDate: Int32, giftCodeSlug: String?, starsPrize: Int64?, finishDate: Int32, winnersCount: Int32, activatedCount: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1483))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, startDate)
        tlStoreReference(_tlObject, 48, giftCodeSlug.map { value in value as NSString })
        if let _tlValue = starsPrize { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, finishDate)
        tlStore(_tlObject, 36, winnersCount)
        if let _tlValue = activatedCount { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 1 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum PaymentForm: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentForm {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_paymentFormStarGift {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_paymentFormStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentForm(Cons_paymentForm)
        case paymentFormStarGift(Cons_paymentFormStarGift)
        case paymentFormStars(Cons_paymentFormStars)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentForm(Cons_paymentForm(tlObject: object))
            case 1:
                self = .paymentFormStarGift(Cons_paymentFormStarGift(tlObject: object))
            case 2:
                self = .paymentFormStars(Cons_paymentFormStars(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentForm(let _data):
                return _data.tlObject
            case .paymentFormStarGift(let _data):
                return _data.tlObject
            case .paymentFormStars(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.PaymentForm] {
            return tlObjectsAt(object, offset).map { Api.payments.PaymentForm(tlObject: $0) }
        }

    }
}
public extension Api.payments.PaymentForm.Cons_paymentForm {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var formId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var providerId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var nativeProvider: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : tlStringAt(self.tlObject, 96) } }
    }
    @_alwaysEmitIntoClient var nativeParams: Api.DataJSON? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var additionalMethods: [Api.PaymentFormMethod]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.PaymentFormMethod.tlArray(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var savedInfo: Api.PaymentRequestedInfo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.PaymentRequestedInfo(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    @_alwaysEmitIntoClient var savedCredentials: [Api.PaymentSavedCredentials]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 128) ? nil : Api.PaymentSavedCredentials.tlArray(self.tlObject, 128) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 136) } }
    }
    init(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, providerId: Int64, url: String, nativeProvider: String?, nativeParams: Api.DataJSON?, additionalMethods: [Api.PaymentFormMethod]?, savedInfo: Api.PaymentRequestedInfo?, savedCredentials: [Api.PaymentSavedCredentials]?, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1044))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, formId)
        tlStore(_tlObject, 40, botId)
        tlStoreReference(_tlObject, 48, title as NSString)
        tlStoreReference(_tlObject, 56, description as NSString)
        tlStoreReference(_tlObject, 64, photo?.tlObject)
        tlStoreReference(_tlObject, 72, invoice.tlObject)
        tlStore(_tlObject, 80, providerId)
        tlStoreReference(_tlObject, 88, url as NSString)
        tlStoreReference(_tlObject, 96, nativeProvider.map { value in value as NSString })
        tlStoreReference(_tlObject, 104, nativeParams?.tlObject)
        tlStoreReference(_tlObject, 112, additionalMethods.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 120, savedInfo?.tlObject)
        tlStoreReference(_tlObject, 128, savedCredentials.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 136, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments.PaymentForm.Cons_paymentFormStarGift {
    @_alwaysEmitIntoClient var formId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(formId: Int64, invoice: Api.Invoice) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1174))
        tlStore(_tlObject, 24, formId)
        tlStoreReference(_tlObject, 32, invoice.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments.PaymentForm.Cons_paymentFormStars {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var formId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 80) } }
    }
    init(flags: Int32, formId: Int64, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(797))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, formId)
        tlStore(_tlObject, 40, botId)
        tlStoreReference(_tlObject, 48, title as NSString)
        tlStoreReference(_tlObject, 56, description as NSString)
        tlStoreReference(_tlObject, 64, photo?.tlObject)
        tlStoreReference(_tlObject, 72, invoice.tlObject)
        tlStoreReference(_tlObject, 80, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum PaymentReceipt: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentReceipt {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_paymentReceiptStars {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentReceipt(Cons_paymentReceipt)
        case paymentReceiptStars(Cons_paymentReceiptStars)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentReceipt(Cons_paymentReceipt(tlObject: object))
            case 1:
                self = .paymentReceiptStars(Cons_paymentReceiptStars(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentReceipt(let _data):
                return _data.tlObject
            case .paymentReceiptStars(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.PaymentReceipt] {
            return tlObjectsAt(object, offset).map { Api.payments.PaymentReceipt(tlObject: $0) }
        }

    }
}
public extension Api.payments.PaymentReceipt.Cons_paymentReceipt {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var providerId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var info: Api.PaymentRequestedInfo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.PaymentRequestedInfo(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var shipping: Api.ShippingOption? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.ShippingOption(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var tipAmount: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 136, 0) ? tlBase(self.tlObject).load(fromByteOffset: 96, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 104) } }
    }
    @_alwaysEmitIntoClient var totalAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 112, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var credentialsTitle: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 120) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 128) } }
    }
    init(flags: Int32, date: Int32, botId: Int64, providerId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, info: Api.PaymentRequestedInfo?, shipping: Api.ShippingOption?, tipAmount: Int64?, currency: String, totalAmount: Int64, credentialsTitle: String, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(719))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 32, botId)
        tlStore(_tlObject, 40, providerId)
        tlStoreReference(_tlObject, 48, title as NSString)
        tlStoreReference(_tlObject, 56, description as NSString)
        tlStoreReference(_tlObject, 64, photo?.tlObject)
        tlStoreReference(_tlObject, 72, invoice.tlObject)
        tlStoreReference(_tlObject, 80, info?.tlObject)
        tlStoreReference(_tlObject, 88, shipping?.tlObject)
        if let _tlValue = tipAmount { tlStore(_tlObject, 96, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 104, currency as NSString)
        tlStore(_tlObject, 112, totalAmount)
        tlStoreReference(_tlObject, 120, credentialsTitle as NSString)
        tlStoreReference(_tlObject, 128, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 136, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments.PaymentReceipt.Cons_paymentReceiptStars {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var description: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var photo: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var invoice: Api.Invoice {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Invoice(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var currency: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var totalAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 80, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var transactionId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 96) } }
    }
    init(flags: Int32, date: Int32, botId: Int64, title: String, description: String, photo: Api.WebDocument?, invoice: Api.Invoice, currency: String, totalAmount: Int64, transactionId: String, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1430))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, date)
        tlStore(_tlObject, 32, botId)
        tlStoreReference(_tlObject, 40, title as NSString)
        tlStoreReference(_tlObject, 48, description as NSString)
        tlStoreReference(_tlObject, 56, photo?.tlObject)
        tlStoreReference(_tlObject, 64, invoice.tlObject)
        tlStoreReference(_tlObject, 72, currency as NSString)
        tlStore(_tlObject, 80, totalAmount)
        tlStoreReference(_tlObject, 88, transactionId as NSString)
        tlStoreReference(_tlObject, 96, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    indirect enum PaymentResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_paymentResult {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_paymentVerificationNeeded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case paymentResult(Cons_paymentResult)
        case paymentVerificationNeeded(Cons_paymentVerificationNeeded)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .paymentResult(Cons_paymentResult(tlObject: object))
            case 1:
                self = .paymentVerificationNeeded(Cons_paymentVerificationNeeded(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .paymentResult(let _data):
                return _data.tlObject
            case .paymentVerificationNeeded(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.PaymentResult] {
            return tlObjectsAt(object, offset).map { Api.payments.PaymentResult(tlObject: $0) }
        }

    }
}
public extension Api.payments.PaymentResult.Cons_paymentResult {
    @_alwaysEmitIntoClient var updates: Api.Updates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Updates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(updates: Api.Updates) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(506))
        tlStoreReference(_tlObject, 24, updates.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments.PaymentResult.Cons_paymentVerificationNeeded {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1421))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum ResaleStarGifts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_resaleStarGifts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case resaleStarGifts(Cons_resaleStarGifts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .resaleStarGifts(Cons_resaleStarGifts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .resaleStarGifts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.ResaleStarGifts] {
            return tlObjectsAt(object, offset).map { Api.payments.ResaleStarGifts(tlObject: $0) }
        }

    }
}
public extension Api.payments.ResaleStarGifts.Cons_resaleStarGifts {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var gifts: [Api.StarGift] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.StarGiftAttribute]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.StarGiftAttribute.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var attributesHash: Int64? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 56, as: Int64.self) : nil } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var counters: [Api.StarGiftAttributeCounter]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.StarGiftAttributeCounter.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 80) } }
    }
    init(flags: Int32, count: Int32, gifts: [Api.StarGift], nextOffset: String?, attributes: [Api.StarGiftAttribute]?, attributesHash: Int64?, chats: [Api.Chat], counters: [Api.StarGiftAttributeCounter]?, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(945))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, gifts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, attributes.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = attributesHash { tlStore(_tlObject, 56, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 64, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, counters.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum SavedInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedInfo(Cons_savedInfo)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedInfo(Cons_savedInfo(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedInfo(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.SavedInfo] {
            return tlObjectsAt(object, offset).map { Api.payments.SavedInfo(tlObject: $0) }
        }

    }
}
public extension Api.payments.SavedInfo.Cons_savedInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var savedInfo: Api.PaymentRequestedInfo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.PaymentRequestedInfo(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, savedInfo: Api.PaymentRequestedInfo?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1675))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, savedInfo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum SavedStarGifts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedStarGifts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedStarGifts(Cons_savedStarGifts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedStarGifts(Cons_savedStarGifts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedStarGifts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.SavedStarGifts] {
            return tlObjectsAt(object, offset).map { Api.payments.SavedStarGifts(tlObject: $0) }
        }

    }
}
public extension Api.payments.SavedStarGifts.Cons_savedStarGifts {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chatNotificationsEnabled: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var gifts: [Api.SavedStarGift] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SavedStarGift.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, count: Int32, chatNotificationsEnabled: Api.Bool?, gifts: [Api.SavedStarGift], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(957))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, chatNotificationsEnabled?.tlObject)
        tlStoreReference(_tlObject, 40, gifts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftActiveAuctions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftActiveAuctions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftActiveAuctions(Cons_starGiftActiveAuctions)
        case starGiftActiveAuctionsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftActiveAuctions(Cons_starGiftActiveAuctions(tlObject: object))
            case 1:
                self = .starGiftActiveAuctionsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftActiveAuctions(let _data):
                return _data.tlObject
            case .starGiftActiveAuctionsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1435))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftActiveAuctions] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftActiveAuctions(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftActiveAuctions.Cons_starGiftActiveAuctions {
    @_alwaysEmitIntoClient var auctions: [Api.StarGiftActiveAuctionState] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftActiveAuctionState.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    init(auctions: [Api.StarGiftActiveAuctionState], users: [Api.User], chats: [Api.Chat]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1141))
        tlStoreReference(_tlObject, 24, auctions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftAuctionAcquiredGifts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionAcquiredGifts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionAcquiredGifts(Cons_starGiftAuctionAcquiredGifts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionAcquiredGifts(Cons_starGiftAuctionAcquiredGifts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionAcquiredGifts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftAuctionAcquiredGifts] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftAuctionAcquiredGifts(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftAuctionAcquiredGifts.Cons_starGiftAuctionAcquiredGifts {
    @_alwaysEmitIntoClient var gifts: [Api.StarGiftAuctionAcquiredGift] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionAcquiredGift.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    init(gifts: [Api.StarGiftAuctionAcquiredGift], users: [Api.User], chats: [Api.Chat]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(804))
        tlStoreReference(_tlObject, 24, gifts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftAuctionState: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftAuctionState {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftAuctionState(Cons_starGiftAuctionState)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftAuctionState(Cons_starGiftAuctionState(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftAuctionState(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftAuctionState] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftAuctionState(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftAuctionState.Cons_starGiftAuctionState {
    @_alwaysEmitIntoClient var gift: Api.StarGift {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var state: Api.StarGiftAuctionState {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionState(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var userState: Api.StarGiftAuctionUserState {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAuctionUserState(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var timeout: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 64) } }
    }
    init(gift: Api.StarGift, state: Api.StarGiftAuctionState, userState: Api.StarGiftAuctionUserState, timeout: Int32, users: [Api.User], chats: [Api.Chat]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(684))
        tlStoreReference(_tlObject, 32, gift.tlObject)
        tlStoreReference(_tlObject, 40, state.tlObject)
        tlStoreReference(_tlObject, 48, userState.tlObject)
        tlStore(_tlObject, 24, timeout)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, chats.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftCollections: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftCollections {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftCollections(Cons_starGiftCollections)
        case starGiftCollectionsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftCollections(Cons_starGiftCollections(tlObject: object))
            case 1:
                self = .starGiftCollectionsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftCollections(let _data):
                return _data.tlObject
            case .starGiftCollectionsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1051))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftCollections] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftCollections(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftCollections.Cons_starGiftCollections {
    @_alwaysEmitIntoClient var collections: [Api.StarGiftCollection] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftCollection.tlArray(self.tlObject, 24) } }
    }
    init(collections: [Api.StarGiftCollection]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(883))
        tlStoreReference(_tlObject, 24, collections.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftUpgradeAttributes: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftUpgradeAttributes {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftUpgradeAttributes(Cons_starGiftUpgradeAttributes)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftUpgradeAttributes(Cons_starGiftUpgradeAttributes(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftUpgradeAttributes(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftUpgradeAttributes] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftUpgradeAttributes(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftUpgradeAttributes.Cons_starGiftUpgradeAttributes {
    @_alwaysEmitIntoClient var attributes: [Api.StarGiftAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttribute.tlArray(self.tlObject, 24) } }
    }
    init(attributes: [Api.StarGiftAttribute]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(454))
        tlStoreReference(_tlObject, 24, attributes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftUpgradePreview: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftUpgradePreview {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftUpgradePreview(Cons_starGiftUpgradePreview)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftUpgradePreview(Cons_starGiftUpgradePreview(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftUpgradePreview(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftUpgradePreview] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftUpgradePreview(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftUpgradePreview.Cons_starGiftUpgradePreview {
    @_alwaysEmitIntoClient var sampleAttributes: [Api.StarGiftAttribute] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftAttribute.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var prices: [Api.StarGiftUpgradePrice] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftUpgradePrice.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextPrices: [Api.StarGiftUpgradePrice] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGiftUpgradePrice.tlArray(self.tlObject, 40) } }
    }
    init(sampleAttributes: [Api.StarGiftAttribute], prices: [Api.StarGiftUpgradePrice], nextPrices: [Api.StarGiftUpgradePrice]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(396))
        tlStoreReference(_tlObject, 24, sampleAttributes.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, prices.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextPrices.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGiftWithdrawalUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGiftWithdrawalUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGiftWithdrawalUrl(Cons_starGiftWithdrawalUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGiftWithdrawalUrl(Cons_starGiftWithdrawalUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGiftWithdrawalUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGiftWithdrawalUrl] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGiftWithdrawalUrl(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGiftWithdrawalUrl.Cons_starGiftWithdrawalUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(849))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarGifts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starGifts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starGifts(Cons_starGifts)
        case starGiftsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starGifts(Cons_starGifts(tlObject: object))
            case 1:
                self = .starGiftsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starGifts(let _data):
                return _data.tlObject
            case .starGiftsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1066))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarGifts] {
            return tlObjectsAt(object, offset).map { Api.payments.StarGifts(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarGifts.Cons_starGifts {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var gifts: [Api.StarGift] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarGift.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(hash: Int32, gifts: [Api.StarGift], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(294))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, gifts.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarsRevenueAdsAccountUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsRevenueAdsAccountUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsRevenueAdsAccountUrl(Cons_starsRevenueAdsAccountUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsRevenueAdsAccountUrl(Cons_starsRevenueAdsAccountUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsRevenueAdsAccountUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarsRevenueAdsAccountUrl] {
            return tlObjectsAt(object, offset).map { Api.payments.StarsRevenueAdsAccountUrl(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarsRevenueAdsAccountUrl.Cons_starsRevenueAdsAccountUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(366))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarsRevenueStats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsRevenueStats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsRevenueStats(Cons_starsRevenueStats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsRevenueStats(Cons_starsRevenueStats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsRevenueStats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarsRevenueStats] {
            return tlObjectsAt(object, offset).map { Api.payments.StarsRevenueStats(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarsRevenueStats.Cons_starsRevenueStats {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var topHoursGraph: Api.StatsGraph? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var revenueGraph: Api.StatsGraph {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StatsGraph(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var status: Api.StarsRevenueStatus {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StarsRevenueStatus(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var usdRate: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 56, as: Double.self) } }
    }
    init(flags: Int32, topHoursGraph: Api.StatsGraph?, revenueGraph: Api.StatsGraph, status: Api.StarsRevenueStatus, usdRate: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(687))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, topHoursGraph?.tlObject)
        tlStoreReference(_tlObject, 40, revenueGraph.tlObject)
        tlStoreReference(_tlObject, 48, status.tlObject)
        tlStore(_tlObject, 56, usdRate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.payments {
    enum StarsRevenueWithdrawalUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_starsRevenueWithdrawalUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case starsRevenueWithdrawalUrl(Cons_starsRevenueWithdrawalUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .starsRevenueWithdrawalUrl(Cons_starsRevenueWithdrawalUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .starsRevenueWithdrawalUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.payments.StarsRevenueWithdrawalUrl] {
            return tlObjectsAt(object, offset).map { Api.payments.StarsRevenueWithdrawalUrl(tlObject: $0) }
        }

    }
}
public extension Api.payments.StarsRevenueWithdrawalUrl.Cons_starsRevenueWithdrawalUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(198))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
