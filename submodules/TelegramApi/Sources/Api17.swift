public extension Api {
    enum MessagePeerReaction: TypeConstructorDescription {
        case messagePeerReaction(flags: Int32, peerId: Api.Peer, date: Int32, reaction: Api.Reaction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messagePeerReaction(let flags, let peerId, let date, let reaction):
                    if boxed {
                        buffer.appendInt32(-1938180548)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peerId.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messagePeerReaction(let flags, let peerId, let date, let reaction):
                return ("messagePeerReaction", [("flags", flags as Any), ("peerId", peerId as Any), ("date", date as Any), ("reaction", reaction as Any)])
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
                return Api.MessagePeerReaction.messagePeerReaction(flags: _1!, peerId: _2!, date: _3!, reaction: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessagePeerVote: TypeConstructorDescription {
        case messagePeerVote(peer: Api.Peer, option: Buffer, date: Int32)
        case messagePeerVoteInputOption(peer: Api.Peer, date: Int32)
        case messagePeerVoteMultiple(peer: Api.Peer, options: [Buffer], date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messagePeerVote(let peer, let option, let date):
                    if boxed {
                        buffer.appendInt32(-1228133028)
                    }
                    peer.serialize(buffer, true)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messagePeerVoteInputOption(let peer, let date):
                    if boxed {
                        buffer.appendInt32(1959634180)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messagePeerVoteMultiple(let peer, let options, let date):
                    if boxed {
                        buffer.appendInt32(1177089766)
                    }
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messagePeerVote(let peer, let option, let date):
                return ("messagePeerVote", [("peer", peer as Any), ("option", option as Any), ("date", date as Any)])
                case .messagePeerVoteInputOption(let peer, let date):
                return ("messagePeerVoteInputOption", [("peer", peer as Any), ("date", date as Any)])
                case .messagePeerVoteMultiple(let peer, let options, let date):
                return ("messagePeerVoteMultiple", [("peer", peer as Any), ("options", options as Any), ("date", date as Any)])
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
                return Api.MessagePeerVote.messagePeerVote(peer: _1!, option: _2!, date: _3!)
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
                return Api.MessagePeerVote.messagePeerVoteInputOption(peer: _1!, date: _2!)
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
                return Api.MessagePeerVote.messagePeerVoteMultiple(peer: _1!, options: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageRange: TypeConstructorDescription {
        case messageRange(minId: Int32, maxId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageRange(let minId, let maxId):
                    if boxed {
                        buffer.appendInt32(182649427)
                    }
                    serializeInt32(minId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageRange(let minId, let maxId):
                return ("messageRange", [("minId", minId as Any), ("maxId", maxId as Any)])
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
                return Api.MessageRange.messageRange(minId: _1!, maxId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageReactions: TypeConstructorDescription {
        case messageReactions(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?, topReactors: [Api.MessageReactor]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReactions(let flags, let results, let recentReactions, let topReactors):
                    if boxed {
                        buffer.appendInt32(171155211)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(results.count))
                    for item in results {
                        item.serialize(buffer, true)
                    }
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentReactions!.count))
                    for item in recentReactions! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(topReactors!.count))
                    for item in topReactors! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReactions(let flags, let results, let recentReactions, let topReactors):
                return ("messageReactions", [("flags", flags as Any), ("results", results as Any), ("recentReactions", recentReactions as Any), ("topReactors", topReactors as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessagePeerReaction.self)
            } }
            var _4: [Api.MessageReactor]?
            if Int(_1!) & Int(1 << 4) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageReactor.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 4) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageReactions.messageReactions(flags: _1!, results: _2!, recentReactions: _3, topReactors: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageReactor: TypeConstructorDescription {
        case messageReactor(flags: Int32, peerId: Api.Peer?, count: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReactor(let flags, let peerId, let count):
                    if boxed {
                        buffer.appendInt32(1269016922)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {peerId!.serialize(buffer, true)}
                    serializeInt32(count, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReactor(let flags, let peerId, let count):
                return ("messageReactor", [("flags", flags as Any), ("peerId", peerId as Any), ("count", count as Any)])
    }
    }
    
        public static func parse_messageReactor(_ reader: BufferReader) -> MessageReactor? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageReactor.messageReactor(flags: _1!, peerId: _2, count: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageReplies: TypeConstructorDescription {
        case messageReplies(flags: Int32, replies: Int32, repliesPts: Int32, recentRepliers: [Api.Peer]?, channelId: Int64?, maxId: Int32?, readMaxId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReplies(let flags, let replies, let repliesPts, let recentRepliers, let channelId, let maxId, let readMaxId):
                    if boxed {
                        buffer.appendInt32(-2083123262)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(replies, buffer: buffer, boxed: false)
                    serializeInt32(repliesPts, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentRepliers!.count))
                    for item in recentRepliers! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(channelId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(maxId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(readMaxId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReplies(let flags, let replies, let repliesPts, let recentRepliers, let channelId, let maxId, let readMaxId):
                return ("messageReplies", [("flags", flags as Any), ("replies", replies as Any), ("repliesPts", repliesPts as Any), ("recentRepliers", recentRepliers as Any), ("channelId", channelId as Any), ("maxId", maxId as Any), ("readMaxId", readMaxId as Any)])
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
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Peer.self)
            } }
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt64() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageReplies.messageReplies(flags: _1!, replies: _2!, repliesPts: _3!, recentRepliers: _4, channelId: _5, maxId: _6, readMaxId: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum MessageReplyHeader: TypeConstructorDescription {
        case messageReplyHeader(flags: Int32, replyToMsgId: Int32?, replyToPeerId: Api.Peer?, replyFrom: Api.MessageFwdHeader?, replyMedia: Api.MessageMedia?, replyToTopId: Int32?, quoteText: String?, quoteEntities: [Api.MessageEntity]?, quoteOffset: Int32?)
        case messageReplyStoryHeader(peer: Api.Peer, storyId: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReplyHeader(let flags, let replyToMsgId, let replyToPeerId, let replyFrom, let replyMedia, let replyToTopId, let quoteText, let quoteEntities, let quoteOffset):
                    if boxed {
                        buffer.appendInt32(-1346631205)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(replyToMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {replyToPeerId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {replyFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 8) != 0 {replyMedia!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(replyToTopId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(quoteText!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(quoteEntities!.count))
                    for item in quoteEntities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(quoteOffset!, buffer: buffer, boxed: false)}
                    break
                case .messageReplyStoryHeader(let peer, let storyId):
                    if boxed {
                        buffer.appendInt32(240843065)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(storyId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReplyHeader(let flags, let replyToMsgId, let replyToPeerId, let replyFrom, let replyMedia, let replyToTopId, let quoteText, let quoteEntities, let quoteOffset):
                return ("messageReplyHeader", [("flags", flags as Any), ("replyToMsgId", replyToMsgId as Any), ("replyToPeerId", replyToPeerId as Any), ("replyFrom", replyFrom as Any), ("replyMedia", replyMedia as Any), ("replyToTopId", replyToTopId as Any), ("quoteText", quoteText as Any), ("quoteEntities", quoteEntities as Any), ("quoteOffset", quoteOffset as Any)])
                case .messageReplyStoryHeader(let peer, let storyId):
                return ("messageReplyStoryHeader", [("peer", peer as Any), ("storyId", storyId as Any)])
    }
    }
    
        public static func parse_messageReplyHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_2 = reader.readInt32() }
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _5: Api.MessageMedia?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            var _7: String?
            if Int(_1!) & Int(1 << 6) != 0 {_7 = parseString(reader) }
            var _8: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _9: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_9 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 4) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 5) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 8) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 6) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 7) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 10) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.MessageReplyHeader.messageReplyHeader(flags: _1!, replyToMsgId: _2, replyToPeerId: _3, replyFrom: _4, replyMedia: _5, replyToTopId: _6, quoteText: _7, quoteEntities: _8, quoteOffset: _9)
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
                return Api.MessageReplyHeader.messageReplyStoryHeader(peer: _1!, storyId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageReportOption: TypeConstructorDescription {
        case messageReportOption(text: String, option: Buffer)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReportOption(let text, let option):
                    if boxed {
                        buffer.appendInt32(2030298073)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReportOption(let text, let option):
                return ("messageReportOption", [("text", text as Any), ("option", option as Any)])
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
                return Api.MessageReportOption.messageReportOption(text: _1!, option: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageViews: TypeConstructorDescription {
        case messageViews(flags: Int32, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageViews(let flags, let views, let forwards, let replies):
                    if boxed {
                        buffer.appendInt32(1163625789)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(views!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(forwards!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {replies!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageViews(let flags, let views, let forwards, let replies):
                return ("messageViews", [("flags", flags as Any), ("views", views as Any), ("forwards", forwards as Any), ("replies", replies as Any)])
    }
    }
    
        public static func parse_messageViews(_ reader: BufferReader) -> MessageViews? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            var _4: Api.MessageReplies?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.MessageReplies
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageViews.messageViews(flags: _1!, views: _2, forwards: _3, replies: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessagesFilter: TypeConstructorDescription {
        case inputMessagesFilterChatPhotos
        case inputMessagesFilterContacts
        case inputMessagesFilterDocument
        case inputMessagesFilterEmpty
        case inputMessagesFilterGeo
        case inputMessagesFilterGif
        case inputMessagesFilterMusic
        case inputMessagesFilterMyMentions
        case inputMessagesFilterPhoneCalls(flags: Int32)
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
                case .inputMessagesFilterPhoneCalls(let flags):
                    if boxed {
                        buffer.appendInt32(-2134272152)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
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
                case .inputMessagesFilterPhoneCalls(let flags):
                return ("inputMessagesFilterPhoneCalls", [("flags", flags as Any)])
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
                return Api.MessagesFilter.inputMessagesFilterPhoneCalls(flags: _1!)
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
        case missingInvitee(flags: Int32, userId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .missingInvitee(let flags, let userId):
                    if boxed {
                        buffer.appendInt32(1653379620)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .missingInvitee(let flags, let userId):
                return ("missingInvitee", [("flags", flags as Any), ("userId", userId as Any)])
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
                return Api.MissingInvitee.missingInvitee(flags: _1!, userId: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MyBoost: TypeConstructorDescription {
        case myBoost(flags: Int32, slot: Int32, peer: Api.Peer?, date: Int32, expires: Int32, cooldownUntilDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .myBoost(let flags, let slot, let peer, let date, let expires, let cooldownUntilDate):
                    if boxed {
                        buffer.appendInt32(-1001897636)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(slot, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peer!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(cooldownUntilDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .myBoost(let flags, let slot, let peer, let date, let expires, let cooldownUntilDate):
                return ("myBoost", [("flags", flags as Any), ("slot", slot as Any), ("peer", peer as Any), ("date", date as Any), ("expires", expires as Any), ("cooldownUntilDate", cooldownUntilDate as Any)])
    }
    }
    
        public static func parse_myBoost(_ reader: BufferReader) -> MyBoost? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MyBoost.myBoost(flags: _1!, slot: _2!, peer: _3, date: _4!, expires: _5!, cooldownUntilDate: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum NearestDc: TypeConstructorDescription {
        case nearestDc(country: String, thisDc: Int32, nearestDc: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .nearestDc(let country, let thisDc, let nearestDc):
                    if boxed {
                        buffer.appendInt32(-1910892683)
                    }
                    serializeString(country, buffer: buffer, boxed: false)
                    serializeInt32(thisDc, buffer: buffer, boxed: false)
                    serializeInt32(nearestDc, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .nearestDc(let country, let thisDc, let nearestDc):
                return ("nearestDc", [("country", country as Any), ("thisDc", thisDc as Any), ("nearestDc", nearestDc as Any)])
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
                return Api.NearestDc.nearestDc(country: _1!, thisDc: _2!, nearestDc: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
