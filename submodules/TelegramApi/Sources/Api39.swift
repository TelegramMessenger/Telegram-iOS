public extension Api.stories {
    enum PeerStories: TypeConstructorDescription {
        public class Cons_peerStories {
            public var stories: Api.PeerStories
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(stories: Api.PeerStories, chats: [Api.Chat], users: [Api.User]) {
                self.stories = stories
                self.chats = chats
                self.users = users
            }
        }
        case peerStories(Cons_peerStories)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .peerStories(let _data):
                if boxed {
                    buffer.appendInt32(-890861720)
                }
                _data.stories.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .peerStories(let _data):
                return ("peerStories", [("stories", _data.stories as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_peerStories(_ reader: BufferReader) -> PeerStories? {
            var _1: Api.PeerStories?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PeerStories
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.stories.PeerStories.peerStories(Cons_peerStories(stories: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum Stories: TypeConstructorDescription {
        public class Cons_stories {
            public var flags: Int32
            public var count: Int32
            public var stories: [Api.StoryItem]
            public var pinnedToTop: [Int32]?
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, count: Int32, stories: [Api.StoryItem], pinnedToTop: [Int32]?, chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.count = count
                self.stories = stories
                self.pinnedToTop = pinnedToTop
                self.chats = chats
                self.users = users
            }
        }
        case stories(Cons_stories)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .stories(let _data):
                if boxed {
                    buffer.appendInt32(1673780490)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.stories.count))
                for item in _data.stories {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.pinnedToTop!.count))
                    for item in _data.pinnedToTop! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .stories(let _data):
                return ("stories", [("flags", _data.flags as Any), ("count", _data.count as Any), ("stories", _data.stories as Any), ("pinnedToTop", _data.pinnedToTop as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_stories(_ reader: BufferReader) -> Stories? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StoryItem]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryItem.self)
            }
            var _4: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
                }
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.Stories.stories(Cons_stories(flags: _1!, count: _2!, stories: _3!, pinnedToTop: _4, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum StoryReactionsList: TypeConstructorDescription {
        public class Cons_storyReactionsList {
            public var flags: Int32
            public var count: Int32
            public var reactions: [Api.StoryReaction]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, reactions: [Api.StoryReaction], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.reactions = reactions
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case storyReactionsList(Cons_storyReactionsList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyReactionsList(let _data):
                if boxed {
                    buffer.appendInt32(-1436583780)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.reactions.count))
                for item in _data.reactions {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyReactionsList(let _data):
                return ("storyReactionsList", [("flags", _data.flags as Any), ("count", _data.count as Any), ("reactions", _data.reactions as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("nextOffset", _data.nextOffset as Any)])
            }
        }

        public static func parse_storyReactionsList(_ reader: BufferReader) -> StoryReactionsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.StoryReaction]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryReaction.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _6 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.stories.StoryReactionsList.storyReactionsList(Cons_storyReactionsList(flags: _1!, count: _2!, reactions: _3!, chats: _4!, users: _5!, nextOffset: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum StoryViews: TypeConstructorDescription {
        public class Cons_storyViews {
            public var views: [Api.StoryViews]
            public var users: [Api.User]
            public init(views: [Api.StoryViews], users: [Api.User]) {
                self.views = views
                self.users = users
            }
        }
        case storyViews(Cons_storyViews)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyViews(let _data):
                if boxed {
                    buffer.appendInt32(-560009955)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.views.count))
                for item in _data.views {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyViews(let _data):
                return ("storyViews", [("views", _data.views as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            var _1: [Api.StoryViews]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryViews.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.stories.StoryViews.storyViews(Cons_storyViews(views: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.stories {
    enum StoryViewsList: TypeConstructorDescription {
        public class Cons_storyViewsList {
            public var flags: Int32
            public var count: Int32
            public var viewsCount: Int32
            public var forwardsCount: Int32
            public var reactionsCount: Int32
            public var views: [Api.StoryView]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var nextOffset: String?
            public init(flags: Int32, count: Int32, viewsCount: Int32, forwardsCount: Int32, reactionsCount: Int32, views: [Api.StoryView], chats: [Api.Chat], users: [Api.User], nextOffset: String?) {
                self.flags = flags
                self.count = count
                self.viewsCount = viewsCount
                self.forwardsCount = forwardsCount
                self.reactionsCount = reactionsCount
                self.views = views
                self.chats = chats
                self.users = users
                self.nextOffset = nextOffset
            }
        }
        case storyViewsList(Cons_storyViewsList)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .storyViewsList(let _data):
                if boxed {
                    buffer.appendInt32(1507299269)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                serializeInt32(_data.viewsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.forwardsCount, buffer: buffer, boxed: false)
                serializeInt32(_data.reactionsCount, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.views.count))
                for item in _data.views {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeString(_data.nextOffset!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .storyViewsList(let _data):
                return ("storyViewsList", [("flags", _data.flags as Any), ("count", _data.count as Any), ("viewsCount", _data.viewsCount as Any), ("forwardsCount", _data.forwardsCount as Any), ("reactionsCount", _data.reactionsCount as Any), ("views", _data.views as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("nextOffset", _data.nextOffset as Any)])
            }
        }

        public static func parse_storyViewsList(_ reader: BufferReader) -> StoryViewsList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: [Api.StoryView]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StoryView.self)
            }
            var _7: [Api.Chat]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _8: [Api.User]?
            if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _9: String?
            if Int(_1!) & Int(1 << 0) != 0 {
                _9 = parseString(reader)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 0) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.stories.StoryViewsList.storyViewsList(Cons_storyViewsList(flags: _1!, count: _2!, viewsCount: _3!, forwardsCount: _4!, reactionsCount: _5!, views: _6!, chats: _7!, users: _8!, nextOffset: _9))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.updates {
    indirect enum ChannelDifference: TypeConstructorDescription {
        public class Cons_channelDifference {
            public var flags: Int32
            public var pts: Int32
            public var timeout: Int32?
            public var newMessages: [Api.Message]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, pts: Int32, timeout: Int32?, newMessages: [Api.Message], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.pts = pts
                self.timeout = timeout
                self.newMessages = newMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
            }
        }
        public class Cons_channelDifferenceEmpty {
            public var flags: Int32
            public var pts: Int32
            public var timeout: Int32?
            public init(flags: Int32, pts: Int32, timeout: Int32?) {
                self.flags = flags
                self.pts = pts
                self.timeout = timeout
            }
        }
        public class Cons_channelDifferenceTooLong {
            public var flags: Int32
            public var timeout: Int32?
            public var dialog: Api.Dialog
            public var messages: [Api.Message]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(flags: Int32, timeout: Int32?, dialog: Api.Dialog, messages: [Api.Message], chats: [Api.Chat], users: [Api.User]) {
                self.flags = flags
                self.timeout = timeout
                self.dialog = dialog
                self.messages = messages
                self.chats = chats
                self.users = users
            }
        }
        case channelDifference(Cons_channelDifference)
        case channelDifferenceEmpty(Cons_channelDifferenceEmpty)
        case channelDifferenceTooLong(Cons_channelDifferenceTooLong)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .channelDifference(let _data):
                if boxed {
                    buffer.appendInt32(543450958)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.timeout!, buffer: buffer, boxed: false)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newMessages.count))
                for item in _data.newMessages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.otherUpdates.count))
                for item in _data.otherUpdates {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .channelDifferenceEmpty(let _data):
                if boxed {
                    buffer.appendInt32(1041346555)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.timeout!, buffer: buffer, boxed: false)
                }
                break
            case .channelDifferenceTooLong(let _data):
                if boxed {
                    buffer.appendInt32(-1531132162)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.timeout!, buffer: buffer, boxed: false)
                }
                _data.dialog.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.messages.count))
                for item in _data.messages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .channelDifference(let _data):
                return ("channelDifference", [("flags", _data.flags as Any), ("pts", _data.pts as Any), ("timeout", _data.timeout as Any), ("newMessages", _data.newMessages as Any), ("otherUpdates", _data.otherUpdates as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            case .channelDifferenceEmpty(let _data):
                return ("channelDifferenceEmpty", [("flags", _data.flags as Any), ("pts", _data.pts as Any), ("timeout", _data.timeout as Any)])
            case .channelDifferenceTooLong(let _data):
                return ("channelDifferenceTooLong", [("flags", _data.flags as Any), ("timeout", _data.timeout as Any), ("dialog", _data.dialog as Any), ("messages", _data.messages as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_channelDifference(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Update]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _6: [Api.Chat]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _7: [Api.User]?
            if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.updates.ChannelDifference.channelDifference(Cons_channelDifference(flags: _1!, pts: _2!, timeout: _3, newMessages: _4!, otherUpdates: _5!, chats: _6!, users: _7!))
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceEmpty(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.updates.ChannelDifference.channelDifferenceEmpty(Cons_channelDifferenceEmpty(flags: _1!, pts: _2!, timeout: _3))
            }
            else {
                return nil
            }
        }
        public static func parse_channelDifferenceTooLong(_ reader: BufferReader) -> ChannelDifference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.Dialog?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Dialog
            }
            var _4: [Api.Message]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _5: [Api.Chat]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _6: [Api.User]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.ChannelDifference.channelDifferenceTooLong(Cons_channelDifferenceTooLong(flags: _1!, timeout: _2, dialog: _3!, messages: _4!, chats: _5!, users: _6!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.updates {
    enum Difference: TypeConstructorDescription {
        public class Cons_difference {
            public var newMessages: [Api.Message]
            public var newEncryptedMessages: [Api.EncryptedMessage]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var state: Api.updates.State
            public init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], state: Api.updates.State) {
                self.newMessages = newMessages
                self.newEncryptedMessages = newEncryptedMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
                self.state = state
            }
        }
        public class Cons_differenceEmpty {
            public var date: Int32
            public var seq: Int32
            public init(date: Int32, seq: Int32) {
                self.date = date
                self.seq = seq
            }
        }
        public class Cons_differenceSlice {
            public var newMessages: [Api.Message]
            public var newEncryptedMessages: [Api.EncryptedMessage]
            public var otherUpdates: [Api.Update]
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public var intermediateState: Api.updates.State
            public init(newMessages: [Api.Message], newEncryptedMessages: [Api.EncryptedMessage], otherUpdates: [Api.Update], chats: [Api.Chat], users: [Api.User], intermediateState: Api.updates.State) {
                self.newMessages = newMessages
                self.newEncryptedMessages = newEncryptedMessages
                self.otherUpdates = otherUpdates
                self.chats = chats
                self.users = users
                self.intermediateState = intermediateState
            }
        }
        public class Cons_differenceTooLong {
            public var pts: Int32
            public init(pts: Int32) {
                self.pts = pts
            }
        }
        case difference(Cons_difference)
        case differenceEmpty(Cons_differenceEmpty)
        case differenceSlice(Cons_differenceSlice)
        case differenceTooLong(Cons_differenceTooLong)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .difference(let _data):
                if boxed {
                    buffer.appendInt32(16030880)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newMessages.count))
                for item in _data.newMessages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newEncryptedMessages.count))
                for item in _data.newEncryptedMessages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.otherUpdates.count))
                for item in _data.otherUpdates {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                _data.state.serialize(buffer, true)
                break
            case .differenceEmpty(let _data):
                if boxed {
                    buffer.appendInt32(1567990072)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.seq, buffer: buffer, boxed: false)
                break
            case .differenceSlice(let _data):
                if boxed {
                    buffer.appendInt32(-1459938943)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newMessages.count))
                for item in _data.newMessages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.newEncryptedMessages.count))
                for item in _data.newEncryptedMessages {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.otherUpdates.count))
                for item in _data.otherUpdates {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                _data.intermediateState.serialize(buffer, true)
                break
            case .differenceTooLong(let _data):
                if boxed {
                    buffer.appendInt32(1258196845)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .difference(let _data):
                return ("difference", [("newMessages", _data.newMessages as Any), ("newEncryptedMessages", _data.newEncryptedMessages as Any), ("otherUpdates", _data.otherUpdates as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("state", _data.state as Any)])
            case .differenceEmpty(let _data):
                return ("differenceEmpty", [("date", _data.date as Any), ("seq", _data.seq as Any)])
            case .differenceSlice(let _data):
                return ("differenceSlice", [("newMessages", _data.newMessages as Any), ("newEncryptedMessages", _data.newEncryptedMessages as Any), ("otherUpdates", _data.otherUpdates as Any), ("chats", _data.chats as Any), ("users", _data.users as Any), ("intermediateState", _data.intermediateState as Any)])
            case .differenceTooLong(let _data):
                return ("differenceTooLong", [("pts", _data.pts as Any)])
            }
        }

        public static func parse_difference(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.difference(Cons_difference(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, state: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_differenceEmpty(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.updates.Difference.differenceEmpty(Cons_differenceEmpty(date: _1!, seq: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_differenceSlice(_ reader: BufferReader) -> Difference? {
            var _1: [Api.Message]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Message.self)
            }
            var _2: [Api.EncryptedMessage]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.EncryptedMessage.self)
            }
            var _3: [Api.Update]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _4: [Api.Chat]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _5: [Api.User]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _6: Api.updates.State?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.updates.State
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.updates.Difference.differenceSlice(Cons_differenceSlice(newMessages: _1!, newEncryptedMessages: _2!, otherUpdates: _3!, chats: _4!, users: _5!, intermediateState: _6!))
            }
            else {
                return nil
            }
        }
        public static func parse_differenceTooLong(_ reader: BufferReader) -> Difference? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.updates.Difference.differenceTooLong(Cons_differenceTooLong(pts: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.updates {
    enum State: TypeConstructorDescription {
        public class Cons_state {
            public var pts: Int32
            public var qts: Int32
            public var date: Int32
            public var seq: Int32
            public var unreadCount: Int32
            public init(pts: Int32, qts: Int32, date: Int32, seq: Int32, unreadCount: Int32) {
                self.pts = pts
                self.qts = qts
                self.date = date
                self.seq = seq
                self.unreadCount = unreadCount
            }
        }
        case state(Cons_state)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .state(let _data):
                if boxed {
                    buffer.appendInt32(-1519637954)
                }
                serializeInt32(_data.pts, buffer: buffer, boxed: false)
                serializeInt32(_data.qts, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.seq, buffer: buffer, boxed: false)
                serializeInt32(_data.unreadCount, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .state(let _data):
                return ("state", [("pts", _data.pts as Any), ("qts", _data.qts as Any), ("date", _data.date as Any), ("seq", _data.seq as Any), ("unreadCount", _data.unreadCount as Any)])
            }
        }

        public static func parse_state(_ reader: BufferReader) -> State? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.updates.State.state(Cons_state(pts: _1!, qts: _2!, date: _3!, seq: _4!, unreadCount: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.upload {
    enum CdnFile: TypeConstructorDescription {
        public class Cons_cdnFile {
            public var bytes: Buffer
            public init(bytes: Buffer) {
                self.bytes = bytes
            }
        }
        public class Cons_cdnFileReuploadNeeded {
            public var requestToken: Buffer
            public init(requestToken: Buffer) {
                self.requestToken = requestToken
            }
        }
        case cdnFile(Cons_cdnFile)
        case cdnFileReuploadNeeded(Cons_cdnFileReuploadNeeded)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .cdnFile(let _data):
                if boxed {
                    buffer.appendInt32(-1449145777)
                }
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                break
            case .cdnFileReuploadNeeded(let _data):
                if boxed {
                    buffer.appendInt32(-290921362)
                }
                serializeBytes(_data.requestToken, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .cdnFile(let _data):
                return ("cdnFile", [("bytes", _data.bytes as Any)])
            case .cdnFileReuploadNeeded(let _data):
                return ("cdnFileReuploadNeeded", [("requestToken", _data.requestToken as Any)])
            }
        }

        public static func parse_cdnFile(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFile(Cons_cdnFile(bytes: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_cdnFileReuploadNeeded(_ reader: BufferReader) -> CdnFile? {
            var _1: Buffer?
            _1 = parseBytes(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.upload.CdnFile.cdnFileReuploadNeeded(Cons_cdnFileReuploadNeeded(requestToken: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.upload {
    enum File: TypeConstructorDescription {
        public class Cons_file {
            public var type: Api.storage.FileType
            public var mtime: Int32
            public var bytes: Buffer
            public init(type: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
                self.type = type
                self.mtime = mtime
                self.bytes = bytes
            }
        }
        public class Cons_fileCdnRedirect {
            public var dcId: Int32
            public var fileToken: Buffer
            public var encryptionKey: Buffer
            public var encryptionIv: Buffer
            public var fileHashes: [Api.FileHash]
            public init(dcId: Int32, fileToken: Buffer, encryptionKey: Buffer, encryptionIv: Buffer, fileHashes: [Api.FileHash]) {
                self.dcId = dcId
                self.fileToken = fileToken
                self.encryptionKey = encryptionKey
                self.encryptionIv = encryptionIv
                self.fileHashes = fileHashes
            }
        }
        case file(Cons_file)
        case fileCdnRedirect(Cons_fileCdnRedirect)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .file(let _data):
                if boxed {
                    buffer.appendInt32(157948117)
                }
                _data.type.serialize(buffer, true)
                serializeInt32(_data.mtime, buffer: buffer, boxed: false)
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                break
            case .fileCdnRedirect(let _data):
                if boxed {
                    buffer.appendInt32(-242427324)
                }
                serializeInt32(_data.dcId, buffer: buffer, boxed: false)
                serializeBytes(_data.fileToken, buffer: buffer, boxed: false)
                serializeBytes(_data.encryptionKey, buffer: buffer, boxed: false)
                serializeBytes(_data.encryptionIv, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.fileHashes.count))
                for item in _data.fileHashes {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .file(let _data):
                return ("file", [("type", _data.type as Any), ("mtime", _data.mtime as Any), ("bytes", _data.bytes as Any)])
            case .fileCdnRedirect(let _data):
                return ("fileCdnRedirect", [("dcId", _data.dcId as Any), ("fileToken", _data.fileToken as Any), ("encryptionKey", _data.encryptionKey as Any), ("encryptionIv", _data.encryptionIv as Any), ("fileHashes", _data.fileHashes as Any)])
            }
        }

        public static func parse_file(_ reader: BufferReader) -> File? {
            var _1: Api.storage.FileType?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.storage.FileType
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Buffer?
            _3 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.upload.File.file(Cons_file(type: _1!, mtime: _2!, bytes: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_fileCdnRedirect(_ reader: BufferReader) -> File? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: [Api.FileHash]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FileHash.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.upload.File.fileCdnRedirect(Cons_fileCdnRedirect(dcId: _1!, fileToken: _2!, encryptionKey: _3!, encryptionIv: _4!, fileHashes: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.upload {
    enum WebFile: TypeConstructorDescription {
        public class Cons_webFile {
            public var size: Int32
            public var mimeType: String
            public var fileType: Api.storage.FileType
            public var mtime: Int32
            public var bytes: Buffer
            public init(size: Int32, mimeType: String, fileType: Api.storage.FileType, mtime: Int32, bytes: Buffer) {
                self.size = size
                self.mimeType = mimeType
                self.fileType = fileType
                self.mtime = mtime
                self.bytes = bytes
            }
        }
        case webFile(Cons_webFile)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .webFile(let _data):
                if boxed {
                    buffer.appendInt32(568808380)
                }
                serializeInt32(_data.size, buffer: buffer, boxed: false)
                serializeString(_data.mimeType, buffer: buffer, boxed: false)
                _data.fileType.serialize(buffer, true)
                serializeInt32(_data.mtime, buffer: buffer, boxed: false)
                serializeBytes(_data.bytes, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .webFile(let _data):
                return ("webFile", [("size", _data.size as Any), ("mimeType", _data.mimeType as Any), ("fileType", _data.fileType as Any), ("mtime", _data.mtime as Any), ("bytes", _data.bytes as Any)])
            }
        }

        public static func parse_webFile(_ reader: BufferReader) -> WebFile? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.storage.FileType?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.storage.FileType
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Buffer?
            _5 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.upload.WebFile.webFile(Cons_webFile(size: _1!, mimeType: _2!, fileType: _3!, mtime: _4!, bytes: _5!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.users {
    enum SavedMusic: TypeConstructorDescription {
        public class Cons_savedMusic {
            public var count: Int32
            public var documents: [Api.Document]
            public init(count: Int32, documents: [Api.Document]) {
                self.count = count
                self.documents = documents
            }
        }
        public class Cons_savedMusicNotModified {
            public var count: Int32
            public init(count: Int32) {
                self.count = count
            }
        }
        case savedMusic(Cons_savedMusic)
        case savedMusicNotModified(Cons_savedMusicNotModified)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .savedMusic(let _data):
                if boxed {
                    buffer.appendInt32(883094167)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.documents.count))
                for item in _data.documents {
                    item.serialize(buffer, true)
                }
                break
            case .savedMusicNotModified(let _data):
                if boxed {
                    buffer.appendInt32(-477656412)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .savedMusic(let _data):
                return ("savedMusic", [("count", _data.count as Any), ("documents", _data.documents as Any)])
            case .savedMusicNotModified(let _data):
                return ("savedMusicNotModified", [("count", _data.count as Any)])
            }
        }

        public static func parse_savedMusic(_ reader: BufferReader) -> SavedMusic? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.users.SavedMusic.savedMusic(Cons_savedMusic(count: _1!, documents: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_savedMusicNotModified(_ reader: BufferReader) -> SavedMusic? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.users.SavedMusic.savedMusicNotModified(Cons_savedMusicNotModified(count: _1!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.users {
    enum UserFull: TypeConstructorDescription {
        public class Cons_userFull {
            public var fullUser: Api.UserFull
            public var chats: [Api.Chat]
            public var users: [Api.User]
            public init(fullUser: Api.UserFull, chats: [Api.Chat], users: [Api.User]) {
                self.fullUser = fullUser
                self.chats = chats
                self.users = users
            }
        }
        case userFull(Cons_userFull)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .userFull(let _data):
                if boxed {
                    buffer.appendInt32(997004590)
                }
                _data.fullUser.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.chats.count))
                for item in _data.chats {
                    item.serialize(buffer, true)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .userFull(let _data):
                return ("userFull", [("fullUser", _data.fullUser as Any), ("chats", _data.chats as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Api.UserFull?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.UserFull
            }
            var _2: [Api.Chat]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _3: [Api.User]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.users.UserFull.userFull(Cons_userFull(fullUser: _1!, chats: _2!, users: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api.users {
    enum Users: TypeConstructorDescription {
        public class Cons_users {
            public var users: [Api.User]
            public init(users: [Api.User]) {
                self.users = users
            }
        }
        public class Cons_usersSlice {
            public var count: Int32
            public var users: [Api.User]
            public init(count: Int32, users: [Api.User]) {
                self.count = count
                self.users = users
            }
        }
        case users(Cons_users)
        case usersSlice(Cons_usersSlice)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .users(let _data):
                if boxed {
                    buffer.appendInt32(1658259128)
                }
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            case .usersSlice(let _data):
                if boxed {
                    buffer.appendInt32(828000628)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.users.count))
                for item in _data.users {
                    item.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .users(let _data):
                return ("users", [("users", _data.users as Any)])
            case .usersSlice(let _data):
                return ("usersSlice", [("count", _data.count as Any), ("users", _data.users as Any)])
            }
        }

        public static func parse_users(_ reader: BufferReader) -> Users? {
            var _1: [Api.User]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.users.Users.users(Cons_users(users: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_usersSlice(_ reader: BufferReader) -> Users? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.users.Users.usersSlice(Cons_usersSlice(count: _1!, users: _2!))
            }
            else {
                return nil
            }
        }
    }
}
