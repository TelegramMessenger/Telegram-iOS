import TelegramApiObjC
public extension Api.messages {
    enum HistoryImportParsed: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_historyImportParsed {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case historyImportParsed(Cons_historyImportParsed)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .historyImportParsed(Cons_historyImportParsed(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .historyImportParsed(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.HistoryImportParsed] {
            return tlObjectsAt(object, offset).map { Api.messages.HistoryImportParsed(tlObject: $0) }
        }

    }
}
public extension Api.messages.HistoryImportParsed.Cons_historyImportParsed {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, title: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(606))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum InactiveChats: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_inactiveChats {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case inactiveChats(Cons_inactiveChats)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .inactiveChats(Cons_inactiveChats(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .inactiveChats(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.InactiveChats] {
            return tlObjectsAt(object, offset).map { Api.messages.InactiveChats(tlObject: $0) }
        }

    }
}
public extension Api.messages.InactiveChats.Cons_inactiveChats {
    @_alwaysEmitIntoClient var dates: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(dates: [Int32], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1105))
        tlStoreReference(_tlObject, 24, tlPackInt32(dates) as NSData)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    indirect enum InvitedUsers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_invitedUsers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case invitedUsers(Cons_invitedUsers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .invitedUsers(Cons_invitedUsers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .invitedUsers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.InvitedUsers] {
            return tlObjectsAt(object, offset).map { Api.messages.InvitedUsers(tlObject: $0) }
        }

    }
}
public extension Api.messages.InvitedUsers.Cons_invitedUsers {
    @_alwaysEmitIntoClient var updates: Api.Updates {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Updates(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var missingInvitees: [Api.MissingInvitee] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MissingInvitee.tlArray(self.tlObject, 32) } }
    }
    init(updates: Api.Updates, missingInvitees: [Api.MissingInvitee]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(820))
        tlStoreReference(_tlObject, 24, updates.tlObject)
        tlStoreReference(_tlObject, 32, missingInvitees.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum MessageEditData: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageEditData {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageEditData(Cons_messageEditData)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageEditData(Cons_messageEditData(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageEditData(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.MessageEditData] {
            return tlObjectsAt(object, offset).map { Api.messages.MessageEditData(tlObject: $0) }
        }

    }
}
public extension Api.messages.MessageEditData.Cons_messageEditData {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(256))
        tlStore(_tlObject, 24, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum MessageReactionsList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageReactionsList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageReactionsList(Cons_messageReactionsList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageReactionsList(Cons_messageReactionsList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageReactionsList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.MessageReactionsList] {
            return tlObjectsAt(object, offset).map { Api.messages.MessageReactionsList(tlObject: $0) }
        }

    }
}
public extension Api.messages.MessageReactionsList.Cons_messageReactionsList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactions: [Api.MessagePeerReaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessagePeerReaction.tlArray(self.tlObject, 32) } }
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
    init(flags: Int32, count: Int32, reactions: [Api.MessagePeerReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(317))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, reactions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum MessageViews: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_messageViews {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case messageViews(Cons_messageViews)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .messageViews(Cons_messageViews(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .messageViews(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.MessageViews] {
            return tlObjectsAt(object, offset).map { Api.messages.MessageViews(tlObject: $0) }
        }

    }
}
public extension Api.messages.MessageViews.Cons_messageViews {
    @_alwaysEmitIntoClient var views: [Api.MessageViews] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageViews.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(views: [Api.MessageViews], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1202))
        tlStoreReference(_tlObject, 24, views.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum Messages: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messagesNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_messagesSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelMessages(Cons_channelMessages)
        case messages(Cons_messages)
        case messagesNotModified(Cons_messagesNotModified)
        case messagesSlice(Cons_messagesSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelMessages(Cons_channelMessages(tlObject: object))
            case 1:
                self = .messages(Cons_messages(tlObject: object))
            case 2:
                self = .messagesNotModified(Cons_messagesNotModified(tlObject: object))
            case 3:
                self = .messagesSlice(Cons_messagesSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelMessages(let _data):
                return _data.tlObject
            case .messages(let _data):
                return _data.tlObject
            case .messagesNotModified(let _data):
                return _data.tlObject
            case .messagesSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.Messages] {
            return tlObjectsAt(object, offset).map { Api.messages.Messages(tlObject: $0) }
        }

    }
}
public extension Api.messages.Messages.Cons_channelMessages {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offsetIdOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var topics: [Api.ForumTopic] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, pts: Int32, count: Int32, offsetIdOffset: Int32?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1330))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, pts)
        tlStore(_tlObject, 32, count)
        if let _tlValue = offsetIdOffset { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, topics.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Messages.Cons_messages {
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var topics: [Api.ForumTopic] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 48) } }
    }
    init(messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(194))
        tlStoreReference(_tlObject, 24, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, topics.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Messages.Cons_messagesNotModified {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(743))
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.Messages.Cons_messagesSlice {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var nextRate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var offsetIdOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var searchFlood: Api.SearchPostsFlood? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.SearchPostsFlood(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var topics: [Api.ForumTopic] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ForumTopic.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 72) } }
    }
    init(flags: Int32, count: Int32, nextRate: Int32?, offsetIdOffset: Int32?, searchFlood: Api.SearchPostsFlood?, messages: [Api.Message], topics: [Api.ForumTopic], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(609))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        if let _tlValue = nextRate { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = offsetIdOffset { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 40, searchFlood?.tlObject)
        tlStoreReference(_tlObject, 48, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, topics.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum MyStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_myStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case myStickers(Cons_myStickers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .myStickers(Cons_myStickers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .myStickers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.MyStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.MyStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.MyStickers.Cons_myStickers {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sets: [Api.StickerSetCovered] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, sets: [Api.StickerSetCovered]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1673))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, sets.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum PeerDialogs: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerDialogs {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerDialogs(Cons_peerDialogs)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerDialogs(Cons_peerDialogs(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerDialogs(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.PeerDialogs] {
            return tlObjectsAt(object, offset).map { Api.messages.PeerDialogs(tlObject: $0) }
        }

    }
}
public extension Api.messages.PeerDialogs.Cons_peerDialogs {
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
    @_alwaysEmitIntoClient var state: Api.updates.State {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.updates.State(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(dialogs: [Api.Dialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(326))
        tlStoreReference(_tlObject, 24, dialogs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, state.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum PeerSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerSettings(Cons_peerSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerSettings(Cons_peerSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.PeerSettings] {
            return tlObjectsAt(object, offset).map { Api.messages.PeerSettings(tlObject: $0) }
        }

    }
}
public extension Api.messages.PeerSettings.Cons_peerSettings {
    @_alwaysEmitIntoClient var settings: Api.PeerSettings {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerSettings(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(settings: Api.PeerSettings, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(668))
        tlStoreReference(_tlObject, 24, settings.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum PreparedInlineMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_preparedInlineMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case preparedInlineMessage(Cons_preparedInlineMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .preparedInlineMessage(Cons_preparedInlineMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .preparedInlineMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.PreparedInlineMessage] {
            return tlObjectsAt(object, offset).map { Api.messages.PreparedInlineMessage(tlObject: $0) }
        }

    }
}
public extension Api.messages.PreparedInlineMessage.Cons_preparedInlineMessage {
    @_alwaysEmitIntoClient var queryId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var result: Api.BotInlineResult {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BotInlineResult(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var peerTypes: [Api.InlineQueryPeerType] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.InlineQueryPeerType.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var cacheTime: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(queryId: Int64, result: Api.BotInlineResult, peerTypes: [Api.InlineQueryPeerType], cacheTime: Int32, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1705))
        tlStore(_tlObject, 32, queryId)
        tlStoreReference(_tlObject, 40, result.tlObject)
        tlStoreReference(_tlObject, 48, peerTypes.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 24, cacheTime)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum QuickReplies: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_quickReplies {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case quickReplies(Cons_quickReplies)
        case quickRepliesNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .quickReplies(Cons_quickReplies(tlObject: object))
            case 1:
                self = .quickRepliesNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .quickReplies(let _data):
                return _data.tlObject
            case .quickRepliesNotModified:
                return TLObjectSingleton(TLApiConstructorAt(613))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.QuickReplies] {
            return tlObjectsAt(object, offset).map { Api.messages.QuickReplies(tlObject: $0) }
        }

    }
}
public extension Api.messages.QuickReplies.Cons_quickReplies {
    @_alwaysEmitIntoClient var quickReplies: [Api.QuickReply] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.QuickReply.tlArray(self.tlObject, 24) } }
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
    init(quickReplies: [Api.QuickReply], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1325))
        tlStoreReference(_tlObject, 24, quickReplies.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum Reactions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_reactions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case reactions(Cons_reactions)
        case reactionsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reactions(Cons_reactions(tlObject: object))
            case 1:
                self = .reactionsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reactions(let _data):
                return _data.tlObject
            case .reactionsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1150))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.Reactions] {
            return tlObjectsAt(object, offset).map { Api.messages.Reactions(tlObject: $0) }
        }

    }
}
public extension Api.messages.Reactions.Cons_reactions {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var reactions: [Api.Reaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, reactions: [Api.Reaction]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1553))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, reactions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum RecentStickers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_recentStickers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case recentStickers(Cons_recentStickers)
        case recentStickersNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .recentStickers(Cons_recentStickers(tlObject: object))
            case 1:
                self = .recentStickersNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .recentStickers(let _data):
                return _data.tlObject
            case .recentStickersNotModified:
                return TLObjectSingleton(TLApiConstructorAt(74))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.RecentStickers] {
            return tlObjectsAt(object, offset).map { Api.messages.RecentStickers(tlObject: $0) }
        }

    }
}
public extension Api.messages.RecentStickers.Cons_recentStickers {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var packs: [Api.StickerPack] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerPack.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var stickers: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var dates: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 48) } }
    }
    init(hash: Int64, packs: [Api.StickerPack], stickers: [Api.Document], dates: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(876))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, packs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, stickers.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, tlPackInt32(dates) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SavedDialogs: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedDialogs {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_savedDialogsNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_savedDialogsSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedDialogs(Cons_savedDialogs)
        case savedDialogsNotModified(Cons_savedDialogsNotModified)
        case savedDialogsSlice(Cons_savedDialogsSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedDialogs(Cons_savedDialogs(tlObject: object))
            case 1:
                self = .savedDialogsNotModified(Cons_savedDialogsNotModified(tlObject: object))
            case 2:
                self = .savedDialogsSlice(Cons_savedDialogsSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedDialogs(let _data):
                return _data.tlObject
            case .savedDialogsNotModified(let _data):
                return _data.tlObject
            case .savedDialogsSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SavedDialogs] {
            return tlObjectsAt(object, offset).map { Api.messages.SavedDialogs(tlObject: $0) }
        }

    }
}
public extension Api.messages.SavedDialogs.Cons_savedDialogs {
    @_alwaysEmitIntoClient var dialogs: [Api.SavedDialog] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SavedDialog.tlArray(self.tlObject, 24) } }
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
    init(dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1646))
        tlStoreReference(_tlObject, 24, dialogs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.SavedDialogs.Cons_savedDialogsNotModified {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1280))
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.SavedDialogs.Cons_savedDialogsSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var dialogs: [Api.SavedDialog] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SavedDialog.tlArray(self.tlObject, 32) } }
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
    init(count: Int32, dialogs: [Api.SavedDialog], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(445))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, dialogs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SavedGifs: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedGifs {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedGifs(Cons_savedGifs)
        case savedGifsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedGifs(Cons_savedGifs(tlObject: object))
            case 1:
                self = .savedGifsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedGifs(let _data):
                return _data.tlObject
            case .savedGifsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1527))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SavedGifs] {
            return tlObjectsAt(object, offset).map { Api.messages.SavedGifs(tlObject: $0) }
        }

    }
}
public extension Api.messages.SavedGifs.Cons_savedGifs {
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var gifs: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(hash: Int64, gifs: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(850))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, gifs.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SavedReactionTags: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedReactionTags {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedReactionTags(Cons_savedReactionTags)
        case savedReactionTagsNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedReactionTags(Cons_savedReactionTags(tlObject: object))
            case 1:
                self = .savedReactionTagsNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedReactionTags(let _data):
                return _data.tlObject
            case .savedReactionTagsNotModified:
                return TLObjectSingleton(TLApiConstructorAt(874))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SavedReactionTags] {
            return tlObjectsAt(object, offset).map { Api.messages.SavedReactionTags(tlObject: $0) }
        }

    }
}
public extension Api.messages.SavedReactionTags.Cons_savedReactionTags {
    @_alwaysEmitIntoClient var tags: [Api.SavedReactionTag] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SavedReactionTag.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var hash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(tags: [Api.SavedReactionTag], hash: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(321))
        tlStoreReference(_tlObject, 24, tags.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 32, hash)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SearchCounter: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchCounter {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchCounter(Cons_searchCounter)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchCounter(Cons_searchCounter(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchCounter(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SearchCounter] {
            return tlObjectsAt(object, offset).map { Api.messages.SearchCounter(tlObject: $0) }
        }

    }
}
public extension Api.messages.SearchCounter.Cons_searchCounter {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var filter: Api.MessagesFilter {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessagesFilter(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(flags: Int32, filter: Api.MessagesFilter, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1528))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, filter.tlObject)
        tlStore(_tlObject, 28, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SearchResultsCalendar: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchResultsCalendar {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchResultsCalendar(Cons_searchResultsCalendar)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchResultsCalendar(Cons_searchResultsCalendar(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchResultsCalendar(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SearchResultsCalendar] {
            return tlObjectsAt(object, offset).map { Api.messages.SearchResultsCalendar(tlObject: $0) }
        }

    }
}
public extension Api.messages.SearchResultsCalendar.Cons_searchResultsCalendar {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var minDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var minMsgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var offsetIdOffset: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var periods: [Api.SearchResultsCalendarPeriod] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SearchResultsCalendarPeriod.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var messages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 72) } }
    }
    init(flags: Int32, count: Int32, minDate: Int32, minMsgId: Int32, offsetIdOffset: Int32?, periods: [Api.SearchResultsCalendarPeriod], messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(125))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStore(_tlObject, 32, minDate)
        tlStore(_tlObject, 36, minMsgId)
        if let _tlValue = offsetIdOffset { tlStore(_tlObject, 40, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, periods.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SearchResultsPositions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_searchResultsPositions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case searchResultsPositions(Cons_searchResultsPositions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .searchResultsPositions(Cons_searchResultsPositions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .searchResultsPositions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SearchResultsPositions] {
            return tlObjectsAt(object, offset).map { Api.messages.SearchResultsPositions(tlObject: $0) }
        }

    }
}
public extension Api.messages.SearchResultsPositions.Cons_searchResultsPositions {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var positions: [Api.SearchResultsPosition] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SearchResultsPosition.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, positions: [Api.SearchResultsPosition]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(546))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, positions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SentEncryptedMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sentEncryptedFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_sentEncryptedMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sentEncryptedFile(Cons_sentEncryptedFile)
        case sentEncryptedMessage(Cons_sentEncryptedMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sentEncryptedFile(Cons_sentEncryptedFile(tlObject: object))
            case 1:
                self = .sentEncryptedMessage(Cons_sentEncryptedMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sentEncryptedFile(let _data):
                return _data.tlObject
            case .sentEncryptedMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SentEncryptedMessage] {
            return tlObjectsAt(object, offset).map { Api.messages.SentEncryptedMessage(tlObject: $0) }
        }

    }
}
public extension Api.messages.SentEncryptedMessage.Cons_sentEncryptedFile {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var file: Api.EncryptedFile {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EncryptedFile(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(date: Int32, file: Api.EncryptedFile) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(948))
        tlStore(_tlObject, 24, date)
        tlStoreReference(_tlObject, 32, file.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages.SentEncryptedMessage.Cons_sentEncryptedMessage {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(555))
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum SponsoredMessages: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_sponsoredMessages {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case sponsoredMessages(Cons_sponsoredMessages)
        case sponsoredMessagesEmpty


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .sponsoredMessages(Cons_sponsoredMessages(tlObject: object))
            case 1:
                self = .sponsoredMessagesEmpty
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .sponsoredMessages(let _data):
                return _data.tlObject
            case .sponsoredMessagesEmpty:
                return TLObjectSingleton(TLApiConstructorAt(157))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.SponsoredMessages] {
            return tlObjectsAt(object, offset).map { Api.messages.SponsoredMessages(tlObject: $0) }
        }

    }
}
public extension Api.messages.SponsoredMessages.Cons_sponsoredMessages {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var postsBetween: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var startDelay: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 1) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var betweenDelay: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 2) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var messages: [Api.SponsoredMessage] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.SponsoredMessage.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, postsBetween: Int32?, startDelay: Int32?, betweenDelay: Int32?, messages: [Api.SponsoredMessage], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1713))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = postsBetween { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        if let _tlValue = startDelay { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 1 }
        if let _tlValue = betweenDelay { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 2 }
        tlStoreReference(_tlObject, 40, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum StickerSet: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerSet(Cons_stickerSet)
        case stickerSetNotModified


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerSet(Cons_stickerSet(tlObject: object))
            case 1:
                self = .stickerSetNotModified
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerSet(let _data):
                return _data.tlObject
            case .stickerSetNotModified:
                return TLObjectSingleton(TLApiConstructorAt(1397))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.StickerSet] {
            return tlObjectsAt(object, offset).map { Api.messages.StickerSet(tlObject: $0) }
        }

    }
}
public extension Api.messages.StickerSet.Cons_stickerSet {
    @_alwaysEmitIntoClient var set: Api.StickerSet {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSet(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var packs: [Api.StickerPack] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerPack.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var keywords: [Api.StickerKeyword] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerKeyword.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 48) } }
    }
    init(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(701))
        tlStoreReference(_tlObject, 24, set.tlObject)
        tlStoreReference(_tlObject, 32, packs.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, keywords.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, documents.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.messages {
    enum StickerSetInstallResult: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stickerSetInstallResultArchive {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stickerSetInstallResultArchive(Cons_stickerSetInstallResultArchive)
        case stickerSetInstallResultSuccess


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stickerSetInstallResultArchive(Cons_stickerSetInstallResultArchive(tlObject: object))
            case 1:
                self = .stickerSetInstallResultSuccess
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stickerSetInstallResultArchive(let _data):
                return _data.tlObject
            case .stickerSetInstallResultSuccess:
                return TLObjectSingleton(TLApiConstructorAt(360))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.messages.StickerSetInstallResult] {
            return tlObjectsAt(object, offset).map { Api.messages.StickerSetInstallResult(tlObject: $0) }
        }

    }
}
public extension Api.messages.StickerSetInstallResult.Cons_stickerSetInstallResultArchive {
    @_alwaysEmitIntoClient var sets: [Api.StickerSetCovered] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered.tlArray(self.tlObject, 24) } }
    }
    init(sets: [Api.StickerSetCovered]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(343))
        tlStoreReference(_tlObject, 24, sets.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
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
                return TLObjectSingleton(TLApiConstructorAt(1604))
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(308))
        tlStore(_tlObject, 24, hash)
        tlStoreReference(_tlObject, 32, stickers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
