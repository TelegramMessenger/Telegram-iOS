import TelegramApiObjC
public extension Api {
    enum PrivacyRule: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_privacyValueAllowChatParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_privacyValueAllowUsers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_privacyValueDisallowChatParticipants {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_privacyValueDisallowUsers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case privacyValueAllowAll
        case privacyValueAllowBots
        case privacyValueAllowChatParticipants(Cons_privacyValueAllowChatParticipants)
        case privacyValueAllowCloseFriends
        case privacyValueAllowContacts
        case privacyValueAllowPremium
        case privacyValueAllowUsers(Cons_privacyValueAllowUsers)
        case privacyValueDisallowAll
        case privacyValueDisallowBots
        case privacyValueDisallowChatParticipants(Cons_privacyValueDisallowChatParticipants)
        case privacyValueDisallowContacts
        case privacyValueDisallowUsers(Cons_privacyValueDisallowUsers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .privacyValueAllowAll
            case 1:
                self = .privacyValueAllowBots
            case 2:
                self = .privacyValueAllowChatParticipants(Cons_privacyValueAllowChatParticipants(tlObject: object))
            case 3:
                self = .privacyValueAllowCloseFriends
            case 4:
                self = .privacyValueAllowContacts
            case 5:
                self = .privacyValueAllowPremium
            case 6:
                self = .privacyValueAllowUsers(Cons_privacyValueAllowUsers(tlObject: object))
            case 7:
                self = .privacyValueDisallowAll
            case 8:
                self = .privacyValueDisallowBots
            case 9:
                self = .privacyValueDisallowChatParticipants(Cons_privacyValueDisallowChatParticipants(tlObject: object))
            case 10:
                self = .privacyValueDisallowContacts
            case 11:
                self = .privacyValueDisallowUsers(Cons_privacyValueDisallowUsers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .privacyValueAllowAll:
                return TLObjectSingleton(TLApiConstructorAt(649))
            case .privacyValueAllowBots:
                return TLObjectSingleton(TLApiConstructorAt(230))
            case .privacyValueAllowChatParticipants(let _data):
                return _data.tlObject
            case .privacyValueAllowCloseFriends:
                return TLObjectSingleton(TLApiConstructorAt(1644))
            case .privacyValueAllowContacts:
                return TLObjectSingleton(TLApiConstructorAt(1715))
            case .privacyValueAllowPremium:
                return TLObjectSingleton(TLApiConstructorAt(1566))
            case .privacyValueAllowUsers(let _data):
                return _data.tlObject
            case .privacyValueDisallowAll:
                return TLObjectSingleton(TLApiConstructorAt(893))
            case .privacyValueDisallowBots:
                return TLObjectSingleton(TLApiConstructorAt(1638))
            case .privacyValueDisallowChatParticipants(let _data):
                return _data.tlObject
            case .privacyValueDisallowContacts:
                return TLObjectSingleton(TLApiConstructorAt(1649))
            case .privacyValueDisallowUsers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PrivacyRule] {
            return tlObjectsAt(object, offset).map { Api.PrivacyRule(tlObject: $0) }
        }

    }
}
public extension Api.PrivacyRule.Cons_privacyValueAllowChatParticipants {
    @_alwaysEmitIntoClient var chats: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(chats: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(684))
        tlStoreReference(_tlObject, 24, tlPackInt64(chats) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PrivacyRule.Cons_privacyValueAllowUsers {
    @_alwaysEmitIntoClient var users: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(users: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1213))
        tlStoreReference(_tlObject, 24, tlPackInt64(users) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PrivacyRule.Cons_privacyValueDisallowChatParticipants {
    @_alwaysEmitIntoClient var chats: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(chats: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(426))
        tlStoreReference(_tlObject, 24, tlPackInt64(chats) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PrivacyRule.Cons_privacyValueDisallowUsers {
    @_alwaysEmitIntoClient var users: [Int64] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt64sAt(self.tlObject, 24) } }
    }
    init(users: [Int64]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1501))
        tlStoreReference(_tlObject, 24, tlPackInt64(users) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ProfileTab: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case profileTabFiles
        case profileTabGifs
        case profileTabGifts
        case profileTabLinks
        case profileTabMedia
        case profileTabMusic
        case profileTabPosts
        case profileTabVoice


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .profileTabFiles
            case 1:
                self = .profileTabGifs
            case 2:
                self = .profileTabGifts
            case 3:
                self = .profileTabLinks
            case 4:
                self = .profileTabMedia
            case 5:
                self = .profileTabMusic
            case 6:
                self = .profileTabPosts
            case 7:
                self = .profileTabVoice
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .profileTabFiles:
                return TLObjectSingleton(TLApiConstructorAt(1118))
            case .profileTabGifs:
                return TLObjectSingleton(TLApiConstructorAt(1065))
            case .profileTabGifts:
                return TLObjectSingleton(TLApiConstructorAt(497))
            case .profileTabLinks:
                return TLObjectSingleton(TLApiConstructorAt(1395))
            case .profileTabMedia:
                return TLObjectSingleton(TLApiConstructorAt(733))
            case .profileTabMusic:
                return TLObjectSingleton(TLApiConstructorAt(1038))
            case .profileTabPosts:
                return TLObjectSingleton(TLApiConstructorAt(1223))
            case .profileTabVoice:
                return TLObjectSingleton(TLApiConstructorAt(1502))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ProfileTab] {
            return tlObjectsAt(object, offset).map { Api.ProfileTab(tlObject: $0) }
        }

    }
}
public extension Api {
    indirect enum PublicForward: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_publicForwardMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_publicForwardStory {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case publicForwardMessage(Cons_publicForwardMessage)
        case publicForwardStory(Cons_publicForwardStory)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .publicForwardMessage(Cons_publicForwardMessage(tlObject: object))
            case 1:
                self = .publicForwardStory(Cons_publicForwardStory(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .publicForwardMessage(let _data):
                return _data.tlObject
            case .publicForwardStory(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.PublicForward] {
            return tlObjectsAt(object, offset).map { Api.PublicForward(tlObject: $0) }
        }

    }
}
public extension Api.PublicForward.Cons_publicForwardMessage {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(14))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.PublicForward.Cons_publicForwardStory {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var story: Api.StoryItem {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(peer: Api.Peer, story: Api.StoryItem) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1576))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStoreReference(_tlObject, 32, story.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum QuickReply: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_quickReply {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case quickReply(Cons_quickReply)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .quickReply(Cons_quickReply(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .quickReply(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.QuickReply] {
            return tlObjectsAt(object, offset).map { Api.QuickReply(tlObject: $0) }
        }

    }
}
public extension Api.QuickReply.Cons_quickReply {
    @_alwaysEmitIntoClient var shortcutId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var shortcut: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var topMessage: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(shortcutId: Int32, shortcut: String, topMessage: Int32, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(46))
        tlStore(_tlObject, 24, shortcutId)
        tlStoreReference(_tlObject, 40, shortcut as NSString)
        tlStore(_tlObject, 28, topMessage)
        tlStore(_tlObject, 32, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Reaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_reactionCustomEmoji {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_reactionEmoji {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case reactionCustomEmoji(Cons_reactionCustomEmoji)
        case reactionEmoji(Cons_reactionEmoji)
        case reactionEmpty
        case reactionPaid


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reactionCustomEmoji(Cons_reactionCustomEmoji(tlObject: object))
            case 1:
                self = .reactionEmoji(Cons_reactionEmoji(tlObject: object))
            case 2:
                self = .reactionEmpty
            case 3:
                self = .reactionPaid
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reactionCustomEmoji(let _data):
                return _data.tlObject
            case .reactionEmoji(let _data):
                return _data.tlObject
            case .reactionEmpty:
                return TLObjectSingleton(TLApiConstructorAt(783))
            case .reactionPaid:
                return TLObjectSingleton(TLApiConstructorAt(532))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Reaction] {
            return tlObjectsAt(object, offset).map { Api.Reaction(tlObject: $0) }
        }

    }
}
public extension Api.Reaction.Cons_reactionCustomEmoji {
    @_alwaysEmitIntoClient var documentId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(documentId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(880))
        tlStore(_tlObject, 24, documentId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.Reaction.Cons_reactionEmoji {
    @_alwaysEmitIntoClient var emoticon: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(emoticon: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(177))
        tlStoreReference(_tlObject, 24, emoticon as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReactionCount: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_reactionCount {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case reactionCount(Cons_reactionCount)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reactionCount(Cons_reactionCount(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reactionCount(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReactionCount] {
            return tlObjectsAt(object, offset).map { Api.ReactionCount(tlObject: $0) }
        }

    }
}
public extension Api.ReactionCount.Cons_reactionCount {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var chosenOrder: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, chosenOrder: Int32?, reaction: Api.Reaction, count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1070))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = chosenOrder { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, reaction.tlObject)
        tlStore(_tlObject, 32, count)
        tlStore(_tlObject, 48, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReactionNotificationsFrom: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case reactionNotificationsFromAll
        case reactionNotificationsFromContacts


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reactionNotificationsFromAll
            case 1:
                self = .reactionNotificationsFromContacts
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reactionNotificationsFromAll:
                return TLObjectSingleton(TLApiConstructorAt(486))
            case .reactionNotificationsFromContacts:
                return TLObjectSingleton(TLApiConstructorAt(1230))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReactionNotificationsFrom] {
            return tlObjectsAt(object, offset).map { Api.ReactionNotificationsFrom(tlObject: $0) }
        }

    }
}
public extension Api {
    enum ReactionsNotifySettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_reactionsNotifySettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case reactionsNotifySettings(Cons_reactionsNotifySettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .reactionsNotifySettings(Cons_reactionsNotifySettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .reactionsNotifySettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReactionsNotifySettings] {
            return tlObjectsAt(object, offset).map { Api.ReactionsNotifySettings(tlObject: $0) }
        }

    }
}
public extension Api.ReactionsNotifySettings.Cons_reactionsNotifySettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var messagesNotifyFrom: Api.ReactionNotificationsFrom? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.ReactionNotificationsFrom(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var storiesNotifyFrom: Api.ReactionNotificationsFrom? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ReactionNotificationsFrom(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var pollVotesNotifyFrom: Api.ReactionNotificationsFrom? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.ReactionNotificationsFrom(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var sound: Api.NotificationSound {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.NotificationSound(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    @_alwaysEmitIntoClient var showPreviews: Api.Bool {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Bool(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(flags: Int32, messagesNotifyFrom: Api.ReactionNotificationsFrom?, storiesNotifyFrom: Api.ReactionNotificationsFrom?, pollVotesNotifyFrom: Api.ReactionNotificationsFrom?, sound: Api.NotificationSound, showPreviews: Api.Bool) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(727))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, messagesNotifyFrom?.tlObject)
        tlStoreReference(_tlObject, 40, storiesNotifyFrom?.tlObject)
        tlStoreReference(_tlObject, 48, pollVotesNotifyFrom?.tlObject)
        tlStoreReference(_tlObject, 56, sound.tlObject)
        tlStoreReference(_tlObject, 64, showPreviews.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReadParticipantDate: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_readParticipantDate {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case readParticipantDate(Cons_readParticipantDate)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .readParticipantDate(Cons_readParticipantDate(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .readParticipantDate(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReadParticipantDate] {
            return tlObjectsAt(object, offset).map { Api.ReadParticipantDate(tlObject: $0) }
        }

    }
}
public extension Api.ReadParticipantDate.Cons_readParticipantDate {
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(userId: Int64, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(476))
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 24, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ReceivedNotifyMessage: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_receivedNotifyMessage {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case receivedNotifyMessage(Cons_receivedNotifyMessage)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .receivedNotifyMessage(Cons_receivedNotifyMessage(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .receivedNotifyMessage(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ReceivedNotifyMessage] {
            return tlObjectsAt(object, offset).map { Api.ReceivedNotifyMessage(tlObject: $0) }
        }

    }
}
public extension Api.ReceivedNotifyMessage.Cons_receivedNotifyMessage {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(id: Int32, flags: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1067))
        tlStore(_tlObject, 24, id)
        tlStore(_tlObject, 28, flags)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum RecentMeUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_recentMeUrlChat {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_recentMeUrlChatInvite {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_recentMeUrlStickerSet {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_recentMeUrlUnknown {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_recentMeUrlUser {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case recentMeUrlChat(Cons_recentMeUrlChat)
        case recentMeUrlChatInvite(Cons_recentMeUrlChatInvite)
        case recentMeUrlStickerSet(Cons_recentMeUrlStickerSet)
        case recentMeUrlUnknown(Cons_recentMeUrlUnknown)
        case recentMeUrlUser(Cons_recentMeUrlUser)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .recentMeUrlChat(Cons_recentMeUrlChat(tlObject: object))
            case 1:
                self = .recentMeUrlChatInvite(Cons_recentMeUrlChatInvite(tlObject: object))
            case 2:
                self = .recentMeUrlStickerSet(Cons_recentMeUrlStickerSet(tlObject: object))
            case 3:
                self = .recentMeUrlUnknown(Cons_recentMeUrlUnknown(tlObject: object))
            case 4:
                self = .recentMeUrlUser(Cons_recentMeUrlUser(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .recentMeUrlChat(let _data):
                return _data.tlObject
            case .recentMeUrlChatInvite(let _data):
                return _data.tlObject
            case .recentMeUrlStickerSet(let _data):
                return _data.tlObject
            case .recentMeUrlUnknown(let _data):
                return _data.tlObject
            case .recentMeUrlUser(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.RecentMeUrl] {
            return tlObjectsAt(object, offset).map { Api.RecentMeUrl(tlObject: $0) }
        }

    }
}
public extension Api.RecentMeUrl.Cons_recentMeUrlChat {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chatId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(url: String, chatId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1166))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStore(_tlObject, 32, chatId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RecentMeUrl.Cons_recentMeUrlChatInvite {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var chatInvite: Api.ChatInvite {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.ChatInvite(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(url: String, chatInvite: Api.ChatInvite) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1555))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, chatInvite.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RecentMeUrl.Cons_recentMeUrlStickerSet {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var set: Api.StickerSetCovered {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StickerSetCovered(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(url: String, set: Api.StickerSetCovered) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1243))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStoreReference(_tlObject, 32, set.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RecentMeUrl.Cons_recentMeUrlUnknown {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    init(url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(455))
        tlStoreReference(_tlObject, 24, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.RecentMeUrl.Cons_recentMeUrlUser {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(url: String, userId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1219))
        tlStoreReference(_tlObject, 24, url as NSString)
        tlStore(_tlObject, 32, userId)
        self.init(tlObject: _tlObject)
    }
}
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
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(721))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = maxId { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
