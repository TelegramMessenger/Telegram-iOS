import TelegramApiObjC
public extension Api.messages {
    enum AvailableReactions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_availableReactions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case availableReactions(Cons_availableReactions)
        case availableReactionsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .availableReactions(Cons_availableReactions(tlObject: object))
            case 1:
                self = .availableReactionsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .availableReactions(let _data):
                return _data.tlObject
            case .availableReactionsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1034))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.AvailableReactions] {
            return tlObjectsAt(object, offset).map { Api.messages.AvailableReactions(tlObject: $0) }
        }

    }
}
public extension Api.messages.AvailableReactions.Cons_availableReactions {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactions: [Api.AvailableReaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.AvailableReaction.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int32, reactions: [Api.AvailableReaction]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(761))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, reactions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum BotApp: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botApp {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botApp(Cons_botApp)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botApp(Cons_botApp(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botApp(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.BotApp] {
            return tlObjectsAt(object, offset).map { Api.messages.BotApp(tlObject: $0) }
        }

    }
}
public extension Api.messages.BotApp.Cons_botApp {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var app: Api.BotApp {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotApp(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, app: Api.BotApp) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1556))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, app.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum BotCallbackAnswer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botCallbackAnswer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botCallbackAnswer(Cons_botCallbackAnswer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botCallbackAnswer(Cons_botCallbackAnswer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botCallbackAnswer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.BotCallbackAnswer] {
            return tlObjectsAt(object, offset).map { Api.messages.BotCallbackAnswer(tlObject: $0) }
        }

    }
}
public extension Api.messages.BotCallbackAnswer.Cons_botCallbackAnswer {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var url: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var cacheTime: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, message: String?, url: String?, cacheTime: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(348))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, url.map { value in value as NSString })
        tlStore(_tlObject, 28, cacheTime)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum BotPreparedInlineMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botPreparedInlineMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botPreparedInlineMessage(Cons_botPreparedInlineMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botPreparedInlineMessage(Cons_botPreparedInlineMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botPreparedInlineMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.BotPreparedInlineMessage] {
            return tlObjectsAt(object, offset).map { Api.messages.BotPreparedInlineMessage(tlObject: $0) }
        }

    }
}
public extension Api.messages.BotPreparedInlineMessage.Cons_botPreparedInlineMessage {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: String, expireDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(915))
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStore(_tlObject, 24, expireDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum BotResults: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_botResults {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case botResults(Cons_botResults)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .botResults(Cons_botResults(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .botResults(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.BotResults] {
            return tlObjectsAt(object, offset).map { Api.messages.BotResults(tlObject: $0) }
        }

    }
}
public extension Api.messages.BotResults.Cons_botResults {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var queryId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var switchPm: Api.InlineBotSwitchPM? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.InlineBotSwitchPM(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var switchWebview: Api.InlineBotWebView? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.InlineBotWebView(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var results: [Api.BotInlineResult] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotInlineResult.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var cacheTime: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 72) } }
    }
    init(flags: Int32, queryId: Int64, nextOffset: String?, switchPm: Api.InlineBotSwitchPM?, switchWebview: Api.InlineBotWebView?, results: [Api.BotInlineResult], cacheTime: Int32, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1473))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, switchPm?.tlObject)
        tlStoreReference(_tlObject, 56, switchWebview?.tlObject)
        tlStoreReference(_tlObject, 64, results.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 28, cacheTime)
        tlStoreReference(_tlObject, 72, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ChatAdminsWithInvites: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatAdminsWithInvites {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatAdminsWithInvites(Cons_chatAdminsWithInvites)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatAdminsWithInvites(Cons_chatAdminsWithInvites(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatAdminsWithInvites(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ChatAdminsWithInvites] {
            return tlObjectsAt(object, offset).map { Api.messages.ChatAdminsWithInvites(tlObject: $0) }
        }

    }
}
public extension Api.messages.ChatAdminsWithInvites.Cons_chatAdminsWithInvites {
    @_alwaysEmitIntoClient var admins: [Api.ChatAdminWithInvites] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatAdminWithInvites.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(admins: [Api.ChatAdminWithInvites], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1200))
        tlStoreReference(_tlObject, 24, admins.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ChatFull: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatFull(Cons_chatFull)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatFull(Cons_chatFull(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatFull(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ChatFull] {
            return tlObjectsAt(object, offset).map { Api.messages.ChatFull(tlObject: $0) }
        }

    }
}
public extension Api.messages.ChatFull.Cons_chatFull {
    @_alwaysEmitIntoClient var fullChat: Api.ChatFull {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatFull(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(fullChat: Api.ChatFull, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1514))
        tlStoreReference(_tlObject, 24, fullChat.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ChatInviteImporters: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatInviteImporters {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatInviteImporters(Cons_chatInviteImporters)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatInviteImporters(Cons_chatInviteImporters(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatInviteImporters(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ChatInviteImporters] {
            return tlObjectsAt(object, offset).map { Api.messages.ChatInviteImporters(tlObject: $0) }
        }

    }
}
public extension Api.messages.ChatInviteImporters.Cons_chatInviteImporters {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var importers: [Api.ChatInviteImporter] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatInviteImporter.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(count: Int32, importers: [Api.ChatInviteImporter], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(833))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, importers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    indirect enum ChatInviteJoinResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chatInviteJoinResultOk {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatInviteJoinResultWebView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chatInviteJoinResultOk(Cons_chatInviteJoinResultOk)
        case chatInviteJoinResultWebView(Cons_chatInviteJoinResultWebView)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chatInviteJoinResultOk(Cons_chatInviteJoinResultOk(tlObject: object))
            case 1:
                self = .chatInviteJoinResultWebView(Cons_chatInviteJoinResultWebView(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chatInviteJoinResultOk(let _data):
                return _data.tlObject
            case .chatInviteJoinResultWebView(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ChatInviteJoinResult] {
            return tlObjectsAt(object, offset).map { Api.messages.ChatInviteJoinResult(tlObject: $0) }
        }

    }
}
public extension Api.messages.ChatInviteJoinResult.Cons_chatInviteJoinResultOk {
    @_alwaysEmitIntoClient var updates: Api.Updates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Updates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(updates: Api.Updates) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(443))
        tlStoreReference(_tlObject, 24, updates.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.ChatInviteJoinResult.Cons_chatInviteJoinResultWebView {
    @_alwaysEmitIntoClient var botId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var queryId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(botId: Int64, queryId: Int64, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(623))
        tlStore(_tlObject, 24, botId)
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum Chats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_chats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_chatsSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case chats(Cons_chats)
        case chatsSlice(Cons_chatsSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .chats(Cons_chats(tlObject: object))
            case 1:
                self = .chatsSlice(Cons_chatsSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .chats(let _data):
                return _data.tlObject
            case .chatsSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.Chats] {
            return tlObjectsAt(object, offset).map { Api.messages.Chats(tlObject: $0) }
        }

    }
}
public extension Api.messages.Chats.Cons_chats {
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 24) } }
    }
    init(chats: [Api.Chat]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(649))
        tlStoreReference(_tlObject, 24, chats.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Chats.Cons_chatsSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, chats: [Api.Chat]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1016))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum CheckedHistoryImportPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_checkedHistoryImportPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case checkedHistoryImportPeer(Cons_checkedHistoryImportPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .checkedHistoryImportPeer(Cons_checkedHistoryImportPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .checkedHistoryImportPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.CheckedHistoryImportPeer] {
            return tlObjectsAt(object, offset).map { Api.messages.CheckedHistoryImportPeer(tlObject: $0) }
        }

    }
}
public extension Api.messages.CheckedHistoryImportPeer.Cons_checkedHistoryImportPeer {
    @_alwaysEmitIntoClient var confirmText: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(confirmText: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1062))
        tlStoreReference(_tlObject, 24, confirmText as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ComposedMessageWithAI: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_composedMessageWithAI {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case composedMessageWithAI(Cons_composedMessageWithAI)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .composedMessageWithAI(Cons_composedMessageWithAI(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .composedMessageWithAI(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ComposedMessageWithAI] {
            return tlObjectsAt(object, offset).map { Api.messages.ComposedMessageWithAI(tlObject: $0) }
        }

    }
}
public extension Api.messages.ComposedMessageWithAI.Cons_composedMessageWithAI {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var resultText: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var diffText: Api.TextWithEntities? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, resultText: Api.TextWithEntities, diffText: Api.TextWithEntities?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(931))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, resultText.tlObject)
        tlStoreReference(_tlObject, 40, diffText?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ComposedRichMessageWithAI: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_composedRichMessageWithAI {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case composedRichMessageWithAI(Cons_composedRichMessageWithAI)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .composedRichMessageWithAI(Cons_composedRichMessageWithAI(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .composedRichMessageWithAI(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ComposedRichMessageWithAI] {
            return tlObjectsAt(object, offset).map { Api.messages.ComposedRichMessageWithAI(tlObject: $0) }
        }

    }
}
public extension Api.messages.ComposedRichMessageWithAI.Cons_composedRichMessageWithAI {
    @_alwaysEmitIntoClient var result: Api.RichMessage {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.RichMessage(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(result: Api.RichMessage) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(495))
        tlStoreReference(_tlObject, 24, result.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum DhConfig: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dhConfig {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dhConfigNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dhConfig(Cons_dhConfig)
        case dhConfigNotModified(Cons_dhConfigNotModified)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dhConfig(Cons_dhConfig(tlObject: object))
            case 1:
                self = .dhConfigNotModified(Cons_dhConfigNotModified(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dhConfig(let _data):
                return _data.tlObject
            case .dhConfigNotModified(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.DhConfig] {
            return tlObjectsAt(object, offset).map { Api.messages.DhConfig(tlObject: $0) }
        }

    }
}
public extension Api.messages.DhConfig.Cons_dhConfig {
    @_alwaysEmitIntoClient var g: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var p: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var version: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var random: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(g: Int32, p: Buffer, version: Int32, random: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(279))
        tlStore(_tlObject, 24, g)
        tlStoreReference(_tlObject, 32, p.makeData() as NSData)
        tlStore(_tlObject, 28, version)
        tlStoreReference(_tlObject, 40, random.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.DhConfig.Cons_dhConfigNotModified {
    @_alwaysEmitIntoClient var random: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(random: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1285))
        tlStoreReference(_tlObject, 24, random.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum DialogFilters: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialogFilters {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialogFilters(Cons_dialogFilters)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialogFilters(Cons_dialogFilters(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialogFilters(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.DialogFilters] {
            return tlObjectsAt(object, offset).map { Api.messages.DialogFilters(tlObject: $0) }
        }

    }
}
public extension Api.messages.DialogFilters.Cons_dialogFilters {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var filters: [Api.DialogFilter] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DialogFilter.tlArray(self.tlObject, 32) } }
    }
    init(flags: Int32, filters: [Api.DialogFilter]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(273))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, filters.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum Dialogs: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_dialogs {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogsNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_dialogsSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case dialogs(Cons_dialogs)
        case dialogsNotModified(Cons_dialogsNotModified)
        case dialogsSlice(Cons_dialogsSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .dialogs(Cons_dialogs(tlObject: object))
            case 1:
                self = .dialogsNotModified(Cons_dialogsNotModified(tlObject: object))
            case 2:
                self = .dialogsSlice(Cons_dialogsSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .dialogs(let _data):
                return _data.tlObject
            case .dialogsNotModified(let _data):
                return _data.tlObject
            case .dialogsSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.Dialogs] {
            return tlObjectsAt(object, offset).map { Api.messages.Dialogs(tlObject: $0) }
        }

    }
}
public extension Api.messages.Dialogs.Cons_dialogs {
    @_alwaysEmitIntoClient var dialogs: [Api.Dialog] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Dialog.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(134))
        tlStoreReference(_tlObject, 24, dialogs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Dialogs.Cons_dialogsNotModified {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1595))
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Dialogs.Cons_dialogsSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var dialogs: [Api.Dialog] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Dialog.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(count: Int32, dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(727))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, dialogs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum DiscussionMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_discussionMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case discussionMessage(Cons_discussionMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .discussionMessage(Cons_discussionMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .discussionMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.DiscussionMessage] {
            return tlObjectsAt(object, offset).map { Api.messages.DiscussionMessage(tlObject: $0) }
        }

    }
}
public extension Api.messages.DiscussionMessage.Cons_discussionMessage {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var maxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var readInboxMaxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var readOutboxMaxId: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var unreadCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, messages: [Api.Message], maxId: Int32?, readInboxMaxId: Int32?, readOutboxMaxId: Int32?, unreadCount: Int32, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1087))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 48, messages.map { item in item.tlObject } as NSArray)
        if let _tlValue = maxId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = readInboxMaxId { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = readOutboxMaxId { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStore(_tlObject, 40, unreadCount)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum EmojiGameInfo: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiGameDiceInfo {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiGameDiceInfo(Cons_emojiGameDiceInfo)
        case emojiGameUnavailable


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiGameDiceInfo(Cons_emojiGameDiceInfo(tlObject: object))
            case 1:
                self = .emojiGameUnavailable
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiGameDiceInfo(let _data):
                return _data.tlObject
            case .emojiGameUnavailable:
                return TLObjectSingleton(TLApiConstructorAt(583))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.EmojiGameInfo] {
            return tlObjectsAt(object, offset).map { Api.messages.EmojiGameInfo(tlObject: $0) }
        }

    }
}
public extension Api.messages.EmojiGameInfo.Cons_emojiGameDiceInfo {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var gameHash: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var prevStake: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 48, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var currentStreak: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var params: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var playsLeft: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, gameHash: String, prevStake: Int64, currentStreak: Int32, params: [Int32], playsLeft: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(447))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, gameHash as NSString)
        tlStore(_tlObject, 48, prevStake)
        tlStore(_tlObject, 28, currentStreak)
        tlStoreReference(_tlObject, 56, tlPackInt32(params) as NSData)
        if let _tlValue = playsLeft { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum EmojiGameOutcome: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiGameOutcome {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiGameOutcome(Cons_emojiGameOutcome)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiGameOutcome(Cons_emojiGameOutcome(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiGameOutcome(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.EmojiGameOutcome] {
            return tlObjectsAt(object, offset).map { Api.messages.EmojiGameOutcome(tlObject: $0) }
        }

    }
}
public extension Api.messages.EmojiGameOutcome.Cons_emojiGameOutcome {
    @_alwaysEmitIntoClient var seed: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var stakeTonAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var tonAmount: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    init(seed: Buffer, stakeTonAmount: Int64, tonAmount: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1430))
        tlStoreReference(_tlObject, 24, seed.makeData() as NSData)
        tlStore(_tlObject, 32, stakeTonAmount)
        tlStore(_tlObject, 40, tonAmount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum EmojiGroups: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_emojiGroups {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case emojiGroups(Cons_emojiGroups)
        case emojiGroupsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .emojiGroups(Cons_emojiGroups(tlObject: object))
            case 1:
                self = .emojiGroupsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .emojiGroups(let _data):
                return _data.tlObject
            case .emojiGroupsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(713))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.EmojiGroups] {
            return tlObjectsAt(object, offset).map { Api.messages.EmojiGroups(tlObject: $0) }
        }

    }
}
public extension Api.messages.EmojiGroups.Cons_emojiGroups {
    @_alwaysEmitIntoClient var hash: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var groups: [Api.EmojiGroup] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EmojiGroup.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int32, groups: [Api.EmojiGroup]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(872))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, groups.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ExportedChatInvite: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedChatInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_exportedChatInviteReplaced {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedChatInvite(Cons_exportedChatInvite)
        case exportedChatInviteReplaced(Cons_exportedChatInviteReplaced)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedChatInvite(Cons_exportedChatInvite(tlObject: object))
            case 1:
                self = .exportedChatInviteReplaced(Cons_exportedChatInviteReplaced(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedChatInvite(let _data):
                return _data.tlObject
            case .exportedChatInviteReplaced(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ExportedChatInvite] {
            return tlObjectsAt(object, offset).map { Api.messages.ExportedChatInvite(tlObject: $0) }
        }

    }
}
public extension Api.messages.ExportedChatInvite.Cons_exportedChatInvite {
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(invite: Api.ExportedChatInvite, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(159))
        tlStoreReference(_tlObject, 24, invite.tlObject)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.ExportedChatInvite.Cons_exportedChatInviteReplaced {
    @_alwaysEmitIntoClient var invite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var newInvite: Api.ExportedChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(invite: Api.ExportedChatInvite, newInvite: Api.ExportedChatInvite, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(234))
        tlStoreReference(_tlObject, 24, invite.tlObject)
        tlStoreReference(_tlObject, 32, newInvite.tlObject)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ExportedChatInvites: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_exportedChatInvites {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case exportedChatInvites(Cons_exportedChatInvites)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .exportedChatInvites(Cons_exportedChatInvites(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .exportedChatInvites(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ExportedChatInvites] {
            return tlObjectsAt(object, offset).map { Api.messages.ExportedChatInvites(tlObject: $0) }
        }

    }
}
public extension Api.messages.ExportedChatInvites.Cons_exportedChatInvites {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var invites: [Api.ExportedChatInvite] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ExportedChatInvite.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(count: Int32, invites: [Api.ExportedChatInvite], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1255))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, invites.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum FavedStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_favedStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case favedStickers(Cons_favedStickers)
        case favedStickersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .favedStickers(Cons_favedStickers(tlObject: object))
            case 1:
                self = .favedStickersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .favedStickers(let _data):
                return _data.tlObject
            case .favedStickersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1030))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.FavedStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.FavedStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.FavedStickers.Cons_favedStickers {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var packs: [Api.StickerPack] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerPack.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 40) } }
    }
    init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(282))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, packs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, stickers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum FeaturedStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_featuredStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_featuredStickersNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case featuredStickers(Cons_featuredStickers)
        case featuredStickersNotModified(Cons_featuredStickersNotModified)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .featuredStickers(Cons_featuredStickers(tlObject: object))
            case 1:
                self = .featuredStickersNotModified(Cons_featuredStickersNotModified(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .featuredStickers(let _data):
                return _data.tlObject
            case .featuredStickersNotModified(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.FeaturedStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.FeaturedStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.FeaturedStickers.Cons_featuredStickers {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sets: [Api.StickerSetCovered] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var unread: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 48) } }
    }
    init(flags: Int32, hash: Int64, count: Int32, sets: [Api.StickerSetCovered], unread: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1265))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, hash)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 40, sets.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, tlPackInt64(unread) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.FeaturedStickers.Cons_featuredStickersNotModified {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1328))
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum ForumTopics: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_forumTopics {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case forumTopics(Cons_forumTopics)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .forumTopics(Cons_forumTopics(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .forumTopics(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.ForumTopics] {
            return tlObjectsAt(object, offset).map { Api.messages.ForumTopics(tlObject: $0) }
        }

    }
}
public extension Api.messages.ForumTopics.Cons_forumTopics {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var topics: [Api.ForumTopic] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, count: Int32, topics: [Api.ForumTopic], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], pts: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(350))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 40, topics.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 32, pts)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum FoundStickerSets: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_foundStickerSets {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case foundStickerSets(Cons_foundStickerSets)
        case foundStickerSetsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .foundStickerSets(Cons_foundStickerSets(tlObject: object))
            case 1:
                self = .foundStickerSetsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .foundStickerSets(let _data):
                return _data.tlObject
            case .foundStickerSetsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(84))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.FoundStickerSets] {
            return tlObjectsAt(object, offset).map { Api.messages.FoundStickerSets(tlObject: $0) }
        }

    }
}
public extension Api.messages.FoundStickerSets.Cons_foundStickerSets {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var sets: [Api.StickerSetCovered] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, sets: [Api.StickerSetCovered]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(892))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, sets.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum FoundStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_foundStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_foundStickersNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case foundStickers(Cons_foundStickers)
        case foundStickersNotModified(Cons_foundStickersNotModified)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .foundStickers(Cons_foundStickers(tlObject: object))
            case 1:
                self = .foundStickersNotModified(Cons_foundStickersNotModified(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .foundStickers(let _data):
                return _data.tlObject
            case .foundStickersNotModified(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.FoundStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.FoundStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.FoundStickers.Cons_foundStickers {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nextOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, nextOffset: Int32?, hash: Int64, stickers: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(838))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = nextOffset { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, hash)
        tlStoreReference(_tlObject, 40, stickers.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.FoundStickers.Cons_foundStickersNotModified {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nextOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 32, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, nextOffset: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(615))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = nextOffset { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum HighScores: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_highScores {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case highScores(Cons_highScores)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .highScores(Cons_highScores(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .highScores(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.HighScores] {
            return tlObjectsAt(object, offset).map { Api.messages.HighScores(tlObject: $0) }
        }

    }
}
public extension Api.messages.HighScores.Cons_highScores {
    @_alwaysEmitIntoClient var scores: [Api.HighScore] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.HighScore.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(scores: [Api.HighScore], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(998))
        tlStoreReference(_tlObject, 24, scores.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum HistoryImport: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_historyImport {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case historyImport(Cons_historyImport)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .historyImport(Cons_historyImport(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .historyImport(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.HistoryImport] {
            return tlObjectsAt(object, offset).map { Api.messages.HistoryImport(tlObject: $0) }
        }

    }
}
public extension Api.messages.HistoryImport.Cons_historyImport {
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(id: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(140))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
