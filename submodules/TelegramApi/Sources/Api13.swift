public extension Api {
    enum MessagePeerReaction: TypeConstructorDescription {
        case messagePeerReaction(flags: Int32, peerId: Api.Peer, reaction: Api.Reaction)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messagePeerReaction(let flags, let peerId, let reaction):
                    if boxed {
                        buffer.appendInt32(-1319698788)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peerId.serialize(buffer, true)
                    reaction.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messagePeerReaction(let flags, let peerId, let reaction):
                return ("messagePeerReaction", [("flags", String(describing: flags)), ("peerId", String(describing: peerId)), ("reaction", String(describing: reaction))])
    }
    }
    
        public static func parse_messagePeerReaction(_ reader: BufferReader) -> MessagePeerReaction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessagePeerReaction.messagePeerReaction(flags: _1!, peerId: _2!, reaction: _3!)
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
                return ("messageRange", [("minId", String(describing: minId)), ("maxId", String(describing: maxId))])
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
        case messageReactions(flags: Int32, results: [Api.ReactionCount], recentReactions: [Api.MessagePeerReaction]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReactions(let flags, let results, let recentReactions):
                    if boxed {
                        buffer.appendInt32(1328256121)
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
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReactions(let flags, let results, let recentReactions):
                return ("messageReactions", [("flags", String(describing: flags)), ("results", String(describing: results)), ("recentReactions", String(describing: recentReactions))])
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
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageReactions.messageReactions(flags: _1!, results: _2!, recentReactions: _3)
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
                return ("messageReplies", [("flags", String(describing: flags)), ("replies", String(describing: replies)), ("repliesPts", String(describing: repliesPts)), ("recentRepliers", String(describing: recentRepliers)), ("channelId", String(describing: channelId)), ("maxId", String(describing: maxId)), ("readMaxId", String(describing: readMaxId))])
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
    enum MessageReplyHeader: TypeConstructorDescription {
        case messageReplyHeader(flags: Int32, replyToMsgId: Int32, replyToPeerId: Api.Peer?, replyToTopId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageReplyHeader(let flags, let replyToMsgId, let replyToPeerId, let replyToTopId):
                    if boxed {
                        buffer.appendInt32(-1495959709)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(replyToMsgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {replyToPeerId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(replyToTopId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageReplyHeader(let flags, let replyToMsgId, let replyToPeerId, let replyToTopId):
                return ("messageReplyHeader", [("flags", String(describing: flags)), ("replyToMsgId", String(describing: replyToMsgId)), ("replyToPeerId", String(describing: replyToPeerId)), ("replyToTopId", String(describing: replyToTopId))])
    }
    }
    
        public static func parse_messageReplyHeader(_ reader: BufferReader) -> MessageReplyHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageReplyHeader.messageReplyHeader(flags: _1!, replyToMsgId: _2!, replyToPeerId: _3, replyToTopId: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageUserVote: TypeConstructorDescription {
        case messageUserVote(userId: Int64, option: Buffer, date: Int32)
        case messageUserVoteInputOption(userId: Int64, date: Int32)
        case messageUserVoteMultiple(userId: Int64, options: [Buffer], date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageUserVote(let userId, let option, let date):
                    if boxed {
                        buffer.appendInt32(886196148)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeBytes(option, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messageUserVoteInputOption(let userId, let date):
                    if boxed {
                        buffer.appendInt32(1017491692)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .messageUserVoteMultiple(let userId, let options, let date):
                    if boxed {
                        buffer.appendInt32(-1973033641)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
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
                case .messageUserVote(let userId, let option, let date):
                return ("messageUserVote", [("userId", String(describing: userId)), ("option", String(describing: option)), ("date", String(describing: date))])
                case .messageUserVoteInputOption(let userId, let date):
                return ("messageUserVoteInputOption", [("userId", String(describing: userId)), ("date", String(describing: date))])
                case .messageUserVoteMultiple(let userId, let options, let date):
                return ("messageUserVoteMultiple", [("userId", String(describing: userId)), ("options", String(describing: options)), ("date", String(describing: date))])
    }
    }
    
        public static func parse_messageUserVote(_ reader: BufferReader) -> MessageUserVote? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageUserVote.messageUserVote(userId: _1!, option: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageUserVoteInputOption(_ reader: BufferReader) -> MessageUserVote? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageUserVote.messageUserVoteInputOption(userId: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageUserVoteMultiple(_ reader: BufferReader) -> MessageUserVote? {
            var _1: Int64?
            _1 = reader.readInt64()
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
                return Api.MessageUserVote.messageUserVoteMultiple(userId: _1!, options: _2!, date: _3!)
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
                return ("messageViews", [("flags", String(describing: flags)), ("views", String(describing: views)), ("forwards", String(describing: forwards)), ("replies", String(describing: replies))])
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
                return ("inputMessagesFilterPhoneCalls", [("flags", String(describing: flags))])
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
                return ("nearestDc", [("country", String(describing: country)), ("thisDc", String(describing: thisDc)), ("nearestDc", String(describing: nearestDc))])
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
public extension Api {
    enum NotificationSound: TypeConstructorDescription {
        case notificationSoundDefault
        case notificationSoundLocal(title: String, data: String)
        case notificationSoundNone
        case notificationSoundRingtone(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .notificationSoundDefault:
                    if boxed {
                        buffer.appendInt32(-1746354498)
                    }
                    
                    break
                case .notificationSoundLocal(let title, let data):
                    if boxed {
                        buffer.appendInt32(-2096391452)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeString(data, buffer: buffer, boxed: false)
                    break
                case .notificationSoundNone:
                    if boxed {
                        buffer.appendInt32(1863070943)
                    }
                    
                    break
                case .notificationSoundRingtone(let id):
                    if boxed {
                        buffer.appendInt32(-9666487)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .notificationSoundDefault:
                return ("notificationSoundDefault", [])
                case .notificationSoundLocal(let title, let data):
                return ("notificationSoundLocal", [("title", String(describing: title)), ("data", String(describing: data))])
                case .notificationSoundNone:
                return ("notificationSoundNone", [])
                case .notificationSoundRingtone(let id):
                return ("notificationSoundRingtone", [("id", String(describing: id))])
    }
    }
    
        public static func parse_notificationSoundDefault(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundDefault
        }
        public static func parse_notificationSoundLocal(_ reader: BufferReader) -> NotificationSound? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotificationSound.notificationSoundLocal(title: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_notificationSoundNone(_ reader: BufferReader) -> NotificationSound? {
            return Api.NotificationSound.notificationSoundNone
        }
        public static func parse_notificationSoundRingtone(_ reader: BufferReader) -> NotificationSound? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotificationSound.notificationSoundRingtone(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum NotifyPeer: TypeConstructorDescription {
        case notifyBroadcasts
        case notifyChats
        case notifyForumTopic(peer: Api.Peer, topMsgId: Int32)
        case notifyPeer(peer: Api.Peer)
        case notifyUsers
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .notifyBroadcasts:
                    if boxed {
                        buffer.appendInt32(-703403793)
                    }
                    
                    break
                case .notifyChats:
                    if boxed {
                        buffer.appendInt32(-1073230141)
                    }
                    
                    break
                case .notifyForumTopic(let peer, let topMsgId):
                    if boxed {
                        buffer.appendInt32(577659656)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    break
                case .notifyPeer(let peer):
                    if boxed {
                        buffer.appendInt32(-1613493288)
                    }
                    peer.serialize(buffer, true)
                    break
                case .notifyUsers:
                    if boxed {
                        buffer.appendInt32(-1261946036)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .notifyBroadcasts:
                return ("notifyBroadcasts", [])
                case .notifyChats:
                return ("notifyChats", [])
                case .notifyForumTopic(let peer, let topMsgId):
                return ("notifyForumTopic", [("peer", String(describing: peer)), ("topMsgId", String(describing: topMsgId))])
                case .notifyPeer(let peer):
                return ("notifyPeer", [("peer", String(describing: peer))])
                case .notifyUsers:
                return ("notifyUsers", [])
    }
    }
    
        public static func parse_notifyBroadcasts(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyBroadcasts
        }
        public static func parse_notifyChats(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyChats
        }
        public static func parse_notifyForumTopic(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.NotifyPeer.notifyForumTopic(peer: _1!, topMsgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_notifyPeer(_ reader: BufferReader) -> NotifyPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.NotifyPeer.notifyPeer(peer: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_notifyUsers(_ reader: BufferReader) -> NotifyPeer? {
            return Api.NotifyPeer.notifyUsers
        }
    
    }
}
