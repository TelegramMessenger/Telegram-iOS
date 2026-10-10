import TelegramApiObjC
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyItem {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyItemDeleted {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyItemSkipped {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyItem(Cons_storyItem)
        case storyItemDeleted(Cons_storyItemDeleted)
        case storyItemSkipped(Cons_storyItemSkipped)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyItem(Cons_storyItem(tlObject: object))
            case 1:
                self = .storyItemDeleted(Cons_storyItemDeleted(tlObject: object))
            case 2:
                self = .storyItemSkipped(Cons_storyItemSkipped(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyItem(let _data):
                return _data.tlObject
            case .storyItemDeleted(let _data):
                return _data.tlObject
            case .storyItemSkipped(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryItem] {
            return tlObjectsAt(object, offset).map { Api.StoryItem(tlObject: $0) }
        }

    }
}
public extension Api.StoryItem.Cons_storyItem {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fromId: Api.Peer? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var fwdFrom: Api.StoryFwdHeader? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.StoryFwdHeader(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var caption: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.MessageEntity.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var media: Api.MessageMedia {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageMedia(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var mediaAreas: [Api.MediaArea]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.MediaArea.tlArray(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var privacy: [Api.PrivacyRule]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.PrivacyRule.tlArray(self.tlObject, 88) } }
    }
    @_alwaysEmitIntoClient var views: Api.StoryViews? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.StoryViews(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var sentReaction: Api.Reaction? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.Reaction(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var albums: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : tlInt32sAt(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var music: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    init(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?, albums: [Int32]?, music: Api.Document?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(142))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, date)
        tlStoreReference(_tlObject, 40, fromId?.tlObject)
        tlStoreReference(_tlObject, 48, fwdFrom?.tlObject)
        tlStore(_tlObject, 36, expireDate)
        tlStoreReference(_tlObject, 56, caption.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, entities.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 72, media.tlObject)
        tlStoreReference(_tlObject, 80, mediaAreas.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 88, privacy.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 96, views?.tlObject)
        tlStoreReference(_tlObject, 104, sentReaction?.tlObject)
        tlStoreReference(_tlObject, 112, albums.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 120, music?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryItem.Cons_storyItemDeleted {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(532))
        tlStore(_tlObject, 24, id)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryItem.Cons_storyItemSkipped {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var expireDate: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    init(flags: Int32, id: Int32, date: Int32, expireDate: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1694))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, id)
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, expireDate)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum StoryReaction: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyReaction {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyReactionPublicForward {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyReactionPublicRepost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyReaction(Cons_storyReaction)
        case storyReactionPublicForward(Cons_storyReactionPublicForward)
        case storyReactionPublicRepost(Cons_storyReactionPublicRepost)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyReaction(Cons_storyReaction(tlObject: object))
            case 1:
                self = .storyReactionPublicForward(Cons_storyReactionPublicForward(tlObject: object))
            case 2:
                self = .storyReactionPublicRepost(Cons_storyReactionPublicRepost(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyReaction(let _data):
                return _data.tlObject
            case .storyReactionPublicForward(let _data):
                return _data.tlObject
            case .storyReactionPublicRepost(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryReaction] {
            return tlObjectsAt(object, offset).map { Api.StoryReaction(tlObject: $0) }
        }

    }
}
public extension Api.StoryReaction.Cons_storyReaction {
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Reaction(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(614))
        tlStoreReference(_tlObject, 32, peerId.tlObject)
        tlStore(_tlObject, 24, date)
        tlStoreReference(_tlObject, 40, reaction.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryReaction.Cons_storyReactionPublicForward {
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1228))
        tlStoreReference(_tlObject, 24, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryReaction.Cons_storyReactionPublicRepost {
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var story: Api.StoryItem {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(peerId: Api.Peer, story: Api.StoryItem) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1366))
        tlStoreReference(_tlObject, 24, peerId.tlObject)
        tlStoreReference(_tlObject, 32, story.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    indirect enum StoryView: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyView {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyViewPublicForward {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_storyViewPublicRepost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyView(Cons_storyView)
        case storyViewPublicForward(Cons_storyViewPublicForward)
        case storyViewPublicRepost(Cons_storyViewPublicRepost)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyView(Cons_storyView(tlObject: object))
            case 1:
                self = .storyViewPublicForward(Cons_storyViewPublicForward(tlObject: object))
            case 2:
                self = .storyViewPublicRepost(Cons_storyViewPublicRepost(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyView(let _data):
                return _data.tlObject
            case .storyViewPublicForward(let _data):
                return _data.tlObject
            case .storyViewPublicRepost(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryView] {
            return tlObjectsAt(object, offset).map { Api.StoryView(tlObject: $0) }
        }

    }
}
public extension Api.StoryView.Cons_storyView {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var userId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reaction: Api.Reaction? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.Reaction(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1142))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, userId)
        tlStore(_tlObject, 28, date)
        tlStoreReference(_tlObject, 40, reaction?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryView.Cons_storyViewPublicForward {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var message: Api.Message {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(flags: Int32, message: Api.Message) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(917))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, message.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.StoryView.Cons_storyViewPublicRepost {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peerId: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var story: Api.StoryItem {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    init(flags: Int32, peerId: Api.Peer, story: Api.StoryItem) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1240))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, peerId.tlObject)
        tlStoreReference(_tlObject, 40, story.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum StoryViews: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyViews {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyViews(Cons_storyViews)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyViews(Cons_storyViews(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyViews(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.StoryViews] {
            return tlObjectsAt(object, offset).map { Api.StoryViews(tlObject: $0) }
        }

    }
}
public extension Api.StoryViews.Cons_storyViews {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var viewsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwardsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var reactions: [Api.ReactionCount]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : Api.ReactionCount.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var reactionsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 56, 1) ? tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var recentViewers: [Int64]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlInt64sAt(self.tlObject, 48) } }
    }
    init(flags: Int32, viewsCount: Int32, forwardsCount: Int32?, reactions: [Api.ReactionCount]?, reactionsCount: Int32?, recentViewers: [Int64]?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(898))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, viewsCount)
        if let _tlValue = forwardsCount { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, reactions.map { value in value.map { item in item.tlObject } as NSArray })
        if let _tlValue = reactionsCount { tlStore(_tlObject, 36, _tlValue); _tlPresent |= 1 << 1 }
        tlStoreReference(_tlObject, 48, recentViewers.map { value in tlPackInt64(value) as NSData })
        tlStore(_tlObject, 56, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum SuggestedPost: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_suggestedPost {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case suggestedPost(Cons_suggestedPost)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .suggestedPost(Cons_suggestedPost(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .suggestedPost(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.SuggestedPost] {
            return tlObjectsAt(object, offset).map { Api.SuggestedPost(tlObject: $0) }
        }

    }
}
public extension Api.SuggestedPost.Cons_suggestedPost {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var price: Api.StarsAmount? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : Api.StarsAmount(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var scheduleDate: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, price: Api.StarsAmount?, scheduleDate: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(97))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, price?.tlObject)
        if let _tlValue = scheduleDate { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TextWithEntities: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_textWithEntities {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case textWithEntities(Cons_textWithEntities)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .textWithEntities(Cons_textWithEntities(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .textWithEntities(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TextWithEntities] {
            return tlObjectsAt(object, offset).map { Api.TextWithEntities(tlObject: $0) }
        }

    }
}
public extension Api.TextWithEntities.Cons_textWithEntities {
    @_alwaysEmitIntoClient var text: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var entities: [Api.MessageEntity] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.MessageEntity.tlArray(self.tlObject, 32) } }
    }
    init(text: String, entities: [Api.MessageEntity]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(743))
        tlStoreReference(_tlObject, 24, text as NSString)
        tlStoreReference(_tlObject, 32, entities.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Theme: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_theme {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case theme(Cons_theme)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .theme(Cons_theme(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .theme(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Theme] {
            return tlObjectsAt(object, offset).map { Api.Theme(tlObject: $0) }
        }

    }
}
public extension Api.Theme.Cons_theme {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var accessHash: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var slug: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var title: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var document: Api.Document? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : Api.Document(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    @_alwaysEmitIntoClient var settings: [Api.ThemeSettings]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.ThemeSettings.tlArray(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var emoticon: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : tlStringAt(self.tlObject, 80) } }
    }
    @_alwaysEmitIntoClient var installsCount: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 88, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    init(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1037))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, id)
        tlStore(_tlObject, 40, accessHash)
        tlStoreReference(_tlObject, 48, slug as NSString)
        tlStoreReference(_tlObject, 56, title as NSString)
        tlStoreReference(_tlObject, 64, document?.tlObject)
        tlStoreReference(_tlObject, 72, settings.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 80, emoticon.map { value in value as NSString })
        if let _tlValue = installsCount { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 88, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum ThemeSettings: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_themeSettings {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case themeSettings(Cons_themeSettings)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .themeSettings(Cons_themeSettings(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .themeSettings(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.ThemeSettings] {
            return tlObjectsAt(object, offset).map { Api.ThemeSettings(tlObject: $0) }
        }

    }
}
public extension Api.ThemeSettings.Cons_themeSettings {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var baseTheme: Api.BaseTheme {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.BaseTheme(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var accentColor: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var outboxAccentColor: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var messageColors: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : tlInt32sAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var wallpaper: Api.WallPaper? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.WallPaper(tlObject: tlObjectAt(self.tlObject, 56)) } }
    }
    init(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1652))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 40, baseTheme.tlObject)
        tlStore(_tlObject, 28, accentColor)
        if let _tlValue = outboxAccentColor { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 48, messageColors.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 56, wallpaper?.tlObject)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum Timezone: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_timezone {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case timezone(Cons_timezone)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .timezone(Cons_timezone(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .timezone(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.Timezone] {
            return tlObjectsAt(object, offset).map { Api.Timezone(tlObject: $0) }
        }

    }
}
public extension Api.Timezone.Cons_timezone {
    @_alwaysEmitIntoClient var id: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var utcOffset: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(id: String, name: String, utcOffset: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1692))
        tlStoreReference(_tlObject, 32, id as NSString)
        tlStoreReference(_tlObject, 40, name as NSString)
        tlStore(_tlObject, 24, utcOffset)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TodoCompletion: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_todoCompletion {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case todoCompletion(Cons_todoCompletion)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .todoCompletion(Cons_todoCompletion(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .todoCompletion(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TodoCompletion] {
            return tlObjectsAt(object, offset).map { Api.TodoCompletion(tlObject: $0) }
        }

    }
}
public extension Api.TodoCompletion.Cons_todoCompletion {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var completedBy: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(id: Int32, completedBy: Api.Peer, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(233))
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 32, completedBy.tlObject)
        tlStore(_tlObject, 28, date)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TodoItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_todoItem {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case todoItem(Cons_todoItem)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .todoItem(Cons_todoItem(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .todoItem(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TodoItem] {
            return tlObjectsAt(object, offset).map { Api.TodoItem(tlObject: $0) }
        }

    }
}
public extension Api.TodoItem.Cons_todoItem {
    @_alwaysEmitIntoClient var id: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    init(id: Int32, title: Api.TextWithEntities) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1344))
        tlStore(_tlObject, 24, id)
        tlStoreReference(_tlObject, 32, title.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TodoList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_todoList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case todoList(Cons_todoList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .todoList(Cons_todoList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .todoList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TodoList] {
            return tlObjectsAt(object, offset).map { Api.TodoList(tlObject: $0) }
        }

    }
}
public extension Api.TodoList.Cons_todoList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var title: Api.TextWithEntities {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TextWithEntities(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var list: [Api.TodoItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TodoItem.tlArray(self.tlObject, 40) } }
    }
    init(flags: Int32, title: Api.TextWithEntities, list: [Api.TodoItem]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(475))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, title.tlObject)
        tlStoreReference(_tlObject, 40, list.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TonConnectManifest: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectManifest {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectManifest(Cons_tonConnectManifest)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectManifest(Cons_tonConnectManifest(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectManifest(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TonConnectManifest] {
            return tlObjectsAt(object, offset).map { Api.TonConnectManifest(tlObject: $0) }
        }

    }
}
public extension Api.TonConnectManifest.Cons_tonConnectManifest {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var name: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var icon: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 48) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 48)) } }
    }
    init(flags: Int32, url: String, name: String, icon: Api.WebDocument?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(113))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStoreReference(_tlObject, 40, name as NSString)
        tlStoreReference(_tlObject, 48, icon?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TonConnectNextEventId: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectNextEventId {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectNextEventId(Cons_tonConnectNextEventId)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectNextEventId(Cons_tonConnectNextEventId(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectNextEventId(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TonConnectNextEventId] {
            return tlObjectsAt(object, offset).map { Api.TonConnectNextEventId(tlObject: $0) }
        }

    }
}
public extension Api.TonConnectNextEventId.Cons_tonConnectNextEventId {
    @_alwaysEmitIntoClient var eventId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }
    }
    init(eventId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(574))
        tlStore(_tlObject, 24, eventId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TonConnectRequest: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectRequest {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectRequest(Cons_tonConnectRequest)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectRequest(Cons_tonConnectRequest(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectRequest(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TonConnectRequest] {
            return tlObjectsAt(object, offset).map { Api.TonConnectRequest(tlObject: $0) }
        }

    }
}
public extension Api.TonConnectRequest.Cons_tonConnectRequest {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var sessionId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var msgId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var body: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var topic: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var traceId: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    init(flags: Int32, sessionId: Int64, msgId: Int32, body: Buffer, expires: Int32, topic: String?, traceId: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1047))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, sessionId)
        tlStore(_tlObject, 28, msgId)
        tlStoreReference(_tlObject, 48, body.makeData() as NSData)
        tlStore(_tlObject, 32, expires)
        tlStoreReference(_tlObject, 56, topic.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, traceId.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TonConnectSession: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectSession {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectSession(Cons_tonConnectSession)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectSession(Cons_tonConnectSession(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectSession(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TonConnectSession] {
            return tlObjectsAt(object, offset).map { Api.TonConnectSession(tlObject: $0) }
        }

    }
}
public extension Api.TonConnectSession.Cons_tonConnectSession {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var id: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var dappClientId: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var clientId: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var nonce: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var manifest: Api.TonConnectManifest? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : Api.TonConnectManifest(tlObject: tlObjectAt(self.tlObject, 72)) } }
    }
    @_alwaysEmitIntoClient var manifestError: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 80, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    init(flags: Int32, id: Int64, dappClientId: String, clientId: String?, nonce: Buffer, manifest: Api.TonConnectManifest?, manifestError: Int32?, date: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(114))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 40, id)
        tlStoreReference(_tlObject, 48, dappClientId as NSString)
        tlStoreReference(_tlObject, 56, clientId.map { value in value as NSString })
        tlStoreReference(_tlObject, 64, nonce.makeData() as NSData)
        tlStoreReference(_tlObject, 72, manifest?.tlObject)
        if let _tlValue = manifestError { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 80, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TopPeer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_topPeer {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case topPeer(Cons_topPeer)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .topPeer(Cons_topPeer(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .topPeer(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TopPeer] {
            return tlObjectsAt(object, offset).map { Api.TopPeer(tlObject: $0) }
        }

    }
}
public extension Api.TopPeer.Cons_topPeer {
    @_alwaysEmitIntoClient var peer: Api.Peer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var rating: Double {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Double.self) } }
    }
    init(peer: Api.Peer, rating: Double) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1560))
        tlStoreReference(_tlObject, 24, peer.tlObject)
        tlStore(_tlObject, 32, rating)
        self.init(tlObject: _tlObject)
    }
}
public extension Api {
    enum TopPeerCategory: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        case topPeerCategoryBotsApp
        case topPeerCategoryBotsGuestChat
        case topPeerCategoryBotsInline
        case topPeerCategoryBotsPM
        case topPeerCategoryChannels
        case topPeerCategoryCorrespondents
        case topPeerCategoryForwardChats
        case topPeerCategoryForwardUsers
        case topPeerCategoryGroups
        case topPeerCategoryPhoneCalls


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .topPeerCategoryBotsApp
            case 1:
                self = .topPeerCategoryBotsGuestChat
            case 2:
                self = .topPeerCategoryBotsInline
            case 3:
                self = .topPeerCategoryBotsPM
            case 4:
                self = .topPeerCategoryChannels
            case 5:
                self = .topPeerCategoryCorrespondents
            case 6:
                self = .topPeerCategoryForwardChats
            case 7:
                self = .topPeerCategoryForwardUsers
            case 8:
                self = .topPeerCategoryGroups
            case 9:
                self = .topPeerCategoryPhoneCalls
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .topPeerCategoryBotsApp:
                return TLObjectSingleton(TLApiConstructorAt(1679))
            case .topPeerCategoryBotsGuestChat:
                return TLObjectSingleton(TLApiConstructorAt(685))
            case .topPeerCategoryBotsInline:
                return TLObjectSingleton(TLApiConstructorAt(127))
            case .topPeerCategoryBotsPM:
                return TLObjectSingleton(TLApiConstructorAt(1109))
            case .topPeerCategoryChannels:
                return TLObjectSingleton(TLApiConstructorAt(139))
            case .topPeerCategoryCorrespondents:
                return TLObjectSingleton(TLApiConstructorAt(42))
            case .topPeerCategoryForwardChats:
                return TLObjectSingleton(TLApiConstructorAt(1666))
            case .topPeerCategoryForwardUsers:
                return TLObjectSingleton(TLApiConstructorAt(1085))
            case .topPeerCategoryGroups:
                return TLObjectSingleton(TLApiConstructorAt(1236))
            case .topPeerCategoryPhoneCalls:
                return TLObjectSingleton(TLApiConstructorAt(205))
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TopPeerCategory] {
            return tlObjectsAt(object, offset).map { Api.TopPeerCategory(tlObject: $0) }
        }

    }
}
public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_topPeerCategoryPeers {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case topPeerCategoryPeers(Cons_topPeerCategoryPeers)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .topPeerCategoryPeers(Cons_topPeerCategoryPeers(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .topPeerCategoryPeers(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.TopPeerCategoryPeers] {
            return tlObjectsAt(object, offset).map { Api.TopPeerCategoryPeers(tlObject: $0) }
        }

    }
}
public extension Api.TopPeerCategoryPeers.Cons_topPeerCategoryPeers {
    @_alwaysEmitIntoClient var category: Api.TopPeerCategory {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TopPeerCategory(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var peers: [Api.TopPeer] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TopPeer.tlArray(self.tlObject, 40) } }
    }
    init(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1661))
        tlStoreReference(_tlObject, 32, category.tlObject)
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 40, peers.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
