import TelegramApiObjC
public extension Api {
    enum RecentStory: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_recentStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case recentStory(Cons_recentStory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .recentStory(Cons_recentStory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .recentStory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RecentStory] {
            return tlObjectsAt(object, offset).map { Api.RecentStory(tlObject: $0) }
        }

    }
}
public extension Api.RecentStory.Cons_recentStory {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var maxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 32, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, maxId: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(720))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = maxId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReplyMarkup: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_replyInlineMarkup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_replyKeyboardForceReply {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_replyKeyboardHide {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_replyKeyboardMarkup {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case replyInlineMarkup(Cons_replyInlineMarkup)
        case replyKeyboardForceReply(Cons_replyKeyboardForceReply)
        case replyKeyboardHide(Cons_replyKeyboardHide)
        case replyKeyboardMarkup(Cons_replyKeyboardMarkup)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .replyInlineMarkup(Cons_replyInlineMarkup(tlObject: object))
            case 1:
                self = .replyKeyboardForceReply(Cons_replyKeyboardForceReply(tlObject: object))
            case 2:
                self = .replyKeyboardHide(Cons_replyKeyboardHide(tlObject: object))
            case 3:
                self = .replyKeyboardMarkup(Cons_replyKeyboardMarkup(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .replyInlineMarkup(let _data):
                return _data.tlObject
            case .replyKeyboardForceReply(let _data):
                return _data.tlObject
            case .replyKeyboardHide(let _data):
                return _data.tlObject
            case .replyKeyboardMarkup(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReplyMarkup] {
            return tlObjectsAt(object, offset).map { Api.ReplyMarkup(tlObject: $0) }
        }

    }
}
public extension Api.ReplyMarkup.Cons_replyInlineMarkup {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rows: [Api.KeyboardInlineButtonRow] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.KeyboardInlineButtonRow.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, rows: [Api.KeyboardInlineButtonRow]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1163))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, rows.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ReplyMarkup.Cons_replyKeyboardForceReply {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var placeholder: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, placeholder: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(862))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, placeholder.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ReplyMarkup.Cons_replyKeyboardHide {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1047))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ReplyMarkup.Cons_replyKeyboardMarkup {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var rows: [Api.KeyboardButtonRow] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.KeyboardButtonRow.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var placeholder: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, rows: [Api.KeyboardButtonRow], placeholder: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(853))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, rows.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, placeholder.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReportReason: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case inputReportReasonChildAbuse
        case inputReportReasonCopyright
        case inputReportReasonFake
        case inputReportReasonGeoIrrelevant
        case inputReportReasonIllegalDrugs
        case inputReportReasonOther
        case inputReportReasonPersonalDetails
        case inputReportReasonPornography
        case inputReportReasonSpam
        case inputReportReasonViolence


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inputReportReasonChildAbuse
            case 1:
                self = .inputReportReasonCopyright
            case 2:
                self = .inputReportReasonFake
            case 3:
                self = .inputReportReasonGeoIrrelevant
            case 4:
                self = .inputReportReasonIllegalDrugs
            case 5:
                self = .inputReportReasonOther
            case 6:
                self = .inputReportReasonPersonalDetails
            case 7:
                self = .inputReportReasonPornography
            case 8:
                self = .inputReportReasonSpam
            case 9:
                self = .inputReportReasonViolence
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inputReportReasonChildAbuse:
                return TLObjectSingleton(TLApiConstructorAt(1132))
            case .inputReportReasonCopyright:
                return TLObjectSingleton(TLApiConstructorAt(1005))
            case .inputReportReasonFake:
                return TLObjectSingleton(TLApiConstructorAt(1633))
            case .inputReportReasonGeoIrrelevant:
                return TLObjectSingleton(TLApiConstructorAt(1443))
            case .inputReportReasonIllegalDrugs:
                return TLObjectSingleton(TLApiConstructorAt(70))
            case .inputReportReasonOther:
                return TLObjectSingleton(TLApiConstructorAt(1289))
            case .inputReportReasonPersonalDetails:
                return TLObjectSingleton(TLApiConstructorAt(1029))
            case .inputReportReasonPornography:
                return TLObjectSingleton(TLApiConstructorAt(288))
            case .inputReportReasonSpam:
                return TLObjectSingleton(TLApiConstructorAt(578))
            case .inputReportReasonViolence:
                return TLObjectSingleton(TLApiConstructorAt(202))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReportReason] {
            return tlObjectsAt(object, offset).map { Api.ReportReason(tlObject: $0) }
        }

    }
}
public extension Api {
    enum ReportResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_reportResultAddComment {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_reportResultChooseOption {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case reportResultAddComment(Cons_reportResultAddComment)
        case reportResultChooseOption(Cons_reportResultChooseOption)
        case reportResultReported


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reportResultAddComment(Cons_reportResultAddComment(tlObject: object))
            case 1:
                self = .reportResultChooseOption(Cons_reportResultChooseOption(tlObject: object))
            case 2:
                self = .reportResultReported
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reportResultAddComment(let _data):
                return _data.tlObject
            case .reportResultChooseOption(let _data):
                return _data.tlObject
            case .reportResultReported:
                return TLObjectSingleton(TLApiConstructorAt(907))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReportResult] {
            return tlObjectsAt(object, offset).map { Api.ReportResult(tlObject: $0) }
        }

    }
}
public extension Api.ReportResult.Cons_reportResultAddComment {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var option: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(flags: Int32, option: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(705))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, option.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.ReportResult.Cons_reportResultChooseOption {
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var options: [Api.MessageReportOption] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageReportOption.tlArray(self.tlObject, 32) } }
    }
    init(title: String, options: [Api.MessageReportOption]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1594))
        tlStoreReference(_tlObject, 24, title as NSString)
        tlStoreReference(_tlObject, 32, options.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RequestPeerType: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_requestPeerTypeBroadcast {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_requestPeerTypeChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_requestPeerTypeCreateBot {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_requestPeerTypeUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case requestPeerTypeBroadcast(Cons_requestPeerTypeBroadcast)
        case requestPeerTypeChat(Cons_requestPeerTypeChat)
        case requestPeerTypeCreateBot(Cons_requestPeerTypeCreateBot)
        case requestPeerTypeUser(Cons_requestPeerTypeUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .requestPeerTypeBroadcast(Cons_requestPeerTypeBroadcast(tlObject: object))
            case 1:
                self = .requestPeerTypeChat(Cons_requestPeerTypeChat(tlObject: object))
            case 2:
                self = .requestPeerTypeCreateBot(Cons_requestPeerTypeCreateBot(tlObject: object))
            case 3:
                self = .requestPeerTypeUser(Cons_requestPeerTypeUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .requestPeerTypeBroadcast(let _data):
                return _data.tlObject
            case .requestPeerTypeChat(let _data):
                return _data.tlObject
            case .requestPeerTypeCreateBot(let _data):
                return _data.tlObject
            case .requestPeerTypeUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RequestPeerType] {
            return tlObjectsAt(object, offset).map { Api.RequestPeerType(tlObject: $0) }
        }

    }
}
public extension Api.RequestPeerType.Cons_requestPeerTypeBroadcast {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hasUsername: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var userAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var botAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, hasUsername: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(327))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, hasUsername?.tlObject)
        tlStoreReference(_tlObject, 40, userAdminRights?.tlObject)
        tlStoreReference(_tlObject, 48, botAdminRights?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RequestPeerType.Cons_requestPeerTypeChat {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hasUsername: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var forum: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var userAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var botAdminRights: Api.ChatAdminRights? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.ChatAdminRights(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, hasUsername: Api.Bool?, forum: Api.Bool?, userAdminRights: Api.ChatAdminRights?, botAdminRights: Api.ChatAdminRights?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1342))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, hasUsername?.tlObject)
        tlStoreReference(_tlObject, 40, forum?.tlObject)
        tlStoreReference(_tlObject, 48, userAdminRights?.tlObject)
        tlStoreReference(_tlObject, 56, botAdminRights?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RequestPeerType.Cons_requestPeerTypeCreateBot {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var suggestedName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var suggestedUsername: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, suggestedName: String?, suggestedUsername: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(407))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, suggestedName.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, suggestedUsername.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RequestPeerType.Cons_requestPeerTypeUser {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bot: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var premium: Api.Bool? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Bool(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, bot: Api.Bool?, premium: Api.Bool?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(609))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, bot?.tlObject)
        tlStoreReference(_tlObject, 40, premium?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RequestedPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_requestedPeerChannel {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_requestedPeerChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_requestedPeerUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case requestedPeerChannel(Cons_requestedPeerChannel)
        case requestedPeerChat(Cons_requestedPeerChat)
        case requestedPeerUser(Cons_requestedPeerUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .requestedPeerChannel(Cons_requestedPeerChannel(tlObject: object))
            case 1:
                self = .requestedPeerChat(Cons_requestedPeerChat(tlObject: object))
            case 2:
                self = .requestedPeerUser(Cons_requestedPeerUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .requestedPeerChannel(let _data):
                return _data.tlObject
            case .requestedPeerChat(let _data):
                return _data.tlObject
            case .requestedPeerUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RequestedPeer] {
            return tlObjectsAt(object, offset).map { Api.RequestedPeer(tlObject: $0) }
        }

    }
}
public extension Api.RequestedPeer.Cons_requestedPeerChannel {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var channelId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var username: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, channelId: Int64, title: String?, username: String?, photo: Api.Photo?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(894))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, channelId)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, username.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, photo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RequestedPeer.Cons_requestedPeerChat {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, chatId: Int64, title: String?, photo: Api.Photo?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(734))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, chatId)
        tlStoreReference(_tlObject, 40, title.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, photo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RequestedPeer.Cons_requestedPeerUser {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var firstName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var lastName: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var username: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var photo: Api.Photo? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.Photo(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, userId: Int64, firstName: String?, lastName: String?, username: String?, photo: Api.Photo?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1407))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStoreReference(_tlObject, 40, firstName.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, lastName.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, username.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, photo?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RequirementToContact: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_requirementToContactPaidMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case requirementToContactEmpty
        case requirementToContactPaidMessages(Cons_requirementToContactPaidMessages)
        case requirementToContactPremium


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .requirementToContactEmpty
            case 1:
                self = .requirementToContactPaidMessages(Cons_requirementToContactPaidMessages(tlObject: object))
            case 2:
                self = .requirementToContactPremium
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .requirementToContactEmpty:
                return TLObjectSingleton(TLApiConstructorAt(35))
            case .requirementToContactPaidMessages(let _data):
                return _data.tlObject
            case .requirementToContactPremium:
                return TLObjectSingleton(TLApiConstructorAt(1508))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RequirementToContact] {
            return tlObjectsAt(object, offset).map { Api.RequirementToContact(tlObject: $0) }
        }

    }
}
public extension Api.RequirementToContact.Cons_requirementToContactPaidMessages {
    @_alwaysEmitIntoClient var starsAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(starsAmount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1186))
        tlStore(_tlObject, 24, starsAmount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RestrictionReason: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_restrictionReason {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case restrictionReason(Cons_restrictionReason)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .restrictionReason(Cons_restrictionReason(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .restrictionReason(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RestrictionReason] {
            return tlObjectsAt(object, offset).map { Api.RestrictionReason(tlObject: $0) }
        }

    }
}
public extension Api.RestrictionReason.Cons_restrictionReason {
    @_alwaysEmitIntoClient var platform: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var reason: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(platform: String, reason: String, text: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1378))
        tlStoreReference(_tlObject, 24, platform as NSString)
        tlStoreReference(_tlObject, 32, reason as NSString)
        tlStoreReference(_tlObject, 40, text as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RichButtonStyle: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_richButtonStyle {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case richButtonStyle(Cons_richButtonStyle)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .richButtonStyle(Cons_richButtonStyle(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .richButtonStyle(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RichButtonStyle] {
            return tlObjectsAt(object, offset).map { Api.RichButtonStyle(tlObject: $0) }
        }

    }
}
public extension Api.RichButtonStyle.Cons_richButtonStyle {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(30))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum RichMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_richMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case richMessage(Cons_richMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .richMessage(Cons_richMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .richMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RichMessage] {
            return tlObjectsAt(object, offset).map { Api.RichMessage(tlObject: $0) }
        }

    }
}
public extension Api.RichMessage.Cons_richMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var blocks: [Api.PageBlock] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PageBlock.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var photos: [Api.Photo] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Photo.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 48) } }
    }
    init(flags: Int32, blocks: [Api.PageBlock], photos: [Api.Photo], documents: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1231))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, blocks.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, photos.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, documents.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
