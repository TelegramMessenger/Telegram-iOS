import TelegramApiObjC
public extension Api.stories {
    enum CanSendStoryCount: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_canSendStoryCount {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case canSendStoryCount(Cons_canSendStoryCount)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .canSendStoryCount(Cons_canSendStoryCount(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .canSendStoryCount(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.CanSendStoryCount] {
            return tlObjectsAt(object, offset).map { Api.stories.CanSendStoryCount(tlObject: $0) }
        }

    }
}
public extension Api.stories.CanSendStoryCount.Cons_canSendStoryCount {
    @_alwaysEmitIntoClient var countRemains: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(countRemains: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1294))
        tlStore(_tlObject, 24, countRemains)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum FoundStories: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_foundStories {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case foundStories(Cons_foundStories)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .foundStories(Cons_foundStories(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .foundStories(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.FoundStories] {
            return tlObjectsAt(object, offset).map { Api.stories.FoundStories(tlObject: $0) }
        }

    }
}
public extension Api.stories.FoundStories.Cons_foundStories {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stories: [Api.FoundStory] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.FoundStory.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, count: Int32, stories: [Api.FoundStory], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1477))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, stories.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum PeerStories: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_peerStories {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case peerStories(Cons_peerStories)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .peerStories(Cons_peerStories(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .peerStories(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.PeerStories] {
            return tlObjectsAt(object, offset).map { Api.stories.PeerStories(tlObject: $0) }
        }

    }
}
public extension Api.stories.PeerStories.Cons_peerStories {
    @_alwaysEmitIntoClient var stories: Api.PeerStories {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.PeerStories(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(stories: Api.PeerStories, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1339))
        tlStoreReference(_tlObject, 24, stories.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum Stories: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_stories {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case stories(Cons_stories)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .stories(Cons_stories(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .stories(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.Stories] {
            return tlObjectsAt(object, offset).map { Api.stories.Stories(tlObject: $0) }
        }

    }
}
public extension Api.stories.Stories.Cons_stories {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var stories: [Api.StoryItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryItem.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var pinnedToTop: [Int32]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlInt32sAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    init(flags: Int32, count: Int32, stories: [Api.StoryItem], pinnedToTop: [Int32]?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(634))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, stories.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, pinnedToTop.map { value in tlPackInt32(value) as NSData })
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum StoryReactionsList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyReactionsList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyReactionsList(Cons_storyReactionsList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyReactionsList(Cons_storyReactionsList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyReactionsList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.StoryReactionsList] {
            return tlObjectsAt(object, offset).map { Api.stories.StoryReactionsList(tlObject: $0) }
        }

    }
}
public extension Api.stories.StoryReactionsList.Cons_storyReactionsList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactions: [Api.StoryReaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryReaction.tlArray(self.tlObject, 32) } }
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
    init(flags: Int32, count: Int32, reactions: [Api.StoryReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1103))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStoreReference(_tlObject, 32, reactions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
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

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.StoryViews] {
            return tlObjectsAt(object, offset).map { Api.stories.StoryViews(tlObject: $0) }
        }

    }
}
public extension Api.stories.StoryViews.Cons_storyViews {
    @_alwaysEmitIntoClient var views: [Api.StoryViews] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryViews.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(views: [Api.StoryViews], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1452))
        tlStoreReference(_tlObject, 24, views.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.stories {
    enum StoryViewsList: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_storyViewsList {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case storyViewsList(Cons_storyViewsList)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .storyViewsList(Cons_storyViewsList(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .storyViewsList(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.stories.StoryViewsList] {
            return tlObjectsAt(object, offset).map { Api.stories.StoryViewsList(tlObject: $0) }
        }

    }
}
public extension Api.stories.StoryViewsList.Cons_storyViewsList {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var viewsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var forwardsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var reactionsCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var views: [Api.StoryView] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.StoryView.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    init(flags: Int32, count: Int32, viewsCount: Int32, forwardsCount: Int32, reactionsCount: Int32, views: [Api.StoryView], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(580))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, count)
        tlStore(_tlObject, 32, viewsCount)
        tlStore(_tlObject, 36, forwardsCount)
        tlStore(_tlObject, 40, reactionsCount)
        tlStoreReference(_tlObject, 48, views.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 72, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.toncenter {
    enum ApiResponse: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_apiResponse {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case apiResponse(Cons_apiResponse)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .apiResponse(Cons_apiResponse(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .apiResponse(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.toncenter.ApiResponse] {
            return tlObjectsAt(object, offset).map { Api.toncenter.ApiResponse(tlObject: $0) }
        }

    }
}
public extension Api.toncenter.ApiResponse.Cons_apiResponse {
    @_alwaysEmitIntoClient var response: Api.DataJSON {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    init(response: Api.DataJSON) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1116))
        tlStoreReference(_tlObject, 24, response.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.toncenter {
    enum StreamingUrl: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_streamingUrl {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case streamingUrl(Cons_streamingUrl)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .streamingUrl(Cons_streamingUrl(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .streamingUrl(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.toncenter.StreamingUrl] {
            return tlObjectsAt(object, offset).map { Api.toncenter.StreamingUrl(tlObject: $0) }
        }

    }
}
public extension Api.toncenter.StreamingUrl.Cons_streamingUrl {
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(url: String, expires: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(168))
        tlStoreReference(_tlObject, 32, url as NSString)
        tlStore(_tlObject, 24, expires)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates {
    indirect enum ChannelDifference: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_channelDifference {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelDifferenceEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_channelDifferenceTooLong {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case channelDifference(Cons_channelDifference)
        case channelDifferenceEmpty(Cons_channelDifferenceEmpty)
        case channelDifferenceTooLong(Cons_channelDifferenceTooLong)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .channelDifference(Cons_channelDifference(tlObject: object))
            case 1:
                self = .channelDifferenceEmpty(Cons_channelDifferenceEmpty(tlObject: object))
            case 2:
                self = .channelDifferenceTooLong(Cons_channelDifferenceTooLong(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .channelDifference(let _data):
                return _data.tlObject
            case .channelDifferenceEmpty(let _data):
                return _data.tlObject
            case .channelDifferenceTooLong(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.updates.ChannelDifference] {
            return tlObjectsAt(object, offset).map { Api.updates.ChannelDifference(tlObject: $0) }
        }

    }
}
public extension Api.updates.ChannelDifference.Cons_channelDifference {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var timeout: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 72, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var newMessages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var otherUpdates: [Api.Update] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 64) } }
    }
    init(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(221))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, pts)
        if let _tlValue = timeout { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 40, newMessages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, otherUpdates.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 72, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates.ChannelDifference.Cons_channelDifferenceEmpty {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var timeout: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 40, 0) ? tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) : nil } }
    }
    init(flags: Int32, pts: Int32, timeout: Int32?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(401))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 28, pts)
        if let _tlValue = timeout { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }
        tlStore(_tlObject, 40, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates.ChannelDifference.Cons_channelDifferenceTooLong {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var timeout: Int32? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 64, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }
    }
    @_alwaysEmitIntoClient var dialog: Api.Dialog {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Dialog(tlObject: tlObjectAt(self.tlObject, 32)) } }
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
    init(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1069))
        var _tlPresent: UInt64 = 0
        tlStore(_tlObject, 24, flags)
        if let _tlValue = timeout { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }
        tlStoreReference(_tlObject, 32, dialog.tlObject)
        tlStoreReference(_tlObject, 40, messages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStore(_tlObject, 64, _tlPresent)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates {
    enum Difference: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_difference {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_differenceEmpty {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_differenceSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_differenceTooLong {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case difference(Cons_difference)
        case differenceEmpty(Cons_differenceEmpty)
        case differenceSlice(Cons_differenceSlice)
        case differenceTooLong(Cons_differenceTooLong)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .difference(Cons_difference(tlObject: object))
            case 1:
                self = .differenceEmpty(Cons_differenceEmpty(tlObject: object))
            case 2:
                self = .differenceSlice(Cons_differenceSlice(tlObject: object))
            case 3:
                self = .differenceTooLong(Cons_differenceTooLong(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .difference(let _data):
                return _data.tlObject
            case .differenceEmpty(let _data):
                return _data.tlObject
            case .differenceSlice(let _data):
                return _data.tlObject
            case .differenceTooLong(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.updates.Difference] {
            return tlObjectsAt(object, offset).map { Api.updates.Difference(tlObject: $0) }
        }

    }
}
public extension Api.updates.Difference.Cons_difference {
    @_alwaysEmitIntoClient var newMessages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newEncryptedMessages: [Api.EncryptedMessage] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EncryptedMessage.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var otherUpdates: [Api.Update] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var state: Api.updates.State {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.updates.State(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(7))
        tlStoreReference(_tlObject, 24, newMessages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, newEncryptedMessages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, otherUpdates.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, state.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates.Difference.Cons_differenceEmpty {
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seq: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    init(date: Int32, seq: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(597))
        tlStore(_tlObject, 24, date)
        tlStore(_tlObject, 28, seq)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates.Difference.Cons_differenceSlice {
    @_alwaysEmitIntoClient var newMessages: [Api.Message] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Message.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var newEncryptedMessages: [Api.EncryptedMessage] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.EncryptedMessage.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var otherUpdates: [Api.Update] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Update.tlArray(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var intermediateState: Api.updates.State {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.updates.State(tlObject: tlObjectAt(self.tlObject, 64)) } }
    }
    init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1093))
        tlStoreReference(_tlObject, 24, newMessages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, newEncryptedMessages.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, otherUpdates.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 56, users.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, intermediateState.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates.Difference.Cons_differenceTooLong {
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(pts: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(483))
        tlStore(_tlObject, 24, pts)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.updates {
    enum State: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_state {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case state(Cons_state)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .state(Cons_state(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .state(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.updates.State] {
            return tlObjectsAt(object, offset).map { Api.updates.State(tlObject: $0) }
        }

    }
}
public extension Api.updates.State.Cons_state {
    @_alwaysEmitIntoClient var pts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var qts: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var date: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var seq: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 36, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var unreadCount: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 40, as: Int32.self) } }
    }
    init(pts: Int32, qts: Int32, date: Int32, seq: Int32, unreadCount: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1072))
        tlStore(_tlObject, 24, pts)
        tlStore(_tlObject, 28, qts)
        tlStore(_tlObject, 32, date)
        tlStore(_tlObject, 36, seq)
        tlStore(_tlObject, 40, unreadCount)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.upload {
    enum CdnFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_cdnFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_cdnFileReuploadNeeded {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case cdnFile(Cons_cdnFile)
        case cdnFileReuploadNeeded(Cons_cdnFileReuploadNeeded)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .cdnFile(Cons_cdnFile(tlObject: object))
            case 1:
                self = .cdnFileReuploadNeeded(Cons_cdnFileReuploadNeeded(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .cdnFile(let _data):
                return _data.tlObject
            case .cdnFileReuploadNeeded(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.upload.CdnFile] {
            return tlObjectsAt(object, offset).map { Api.upload.CdnFile(tlObject: $0) }
        }

    }
}
public extension Api.upload.CdnFile.Cons_cdnFile {
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1098))
        tlStoreReference(_tlObject, 24, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.upload.CdnFile.Cons_cdnFileReuploadNeeded {
    @_alwaysEmitIntoClient var requestToken: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(requestToken: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1568))
        tlStoreReference(_tlObject, 24, requestToken.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.upload {
    enum File: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_file {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_fileCdnRedirect {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case file(Cons_file)
        case fileCdnRedirect(Cons_fileCdnRedirect)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .file(Cons_file(tlObject: object))
            case 1:
                self = .fileCdnRedirect(Cons_fileCdnRedirect(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .file(let _data):
                return _data.tlObject
            case .fileCdnRedirect(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.upload.File] {
            return tlObjectsAt(object, offset).map { Api.upload.File(tlObject: $0) }
        }

    }
}
public extension Api.upload.File.Cons_file {
    @_alwaysEmitIntoClient var type: Api.storage.FileType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.storage.FileType(tlObject: tlObjectAt(self.tlObject, 32)) } }
    }
    @_alwaysEmitIntoClient var mtime: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    init(type: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(61))
        tlStoreReference(_tlObject, 32, type.tlObject)
        tlStore(_tlObject, 24, mtime)
        tlStoreReference(_tlObject, 40, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.upload.File.Cons_fileCdnRedirect {
    @_alwaysEmitIntoClient var dcId: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var fileToken: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var encryptionKey: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var encryptionIv: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var fileHashes: [Api.FileHash] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.FileHash.tlArray(self.tlObject, 56) } }
    }
    init(dcId: Int32, fileToken: Buffer, encryptionKey: Buffer, encryptionIv: Buffer, fileHashes: [Api.FileHash]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1590))
        tlStore(_tlObject, 24, dcId)
        tlStoreReference(_tlObject, 32, fileToken.makeData() as NSData)
        tlStoreReference(_tlObject, 40, encryptionKey.makeData() as NSData)
        tlStoreReference(_tlObject, 48, encryptionIv.makeData() as NSData)
        tlStoreReference(_tlObject, 56, fileHashes.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.upload {
    enum WebFile: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_webFile {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case webFile(Cons_webFile)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .webFile(Cons_webFile(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .webFile(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.upload.WebFile] {
            return tlObjectsAt(object, offset).map { Api.upload.WebFile(tlObject: $0) }
        }

    }
}
public extension Api.upload.WebFile.Cons_webFile {
    @_alwaysEmitIntoClient var size: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var mimeType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var fileType: Api.storage.FileType {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.storage.FileType(tlObject: tlObjectAt(self.tlObject, 40)) } }
    }
    @_alwaysEmitIntoClient var mtime: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var bytes: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 48) } }
    }
    init(size: Int32, mimeType: String, fileType: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(231))
        tlStore(_tlObject, 24, size)
        tlStoreReference(_tlObject, 32, mimeType as NSString)
        tlStoreReference(_tlObject, 40, fileType.tlObject)
        tlStore(_tlObject, 28, mtime)
        tlStoreReference(_tlObject, 48, bytes.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.users {
    enum SavedMusic: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_savedMusic {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_savedMusicNotModified {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case savedMusic(Cons_savedMusic)
        case savedMusicNotModified(Cons_savedMusicNotModified)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .savedMusic(Cons_savedMusic(tlObject: object))
            case 1:
                self = .savedMusicNotModified(Cons_savedMusicNotModified(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .savedMusic(let _data):
                return _data.tlObject
            case .savedMusicNotModified(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.users.SavedMusic] {
            return tlObjectsAt(object, offset).map { Api.users.SavedMusic(tlObject: $0) }
        }

    }
}
public extension Api.users.SavedMusic.Cons_savedMusic {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var documents: [Api.Document] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Document.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, documents: [Api.Document]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(336))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, documents.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.users.SavedMusic.Cons_savedMusicNotModified {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    init(count: Int32) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1483))
        tlStore(_tlObject, 24, count)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.users {
    enum UserFull: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userFull {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userFull(Cons_userFull)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userFull(Cons_userFull(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userFull(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.users.UserFull] {
            return tlObjectsAt(object, offset).map { Api.users.UserFull(tlObject: $0) }
        }

    }
}
public extension Api.users.UserFull.Cons_userFull {
    @_alwaysEmitIntoClient var fullUser: Api.UserFull {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.UserFull(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var chats: [Api.Chat] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Chat.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 40) } }
    }
    init(fullUser: Api.UserFull, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(375))
        tlStoreReference(_tlObject, 24, fullUser.tlObject)
        tlStoreReference(_tlObject, 32, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.users {
    enum Users: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_users {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        @frozen public struct Cons_usersSlice {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case users(Cons_users)
        case usersSlice(Cons_usersSlice)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .users(Cons_users(tlObject: object))
            case 1:
                self = .usersSlice(Cons_usersSlice(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .users(let _data):
                return _data.tlObject
            case .usersSlice(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.users.Users] {
            return tlObjectsAt(object, offset).map { Api.users.Users(tlObject: $0) }
        }

    }
}
public extension Api.users.Users.Cons_users {
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 24) } }
    }
    init(users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(627))
        tlStoreReference(_tlObject, 24, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.users.Users.Cons_usersSlice {
    @_alwaysEmitIntoClient var count: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(count: Int32, users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(314))
        tlStore(_tlObject, 24, count)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum EncryptedSecretPhrasePart: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_encryptedSecretPhrasePart {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case encryptedSecretPhrasePart(Cons_encryptedSecretPhrasePart)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .encryptedSecretPhrasePart(Cons_encryptedSecretPhrasePart(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .encryptedSecretPhrasePart(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.EncryptedSecretPhrasePart] {
            return tlObjectsAt(object, offset).map { Api.wallet.EncryptedSecretPhrasePart(tlObject: $0) }
        }

    }
}
public extension Api.wallet.EncryptedSecretPhrasePart.Cons_encryptedSecretPhrasePart {
    @_alwaysEmitIntoClient var data: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    init(data: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(164))
        tlStoreReference(_tlObject, 24, data.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum ExistingBalance: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_existingBalance {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case existingBalance(Cons_existingBalance)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .existingBalance(Cons_existingBalance(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .existingBalance(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.ExistingBalance] {
            return tlObjectsAt(object, offset).map { Api.wallet.ExistingBalance(tlObject: $0) }
        }

    }
}
public extension Api.wallet.ExistingBalance.Cons_existingBalance {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var url: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(flags: Int32, url: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1249))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, url as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum HolderDc: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_holderDc {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case holderDc(Cons_holderDc)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .holderDc(Cons_holderDc(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .holderDc(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.HolderDc] {
            return tlObjectsAt(object, offset).map { Api.wallet.HolderDc(tlObject: $0) }
        }

    }
}
public extension Api.wallet.HolderDc.Cons_holderDc {
    @_alwaysEmitIntoClient var dc: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var publicKey: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 32) } }
    }
    init(dc: Int32, publicKey: Buffer) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1646))
        tlStore(_tlObject, 24, dc)
        tlStoreReference(_tlObject, 32, publicKey.makeData() as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum NftAttribute: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_nftAttribute {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case nftAttribute(Cons_nftAttribute)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .nftAttribute(Cons_nftAttribute(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .nftAttribute(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.NftAttribute] {
            return tlObjectsAt(object, offset).map { Api.wallet.NftAttribute(tlObject: $0) }
        }

    }
}
public extension Api.wallet.NftAttribute.Cons_nftAttribute {
    @_alwaysEmitIntoClient var traitType: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var value: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    init(traitType: String, value: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(493))
        tlStoreReference(_tlObject, 24, traitType as NSString)
        tlStoreReference(_tlObject, 32, value as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum NftItem: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_nftItem {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case nftItem(Cons_nftItem)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .nftItem(Cons_nftItem(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .nftItem(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.NftItem] {
            return tlObjectsAt(object, offset).map { Api.wallet.NftItem(tlObject: $0) }
        }

    }
}
public extension Api.wallet.NftItem.Cons_nftItem {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var collectionAddress: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 32) ? nil : tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var address: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    @_alwaysEmitIntoClient var ownerAddress: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 48) } }
    }
    @_alwaysEmitIntoClient var index: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 56) } }
    }
    @_alwaysEmitIntoClient var name: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 64) ? nil : tlStringAt(self.tlObject, 64) } }
    }
    @_alwaysEmitIntoClient var description: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 72) ? nil : tlStringAt(self.tlObject, 72) } }
    }
    @_alwaysEmitIntoClient var image: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 80) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 80)) } }
    }
    @_alwaysEmitIntoClient var imageSmall: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 88) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 88)) } }
    }
    @_alwaysEmitIntoClient var contentUrl: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 96) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 96)) } }
    }
    @_alwaysEmitIntoClient var lottie: Api.WebDocument? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 104) ? nil : Api.WebDocument(tlObject: tlObjectAt(self.tlObject, 104)) } }
    }
    @_alwaysEmitIntoClient var attributes: [Api.wallet.NftAttribute]? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 112) ? nil : Api.wallet.NftAttribute.tlArray(self.tlObject, 112) } }
    }
    @_alwaysEmitIntoClient var extra: Api.DataJSON? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 120) ? nil : Api.DataJSON(tlObject: tlObjectAt(self.tlObject, 120)) } }
    }
    init(flags: Int32, collectionAddress: String?, address: String, ownerAddress: String, index: String, name: String?, description: String?, image: Api.WebDocument?, imageSmall: Api.WebDocument?, contentUrl: Api.WebDocument?, lottie: Api.WebDocument?, attributes: [Api.wallet.NftAttribute]?, extra: Api.DataJSON?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(332))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, collectionAddress.map { value in value as NSString })
        tlStoreReference(_tlObject, 40, address as NSString)
        tlStoreReference(_tlObject, 48, ownerAddress as NSString)
        tlStoreReference(_tlObject, 56, index as NSString)
        tlStoreReference(_tlObject, 64, name.map { value in value as NSString })
        tlStoreReference(_tlObject, 72, description.map { value in value as NSString })
        tlStoreReference(_tlObject, 80, image?.tlObject)
        tlStoreReference(_tlObject, 88, imageSmall?.tlObject)
        tlStoreReference(_tlObject, 96, contentUrl?.tlObject)
        tlStoreReference(_tlObject, 104, lottie?.tlObject)
        tlStoreReference(_tlObject, 112, attributes.map { value in value.map { item in item.tlObject } as NSArray })
        tlStoreReference(_tlObject, 120, extra?.tlObject)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum NftItems: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_nftItems {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case nftItems(Cons_nftItems)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .nftItems(Cons_nftItems(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .nftItems(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.NftItems] {
            return tlObjectsAt(object, offset).map { Api.wallet.NftItems(tlObject: $0) }
        }

    }
}
public extension Api.wallet.NftItems.Cons_nftItems {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var items: [Api.wallet.NftItem] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.wallet.NftItem.tlArray(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var nextOffset: String? {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 40) ? nil : tlStringAt(self.tlObject, 40) } }
    }
    init(flags: Int32, items: [Api.wallet.NftItem], nextOffset: String?) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(774))
        tlStore(_tlObject, 24, flags)
        tlStoreReference(_tlObject, 32, items.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 40, nextOffset.map { value in value as NSString })
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum ProofChallenge: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_proofChallenge {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case proofChallenge(Cons_proofChallenge)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .proofChallenge(Cons_proofChallenge(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .proofChallenge(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.ProofChallenge] {
            return tlObjectsAt(object, offset).map { Api.wallet.ProofChallenge(tlObject: $0) }
        }

    }
}
public extension Api.wallet.ProofChallenge.Cons_proofChallenge {
    @_alwaysEmitIntoClient var payload: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }
    }
    @_alwaysEmitIntoClient var expires: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var domain: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 40) } }
    }
    init(payload: String, expires: Int32, domain: String) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(984))
        tlStoreReference(_tlObject, 32, payload as NSString)
        tlStore(_tlObject, 24, expires)
        tlStoreReference(_tlObject, 40, domain as NSString)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum SecretPhraseParts: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_secretPhraseParts {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case secretPhraseParts(Cons_secretPhraseParts)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .secretPhraseParts(Cons_secretPhraseParts(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .secretPhraseParts(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.SecretPhraseParts] {
            return tlObjectsAt(object, offset).map { Api.wallet.SecretPhraseParts(tlObject: $0) }
        }

    }
}
public extension Api.wallet.SecretPhraseParts.Cons_secretPhraseParts {
    @_alwaysEmitIntoClient var token: String {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var dcs: [Int32] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlInt32sAt(self.tlObject, 32) } }
    }
    init(token: String, dcs: [Int32]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(1506))
        tlStoreReference(_tlObject, 24, token as NSString)
        tlStoreReference(_tlObject, 32, tlPackInt32(dcs) as NSData)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum TonConnectChallenge: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectChallenge {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectChallenge(Cons_tonConnectChallenge)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectChallenge(Cons_tonConnectChallenge(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectChallenge(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.TonConnectChallenge] {
            return tlObjectsAt(object, offset).map { Api.wallet.TonConnectChallenge(tlObject: $0) }
        }

    }
}
public extension Api.wallet.TonConnectChallenge.Cons_tonConnectChallenge {
    @_alwaysEmitIntoClient var challenge: Buffer {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBufferAt(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var eventId: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    init(challenge: Buffer, eventId: Int64) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(491))
        tlStoreReference(_tlObject, 24, challenge.makeData() as NSData)
        tlStore(_tlObject, 32, eventId)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum TonConnectPending: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectPending {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectPending(Cons_tonConnectPending)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectPending(Cons_tonConnectPending(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectPending(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.TonConnectPending] {
            return tlObjectsAt(object, offset).map { Api.wallet.TonConnectPending(tlObject: $0) }
        }

    }
}
public extension Api.wallet.TonConnectPending.Cons_tonConnectPending {
    @_alwaysEmitIntoClient var session: Api.TonConnectSession {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TonConnectSession(tlObject: tlObjectAt(self.tlObject, 24)) } }
    }
    @_alwaysEmitIntoClient var requests: [Api.TonConnectRequest] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TonConnectRequest.tlArray(self.tlObject, 32) } }
    }
    init(session: Api.TonConnectSession, requests: [Api.TonConnectRequest]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(845))
        tlStoreReference(_tlObject, 24, session.tlObject)
        tlStoreReference(_tlObject, 32, requests.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum TonConnectSessions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_tonConnectSessions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case tonConnectSessions(Cons_tonConnectSessions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .tonConnectSessions(Cons_tonConnectSessions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .tonConnectSessions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.TonConnectSessions] {
            return tlObjectsAt(object, offset).map { Api.wallet.TonConnectSessions(tlObject: $0) }
        }

    }
}
public extension Api.wallet.TonConnectSessions.Cons_tonConnectSessions {
    @_alwaysEmitIntoClient var sessions: [Api.TonConnectSession] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.TonConnectSession.tlArray(self.tlObject, 24) } }
    }
    init(sessions: [Api.TonConnectSession]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(92))
        tlStoreReference(_tlObject, 24, sessions.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum Transactions: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_transactions {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case transactions(Cons_transactions)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .transactions(Cons_transactions(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .transactions(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.Transactions] {
            return tlObjectsAt(object, offset).map { Api.wallet.Transactions(tlObject: $0) }
        }

    }
}
public extension Api.wallet.Transactions.Cons_transactions {
    @_alwaysEmitIntoClient var flags: Int32 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int32.self) } }
    }
    @_alwaysEmitIntoClient var balance: Int64 {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 32, as: Int64.self) } }
    }
    @_alwaysEmitIntoClient var transactions: [Api.WalletTransaction] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WalletTransaction.tlArray(self.tlObject, 40) } }
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
    init(flags: Int32, balance: Int64, transactions: [Api.WalletTransaction], nextOffset: String?, chats: [Api.Chat], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(438))
        tlStore(_tlObject, 24, flags)
        tlStore(_tlObject, 32, balance)
        tlStoreReference(_tlObject, 40, transactions.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 48, nextOffset.map { value in value as NSString })
        tlStoreReference(_tlObject, 56, chats.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 64, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
public extension Api.wallet {
    enum UserAddresses: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {
        @frozen public struct Cons_userAddresses {
            @usableFromInline let tlObject: TLObject
            init(tlObject: TLObject) {
                self.tlObject = tlObject
            }
        }
        case userAddresses(Cons_userAddresses)


        @usableFromInline init(tlObject object: TLObject) {
            switch object.tl_caseIndex {
            case 0:
                self = .userAddresses(Cons_userAddresses(tlObject: object))
            default:
                preconditionFailure()
            }
        }

        @usableFromInline var tlObject: TLObject {
            switch self {
            case .userAddresses(let _data):
                return _data.tlObject
            }
        }

        public var tlBackingObject: TLObject {
            return self.tlObject
        }

        @usableFromInline static func tlArray(_ object: TLObject, _ offset: Int) -> [Api.wallet.UserAddresses] {
            return tlObjectsAt(object, offset).map { Api.wallet.UserAddresses(tlObject: $0) }
        }

    }
}
public extension Api.wallet.UserAddresses.Cons_userAddresses {
    @_alwaysEmitIntoClient var addresses: [Api.WalletUserAddress] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.WalletUserAddress.tlArray(self.tlObject, 24) } }
    }
    @_alwaysEmitIntoClient var users: [Api.User] {
        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.User.tlArray(self.tlObject, 32) } }
    }
    init(addresses: [Api.WalletUserAddress], users: [Api.User]) {
        let _tlObject = TLObjectAllocate(TLApiConstructorAt(925))
        tlStoreReference(_tlObject, 24, addresses.map { item in item.tlObject } as NSArray)
        tlStoreReference(_tlObject, 32, users.map { item in item.tlObject } as NSArray)
        self.init(tlObject: _tlObject)
    }
}
