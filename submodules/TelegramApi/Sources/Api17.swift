public extension Api {
    enum MessagePeerReaction: TypeConstructorDescription {
        public class Cons_messagePeerReaction {
            public var flags: Int32
            public var peerId: Api.Peer
            public var date: Int32
            public var reaction: Api.Reaction
            public init(flags: Int32, peerId: Api.Peer, date: Int32, reaction: Api.Reaction) {
                self.flags = flags
                self.peerId = peerId
                self.date = date
                self.reaction = reaction
            }
        }
        case messagePeerReaction(Cons_messagePeerReaction)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messagePeerReaction(let _data):
                if boxed {
                    buffer.appendInt32(-1938180548)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                _data.peerId.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                _data.reaction.serialize(buffer, true)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messagePeerReaction(let _data):
                return ("messagePeerReaction", [("flags", _data.flags as Any), ("peerId", _data.peerId as Any), ("date", _data.date as Any), ("reaction", _data.reaction as Any)])
            }
        }

        public static func parse_messagePeerReaction(_ reader: BufferReader) -> MessagePeerReaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Reaction?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessagePeerReaction.messagePeerReaction(Cons_messagePeerReaction(flags: _1!, peerId: _2!, date: _3!, reaction: _4!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessagePeerVote: TypeConstructorDescription {
        public class Cons_messagePeerVote {
            public var peer: Api.Peer
            public var option: Buffer
            public var date: Int32
            public init(peer: Api.Peer, option: Buffer, date: Int32) {
                self.peer = peer
                self.option = option
                self.date = date
            }
        }
        public class Cons_messagePeerVoteInputOption {
            public var peer: Api.Peer
            public var date: Int32
            public init(peer: Api.Peer, date: Int32) {
                self.peer = peer
                self.date = date
            }
        }
        public class Cons_messagePeerVoteMultiple {
            public var peer: Api.Peer
            public var options: [Buffer]
            public var date: Int32
            public init(peer: Api.Peer, options: [Buffer], date: Int32) {
                self.peer = peer
                self.options = options
                self.date = date
            }
        }
        case messagePeerVote(Cons_messagePeerVote)
        case messagePeerVoteInputOption(Cons_messagePeerVoteInputOption)
        case messagePeerVoteMultiple(Cons_messagePeerVoteMultiple)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messagePeerVote(let _data):
                if boxed {
                    buffer.appendInt32(-1228133028)
                }
                _data.peer.serialize(buffer, true)
                serializeBytes(_data.option, buffer: buffer, boxed: false)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .messagePeerVoteInputOption(let _data):
                if boxed {
                    buffer.appendInt32(1959634180)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            case .messagePeerVoteMultiple(let _data):
                if boxed {
                    buffer.appendInt32(1177089766)
                }
                _data.peer.serialize(buffer, true)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.options.count))
                for item in _data.options {
                    serializeBytes(item, buffer: buffer, boxed: false)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messagePeerVote(let _data):
                return ("messagePeerVote", [("peer", _data.peer as Any), ("option", _data.option as Any), ("date", _data.date as Any)])
            case .messagePeerVoteInputOption(let _data):
                return ("messagePeerVoteInputOption", [("peer", _data.peer as Any), ("date", _data.date as Any)])
            case .messagePeerVoteMultiple(let _data):
                return ("messagePeerVoteMultiple", [("peer", _data.peer as Any), ("options", _data.options as Any), ("date", _data.date as Any)])
            }
        }

        public static func parse_messagePeerVote(_ reader: BufferReader) -> MessagePeerVote? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessagePeerVote.messagePeerVote(Cons_messagePeerVote(peer: _1!, option: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
        public static func parse_messagePeerVoteInputOption(_ reader: BufferReader) -> MessagePeerVote? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessagePeerVote.messagePeerVoteInputOption(Cons_messagePeerVoteInputOption(peer: _1!, date: _2!))
            }
            else {
                return nil
            }
        }
        public static func parse_messagePeerVoteMultiple(_ reader: BufferReader) -> MessagePeerVote? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: [Buffer]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessagePeerVote.messagePeerVoteMultiple(Cons_messagePeerVoteMultiple(peer: _1!, options: _2!, date: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageRange: TypeConstructorDescription {
        public class Cons_messageRange {
            public var minId: Int32
            public var maxId: Int32
            public init(minId: Int32, maxId: Int32) {
                self.minId = minId
                self.maxId = maxId
            }
        }
        case messageRange(Cons_messageRange)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageRange(let _data):
                if boxed {
                    buffer.appendInt32(182649427)
                }
                serializeInt32(_data.minId, buffer: buffer, boxed: false)
                serializeInt32(_data.maxId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageRange(let _data):
                return ("messageRange", [("minId", _data.minId as Any), ("maxId", _data.maxId as Any)])
            }
        }

        public static func parse_messageRange(_ reader: BufferReader) -> MessageRange? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageRange.messageRange(Cons_messageRange(minId: _1!, maxId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageReactions: TypeConstructorDescription {
        public class Cons_messageReactions {
            public var flags: Int32
            public var results: [Api.ReactionCount]
            public var recentReactions: [Api.MessagePeerReaction]?
            public var topReactors: [Api.MessageReactor]?
            public init(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?, topReactors: [Api.MessageReactor]?) {
                self.flags = flags
                self.results = results
                self.recentReactions = recentReactions
                self.topReactors = topReactors
            }
        }
        case messageReactions(Cons_messageReactions)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReactions(let _data):
                if boxed {
                    buffer.appendInt32(171155211)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                buffer.appendInt32(481674261)
                buffer.appendInt32(Int32(_data.results.count))
                for item in _data.results {
                    item.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.recentReactions!.count))
                    for item in _data.recentReactions! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.topReactors!.count))
                    for item in _data.topReactors! {
                        item.serialize(buffer, true)
                    }
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageReactions(let _data):
                return ("messageReactions", [("flags", _data.flags as Any), ("results", _data.results as Any), ("recentReactions", _data.recentReactions as Any), ("topReactors", _data.topReactors as Any)])
            }
        }

        public static func parse_messageReactions(_ reader: BufferReader) -> MessageReactions? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.ReactionCount]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReactionCount.self)
            }
            var _3: [Api.MessagePeerReaction]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerReaction.self)
                }
            }
            var _4: [Api.MessageReactor]?
            if Int(_1!) & Int(1 << 4) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageReactor.self)
                }
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageReactions.messageReactions(Cons_messageReactions(flags: _1!, results: _2!, recentReactions: _3, topReactors: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageReactor: TypeConstructorDescription {
        public class Cons_messageReactor {
            public var flags: Int32
            public var peerId: Api.Peer?
            public var count: Int32
            public init(flags: Int32, peerId: Api.Peer?, count: Int32) {
                self.flags = flags
                self.peerId = peerId
                self.count = count
            }
        }
        case messageReactor(Cons_messageReactor)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReactor(let _data):
                if boxed {
                    buffer.appendInt32(1269016922)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    _data.peerId!.serialize(buffer, true)
                }
                serializeInt32(_data.count, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageReactor(let _data):
                return ("messageReactor", [("flags", _data.flags as Any), ("peerId", _data.peerId as Any), ("count", _data.count as Any)])
            }
        }

        public static func parse_messageReactor(_ reader: BufferReader) -> MessageReactor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {
                if let signature = reader.readInt32() {
                    _2 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageReactor.messageReactor(Cons_messageReactor(flags: _1!, peerId: _2, count: _3!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageReplies: TypeConstructorDescription {
        public class Cons_messageReplies {
            public var flags: Int32
            public var replies: Int32
            public var repliesPts: Int32
            public var recentRepliers: [Api.Peer]?
            public var channelId: Int64?
            public var maxId: Int32?
            public var readMaxId: Int32?
            public init(flags: Int32, replies: Int32, repliesPts: Int32, recentRepliers: [Api.Peer]?, channelId: Int64?, maxId: Int32?, readMaxId: Int32?) {
                self.flags = flags
                self.replies = replies
                self.repliesPts = repliesPts
                self.recentRepliers = recentRepliers
                self.channelId = channelId
                self.maxId = maxId
                self.readMaxId = readMaxId
            }
        }
        case messageReplies(Cons_messageReplies)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReplies(let _data):
                if boxed {
                    buffer.appendInt32(-2083123262)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.replies, buffer: buffer, boxed: false)
                serializeInt32(_data.repliesPts, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.recentRepliers!.count))
                    for item in _data.recentRepliers! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt64(_data.channelId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    serializeInt32(_data.maxId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 3) != 0 {
                    serializeInt32(_data.readMaxId!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageReplies(let _data):
                return ("messageReplies", [("flags", _data.flags as Any), ("replies", _data.replies as Any), ("repliesPts", _data.repliesPts as Any), ("recentRepliers", _data.recentRepliers as Any), ("channelId", _data.channelId as Any), ("maxId", _data.maxId as Any), ("readMaxId", _data.readMaxId as Any)])
            }
        }

        public static func parse_messageReplies(_ reader: BufferReader) -> MessageReplies? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.Peer]?
            if Int(_1!) & Int(1 << 1) != 0 {
                if let _ = reader.readInt32() {
                    _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
                }
            }
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {
                _5 = reader.readInt64()
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {
                _6 = reader.readInt32()
            }
            var _7: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {
                _7 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageReplies.messageReplies(Cons_messageReplies(flags: _1!, replies: _2!, repliesPts: _3!, recentRepliers: _4, channelId: _5, maxId: _6, readMaxId: _7))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    indirect enum MessageReplyHeader: TypeConstructorDescription {
        public class Cons_messageReplyHeader {
            public var flags: Int32
            public var replyToMsgId: Int32?
            public var replyToPeerId: Api.Peer?
            public var replyFrom: Api.MessageFwdHeader?
            public var replyMedia: Api.MessageMedia?
            public var replyToTopId: Int32?
            public var quoteText: String?
            public var quoteEntities: [Api.MessageEntity]?
            public var quoteOffset: Int32?
            public var todoItemId: Int32?
            public init(flags: Int32, replyToMsgId: Int32?, replyToPeerId: Api.Peer?, replyFrom: Api.MessageFwdHeader?, replyMedia: Api.MessageMedia?, replyToTopId: Int32?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?, todoItemId: Int32?) {
                self.flags = flags
                self.replyToMsgId = replyToMsgId
                self.replyToPeerId = replyToPeerId
                self.replyFrom = replyFrom
                self.replyMedia = replyMedia
                self.replyToTopId = replyToTopId
                self.quoteText = quoteText
                self.quoteEntities = quoteEntities
                self.quoteOffset = quoteOffset
                self.todoItemId = todoItemId
            }
        }
        public class Cons_messageReplyStoryHeader {
            public var peer: Api.Peer
            public var storyId: Int32
            public init(peer: Api.Peer, storyId: Int32) {
                self.peer = peer
                self.storyId = storyId
            }
        }
        case messageReplyHeader(Cons_messageReplyHeader)
        case messageReplyStoryHeader(Cons_messageReplyStoryHeader)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReplyHeader(let _data):
                if boxed {
                    buffer.appendInt32(1763137035)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 4) != 0 {
                    serializeInt32(_data.replyToMsgId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.replyToPeerId!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 5) != 0 {
                    _data.replyFrom!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 8) != 0 {
                    _data.replyMedia!.serialize(buffer, true)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.replyToTopId!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 6) != 0 {
                    serializeString(_data.quoteText!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 7) != 0 {
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(_data.quoteEntities!.count))
                    for item in _data.quoteEntities! {
                        item.serialize(buffer, true)
                    }
                }
                if Int(_data.flags) & Int(1 << 10) != 0 {
                    serializeInt32(_data.quoteOffset!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 11) != 0 {
                    serializeInt32(_data.todoItemId!, buffer: buffer, boxed: false)
                }
                break
            case .messageReplyStoryHeader(let _data):
                if boxed {
                    buffer.appendInt32(240843065)
                }
                _data.peer.serialize(buffer, true)
                serializeInt32(_data.storyId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageReplyHeader(let _data):
                return ("messageReplyHeader", [("flags", _data.flags as Any), ("replyToMsgId", _data.replyToMsgId as Any), ("replyToPeerId", _data.replyToPeerId as Any), ("replyFrom", _data.replyFrom as Any), ("replyMedia", _data.replyMedia as Any), ("replyToTopId", _data.replyToTopId as Any), ("quoteText", _data.quoteText as Any), ("quoteEntities", _data.quoteEntities as Any), ("quoteOffset", _data.quoteOffset as Any), ("todoItemId", _data.todoItemId as Any)])
            case .messageReplyStoryHeader(let _data):
                return ("messageReplyStoryHeader", [("peer", _data.peer as Any), ("storyId", _data.storyId as Any)])
            }
        }

        public static func parse_messageReplyHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _4: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 5) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
                }
            }
            var _5: Api.MessageMedia?
            if Int(_1!) & Int(1 << 8) != 0 {
                if let signature = reader.readInt32() {
                    _5 = Api.parse(reader, signature: signature) as? Api.MessageMedia
                }
            }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            var _7: String?
            if Int(_1!) & Int(1 << 6) != 0 {
                _7 = parseString(reader)
            }
            var _8: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {
                if let _ = reader.readInt32() {
                    _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
                }
            }
            var _9: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {
                _9 = reader.readInt32()
            }
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {
                _10 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 5) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 {
                return Api.MessageReplyHeader.messageReplyHeader(Cons_messageReplyHeader(flags: _1!, replyToMsgId: _2, replyToPeerId: _3, replyFrom: _4, replyMedia: _5, replyToTopId: _6, quoteText: _7, quoteEntities: _8, quoteOffset: _9, todoItemId: _10))
            }
            else {
                return nil
            }
        }
        public static func parse_messageReplyStoryHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageReplyHeader.messageReplyStoryHeader(Cons_messageReplyStoryHeader(peer: _1!, storyId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageReportOption: TypeConstructorDescription {
        public class Cons_messageReportOption {
            public var text: String
            public var option: Buffer
            public init(text: String, option: Buffer) {
                self.text = text
                self.option = option
            }
        }
        case messageReportOption(Cons_messageReportOption)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageReportOption(let _data):
                if boxed {
                    buffer.appendInt32(2030298073)
                }
                serializeString(_data.text, buffer: buffer, boxed: false)
                serializeBytes(_data.option, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageReportOption(let _data):
                return ("messageReportOption", [("text", _data.text as Any), ("option", _data.option as Any)])
            }
        }

        public static func parse_messageReportOption(_ reader: BufferReader) -> MessageReportOption? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageReportOption.messageReportOption(Cons_messageReportOption(text: _1!, option: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessageViews: TypeConstructorDescription {
        public class Cons_messageViews {
            public var flags: Int32
            public var views: Int32?
            public var forwards: Int32?
            public var replies: Api.MessageReplies?
            public init(flags: Int32, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?) {
                self.flags = flags
                self.views = views
                self.forwards = forwards
                self.replies = replies
            }
        }
        case messageViews(Cons_messageViews)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .messageViews(let _data):
                if boxed {
                    buffer.appendInt32(1163625789)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    serializeInt32(_data.views!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.forwards!, buffer: buffer, boxed: false)
                }
                if Int(_data.flags) & Int(1 << 2) != 0 {
                    _data.replies!.serialize(buffer, true)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .messageViews(let _data):
                return ("messageViews", [("flags", _data.flags as Any), ("views", _data.views as Any), ("forwards", _data.forwards as Any), ("replies", _data.replies as Any)])
            }
        }

        public static func parse_messageViews(_ reader: BufferReader) -> MessageViews? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {
                _2 = reader.readInt32()
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _3 = reader.readInt32()
            }
            var _4: Api.MessageReplies?
            if Int(_1!) & Int(1 << 2) != 0 {
                if let signature = reader.readInt32() {
                    _4 = Api.parse(reader, signature: signature) as? Api.MessageReplies
                }
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageViews.messageViews(Cons_messageViews(flags: _1!, views: _2, forwards: _3, replies: _4))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MessagesFilter: TypeConstructorDescription {
        public class Cons_inputMessagesFilterPhoneCalls {
            public var flags: Int32
            public init(flags: Int32) {
                self.flags = flags
            }
        }
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterContacts
        case inputMessagesFilterDocument
        case inputMessagesFilterEmpty
        case inputMessagesFilterGeo
        case inputMessagesFilterGif
        case inputMessagesFilterMusic
        case inputMessagesFilterMyMentions
        case inputMessagesFilterPhoneCalls(Cons_inputMessagesFilterPhoneCalls)
        case inputMessagesFilterPhotoVideo
        case inputMessagesFilterPhotos
        case inputMessagesFilterPinned
        case inputMessagesFilterRoundVideo
        case inputMessagesFilterRoundVoice
        case inputMessagesFilterUrl
        case inputMessagesFilterVideo
        case inputMessagesFilterVoice

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .inputMessagesFilterChatPhotos:
                if boxed {
                    buffer.appendInt32(975236280)
                }
                break
            case .inputMessagesFilterContacts:
                if boxed {
                    buffer.appendInt32(-530392189)
                }
                break
            case .inputMessagesFilterDocument:
                if boxed {
                    buffer.appendInt32(-1629621880)
                }
                break
            case .inputMessagesFilterEmpty:
                if boxed {
                    buffer.appendInt32(1474492012)
                }
                break
            case .inputMessagesFilterGeo:
                if boxed {
                    buffer.appendInt32(-419271411)
                }
                break
            case .inputMessagesFilterGif:
                if boxed {
                    buffer.appendInt32(-3644025)
                }
                break
            case .inputMessagesFilterMusic:
                if boxed {
                    buffer.appendInt32(928101534)
                }
                break
            case .inputMessagesFilterMyMentions:
                if boxed {
                    buffer.appendInt32(-1040652646)
                }
                break
            case .inputMessagesFilterPhoneCalls(let _data):
                if boxed {
                    buffer.appendInt32(-2134272152)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                break
            case .inputMessagesFilterPhotoVideo:
                if boxed {
                    buffer.appendInt32(1458172132)
                }
                break
            case .inputMessagesFilterPhotos:
                if boxed {
                    buffer.appendInt32(-1777752804)
                }
                break
            case .inputMessagesFilterPinned:
                if boxed {
                    buffer.appendInt32(464520273)
                }
                break
            case .inputMessagesFilterRoundVideo:
                if boxed {
                    buffer.appendInt32(-1253451181)
                }
                break
            case .inputMessagesFilterRoundVoice:
                if boxed {
                    buffer.appendInt32(2054952868)
                }
                break
            case .inputMessagesFilterUrl:
                if boxed {
                    buffer.appendInt32(2129714567)
                }
                break
            case .inputMessagesFilterVideo:
                if boxed {
                    buffer.appendInt32(-1614803355)
                }
                break
            case .inputMessagesFilterVoice:
                if boxed {
                    buffer.appendInt32(1358283666)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .inputMessagesFilterChatPhotos:
                return ("inputMessagesFilterChatPhotos", [])
            case .inputMessagesFilterContacts:
                return ("inputMessagesFilterContacts", [])
            case .inputMessagesFilterDocument:
                return ("inputMessagesFilterDocument", [])
            case .inputMessagesFilterEmpty:
                return ("inputMessagesFilterEmpty", [])
            case .inputMessagesFilterGeo:
                return ("inputMessagesFilterGeo", [])
            case .inputMessagesFilterGif:
                return ("inputMessagesFilterGif", [])
            case .inputMessagesFilterMusic:
                return ("inputMessagesFilterMusic", [])
            case .inputMessagesFilterMyMentions:
                return ("inputMessagesFilterMyMentions", [])
            case .inputMessagesFilterPhoneCalls(let _data):
                return ("inputMessagesFilterPhoneCalls", [("flags", _data.flags as Any)])
            case .inputMessagesFilterPhotoVideo:
                return ("inputMessagesFilterPhotoVideo", [])
            case .inputMessagesFilterPhotos:
                return ("inputMessagesFilterPhotos", [])
            case .inputMessagesFilterPinned:
                return ("inputMessagesFilterPinned", [])
            case .inputMessagesFilterRoundVideo:
                return ("inputMessagesFilterRoundVideo", [])
            case .inputMessagesFilterRoundVoice:
                return ("inputMessagesFilterRoundVoice", [])
            case .inputMessagesFilterUrl:
                return ("inputMessagesFilterUrl", [])
            case .inputMessagesFilterVideo:
                return ("inputMessagesFilterVideo", [])
            case .inputMessagesFilterVoice:
                return ("inputMessagesFilterVoice", [])
            }
        }

        public static func parse_inputMessagesFilterChatPhotos(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterChatPhotos
        }
        public static func parse_inputMessagesFilterContacts(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterContacts
        }
        public static func parse_inputMessagesFilterDocument(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterDocument
        }
        public static func parse_inputMessagesFilterEmpty(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterEmpty
        }
        public static func parse_inputMessagesFilterGeo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterGeo
        }
        public static func parse_inputMessagesFilterGif(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterGif
        }
        public static func parse_inputMessagesFilterMusic(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterMusic
        }
        public static func parse_inputMessagesFilterMyMentions(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterMyMentions
        }
        public static func parse_inputMessagesFilterPhoneCalls(_ reader: BufferReader) -> MessagesFilter? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessagesFilter.inputMessagesFilterPhoneCalls(Cons_inputMessagesFilterPhoneCalls(flags: _1!))
            }
            else {
                return nil
            }
        }
        public static func parse_inputMessagesFilterPhotoVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPhotoVideo
        }
        public static func parse_inputMessagesFilterPhotos(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPhotos
        }
        public static func parse_inputMessagesFilterPinned(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterPinned
        }
        public static func parse_inputMessagesFilterRoundVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterRoundVideo
        }
        public static func parse_inputMessagesFilterRoundVoice(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterRoundVoice
        }
        public static func parse_inputMessagesFilterUrl(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterUrl
        }
        public static func parse_inputMessagesFilterVideo(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterVideo
        }
        public static func parse_inputMessagesFilterVoice(_ reader: BufferReader) -> MessagesFilter? {
            return Api.MessagesFilter.inputMessagesFilterVoice
        }
    }
}
public extension Api {
    enum MissingInvitee: TypeConstructorDescription {
        public class Cons_missingInvitee {
            public var flags: Int32
            public var userId: Int64
            public init(flags: Int32, userId: Int64) {
                self.flags = flags
                self.userId = userId
            }
        }
        case missingInvitee(Cons_missingInvitee)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .missingInvitee(let _data):
                if boxed {
                    buffer.appendInt32(1653379620)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt64(_data.userId, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .missingInvitee(let _data):
                return ("missingInvitee", [("flags", _data.flags as Any), ("userId", _data.userId as Any)])
            }
        }

        public static func parse_missingInvitee(_ reader: BufferReader) -> MissingInvitee? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MissingInvitee.missingInvitee(Cons_missingInvitee(flags: _1!, userId: _2!))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum MyBoost: TypeConstructorDescription {
        public class Cons_myBoost {
            public var flags: Int32
            public var slot: Int32
            public var peer: Api.Peer?
            public var date: Int32
            public var expires: Int32
            public var cooldownUntilDate: Int32?
            public init(flags: Int32, slot: Int32, peer: Api.Peer?, date: Int32, expires: Int32, cooldownUntilDate: Int32?) {
                self.flags = flags
                self.slot = slot
                self.peer = peer
                self.date = date
                self.expires = expires
                self.cooldownUntilDate = cooldownUntilDate
            }
        }
        case myBoost(Cons_myBoost)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .myBoost(let _data):
                if boxed {
                    buffer.appendInt32(-1001897636)
                }
                serializeInt32(_data.flags, buffer: buffer, boxed: false)
                serializeInt32(_data.slot, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 0) != 0 {
                    _data.peer!.serialize(buffer, true)
                }
                serializeInt32(_data.date, buffer: buffer, boxed: false)
                serializeInt32(_data.expires, buffer: buffer, boxed: false)
                if Int(_data.flags) & Int(1 << 1) != 0 {
                    serializeInt32(_data.cooldownUntilDate!, buffer: buffer, boxed: false)
                }
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .myBoost(let _data):
                return ("myBoost", [("flags", _data.flags as Any), ("slot", _data.slot as Any), ("peer", _data.peer as Any), ("date", _data.date as Any), ("expires", _data.expires as Any), ("cooldownUntilDate", _data.cooldownUntilDate as Any)])
            }
        }

        public static func parse_myBoost(_ reader: BufferReader) -> MyBoost? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {
                if let signature = reader.readInt32() {
                    _3 = Api.parse(reader, signature: signature) as? Api.Peer
                }
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {
                _6 = reader.readInt32()
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MyBoost.myBoost(Cons_myBoost(flags: _1!, slot: _2!, peer: _3, date: _4!, expires: _5!, cooldownUntilDate: _6))
            }
            else {
                return nil
            }
        }
    }
}
public extension Api {
    enum NearestDc: TypeConstructorDescription {
        public class Cons_nearestDc {
            public var country: String
            public var thisDc: Int32
            public var nearestDc: Int32
            public init(country: String, thisDc: Int32, nearestDc: Int32) {
                self.country = country
                self.thisDc = thisDc
                self.nearestDc = nearestDc
            }
        }
        case nearestDc(Cons_nearestDc)

        public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
            switch self {
            case .nearestDc(let _data):
                if boxed {
                    buffer.appendInt32(-1910892683)
                }
                serializeString(_data.country, buffer: buffer, boxed: false)
                serializeInt32(_data.thisDc, buffer: buffer, boxed: false)
                serializeInt32(_data.nearestDc, buffer: buffer, boxed: false)
                break
            }
        }

        public func descriptionFields() -> (String, [(String, Any)]) {
            switch self {
            case .nearestDc(let _data):
                return ("nearestDc", [("country", _data.country as Any), ("thisDc", _data.thisDc as Any), ("nearestDc", _data.nearestDc as Any)])
            }
        }

        public static func parse_nearestDc(_ reader: BufferReader) -> NearestDc? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.NearestDc.nearestDc(Cons_nearestDc(country: _1!, thisDc: _2!, nearestDc: _3!))
            }
            else {
                return nil
            }
        }
    }
}
