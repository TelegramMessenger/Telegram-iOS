public extension Api {
    enum StoriesStealthMode: TypeConstructorDescription {
        case storiesStealthMode(flags: Int32, activeUntilDate: Int32?, cooldownUntilDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storiesStealthMode(let flags, let activeUntilDate, let cooldownUntilDate):
                    if boxed {
                        buffer.appendInt32(1898850301)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(activeUntilDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(cooldownUntilDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storiesStealthMode(let flags, let activeUntilDate, let cooldownUntilDate):
                return ("storiesStealthMode", [("flags", flags as Any), ("activeUntilDate", activeUntilDate as Any), ("cooldownUntilDate", cooldownUntilDate as Any)])
    }
    }
    
        public static func parse_storiesStealthMode(_ reader: BufferReader) -> StoriesStealthMode? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoriesStealthMode.storiesStealthMode(flags: _1!, activeUntilDate: _2, cooldownUntilDate: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StoryFwdHeader: TypeConstructorDescription {
        case storyFwdHeader(flags: Int32, from: Api.Peer?, fromName: String?, storyId: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyFwdHeader(let flags, let from, let fromName, let storyId):
                    if boxed {
                        buffer.appendInt32(-1205411504)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {from!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(fromName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(storyId!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyFwdHeader(let flags, let from, let fromName, let storyId):
                return ("storyFwdHeader", [("flags", flags as Any), ("from", from as Any), ("fromName", fromName as Any), ("storyId", storyId as Any)])
    }
    }
    
        public static func parse_storyFwdHeader(_ reader: BufferReader) -> StoryFwdHeader? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryFwdHeader.storyFwdHeader(flags: _1!, from: _2, fromName: _3, storyId: _4)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum StoryItem: TypeConstructorDescription {
        case storyItem(flags: Int32, id: Int32, date: Int32, fromId: Api.Peer?, fwdFrom: Api.StoryFwdHeader?, expireDate: Int32, caption: String?, entities: [Api.MessageEntity]?, media: Api.MessageMedia, mediaAreas: [Api.MediaArea]?, privacy: [Api.PrivacyRule]?, views: Api.StoryViews?, sentReaction: Api.Reaction?)
        case storyItemDeleted(id: Int32)
        case storyItemSkipped(flags: Int32, id: Int32, date: Int32, expireDate: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyItem(let flags, let id, let date, let fromId, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                    if boxed {
                        buffer.appendInt32(2041735716)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 18) != 0 {fromId!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 17) != 0 {fwdFrom!.serialize(buffer, true)}
                    serializeInt32(expireDate, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(caption!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    media.serialize(buffer, true)
                    if Int(flags) & Int(1 << 14) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(mediaAreas!.count))
                    for item in mediaAreas! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 2) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(privacy!.count))
                    for item in privacy! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 3) != 0 {views!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {sentReaction!.serialize(buffer, true)}
                    break
                case .storyItemDeleted(let id):
                    if boxed {
                        buffer.appendInt32(1374088783)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    break
                case .storyItemSkipped(let flags, let id, let date, let expireDate):
                    if boxed {
                        buffer.appendInt32(-5388013)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(expireDate, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyItem(let flags, let id, let date, let fromId, let fwdFrom, let expireDate, let caption, let entities, let media, let mediaAreas, let privacy, let views, let sentReaction):
                return ("storyItem", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("fromId", fromId as Any), ("fwdFrom", fwdFrom as Any), ("expireDate", expireDate as Any), ("caption", caption as Any), ("entities", entities as Any), ("media", media as Any), ("mediaAreas", mediaAreas as Any), ("privacy", privacy as Any), ("views", views as Any), ("sentReaction", sentReaction as Any)])
                case .storyItemDeleted(let id):
                return ("storyItemDeleted", [("id", id as Any)])
                case .storyItemSkipped(let flags, let id, let date, let expireDate):
                return ("storyItemSkipped", [("flags", flags as Any), ("id", id as Any), ("date", date as Any), ("expireDate", expireDate as Any)])
    }
    }
    
        public static func parse_storyItem(_ reader: BufferReader) -> StoryItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _5: Api.StoryFwdHeader?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.StoryFwdHeader
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: String?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseString(reader) }
            var _8: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 1) != 0 {if let _ = reader.readInt32() {
                _8 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _9: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _10: [Api.MediaArea]?
            if Int(_1!) & Int(1 << 14) != 0 {if let _ = reader.readInt32() {
                _10 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MediaArea.self)
            } }
            var _11: [Api.PrivacyRule]?
            if Int(_1!) & Int(1 << 2) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            } }
            var _12: Api.StoryViews?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _12 = Api.parse(reader, signature: signature) as? Api.StoryViews
            } }
            var _13: Api.Reaction?
            if Int(_1!) & Int(1 << 15) != 0 {if let signature = reader.readInt32() {
                _13 = Api.parse(reader, signature: signature) as? Api.Reaction
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 18) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 17) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 14) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 2) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 3) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 15) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.StoryItem.storyItem(flags: _1!, id: _2!, date: _3!, fromId: _4, fwdFrom: _5, expireDate: _6!, caption: _7, entities: _8, media: _9!, mediaAreas: _10, privacy: _11, views: _12, sentReaction: _13)
            }
            else {
                return nil
            }
        }
        public static func parse_storyItemDeleted(_ reader: BufferReader) -> StoryItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.StoryItem.storyItemDeleted(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_storyItemSkipped(_ reader: BufferReader) -> StoryItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryItem.storyItemSkipped(flags: _1!, id: _2!, date: _3!, expireDate: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum StoryReaction: TypeConstructorDescription {
        case storyReaction(peerId: Api.Peer, date: Int32, reaction: Api.Reaction)
        case storyReactionPublicForward(message: Api.Message)
        case storyReactionPublicRepost(peerId: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyReaction(let peerId, let date, let reaction):
                    if boxed {
                        buffer.appendInt32(1620104917)
                    }
                    peerId.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    break
                case .storyReactionPublicForward(let message):
                    if boxed {
                        buffer.appendInt32(-1146411453)
                    }
                    message.serialize(buffer, true)
                    break
                case .storyReactionPublicRepost(let peerId, let story):
                    if boxed {
                        buffer.appendInt32(-808644845)
                    }
                    peerId.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyReaction(let peerId, let date, let reaction):
                return ("storyReaction", [("peerId", peerId as Any), ("date", date as Any), ("reaction", reaction as Any)])
                case .storyReactionPublicForward(let message):
                return ("storyReactionPublicForward", [("message", message as Any)])
                case .storyReactionPublicRepost(let peerId, let story):
                return ("storyReactionPublicRepost", [("peerId", peerId as Any), ("story", story as Any)])
    }
    }
    
        public static func parse_storyReaction(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoryReaction.storyReaction(peerId: _1!, date: _2!, reaction: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_storyReactionPublicForward(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.StoryReaction.storyReactionPublicForward(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_storyReactionPublicRepost(_ reader: BufferReader) -> StoryReaction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StoryReaction.storyReactionPublicRepost(peerId: _1!, story: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum StoryView: TypeConstructorDescription {
        case storyView(flags: Int32, userId: Int64, date: Int32, reaction: Api.Reaction?)
        case storyViewPublicForward(flags: Int32, message: Api.Message)
        case storyViewPublicRepost(flags: Int32, peerId: Api.Peer, story: Api.StoryItem)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyView(let flags, let userId, let date, let reaction):
                    if boxed {
                        buffer.appendInt32(-1329730875)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {reaction!.serialize(buffer, true)}
                    break
                case .storyViewPublicForward(let flags, let message):
                    if boxed {
                        buffer.appendInt32(-1870436597)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    break
                case .storyViewPublicRepost(let flags, let peerId, let story):
                    if boxed {
                        buffer.appendInt32(-1116418231)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peerId.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyView(let flags, let userId, let date, let reaction):
                return ("storyView", [("flags", flags as Any), ("userId", userId as Any), ("date", date as Any), ("reaction", reaction as Any)])
                case .storyViewPublicForward(let flags, let message):
                return ("storyViewPublicForward", [("flags", flags as Any), ("message", message as Any)])
                case .storyViewPublicRepost(let flags, let peerId, let story):
                return ("storyViewPublicRepost", [("flags", flags as Any), ("peerId", peerId as Any), ("story", story as Any)])
    }
    }
    
        public static func parse_storyView(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Reaction?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Reaction
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StoryView.storyView(flags: _1!, userId: _2!, date: _3!, reaction: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_storyViewPublicForward(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Message?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StoryView.storyViewPublicForward(flags: _1!, message: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_storyViewPublicRepost(_ reader: BufferReader) -> StoryView? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.StoryItem?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.StoryView.storyViewPublicRepost(flags: _1!, peerId: _2!, story: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum StoryViews: TypeConstructorDescription {
        case storyViews(flags: Int32, viewsCount: Int32, forwardsCount: Int32?, reactions: [Api.ReactionCount]?, reactionsCount: Int32?, recentViewers: [Int64]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .storyViews(let flags, let viewsCount, let forwardsCount, let reactions, let reactionsCount, let recentViewers):
                    if boxed {
                        buffer.appendInt32(-1923523370)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(viewsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {serializeInt32(forwardsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions!.count))
                    for item in reactions! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(reactionsCount!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentViewers!.count))
                    for item in recentViewers! {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .storyViews(let flags, let viewsCount, let forwardsCount, let reactions, let reactionsCount, let recentViewers):
                return ("storyViews", [("flags", flags as Any), ("viewsCount", viewsCount as Any), ("forwardsCount", forwardsCount as Any), ("reactions", reactions as Any), ("reactionsCount", reactionsCount as Any), ("recentViewers", recentViewers as Any)])
    }
    }
    
        public static func parse_storyViews(_ reader: BufferReader) -> StoryViews? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            if Int(_1!) & Int(1 << 2) != 0 {_3 = reader.readInt32() }
            var _4: [Api.ReactionCount]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReactionCount.self)
            } }
            var _5: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_5 = reader.readInt32() }
            var _6: [Int64]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 4) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.StoryViews.storyViews(flags: _1!, viewsCount: _2!, forwardsCount: _3, reactions: _4, reactionsCount: _5, recentViewers: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TextWithEntities: TypeConstructorDescription {
        case textWithEntities(text: String, entities: [Api.MessageEntity])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .textWithEntities(let text, let entities):
                    if boxed {
                        buffer.appendInt32(1964978502)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .textWithEntities(let text, let entities):
                return ("textWithEntities", [("text", text as Any), ("entities", entities as Any)])
    }
    }
    
        public static func parse_textWithEntities(_ reader: BufferReader) -> TextWithEntities? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TextWithEntities.textWithEntities(text: _1!, entities: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Theme: TypeConstructorDescription {
        case theme(flags: Int32, id: Int64, accessHash: Int64, slug: String, title: String, document: Api.Document?, settings: [Api.ThemeSettings]?, emoticon: String?, installsCount: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let emoticon, let installsCount):
                    if boxed {
                        buffer.appendInt32(-1609668650)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(settings!.count))
                    for item in settings! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 6) != 0 {serializeString(emoticon!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(installsCount!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .theme(let flags, let id, let accessHash, let slug, let title, let document, let settings, let emoticon, let installsCount):
                return ("theme", [("flags", flags as Any), ("id", id as Any), ("accessHash", accessHash as Any), ("slug", slug as Any), ("title", title as Any), ("document", document as Any), ("settings", settings as Any), ("emoticon", emoticon as Any), ("installsCount", installsCount as Any)])
    }
    }
    
        public static func parse_theme(_ reader: BufferReader) -> Theme? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.Document?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _7: [Api.ThemeSettings]?
            if Int(_1!) & Int(1 << 3) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ThemeSettings.self)
            } }
            var _8: String?
            if Int(_1!) & Int(1 << 6) != 0 {_8 = parseString(reader) }
            var _9: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_9 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 4) == 0) || _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Theme.theme(flags: _1!, id: _2!, accessHash: _3!, slug: _4!, title: _5!, document: _6, settings: _7, emoticon: _8, installsCount: _9)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum ThemeSettings: TypeConstructorDescription {
        case themeSettings(flags: Int32, baseTheme: Api.BaseTheme, accentColor: Int32, outboxAccentColor: Int32?, messageColors: [Int32]?, wallpaper: Api.WallPaper?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper):
                    if boxed {
                        buffer.appendInt32(-94849324)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    baseTheme.serialize(buffer, true)
                    serializeInt32(accentColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(outboxAccentColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messageColors!.count))
                    for item in messageColors! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    if Int(flags) & Int(1 << 1) != 0 {wallpaper!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .themeSettings(let flags, let baseTheme, let accentColor, let outboxAccentColor, let messageColors, let wallpaper):
                return ("themeSettings", [("flags", flags as Any), ("baseTheme", baseTheme as Any), ("accentColor", accentColor as Any), ("outboxAccentColor", outboxAccentColor as Any), ("messageColors", messageColors as Any), ("wallpaper", wallpaper as Any)])
    }
    }
    
        public static func parse_themeSettings(_ reader: BufferReader) -> ThemeSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.BaseTheme?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BaseTheme
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_4 = reader.readInt32() }
            var _5: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            var _6: Api.WallPaper?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WallPaper
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 3) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.ThemeSettings.themeSettings(flags: _1!, baseTheme: _2!, accentColor: _3!, outboxAccentColor: _4, messageColors: _5, wallpaper: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum Timezone: TypeConstructorDescription {
        case timezone(id: String, name: String, utcOffset: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .timezone(let id, let name, let utcOffset):
                    if boxed {
                        buffer.appendInt32(-7173643)
                    }
                    serializeString(id, buffer: buffer, boxed: false)
                    serializeString(name, buffer: buffer, boxed: false)
                    serializeInt32(utcOffset, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .timezone(let id, let name, let utcOffset):
                return ("timezone", [("id", id as Any), ("name", name as Any), ("utcOffset", utcOffset as Any)])
    }
    }
    
        public static func parse_timezone(_ reader: BufferReader) -> Timezone? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Timezone.timezone(id: _1!, name: _2!, utcOffset: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TopPeer: TypeConstructorDescription {
        case topPeer(peer: Api.Peer, rating: Double)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeer(let peer, let rating):
                    if boxed {
                        buffer.appendInt32(-305282981)
                    }
                    peer.serialize(buffer, true)
                    serializeDouble(rating, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeer(let peer, let rating):
                return ("topPeer", [("peer", peer as Any), ("rating", rating as Any)])
    }
    }
    
        public static func parse_topPeer(_ reader: BufferReader) -> TopPeer? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Double?
            _2 = reader.readDouble()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TopPeer.topPeer(peer: _1!, rating: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TopPeerCategory: TypeConstructorDescription {
        case topPeerCategoryBotsApp
        case topPeerCategoryBotsInline
        case topPeerCategoryBotsPM
        case topPeerCategoryChannels
        case topPeerCategoryCorrespondents
        case topPeerCategoryForwardChats
        case topPeerCategoryForwardUsers
        case topPeerCategoryGroups
        case topPeerCategoryPhoneCalls
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeerCategoryBotsApp:
                    if boxed {
                        buffer.appendInt32(-39945236)
                    }
                    
                    break
                case .topPeerCategoryBotsInline:
                    if boxed {
                        buffer.appendInt32(344356834)
                    }
                    
                    break
                case .topPeerCategoryBotsPM:
                    if boxed {
                        buffer.appendInt32(-1419371685)
                    }
                    
                    break
                case .topPeerCategoryChannels:
                    if boxed {
                        buffer.appendInt32(371037736)
                    }
                    
                    break
                case .topPeerCategoryCorrespondents:
                    if boxed {
                        buffer.appendInt32(104314861)
                    }
                    
                    break
                case .topPeerCategoryForwardChats:
                    if boxed {
                        buffer.appendInt32(-68239120)
                    }
                    
                    break
                case .topPeerCategoryForwardUsers:
                    if boxed {
                        buffer.appendInt32(-1472172887)
                    }
                    
                    break
                case .topPeerCategoryGroups:
                    if boxed {
                        buffer.appendInt32(-1122524854)
                    }
                    
                    break
                case .topPeerCategoryPhoneCalls:
                    if boxed {
                        buffer.appendInt32(511092620)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeerCategoryBotsApp:
                return ("topPeerCategoryBotsApp", [])
                case .topPeerCategoryBotsInline:
                return ("topPeerCategoryBotsInline", [])
                case .topPeerCategoryBotsPM:
                return ("topPeerCategoryBotsPM", [])
                case .topPeerCategoryChannels:
                return ("topPeerCategoryChannels", [])
                case .topPeerCategoryCorrespondents:
                return ("topPeerCategoryCorrespondents", [])
                case .topPeerCategoryForwardChats:
                return ("topPeerCategoryForwardChats", [])
                case .topPeerCategoryForwardUsers:
                return ("topPeerCategoryForwardUsers", [])
                case .topPeerCategoryGroups:
                return ("topPeerCategoryGroups", [])
                case .topPeerCategoryPhoneCalls:
                return ("topPeerCategoryPhoneCalls", [])
    }
    }
    
        public static func parse_topPeerCategoryBotsApp(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsApp
        }
        public static func parse_topPeerCategoryBotsInline(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsInline
        }
        public static func parse_topPeerCategoryBotsPM(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryBotsPM
        }
        public static func parse_topPeerCategoryChannels(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryChannels
        }
        public static func parse_topPeerCategoryCorrespondents(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryCorrespondents
        }
        public static func parse_topPeerCategoryForwardChats(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardChats
        }
        public static func parse_topPeerCategoryForwardUsers(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryForwardUsers
        }
        public static func parse_topPeerCategoryGroups(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryGroups
        }
        public static func parse_topPeerCategoryPhoneCalls(_ reader: BufferReader) -> TopPeerCategory? {
            return Api.TopPeerCategory.topPeerCategoryPhoneCalls
        }
    
    }
}
public extension Api {
    enum TopPeerCategoryPeers: TypeConstructorDescription {
        case topPeerCategoryPeers(category: Api.TopPeerCategory, count: Int32, peers: [Api.TopPeer])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .topPeerCategoryPeers(let category, let count, let peers):
                    if boxed {
                        buffer.appendInt32(-75283823)
                    }
                    category.serialize(buffer, true)
                    serializeInt32(count, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .topPeerCategoryPeers(let category, let count, let peers):
                return ("topPeerCategoryPeers", [("category", category as Any), ("count", count as Any), ("peers", peers as Any)])
    }
    }
    
        public static func parse_topPeerCategoryPeers(_ reader: BufferReader) -> TopPeerCategoryPeers? {
            var _1: Api.TopPeerCategory?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.TopPeerCategory
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.TopPeer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TopPeer.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TopPeerCategoryPeers.topPeerCategoryPeers(category: _1!, count: _2!, peers: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    indirect enum Update: TypeConstructorDescription {
        case updateAttachMenuBots
        case updateAutoSaveSettings
        case updateBotBusinessConnect(connection: Api.BotBusinessConnection, qts: Int32)
        case updateBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, peer: Api.Peer, msgId: Int32, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateBotChatBoost(peer: Api.Peer, boost: Api.Boost, qts: Int32)
        case updateBotChatInviteRequester(peer: Api.Peer, date: Int32, userId: Int64, about: String, invite: Api.ExportedChatInvite, qts: Int32)
        case updateBotCommands(peer: Api.Peer, botId: Int64, commands: [Api.BotCommand])
        case updateBotDeleteBusinessMessage(connectionId: String, peer: Api.Peer, messages: [Int32], qts: Int32)
        case updateBotEditBusinessMessage(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32)
        case updateBotInlineQuery(flags: Int32, queryId: Int64, userId: Int64, query: String, geo: Api.GeoPoint?, peerType: Api.InlineQueryPeerType?, offset: String)
        case updateBotInlineSend(flags: Int32, userId: Int64, query: String, geo: Api.GeoPoint?, id: String, msgId: Api.InputBotInlineMessageID?)
        case updateBotMenuButton(botId: Int64, button: Api.BotMenuButton)
        case updateBotMessageReaction(peer: Api.Peer, msgId: Int32, date: Int32, actor: Api.Peer, oldReactions: [Api.Reaction], newReactions: [Api.Reaction], qts: Int32)
        case updateBotMessageReactions(peer: Api.Peer, msgId: Int32, date: Int32, reactions: [Api.ReactionCount], qts: Int32)
        case updateBotNewBusinessMessage(flags: Int32, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, qts: Int32)
        case updateBotPrecheckoutQuery(flags: Int32, queryId: Int64, userId: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, currency: String, totalAmount: Int64)
        case updateBotPurchasedPaidMedia(userId: Int64, payload: String, qts: Int32)
        case updateBotShippingQuery(queryId: Int64, userId: Int64, payload: Buffer, shippingAddress: Api.PostAddress)
        case updateBotStopped(userId: Int64, date: Int32, stopped: Api.Bool, qts: Int32)
        case updateBotWebhookJSON(data: Api.DataJSON)
        case updateBotWebhookJSONQuery(queryId: Int64, data: Api.DataJSON, timeout: Int32)
        case updateBroadcastRevenueTransactions(peer: Api.Peer, balances: Api.BroadcastRevenueBalances)
        case updateBusinessBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, connectionId: String, message: Api.Message, replyToMessage: Api.Message?, chatInstance: Int64, data: Buffer?)
        case updateChannel(channelId: Int64)
        case updateChannelAvailableMessages(channelId: Int64, availableMinId: Int32)
        case updateChannelMessageForwards(channelId: Int64, id: Int32, forwards: Int32)
        case updateChannelMessageViews(channelId: Int64, id: Int32, views: Int32)
        case updateChannelParticipant(flags: Int32, channelId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChannelParticipant?, newParticipant: Api.ChannelParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChannelPinnedTopic(flags: Int32, channelId: Int64, topicId: Int32)
        case updateChannelPinnedTopics(flags: Int32, channelId: Int64, order: [Int32]?)
        case updateChannelReadMessagesContents(flags: Int32, channelId: Int64, topMsgId: Int32?, savedPeerId: Api.Peer?, messages: [Int32])
        case updateChannelTooLong(flags: Int32, channelId: Int64, pts: Int32?)
        case updateChannelUserTyping(flags: Int32, channelId: Int64, topMsgId: Int32?, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateChannelViewForumAsMessages(channelId: Int64, enabled: Api.Bool)
        case updateChannelWebPage(channelId: Int64, webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateChat(chatId: Int64)
        case updateChatDefaultBannedRights(peer: Api.Peer, defaultBannedRights: Api.ChatBannedRights, version: Int32)
        case updateChatParticipant(flags: Int32, chatId: Int64, date: Int32, actorId: Int64, userId: Int64, prevParticipant: Api.ChatParticipant?, newParticipant: Api.ChatParticipant?, invite: Api.ExportedChatInvite?, qts: Int32)
        case updateChatParticipantAdd(chatId: Int64, userId: Int64, inviterId: Int64, date: Int32, version: Int32)
        case updateChatParticipantAdmin(chatId: Int64, userId: Int64, isAdmin: Api.Bool, version: Int32)
        case updateChatParticipantDelete(chatId: Int64, userId: Int64, version: Int32)
        case updateChatParticipants(participants: Api.ChatParticipants)
        case updateChatUserTyping(chatId: Int64, fromId: Api.Peer, action: Api.SendMessageAction)
        case updateConfig
        case updateContactsReset
        case updateDcOptions(dcOptions: [Api.DcOption])
        case updateDeleteChannelMessages(channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteMessages(messages: [Int32], pts: Int32, ptsCount: Int32)
        case updateDeleteQuickReply(shortcutId: Int32)
        case updateDeleteQuickReplyMessages(shortcutId: Int32, messages: [Int32])
        case updateDeleteScheduledMessages(flags: Int32, peer: Api.Peer, messages: [Int32], sentMessages: [Int32]?)
        case updateDialogFilter(flags: Int32, id: Int32, filter: Api.DialogFilter?)
        case updateDialogFilterOrder(order: [Int32])
        case updateDialogFilters
        case updateDialogPinned(flags: Int32, folderId: Int32?, peer: Api.DialogPeer)
        case updateDialogUnreadMark(flags: Int32, peer: Api.DialogPeer, savedPeerId: Api.Peer?)
        case updateDraftMessage(flags: Int32, peer: Api.Peer, topMsgId: Int32?, savedPeerId: Api.Peer?, draft: Api.DraftMessage)
        case updateEditChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEditMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateEncryptedChatTyping(chatId: Int32)
        case updateEncryptedMessagesRead(chatId: Int32, maxDate: Int32, date: Int32)
        case updateEncryption(chat: Api.EncryptedChat, date: Int32)
        case updateFavedStickers
        case updateFolderPeers(folderPeers: [Api.FolderPeer], pts: Int32, ptsCount: Int32)
        case updateGeoLiveViewed(peer: Api.Peer, msgId: Int32)
        case updateGroupCall(flags: Int32, chatId: Int64?, call: Api.GroupCall)
        case updateGroupCallChainBlocks(call: Api.InputGroupCall, subChainId: Int32, blocks: [Buffer], nextOffset: Int32)
        case updateGroupCallConnection(flags: Int32, params: Api.DataJSON)
        case updateGroupCallParticipants(call: Api.InputGroupCall, participants: [Api.GroupCallParticipant], version: Int32)
        case updateInlineBotCallbackQuery(flags: Int32, queryId: Int64, userId: Int64, msgId: Api.InputBotInlineMessageID, chatInstance: Int64, data: Buffer?, gameShortName: String?)
        case updateLangPack(difference: Api.LangPackDifference)
        case updateLangPackTooLong(langCode: String)
        case updateLoginToken
        case updateMessageExtendedMedia(peer: Api.Peer, msgId: Int32, extendedMedia: [Api.MessageExtendedMedia])
        case updateMessageID(id: Int32, randomId: Int64)
        case updateMessagePoll(flags: Int32, pollId: Int64, poll: Api.Poll?, results: Api.PollResults)
        case updateMessagePollVote(pollId: Int64, peer: Api.Peer, options: [Buffer], qts: Int32)
        case updateMessageReactions(flags: Int32, peer: Api.Peer, msgId: Int32, topMsgId: Int32?, savedPeerId: Api.Peer?, reactions: Api.MessageReactions)
        case updateMoveStickerSetToTop(flags: Int32, stickerset: Int64)
        case updateNewAuthorization(flags: Int32, hash: Int64, date: Int32?, device: String?, location: String?)
        case updateNewChannelMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewEncryptedMessage(message: Api.EncryptedMessage, qts: Int32)
        case updateNewMessage(message: Api.Message, pts: Int32, ptsCount: Int32)
        case updateNewQuickReply(quickReply: Api.QuickReply)
        case updateNewScheduledMessage(message: Api.Message)
        case updateNewStickerSet(stickerset: Api.messages.StickerSet)
        case updateNewStoryReaction(storyId: Int32, peer: Api.Peer, reaction: Api.Reaction)
        case updateNotifySettings(peer: Api.NotifyPeer, notifySettings: Api.PeerNotifySettings)
        case updatePaidReactionPrivacy(private: Api.PaidReactionPrivacy)
        case updatePeerBlocked(flags: Int32, peerId: Api.Peer)
        case updatePeerHistoryTTL(flags: Int32, peer: Api.Peer, ttlPeriod: Int32?)
        case updatePeerLocated(peers: [Api.PeerLocated])
        case updatePeerSettings(peer: Api.Peer, settings: Api.PeerSettings)
        case updatePeerWallpaper(flags: Int32, peer: Api.Peer, wallpaper: Api.WallPaper?)
        case updatePendingJoinRequests(peer: Api.Peer, requestsPending: Int32, recentRequesters: [Int64])
        case updatePhoneCall(phoneCall: Api.PhoneCall)
        case updatePhoneCallSignalingData(phoneCallId: Int64, data: Buffer)
        case updatePinnedChannelMessages(flags: Int32, channelId: Int64, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePinnedDialogs(flags: Int32, folderId: Int32?, order: [Api.DialogPeer]?)
        case updatePinnedMessages(flags: Int32, peer: Api.Peer, messages: [Int32], pts: Int32, ptsCount: Int32)
        case updatePinnedSavedDialogs(flags: Int32, order: [Api.DialogPeer]?)
        case updatePrivacy(key: Api.PrivacyKey, rules: [Api.PrivacyRule])
        case updatePtsChanged
        case updateQuickReplies(quickReplies: [Api.QuickReply])
        case updateQuickReplyMessage(message: Api.Message)
        case updateReadChannelDiscussionInbox(flags: Int32, channelId: Int64, topMsgId: Int32, readMaxId: Int32, broadcastId: Int64?, broadcastPost: Int32?)
        case updateReadChannelDiscussionOutbox(channelId: Int64, topMsgId: Int32, readMaxId: Int32)
        case updateReadChannelInbox(flags: Int32, folderId: Int32?, channelId: Int64, maxId: Int32, stillUnreadCount: Int32, pts: Int32)
        case updateReadChannelOutbox(channelId: Int64, maxId: Int32)
        case updateReadFeaturedEmojiStickers
        case updateReadFeaturedStickers
        case updateReadHistoryInbox(flags: Int32, folderId: Int32?, peer: Api.Peer, maxId: Int32, stillUnreadCount: Int32, pts: Int32, ptsCount: Int32)
        case updateReadHistoryOutbox(peer: Api.Peer, maxId: Int32, pts: Int32, ptsCount: Int32)
        case updateReadMessagesContents(flags: Int32, messages: [Int32], pts: Int32, ptsCount: Int32, date: Int32?)
        case updateReadMonoForumInbox(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32)
        case updateReadMonoForumOutbox(channelId: Int64, savedPeerId: Api.Peer, readMaxId: Int32)
        case updateReadStories(peer: Api.Peer, maxId: Int32)
        case updateRecentEmojiStatuses
        case updateRecentReactions
        case updateRecentStickers
        case updateSavedDialogPinned(flags: Int32, peer: Api.DialogPeer)
        case updateSavedGifs
        case updateSavedReactionTags
        case updateSavedRingtones
        case updateSentPhoneCode(sentCode: Api.auth.SentCode)
        case updateSentStoryReaction(peer: Api.Peer, storyId: Int32, reaction: Api.Reaction)
        case updateServiceNotification(flags: Int32, inboxDate: Int32?, type: String, message: String, media: Api.MessageMedia, entities: [Api.MessageEntity])
        case updateSmsJob(jobId: String)
        case updateStarsBalance(balance: Api.StarsAmount)
        case updateStarsRevenueStatus(peer: Api.Peer, status: Api.StarsRevenueStatus)
        case updateStickerSets(flags: Int32)
        case updateStickerSetsOrder(flags: Int32, order: [Int64])
        case updateStoriesStealthMode(stealthMode: Api.StoriesStealthMode)
        case updateStory(peer: Api.Peer, story: Api.StoryItem)
        case updateStoryID(id: Int32, randomId: Int64)
        case updateTheme(theme: Api.Theme)
        case updateTranscribedAudio(flags: Int32, peer: Api.Peer, msgId: Int32, transcriptionId: Int64, text: String)
        case updateUser(userId: Int64)
        case updateUserEmojiStatus(userId: Int64, emojiStatus: Api.EmojiStatus)
        case updateUserName(userId: Int64, firstName: String, lastName: String, usernames: [Api.Username])
        case updateUserPhone(userId: Int64, phone: String)
        case updateUserStatus(userId: Int64, status: Api.UserStatus)
        case updateUserTyping(userId: Int64, action: Api.SendMessageAction)
        case updateWebPage(webpage: Api.WebPage, pts: Int32, ptsCount: Int32)
        case updateWebViewResultSent(queryId: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .updateAttachMenuBots:
                    if boxed {
                        buffer.appendInt32(397910539)
                    }
                    
                    break
                case .updateAutoSaveSettings:
                    if boxed {
                        buffer.appendInt32(-335171433)
                    }
                    
                    break
                case .updateBotBusinessConnect(let connection, let qts):
                    if boxed {
                        buffer.appendInt32(-1964652166)
                    }
                    connection.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(-1177566067)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateBotChatBoost(let peer, let boost, let qts):
                    if boxed {
                        buffer.appendInt32(-1873947492)
                    }
                    peer.serialize(buffer, true)
                    boost.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotChatInviteRequester(let peer, let date, let userId, let about, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(299870598)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(about, buffer: buffer, boxed: false)
                    invite.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotCommands(let peer, let botId, let commands):
                    if boxed {
                        buffer.appendInt32(1299263278)
                    }
                    peer.serialize(buffer, true)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(commands.count))
                    for item in commands {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateBotDeleteBusinessMessage(let connectionId, let peer, let messages, let qts):
                    if boxed {
                        buffer.appendInt32(-1607821266)
                    }
                    serializeString(connectionId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotEditBusinessMessage(let flags, let connectionId, let message, let replyToMessage, let qts):
                    if boxed {
                        buffer.appendInt32(132077692)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(connectionId, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyToMessage!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let peerType, let offset):
                    if boxed {
                        buffer.appendInt32(1232025500)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {peerType!.serialize(buffer, true)}
                    serializeString(offset, buffer: buffer, boxed: false)
                    break
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                    if boxed {
                        buffer.appendInt32(317794823)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(query, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {geo!.serialize(buffer, true)}
                    serializeString(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {msgId!.serialize(buffer, true)}
                    break
                case .updateBotMenuButton(let botId, let button):
                    if boxed {
                        buffer.appendInt32(347625491)
                    }
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    button.serialize(buffer, true)
                    break
                case .updateBotMessageReaction(let peer, let msgId, let date, let actor, let oldReactions, let newReactions, let qts):
                    if boxed {
                        buffer.appendInt32(-1407069234)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    actor.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(oldReactions.count))
                    for item in oldReactions {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(newReactions.count))
                    for item in newReactions {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotMessageReactions(let peer, let msgId, let date, let reactions, let qts):
                    if boxed {
                        buffer.appendInt32(164329305)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(reactions.count))
                    for item in reactions {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotNewBusinessMessage(let flags, let connectionId, let message, let replyToMessage, let qts):
                    if boxed {
                        buffer.appendInt32(-1646578564)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(connectionId, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {replyToMessage!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                    if boxed {
                        buffer.appendInt32(-1934976362)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    break
                case .updateBotPurchasedPaidMedia(let userId, let payload, let qts):
                    if boxed {
                        buffer.appendInt32(675009298)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(payload, buffer: buffer, boxed: false)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                    if boxed {
                        buffer.appendInt32(-1246823043)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    shippingAddress.serialize(buffer, true)
                    break
                case .updateBotStopped(let userId, let date, let stopped, let qts):
                    if boxed {
                        buffer.appendInt32(-997782967)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    stopped.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateBotWebhookJSON(let data):
                    if boxed {
                        buffer.appendInt32(-2095595325)
                    }
                    data.serialize(buffer, true)
                    break
                case .updateBotWebhookJSONQuery(let queryId, let data, let timeout):
                    if boxed {
                        buffer.appendInt32(-1684914010)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    data.serialize(buffer, true)
                    serializeInt32(timeout, buffer: buffer, boxed: false)
                    break
                case .updateBroadcastRevenueTransactions(let peer, let balances):
                    if boxed {
                        buffer.appendInt32(-539401739)
                    }
                    peer.serialize(buffer, true)
                    balances.serialize(buffer, true)
                    break
                case .updateBusinessBotCallbackQuery(let flags, let queryId, let userId, let connectionId, let message, let replyToMessage, let chatInstance, let data):
                    if boxed {
                        buffer.appendInt32(513998247)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(connectionId, buffer: buffer, boxed: false)
                    message.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {replyToMessage!.serialize(buffer, true)}
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    break
                case .updateChannel(let channelId):
                    if boxed {
                        buffer.appendInt32(1666927625)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                    if boxed {
                        buffer.appendInt32(-1304443240)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(availableMinId, buffer: buffer, boxed: false)
                    break
                case .updateChannelMessageForwards(let channelId, let id, let forwards):
                    if boxed {
                        buffer.appendInt32(-761649164)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(forwards, buffer: buffer, boxed: false)
                    break
                case .updateChannelMessageViews(let channelId, let id, let views):
                    if boxed {
                        buffer.appendInt32(-232346616)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(views, buffer: buffer, boxed: false)
                    break
                case .updateChannelParticipant(let flags, let channelId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(-1738720581)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(actorId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {invite!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateChannelPinnedTopic(let flags, let channelId, let topicId):
                    if boxed {
                        buffer.appendInt32(422509539)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(topicId, buffer: buffer, boxed: false)
                    break
                case .updateChannelPinnedTopics(let flags, let channelId, let order):
                    if boxed {
                        buffer.appendInt32(-31881726)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order!.count))
                    for item in order! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
                case .updateChannelReadMessagesContents(let flags, let channelId, let topMsgId, let savedPeerId, let messages):
                    if boxed {
                        buffer.appendInt32(636691703)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateChannelTooLong(let flags, let channelId, let pts):
                    if boxed {
                        buffer.appendInt32(277713951)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(pts!, buffer: buffer, boxed: false)}
                    break
                case .updateChannelUserTyping(let flags, let channelId, let topMsgId, let fromId, let action):
                    if boxed {
                        buffer.appendInt32(-1937192669)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    fromId.serialize(buffer, true)
                    action.serialize(buffer, true)
                    break
                case .updateChannelViewForumAsMessages(let channelId, let enabled):
                    if boxed {
                        buffer.appendInt32(129403168)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    enabled.serialize(buffer, true)
                    break
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(791390623)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    webpage.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateChat(let chatId):
                    if boxed {
                        buffer.appendInt32(-124097970)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                    if boxed {
                        buffer.appendInt32(1421875280)
                    }
                    peer.serialize(buffer, true)
                    defaultBannedRights.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipant(let flags, let chatId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                    if boxed {
                        buffer.appendInt32(-796432838)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt64(actorId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {prevParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {newParticipant!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 2) != 0 {invite!.serialize(buffer, true)}
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                    if boxed {
                        buffer.appendInt32(1037718609)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                    if boxed {
                        buffer.appendInt32(-674602590)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    isAdmin.serialize(buffer, true)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                    if boxed {
                        buffer.appendInt32(-483443337)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateChatParticipants(let participants):
                    if boxed {
                        buffer.appendInt32(125178264)
                    }
                    participants.serialize(buffer, true)
                    break
                case .updateChatUserTyping(let chatId, let fromId, let action):
                    if boxed {
                        buffer.appendInt32(-2092401936)
                    }
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    fromId.serialize(buffer, true)
                    action.serialize(buffer, true)
                    break
                case .updateConfig:
                    if boxed {
                        buffer.appendInt32(-1574314746)
                    }
                    
                    break
                case .updateContactsReset:
                    if boxed {
                        buffer.appendInt32(1887741886)
                    }
                    
                    break
                case .updateDcOptions(let dcOptions):
                    if boxed {
                        buffer.appendInt32(-1906403213)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(dcOptions.count))
                    for item in dcOptions {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1020437742)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateDeleteMessages(let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1576161051)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateDeleteQuickReply(let shortcutId):
                    if boxed {
                        buffer.appendInt32(1407644140)
                    }
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    break
                case .updateDeleteQuickReplyMessages(let shortcutId, let messages):
                    if boxed {
                        buffer.appendInt32(1450174413)
                    }
                    serializeInt32(shortcutId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateDeleteScheduledMessages(let flags, let peer, let messages, let sentMessages):
                    if boxed {
                        buffer.appendInt32(-223929981)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(sentMessages!.count))
                    for item in sentMessages! {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }}
                    break
                case .updateDialogFilter(let flags, let id, let filter):
                    if boxed {
                        buffer.appendInt32(654302845)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {filter!.serialize(buffer, true)}
                    break
                case .updateDialogFilterOrder(let order):
                    if boxed {
                        buffer.appendInt32(-1512627963)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateDialogFilters:
                    if boxed {
                        buffer.appendInt32(889491791)
                    }
                    
                    break
                case .updateDialogPinned(let flags, let folderId, let peer):
                    if boxed {
                        buffer.appendInt32(1852826908)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    break
                case .updateDialogUnreadMark(let flags, let peer, let savedPeerId):
                    if boxed {
                        buffer.appendInt32(-1235684802)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    break
                case .updateDraftMessage(let flags, let peer, let topMsgId, let savedPeerId, let draft):
                    if boxed {
                        buffer.appendInt32(-302247650)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    draft.serialize(buffer, true)
                    break
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(457133559)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateEditMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-469536605)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedChatTyping(let chatId):
                    if boxed {
                        buffer.appendInt32(386986326)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    break
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                    if boxed {
                        buffer.appendInt32(956179895)
                    }
                    serializeInt32(chatId, buffer: buffer, boxed: false)
                    serializeInt32(maxDate, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateEncryption(let chat, let date):
                    if boxed {
                        buffer.appendInt32(-1264392051)
                    }
                    chat.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateFavedStickers:
                    if boxed {
                        buffer.appendInt32(-451831443)
                    }
                    
                    break
                case .updateFolderPeers(let folderPeers, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(422972864)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(folderPeers.count))
                    for item in folderPeers {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateGeoLiveViewed(let peer, let msgId):
                    if boxed {
                        buffer.appendInt32(-2027964103)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    break
                case .updateGroupCall(let flags, let chatId, let call):
                    if boxed {
                        buffer.appendInt32(-1747565759)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(chatId!, buffer: buffer, boxed: false)}
                    call.serialize(buffer, true)
                    break
                case .updateGroupCallChainBlocks(let call, let subChainId, let blocks, let nextOffset):
                    if boxed {
                        buffer.appendInt32(-1535694705)
                    }
                    call.serialize(buffer, true)
                    serializeInt32(subChainId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(blocks.count))
                    for item in blocks {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(nextOffset, buffer: buffer, boxed: false)
                    break
                case .updateGroupCallConnection(let flags, let params):
                    if boxed {
                        buffer.appendInt32(192428418)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    params.serialize(buffer, true)
                    break
                case .updateGroupCallParticipants(let call, let participants, let version):
                    if boxed {
                        buffer.appendInt32(-219423922)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(participants.count))
                    for item in participants {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(version, buffer: buffer, boxed: false)
                    break
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                    if boxed {
                        buffer.appendInt32(1763610706)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    msgId.serialize(buffer, true)
                    serializeInt64(chatInstance, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeBytes(data!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(gameShortName!, buffer: buffer, boxed: false)}
                    break
                case .updateLangPack(let difference):
                    if boxed {
                        buffer.appendInt32(1442983757)
                    }
                    difference.serialize(buffer, true)
                    break
                case .updateLangPackTooLong(let langCode):
                    if boxed {
                        buffer.appendInt32(1180041828)
                    }
                    serializeString(langCode, buffer: buffer, boxed: false)
                    break
                case .updateLoginToken:
                    if boxed {
                        buffer.appendInt32(1448076945)
                    }
                    
                    break
                case .updateMessageExtendedMedia(let peer, let msgId, let extendedMedia):
                    if boxed {
                        buffer.appendInt32(-710666460)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(extendedMedia.count))
                    for item in extendedMedia {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateMessageID(let id, let randomId):
                    if boxed {
                        buffer.appendInt32(1318109142)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    break
                case .updateMessagePoll(let flags, let pollId, let poll, let results):
                    if boxed {
                        buffer.appendInt32(-1398708869)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(pollId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {poll!.serialize(buffer, true)}
                    results.serialize(buffer, true)
                    break
                case .updateMessagePollVote(let pollId, let peer, let options, let qts):
                    if boxed {
                        buffer.appendInt32(619974263)
                    }
                    serializeInt64(pollId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(options.count))
                    for item in options {
                        serializeBytes(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateMessageReactions(let flags, let peer, let msgId, let topMsgId, let savedPeerId, let reactions):
                    if boxed {
                        buffer.appendInt32(506035194)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(topMsgId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {savedPeerId!.serialize(buffer, true)}
                    reactions.serialize(buffer, true)
                    break
                case .updateMoveStickerSetToTop(let flags, let stickerset):
                    if boxed {
                        buffer.appendInt32(-2030252155)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(stickerset, buffer: buffer, boxed: false)
                    break
                case .updateNewAuthorization(let flags, let hash, let date, let device, let location):
                    if boxed {
                        buffer.appendInt32(-1991136273)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(date!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(device!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(location!, buffer: buffer, boxed: false)}
                    break
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1656358105)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateNewEncryptedMessage(let message, let qts):
                    if boxed {
                        buffer.appendInt32(314359194)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(qts, buffer: buffer, boxed: false)
                    break
                case .updateNewMessage(let message, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(522914557)
                    }
                    message.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateNewQuickReply(let quickReply):
                    if boxed {
                        buffer.appendInt32(-180508905)
                    }
                    quickReply.serialize(buffer, true)
                    break
                case .updateNewScheduledMessage(let message):
                    if boxed {
                        buffer.appendInt32(967122427)
                    }
                    message.serialize(buffer, true)
                    break
                case .updateNewStickerSet(let stickerset):
                    if boxed {
                        buffer.appendInt32(1753886890)
                    }
                    stickerset.serialize(buffer, true)
                    break
                case .updateNewStoryReaction(let storyId, let peer, let reaction):
                    if boxed {
                        buffer.appendInt32(405070859)
                    }
                    serializeInt32(storyId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    reaction.serialize(buffer, true)
                    break
                case .updateNotifySettings(let peer, let notifySettings):
                    if boxed {
                        buffer.appendInt32(-1094555409)
                    }
                    peer.serialize(buffer, true)
                    notifySettings.serialize(buffer, true)
                    break
                case .updatePaidReactionPrivacy(let `private`):
                    if boxed {
                        buffer.appendInt32(-1955438642)
                    }
                    `private`.serialize(buffer, true)
                    break
                case .updatePeerBlocked(let flags, let peerId):
                    if boxed {
                        buffer.appendInt32(-337610926)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peerId.serialize(buffer, true)
                    break
                case .updatePeerHistoryTTL(let flags, let peer, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(-1147422299)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .updatePeerLocated(let peers):
                    if boxed {
                        buffer.appendInt32(-1263546448)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(peers.count))
                    for item in peers {
                        item.serialize(buffer, true)
                    }
                    break
                case .updatePeerSettings(let peer, let settings):
                    if boxed {
                        buffer.appendInt32(1786671974)
                    }
                    peer.serialize(buffer, true)
                    settings.serialize(buffer, true)
                    break
                case .updatePeerWallpaper(let flags, let peer, let wallpaper):
                    if boxed {
                        buffer.appendInt32(-1371598819)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {wallpaper!.serialize(buffer, true)}
                    break
                case .updatePendingJoinRequests(let peer, let requestsPending, let recentRequesters):
                    if boxed {
                        buffer.appendInt32(1885586395)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(requestsPending, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(recentRequesters.count))
                    for item in recentRequesters {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updatePhoneCall(let phoneCall):
                    if boxed {
                        buffer.appendInt32(-1425052898)
                    }
                    phoneCall.serialize(buffer, true)
                    break
                case .updatePhoneCallSignalingData(let phoneCallId, let data):
                    if boxed {
                        buffer.appendInt32(643940105)
                    }
                    serializeInt64(phoneCallId, buffer: buffer, boxed: false)
                    serializeBytes(data, buffer: buffer, boxed: false)
                    break
                case .updatePinnedChannelMessages(let flags, let channelId, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(1538885128)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updatePinnedDialogs(let flags, let folderId, let order):
                    if boxed {
                        buffer.appendInt32(-99664734)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order!.count))
                    for item in order! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .updatePinnedMessages(let flags, let peer, let messages, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-309990731)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updatePinnedSavedDialogs(let flags, let order):
                    if boxed {
                        buffer.appendInt32(1751942566)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order!.count))
                    for item in order! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .updatePrivacy(let key, let rules):
                    if boxed {
                        buffer.appendInt32(-298113238)
                    }
                    key.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(rules.count))
                    for item in rules {
                        item.serialize(buffer, true)
                    }
                    break
                case .updatePtsChanged:
                    if boxed {
                        buffer.appendInt32(861169551)
                    }
                    
                    break
                case .updateQuickReplies(let quickReplies):
                    if boxed {
                        buffer.appendInt32(-112784718)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(quickReplies.count))
                    for item in quickReplies {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateQuickReplyMessage(let message):
                    if boxed {
                        buffer.appendInt32(1040518415)
                    }
                    message.serialize(buffer, true)
                    break
                case .updateReadChannelDiscussionInbox(let flags, let channelId, let topMsgId, let readMaxId, let broadcastId, let broadcastPost):
                    if boxed {
                        buffer.appendInt32(-693004986)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(broadcastId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(broadcastPost!, buffer: buffer, boxed: false)}
                    break
                case .updateReadChannelDiscussionOutbox(let channelId, let topMsgId, let readMaxId):
                    if boxed {
                        buffer.appendInt32(1767677564)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(topMsgId, buffer: buffer, boxed: false)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    break
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                    if boxed {
                        buffer.appendInt32(-1842450928)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(stillUnreadCount, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    break
                case .updateReadChannelOutbox(let channelId, let maxId):
                    if boxed {
                        buffer.appendInt32(-1218471511)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
                case .updateReadFeaturedEmojiStickers:
                    if boxed {
                        buffer.appendInt32(-78886548)
                    }
                    
                    break
                case .updateReadFeaturedStickers:
                    if boxed {
                        buffer.appendInt32(1461528386)
                    }
                    
                    break
                case .updateReadHistoryInbox(let flags, let folderId, let peer, let maxId, let stillUnreadCount, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(-1667805217)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(stillUnreadCount, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateReadHistoryOutbox(let peer, let maxId, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(791617983)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateReadMessagesContents(let flags, let messages, let pts, let ptsCount, let date):
                    if boxed {
                        buffer.appendInt32(-131960447)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(messages.count))
                    for item in messages {
                        serializeInt32(item, buffer: buffer, boxed: false)
                    }
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(date!, buffer: buffer, boxed: false)}
                    break
                case .updateReadMonoForumInbox(let channelId, let savedPeerId, let readMaxId):
                    if boxed {
                        buffer.appendInt32(2008081266)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    savedPeerId.serialize(buffer, true)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    break
                case .updateReadMonoForumOutbox(let channelId, let savedPeerId, let readMaxId):
                    if boxed {
                        buffer.appendInt32(-1532521610)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    savedPeerId.serialize(buffer, true)
                    serializeInt32(readMaxId, buffer: buffer, boxed: false)
                    break
                case .updateReadStories(let peer, let maxId):
                    if boxed {
                        buffer.appendInt32(-145845461)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(maxId, buffer: buffer, boxed: false)
                    break
                case .updateRecentEmojiStatuses:
                    if boxed {
                        buffer.appendInt32(821314523)
                    }
                    
                    break
                case .updateRecentReactions:
                    if boxed {
                        buffer.appendInt32(1870160884)
                    }
                    
                    break
                case .updateRecentStickers:
                    if boxed {
                        buffer.appendInt32(-1706939360)
                    }
                    
                    break
                case .updateSavedDialogPinned(let flags, let peer):
                    if boxed {
                        buffer.appendInt32(-1364222348)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
                case .updateSavedGifs:
                    if boxed {
                        buffer.appendInt32(-1821035490)
                    }
                    
                    break
                case .updateSavedReactionTags:
                    if boxed {
                        buffer.appendInt32(969307186)
                    }
                    
                    break
                case .updateSavedRingtones:
                    if boxed {
                        buffer.appendInt32(1960361625)
                    }
                    
                    break
                case .updateSentPhoneCode(let sentCode):
                    if boxed {
                        buffer.appendInt32(1347068303)
                    }
                    sentCode.serialize(buffer, true)
                    break
                case .updateSentStoryReaction(let peer, let storyId, let reaction):
                    if boxed {
                        buffer.appendInt32(2103604867)
                    }
                    peer.serialize(buffer, true)
                    serializeInt32(storyId, buffer: buffer, boxed: false)
                    reaction.serialize(buffer, true)
                    break
                case .updateServiceNotification(let flags, let inboxDate, let type, let message, let media, let entities):
                    if boxed {
                        buffer.appendInt32(-337352679)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(inboxDate!, buffer: buffer, boxed: false)}
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    media.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities.count))
                    for item in entities {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateSmsJob(let jobId):
                    if boxed {
                        buffer.appendInt32(-245208620)
                    }
                    serializeString(jobId, buffer: buffer, boxed: false)
                    break
                case .updateStarsBalance(let balance):
                    if boxed {
                        buffer.appendInt32(1317053305)
                    }
                    balance.serialize(buffer, true)
                    break
                case .updateStarsRevenueStatus(let peer, let status):
                    if boxed {
                        buffer.appendInt32(-1518030823)
                    }
                    peer.serialize(buffer, true)
                    status.serialize(buffer, true)
                    break
                case .updateStickerSets(let flags):
                    if boxed {
                        buffer.appendInt32(834816008)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    break
                case .updateStickerSetsOrder(let flags, let order):
                    if boxed {
                        buffer.appendInt32(196268545)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(order.count))
                    for item in order {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .updateStoriesStealthMode(let stealthMode):
                    if boxed {
                        buffer.appendInt32(738741697)
                    }
                    stealthMode.serialize(buffer, true)
                    break
                case .updateStory(let peer, let story):
                    if boxed {
                        buffer.appendInt32(1974712216)
                    }
                    peer.serialize(buffer, true)
                    story.serialize(buffer, true)
                    break
                case .updateStoryID(let id, let randomId):
                    if boxed {
                        buffer.appendInt32(468923833)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(randomId, buffer: buffer, boxed: false)
                    break
                case .updateTheme(let theme):
                    if boxed {
                        buffer.appendInt32(-2112423005)
                    }
                    theme.serialize(buffer, true)
                    break
                case .updateTranscribedAudio(let flags, let peer, let msgId, let transcriptionId, let text):
                    if boxed {
                        buffer.appendInt32(8703322)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    serializeInt32(msgId, buffer: buffer, boxed: false)
                    serializeInt64(transcriptionId, buffer: buffer, boxed: false)
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .updateUser(let userId):
                    if boxed {
                        buffer.appendInt32(542282808)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .updateUserEmojiStatus(let userId, let emojiStatus):
                    if boxed {
                        buffer.appendInt32(674706841)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    emojiStatus.serialize(buffer, true)
                    break
                case .updateUserName(let userId, let firstName, let lastName, let usernames):
                    if boxed {
                        buffer.appendInt32(-1484486364)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(firstName, buffer: buffer, boxed: false)
                    serializeString(lastName, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(usernames.count))
                    for item in usernames {
                        item.serialize(buffer, true)
                    }
                    break
                case .updateUserPhone(let userId, let phone):
                    if boxed {
                        buffer.appendInt32(88680979)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(phone, buffer: buffer, boxed: false)
                    break
                case .updateUserStatus(let userId, let status):
                    if boxed {
                        buffer.appendInt32(-440534818)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    status.serialize(buffer, true)
                    break
                case .updateUserTyping(let userId, let action):
                    if boxed {
                        buffer.appendInt32(-1071741569)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    break
                case .updateWebPage(let webpage, let pts, let ptsCount):
                    if boxed {
                        buffer.appendInt32(2139689491)
                    }
                    webpage.serialize(buffer, true)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    break
                case .updateWebViewResultSent(let queryId):
                    if boxed {
                        buffer.appendInt32(361936797)
                    }
                    serializeInt64(queryId, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .updateAttachMenuBots:
                return ("updateAttachMenuBots", [])
                case .updateAutoSaveSettings:
                return ("updateAutoSaveSettings", [])
                case .updateBotBusinessConnect(let connection, let qts):
                return ("updateBotBusinessConnect", [("connection", connection as Any), ("qts", qts as Any)])
                case .updateBotCallbackQuery(let flags, let queryId, let userId, let peer, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateBotCallbackQuery", [("flags", flags as Any), ("queryId", queryId as Any), ("userId", userId as Any), ("peer", peer as Any), ("msgId", msgId as Any), ("chatInstance", chatInstance as Any), ("data", data as Any), ("gameShortName", gameShortName as Any)])
                case .updateBotChatBoost(let peer, let boost, let qts):
                return ("updateBotChatBoost", [("peer", peer as Any), ("boost", boost as Any), ("qts", qts as Any)])
                case .updateBotChatInviteRequester(let peer, let date, let userId, let about, let invite, let qts):
                return ("updateBotChatInviteRequester", [("peer", peer as Any), ("date", date as Any), ("userId", userId as Any), ("about", about as Any), ("invite", invite as Any), ("qts", qts as Any)])
                case .updateBotCommands(let peer, let botId, let commands):
                return ("updateBotCommands", [("peer", peer as Any), ("botId", botId as Any), ("commands", commands as Any)])
                case .updateBotDeleteBusinessMessage(let connectionId, let peer, let messages, let qts):
                return ("updateBotDeleteBusinessMessage", [("connectionId", connectionId as Any), ("peer", peer as Any), ("messages", messages as Any), ("qts", qts as Any)])
                case .updateBotEditBusinessMessage(let flags, let connectionId, let message, let replyToMessage, let qts):
                return ("updateBotEditBusinessMessage", [("flags", flags as Any), ("connectionId", connectionId as Any), ("message", message as Any), ("replyToMessage", replyToMessage as Any), ("qts", qts as Any)])
                case .updateBotInlineQuery(let flags, let queryId, let userId, let query, let geo, let peerType, let offset):
                return ("updateBotInlineQuery", [("flags", flags as Any), ("queryId", queryId as Any), ("userId", userId as Any), ("query", query as Any), ("geo", geo as Any), ("peerType", peerType as Any), ("offset", offset as Any)])
                case .updateBotInlineSend(let flags, let userId, let query, let geo, let id, let msgId):
                return ("updateBotInlineSend", [("flags", flags as Any), ("userId", userId as Any), ("query", query as Any), ("geo", geo as Any), ("id", id as Any), ("msgId", msgId as Any)])
                case .updateBotMenuButton(let botId, let button):
                return ("updateBotMenuButton", [("botId", botId as Any), ("button", button as Any)])
                case .updateBotMessageReaction(let peer, let msgId, let date, let actor, let oldReactions, let newReactions, let qts):
                return ("updateBotMessageReaction", [("peer", peer as Any), ("msgId", msgId as Any), ("date", date as Any), ("actor", actor as Any), ("oldReactions", oldReactions as Any), ("newReactions", newReactions as Any), ("qts", qts as Any)])
                case .updateBotMessageReactions(let peer, let msgId, let date, let reactions, let qts):
                return ("updateBotMessageReactions", [("peer", peer as Any), ("msgId", msgId as Any), ("date", date as Any), ("reactions", reactions as Any), ("qts", qts as Any)])
                case .updateBotNewBusinessMessage(let flags, let connectionId, let message, let replyToMessage, let qts):
                return ("updateBotNewBusinessMessage", [("flags", flags as Any), ("connectionId", connectionId as Any), ("message", message as Any), ("replyToMessage", replyToMessage as Any), ("qts", qts as Any)])
                case .updateBotPrecheckoutQuery(let flags, let queryId, let userId, let payload, let info, let shippingOptionId, let currency, let totalAmount):
                return ("updateBotPrecheckoutQuery", [("flags", flags as Any), ("queryId", queryId as Any), ("userId", userId as Any), ("payload", payload as Any), ("info", info as Any), ("shippingOptionId", shippingOptionId as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any)])
                case .updateBotPurchasedPaidMedia(let userId, let payload, let qts):
                return ("updateBotPurchasedPaidMedia", [("userId", userId as Any), ("payload", payload as Any), ("qts", qts as Any)])
                case .updateBotShippingQuery(let queryId, let userId, let payload, let shippingAddress):
                return ("updateBotShippingQuery", [("queryId", queryId as Any), ("userId", userId as Any), ("payload", payload as Any), ("shippingAddress", shippingAddress as Any)])
                case .updateBotStopped(let userId, let date, let stopped, let qts):
                return ("updateBotStopped", [("userId", userId as Any), ("date", date as Any), ("stopped", stopped as Any), ("qts", qts as Any)])
                case .updateBotWebhookJSON(let data):
                return ("updateBotWebhookJSON", [("data", data as Any)])
                case .updateBotWebhookJSONQuery(let queryId, let data, let timeout):
                return ("updateBotWebhookJSONQuery", [("queryId", queryId as Any), ("data", data as Any), ("timeout", timeout as Any)])
                case .updateBroadcastRevenueTransactions(let peer, let balances):
                return ("updateBroadcastRevenueTransactions", [("peer", peer as Any), ("balances", balances as Any)])
                case .updateBusinessBotCallbackQuery(let flags, let queryId, let userId, let connectionId, let message, let replyToMessage, let chatInstance, let data):
                return ("updateBusinessBotCallbackQuery", [("flags", flags as Any), ("queryId", queryId as Any), ("userId", userId as Any), ("connectionId", connectionId as Any), ("message", message as Any), ("replyToMessage", replyToMessage as Any), ("chatInstance", chatInstance as Any), ("data", data as Any)])
                case .updateChannel(let channelId):
                return ("updateChannel", [("channelId", channelId as Any)])
                case .updateChannelAvailableMessages(let channelId, let availableMinId):
                return ("updateChannelAvailableMessages", [("channelId", channelId as Any), ("availableMinId", availableMinId as Any)])
                case .updateChannelMessageForwards(let channelId, let id, let forwards):
                return ("updateChannelMessageForwards", [("channelId", channelId as Any), ("id", id as Any), ("forwards", forwards as Any)])
                case .updateChannelMessageViews(let channelId, let id, let views):
                return ("updateChannelMessageViews", [("channelId", channelId as Any), ("id", id as Any), ("views", views as Any)])
                case .updateChannelParticipant(let flags, let channelId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                return ("updateChannelParticipant", [("flags", flags as Any), ("channelId", channelId as Any), ("date", date as Any), ("actorId", actorId as Any), ("userId", userId as Any), ("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any), ("invite", invite as Any), ("qts", qts as Any)])
                case .updateChannelPinnedTopic(let flags, let channelId, let topicId):
                return ("updateChannelPinnedTopic", [("flags", flags as Any), ("channelId", channelId as Any), ("topicId", topicId as Any)])
                case .updateChannelPinnedTopics(let flags, let channelId, let order):
                return ("updateChannelPinnedTopics", [("flags", flags as Any), ("channelId", channelId as Any), ("order", order as Any)])
                case .updateChannelReadMessagesContents(let flags, let channelId, let topMsgId, let savedPeerId, let messages):
                return ("updateChannelReadMessagesContents", [("flags", flags as Any), ("channelId", channelId as Any), ("topMsgId", topMsgId as Any), ("savedPeerId", savedPeerId as Any), ("messages", messages as Any)])
                case .updateChannelTooLong(let flags, let channelId, let pts):
                return ("updateChannelTooLong", [("flags", flags as Any), ("channelId", channelId as Any), ("pts", pts as Any)])
                case .updateChannelUserTyping(let flags, let channelId, let topMsgId, let fromId, let action):
                return ("updateChannelUserTyping", [("flags", flags as Any), ("channelId", channelId as Any), ("topMsgId", topMsgId as Any), ("fromId", fromId as Any), ("action", action as Any)])
                case .updateChannelViewForumAsMessages(let channelId, let enabled):
                return ("updateChannelViewForumAsMessages", [("channelId", channelId as Any), ("enabled", enabled as Any)])
                case .updateChannelWebPage(let channelId, let webpage, let pts, let ptsCount):
                return ("updateChannelWebPage", [("channelId", channelId as Any), ("webpage", webpage as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateChat(let chatId):
                return ("updateChat", [("chatId", chatId as Any)])
                case .updateChatDefaultBannedRights(let peer, let defaultBannedRights, let version):
                return ("updateChatDefaultBannedRights", [("peer", peer as Any), ("defaultBannedRights", defaultBannedRights as Any), ("version", version as Any)])
                case .updateChatParticipant(let flags, let chatId, let date, let actorId, let userId, let prevParticipant, let newParticipant, let invite, let qts):
                return ("updateChatParticipant", [("flags", flags as Any), ("chatId", chatId as Any), ("date", date as Any), ("actorId", actorId as Any), ("userId", userId as Any), ("prevParticipant", prevParticipant as Any), ("newParticipant", newParticipant as Any), ("invite", invite as Any), ("qts", qts as Any)])
                case .updateChatParticipantAdd(let chatId, let userId, let inviterId, let date, let version):
                return ("updateChatParticipantAdd", [("chatId", chatId as Any), ("userId", userId as Any), ("inviterId", inviterId as Any), ("date", date as Any), ("version", version as Any)])
                case .updateChatParticipantAdmin(let chatId, let userId, let isAdmin, let version):
                return ("updateChatParticipantAdmin", [("chatId", chatId as Any), ("userId", userId as Any), ("isAdmin", isAdmin as Any), ("version", version as Any)])
                case .updateChatParticipantDelete(let chatId, let userId, let version):
                return ("updateChatParticipantDelete", [("chatId", chatId as Any), ("userId", userId as Any), ("version", version as Any)])
                case .updateChatParticipants(let participants):
                return ("updateChatParticipants", [("participants", participants as Any)])
                case .updateChatUserTyping(let chatId, let fromId, let action):
                return ("updateChatUserTyping", [("chatId", chatId as Any), ("fromId", fromId as Any), ("action", action as Any)])
                case .updateConfig:
                return ("updateConfig", [])
                case .updateContactsReset:
                return ("updateContactsReset", [])
                case .updateDcOptions(let dcOptions):
                return ("updateDcOptions", [("dcOptions", dcOptions as Any)])
                case .updateDeleteChannelMessages(let channelId, let messages, let pts, let ptsCount):
                return ("updateDeleteChannelMessages", [("channelId", channelId as Any), ("messages", messages as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateDeleteMessages(let messages, let pts, let ptsCount):
                return ("updateDeleteMessages", [("messages", messages as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateDeleteQuickReply(let shortcutId):
                return ("updateDeleteQuickReply", [("shortcutId", shortcutId as Any)])
                case .updateDeleteQuickReplyMessages(let shortcutId, let messages):
                return ("updateDeleteQuickReplyMessages", [("shortcutId", shortcutId as Any), ("messages", messages as Any)])
                case .updateDeleteScheduledMessages(let flags, let peer, let messages, let sentMessages):
                return ("updateDeleteScheduledMessages", [("flags", flags as Any), ("peer", peer as Any), ("messages", messages as Any), ("sentMessages", sentMessages as Any)])
                case .updateDialogFilter(let flags, let id, let filter):
                return ("updateDialogFilter", [("flags", flags as Any), ("id", id as Any), ("filter", filter as Any)])
                case .updateDialogFilterOrder(let order):
                return ("updateDialogFilterOrder", [("order", order as Any)])
                case .updateDialogFilters:
                return ("updateDialogFilters", [])
                case .updateDialogPinned(let flags, let folderId, let peer):
                return ("updateDialogPinned", [("flags", flags as Any), ("folderId", folderId as Any), ("peer", peer as Any)])
                case .updateDialogUnreadMark(let flags, let peer, let savedPeerId):
                return ("updateDialogUnreadMark", [("flags", flags as Any), ("peer", peer as Any), ("savedPeerId", savedPeerId as Any)])
                case .updateDraftMessage(let flags, let peer, let topMsgId, let savedPeerId, let draft):
                return ("updateDraftMessage", [("flags", flags as Any), ("peer", peer as Any), ("topMsgId", topMsgId as Any), ("savedPeerId", savedPeerId as Any), ("draft", draft as Any)])
                case .updateEditChannelMessage(let message, let pts, let ptsCount):
                return ("updateEditChannelMessage", [("message", message as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateEditMessage(let message, let pts, let ptsCount):
                return ("updateEditMessage", [("message", message as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateEncryptedChatTyping(let chatId):
                return ("updateEncryptedChatTyping", [("chatId", chatId as Any)])
                case .updateEncryptedMessagesRead(let chatId, let maxDate, let date):
                return ("updateEncryptedMessagesRead", [("chatId", chatId as Any), ("maxDate", maxDate as Any), ("date", date as Any)])
                case .updateEncryption(let chat, let date):
                return ("updateEncryption", [("chat", chat as Any), ("date", date as Any)])
                case .updateFavedStickers:
                return ("updateFavedStickers", [])
                case .updateFolderPeers(let folderPeers, let pts, let ptsCount):
                return ("updateFolderPeers", [("folderPeers", folderPeers as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateGeoLiveViewed(let peer, let msgId):
                return ("updateGeoLiveViewed", [("peer", peer as Any), ("msgId", msgId as Any)])
                case .updateGroupCall(let flags, let chatId, let call):
                return ("updateGroupCall", [("flags", flags as Any), ("chatId", chatId as Any), ("call", call as Any)])
                case .updateGroupCallChainBlocks(let call, let subChainId, let blocks, let nextOffset):
                return ("updateGroupCallChainBlocks", [("call", call as Any), ("subChainId", subChainId as Any), ("blocks", blocks as Any), ("nextOffset", nextOffset as Any)])
                case .updateGroupCallConnection(let flags, let params):
                return ("updateGroupCallConnection", [("flags", flags as Any), ("params", params as Any)])
                case .updateGroupCallParticipants(let call, let participants, let version):
                return ("updateGroupCallParticipants", [("call", call as Any), ("participants", participants as Any), ("version", version as Any)])
                case .updateInlineBotCallbackQuery(let flags, let queryId, let userId, let msgId, let chatInstance, let data, let gameShortName):
                return ("updateInlineBotCallbackQuery", [("flags", flags as Any), ("queryId", queryId as Any), ("userId", userId as Any), ("msgId", msgId as Any), ("chatInstance", chatInstance as Any), ("data", data as Any), ("gameShortName", gameShortName as Any)])
                case .updateLangPack(let difference):
                return ("updateLangPack", [("difference", difference as Any)])
                case .updateLangPackTooLong(let langCode):
                return ("updateLangPackTooLong", [("langCode", langCode as Any)])
                case .updateLoginToken:
                return ("updateLoginToken", [])
                case .updateMessageExtendedMedia(let peer, let msgId, let extendedMedia):
                return ("updateMessageExtendedMedia", [("peer", peer as Any), ("msgId", msgId as Any), ("extendedMedia", extendedMedia as Any)])
                case .updateMessageID(let id, let randomId):
                return ("updateMessageID", [("id", id as Any), ("randomId", randomId as Any)])
                case .updateMessagePoll(let flags, let pollId, let poll, let results):
                return ("updateMessagePoll", [("flags", flags as Any), ("pollId", pollId as Any), ("poll", poll as Any), ("results", results as Any)])
                case .updateMessagePollVote(let pollId, let peer, let options, let qts):
                return ("updateMessagePollVote", [("pollId", pollId as Any), ("peer", peer as Any), ("options", options as Any), ("qts", qts as Any)])
                case .updateMessageReactions(let flags, let peer, let msgId, let topMsgId, let savedPeerId, let reactions):
                return ("updateMessageReactions", [("flags", flags as Any), ("peer", peer as Any), ("msgId", msgId as Any), ("topMsgId", topMsgId as Any), ("savedPeerId", savedPeerId as Any), ("reactions", reactions as Any)])
                case .updateMoveStickerSetToTop(let flags, let stickerset):
                return ("updateMoveStickerSetToTop", [("flags", flags as Any), ("stickerset", stickerset as Any)])
                case .updateNewAuthorization(let flags, let hash, let date, let device, let location):
                return ("updateNewAuthorization", [("flags", flags as Any), ("hash", hash as Any), ("date", date as Any), ("device", device as Any), ("location", location as Any)])
                case .updateNewChannelMessage(let message, let pts, let ptsCount):
                return ("updateNewChannelMessage", [("message", message as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateNewEncryptedMessage(let message, let qts):
                return ("updateNewEncryptedMessage", [("message", message as Any), ("qts", qts as Any)])
                case .updateNewMessage(let message, let pts, let ptsCount):
                return ("updateNewMessage", [("message", message as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateNewQuickReply(let quickReply):
                return ("updateNewQuickReply", [("quickReply", quickReply as Any)])
                case .updateNewScheduledMessage(let message):
                return ("updateNewScheduledMessage", [("message", message as Any)])
                case .updateNewStickerSet(let stickerset):
                return ("updateNewStickerSet", [("stickerset", stickerset as Any)])
                case .updateNewStoryReaction(let storyId, let peer, let reaction):
                return ("updateNewStoryReaction", [("storyId", storyId as Any), ("peer", peer as Any), ("reaction", reaction as Any)])
                case .updateNotifySettings(let peer, let notifySettings):
                return ("updateNotifySettings", [("peer", peer as Any), ("notifySettings", notifySettings as Any)])
                case .updatePaidReactionPrivacy(let `private`):
                return ("updatePaidReactionPrivacy", [("`private`", `private` as Any)])
                case .updatePeerBlocked(let flags, let peerId):
                return ("updatePeerBlocked", [("flags", flags as Any), ("peerId", peerId as Any)])
                case .updatePeerHistoryTTL(let flags, let peer, let ttlPeriod):
                return ("updatePeerHistoryTTL", [("flags", flags as Any), ("peer", peer as Any), ("ttlPeriod", ttlPeriod as Any)])
                case .updatePeerLocated(let peers):
                return ("updatePeerLocated", [("peers", peers as Any)])
                case .updatePeerSettings(let peer, let settings):
                return ("updatePeerSettings", [("peer", peer as Any), ("settings", settings as Any)])
                case .updatePeerWallpaper(let flags, let peer, let wallpaper):
                return ("updatePeerWallpaper", [("flags", flags as Any), ("peer", peer as Any), ("wallpaper", wallpaper as Any)])
                case .updatePendingJoinRequests(let peer, let requestsPending, let recentRequesters):
                return ("updatePendingJoinRequests", [("peer", peer as Any), ("requestsPending", requestsPending as Any), ("recentRequesters", recentRequesters as Any)])
                case .updatePhoneCall(let phoneCall):
                return ("updatePhoneCall", [("phoneCall", phoneCall as Any)])
                case .updatePhoneCallSignalingData(let phoneCallId, let data):
                return ("updatePhoneCallSignalingData", [("phoneCallId", phoneCallId as Any), ("data", data as Any)])
                case .updatePinnedChannelMessages(let flags, let channelId, let messages, let pts, let ptsCount):
                return ("updatePinnedChannelMessages", [("flags", flags as Any), ("channelId", channelId as Any), ("messages", messages as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updatePinnedDialogs(let flags, let folderId, let order):
                return ("updatePinnedDialogs", [("flags", flags as Any), ("folderId", folderId as Any), ("order", order as Any)])
                case .updatePinnedMessages(let flags, let peer, let messages, let pts, let ptsCount):
                return ("updatePinnedMessages", [("flags", flags as Any), ("peer", peer as Any), ("messages", messages as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updatePinnedSavedDialogs(let flags, let order):
                return ("updatePinnedSavedDialogs", [("flags", flags as Any), ("order", order as Any)])
                case .updatePrivacy(let key, let rules):
                return ("updatePrivacy", [("key", key as Any), ("rules", rules as Any)])
                case .updatePtsChanged:
                return ("updatePtsChanged", [])
                case .updateQuickReplies(let quickReplies):
                return ("updateQuickReplies", [("quickReplies", quickReplies as Any)])
                case .updateQuickReplyMessage(let message):
                return ("updateQuickReplyMessage", [("message", message as Any)])
                case .updateReadChannelDiscussionInbox(let flags, let channelId, let topMsgId, let readMaxId, let broadcastId, let broadcastPost):
                return ("updateReadChannelDiscussionInbox", [("flags", flags as Any), ("channelId", channelId as Any), ("topMsgId", topMsgId as Any), ("readMaxId", readMaxId as Any), ("broadcastId", broadcastId as Any), ("broadcastPost", broadcastPost as Any)])
                case .updateReadChannelDiscussionOutbox(let channelId, let topMsgId, let readMaxId):
                return ("updateReadChannelDiscussionOutbox", [("channelId", channelId as Any), ("topMsgId", topMsgId as Any), ("readMaxId", readMaxId as Any)])
                case .updateReadChannelInbox(let flags, let folderId, let channelId, let maxId, let stillUnreadCount, let pts):
                return ("updateReadChannelInbox", [("flags", flags as Any), ("folderId", folderId as Any), ("channelId", channelId as Any), ("maxId", maxId as Any), ("stillUnreadCount", stillUnreadCount as Any), ("pts", pts as Any)])
                case .updateReadChannelOutbox(let channelId, let maxId):
                return ("updateReadChannelOutbox", [("channelId", channelId as Any), ("maxId", maxId as Any)])
                case .updateReadFeaturedEmojiStickers:
                return ("updateReadFeaturedEmojiStickers", [])
                case .updateReadFeaturedStickers:
                return ("updateReadFeaturedStickers", [])
                case .updateReadHistoryInbox(let flags, let folderId, let peer, let maxId, let stillUnreadCount, let pts, let ptsCount):
                return ("updateReadHistoryInbox", [("flags", flags as Any), ("folderId", folderId as Any), ("peer", peer as Any), ("maxId", maxId as Any), ("stillUnreadCount", stillUnreadCount as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateReadHistoryOutbox(let peer, let maxId, let pts, let ptsCount):
                return ("updateReadHistoryOutbox", [("peer", peer as Any), ("maxId", maxId as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateReadMessagesContents(let flags, let messages, let pts, let ptsCount, let date):
                return ("updateReadMessagesContents", [("flags", flags as Any), ("messages", messages as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any), ("date", date as Any)])
                case .updateReadMonoForumInbox(let channelId, let savedPeerId, let readMaxId):
                return ("updateReadMonoForumInbox", [("channelId", channelId as Any), ("savedPeerId", savedPeerId as Any), ("readMaxId", readMaxId as Any)])
                case .updateReadMonoForumOutbox(let channelId, let savedPeerId, let readMaxId):
                return ("updateReadMonoForumOutbox", [("channelId", channelId as Any), ("savedPeerId", savedPeerId as Any), ("readMaxId", readMaxId as Any)])
                case .updateReadStories(let peer, let maxId):
                return ("updateReadStories", [("peer", peer as Any), ("maxId", maxId as Any)])
                case .updateRecentEmojiStatuses:
                return ("updateRecentEmojiStatuses", [])
                case .updateRecentReactions:
                return ("updateRecentReactions", [])
                case .updateRecentStickers:
                return ("updateRecentStickers", [])
                case .updateSavedDialogPinned(let flags, let peer):
                return ("updateSavedDialogPinned", [("flags", flags as Any), ("peer", peer as Any)])
                case .updateSavedGifs:
                return ("updateSavedGifs", [])
                case .updateSavedReactionTags:
                return ("updateSavedReactionTags", [])
                case .updateSavedRingtones:
                return ("updateSavedRingtones", [])
                case .updateSentPhoneCode(let sentCode):
                return ("updateSentPhoneCode", [("sentCode", sentCode as Any)])
                case .updateSentStoryReaction(let peer, let storyId, let reaction):
                return ("updateSentStoryReaction", [("peer", peer as Any), ("storyId", storyId as Any), ("reaction", reaction as Any)])
                case .updateServiceNotification(let flags, let inboxDate, let type, let message, let media, let entities):
                return ("updateServiceNotification", [("flags", flags as Any), ("inboxDate", inboxDate as Any), ("type", type as Any), ("message", message as Any), ("media", media as Any), ("entities", entities as Any)])
                case .updateSmsJob(let jobId):
                return ("updateSmsJob", [("jobId", jobId as Any)])
                case .updateStarsBalance(let balance):
                return ("updateStarsBalance", [("balance", balance as Any)])
                case .updateStarsRevenueStatus(let peer, let status):
                return ("updateStarsRevenueStatus", [("peer", peer as Any), ("status", status as Any)])
                case .updateStickerSets(let flags):
                return ("updateStickerSets", [("flags", flags as Any)])
                case .updateStickerSetsOrder(let flags, let order):
                return ("updateStickerSetsOrder", [("flags", flags as Any), ("order", order as Any)])
                case .updateStoriesStealthMode(let stealthMode):
                return ("updateStoriesStealthMode", [("stealthMode", stealthMode as Any)])
                case .updateStory(let peer, let story):
                return ("updateStory", [("peer", peer as Any), ("story", story as Any)])
                case .updateStoryID(let id, let randomId):
                return ("updateStoryID", [("id", id as Any), ("randomId", randomId as Any)])
                case .updateTheme(let theme):
                return ("updateTheme", [("theme", theme as Any)])
                case .updateTranscribedAudio(let flags, let peer, let msgId, let transcriptionId, let text):
                return ("updateTranscribedAudio", [("flags", flags as Any), ("peer", peer as Any), ("msgId", msgId as Any), ("transcriptionId", transcriptionId as Any), ("text", text as Any)])
                case .updateUser(let userId):
                return ("updateUser", [("userId", userId as Any)])
                case .updateUserEmojiStatus(let userId, let emojiStatus):
                return ("updateUserEmojiStatus", [("userId", userId as Any), ("emojiStatus", emojiStatus as Any)])
                case .updateUserName(let userId, let firstName, let lastName, let usernames):
                return ("updateUserName", [("userId", userId as Any), ("firstName", firstName as Any), ("lastName", lastName as Any), ("usernames", usernames as Any)])
                case .updateUserPhone(let userId, let phone):
                return ("updateUserPhone", [("userId", userId as Any), ("phone", phone as Any)])
                case .updateUserStatus(let userId, let status):
                return ("updateUserStatus", [("userId", userId as Any), ("status", status as Any)])
                case .updateUserTyping(let userId, let action):
                return ("updateUserTyping", [("userId", userId as Any), ("action", action as Any)])
                case .updateWebPage(let webpage, let pts, let ptsCount):
                return ("updateWebPage", [("webpage", webpage as Any), ("pts", pts as Any), ("ptsCount", ptsCount as Any)])
                case .updateWebViewResultSent(let queryId):
                return ("updateWebViewResultSent", [("queryId", queryId as Any)])
    }
    }
    
        public static func parse_updateAttachMenuBots(_ reader: BufferReader) -> Update? {
            return Api.Update.updateAttachMenuBots
        }
        public static func parse_updateAutoSaveSettings(_ reader: BufferReader) -> Update? {
            return Api.Update.updateAutoSaveSettings
        }
        public static func parse_updateBotBusinessConnect(_ reader: BufferReader) -> Update? {
            var _1: Api.BotBusinessConnection?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.BotBusinessConnection
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBotBusinessConnect(connection: _1!, qts: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int64?
            _6 = reader.readInt64()
            var _7: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_7 = parseBytes(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 1) != 0 {_8 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 0) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 1) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, peer: _4!, msgId: _5!, chatInstance: _6!, data: _7, gameShortName: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotChatBoost(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.Boost?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Boost
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotChatBoost(peer: _1!, boost: _2!, qts: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotChatInviteRequester(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.ExportedChatInvite?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            }
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotChatInviteRequester(peer: _1!, date: _2!, userId: _3!, about: _4!, invite: _5!, qts: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotCommands(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Api.BotCommand]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.BotCommand.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotCommands(peer: _1!, botId: _2!, commands: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotDeleteBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotDeleteBusinessMessage(connectionId: _1!, peer: _2!, messages: _3!, qts: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotEditBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Message?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _4: Api.Message?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Message
            } }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotEditBusinessMessage(flags: _1!, connectionId: _2!, message: _3!, replyToMessage: _4, qts: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _6: Api.InlineQueryPeerType?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InlineQueryPeerType
            } }
            var _7: String?
            _7 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateBotInlineQuery(flags: _1!, queryId: _2!, userId: _3!, query: _4!, geo: _5, peerType: _6, offset: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotInlineSend(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: Api.GeoPoint?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.GeoPoint
            } }
            var _5: String?
            _5 = parseString(reader)
            var _6: Api.InputBotInlineMessageID?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateBotInlineSend(flags: _1!, userId: _2!, query: _3!, geo: _4, id: _5!, msgId: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMenuButton(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.BotMenuButton?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BotMenuButton
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBotMenuButton(botId: _1!, button: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMessageReaction(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            var _6: [Api.Reaction]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Reaction.self)
            }
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateBotMessageReaction(peer: _1!, msgId: _2!, date: _3!, actor: _4!, oldReactions: _5!, newReactions: _6!, qts: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotMessageReactions(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: [Api.ReactionCount]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.ReactionCount.self)
            }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotMessageReactions(peer: _1!, msgId: _2!, date: _3!, reactions: _4!, qts: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotNewBusinessMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Api.Message?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _4: Api.Message?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Message
            } }
            var _5: Int32?
            _5 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateBotNewBusinessMessage(flags: _1!, connectionId: _2!, message: _3!, replyToMessage: _4, qts: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotPrecheckoutQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Buffer?
            _4 = parseBytes(reader)
            var _5: Api.PaymentRequestedInfo?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.PaymentRequestedInfo
            } }
            var _6: String?
            if Int(_1!) & Int(1 << 1) != 0 {_6 = parseString(reader) }
            var _7: String?
            _7 = parseString(reader)
            var _8: Int64?
            _8 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBotPrecheckoutQuery(flags: _1!, queryId: _2!, userId: _3!, payload: _4!, info: _5, shippingOptionId: _6, currency: _7!, totalAmount: _8!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotPurchasedPaidMedia(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotPurchasedPaidMedia(userId: _1!, payload: _2!, qts: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotShippingQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            _3 = parseBytes(reader)
            var _4: Api.PostAddress?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PostAddress
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotShippingQuery(queryId: _1!, userId: _2!, payload: _3!, shippingAddress: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotStopped(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateBotStopped(userId: _1!, date: _2!, stopped: _3!, qts: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSON(_ reader: BufferReader) -> Update? {
            var _1: Api.DataJSON?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateBotWebhookJSON(data: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBotWebhookJSONQuery(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateBotWebhookJSONQuery(queryId: _1!, data: _2!, timeout: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBroadcastRevenueTransactions(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.BroadcastRevenueBalances?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.BroadcastRevenueBalances
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateBroadcastRevenueTransactions(peer: _1!, balances: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateBusinessBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.Message?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _6: Api.Message?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.Message
            } }
            var _7: Int64?
            _7 = reader.readInt64()
            var _8: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_8 = parseBytes(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 0) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Update.updateBusinessBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, connectionId: _4!, message: _5!, replyToMessage: _6, chatInstance: _7!, data: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannel(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChannel(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelAvailableMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelAvailableMessages(channelId: _1!, availableMinId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageForwards(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelMessageForwards(channelId: _1!, id: _2!, forwards: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelMessageViews(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelMessageViews(channelId: _1!, id: _2!, views: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            } }
            var _7: Api.ChannelParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChannelParticipant
            } }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChannelParticipant(flags: _1!, channelId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelPinnedTopic(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelPinnedTopic(flags: _1!, channelId: _2!, topicId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelPinnedTopics(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelPinnedTopics(flags: _1!, channelId: _2!, order: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _5: [Int32]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChannelReadMessagesContents(flags: _1!, channelId: _2!, topMsgId: _3, savedPeerId: _4, messages: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelTooLong(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChannelTooLong(flags: _1!, channelId: _2!, pts: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateChannelUserTyping(flags: _1!, channelId: _2!, topMsgId: _3, fromId: _4!, action: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelViewForumAsMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Bool?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateChannelViewForumAsMessages(channelId: _1!, enabled: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChannelWebPage(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.WebPage?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChannelWebPage(channelId: _1!, webpage: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChat(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChat(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatDefaultBannedRights(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.ChatBannedRights?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.ChatBannedRights
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatDefaultBannedRights(peer: _1!, defaultBannedRights: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipant(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
            } }
            var _7: Api.ChatParticipant?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.ChatParticipant
            } }
            var _8: Api.ExportedChatInvite?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.ExportedChatInvite
            } }
            var _9: Int32?
            _9 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.Update.updateChatParticipant(flags: _1!, chatId: _2!, date: _3!, actorId: _4!, userId: _5!, prevParticipant: _6, newParticipant: _7, invite: _8, qts: _9!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdd(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
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
                return Api.Update.updateChatParticipantAdd(chatId: _1!, userId: _2!, inviterId: _3!, date: _4!, version: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantAdmin(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Bool?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Bool
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateChatParticipantAdmin(chatId: _1!, userId: _2!, isAdmin: _3!, version: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipantDelete(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatParticipantDelete(chatId: _1!, userId: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.ChatParticipants?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.ChatParticipants
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateChatParticipants(participants: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateChatUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateChatUserTyping(chatId: _1!, fromId: _2!, action: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateConfig(_ reader: BufferReader) -> Update? {
            return Api.Update.updateConfig
        }
        public static func parse_updateContactsReset(_ reader: BufferReader) -> Update? {
            return Api.Update.updateContactsReset
        }
        public static func parse_updateDcOptions(_ reader: BufferReader) -> Update? {
            var _1: [Api.DcOption]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DcOption.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDcOptions(dcOptions: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateDeleteChannelMessages(channelId: _1!, messages: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteMessages(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDeleteMessages(messages: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteQuickReply(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDeleteQuickReply(shortcutId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteQuickReplyMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateDeleteQuickReplyMessages(shortcutId: _1!, messages: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDeleteScheduledMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _4: [Int32]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateDeleteScheduledMessages(flags: _1!, peer: _2!, messages: _3!, sentMessages: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilter(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.DialogFilter?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DialogFilter
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogFilter(flags: _1!, id: _2!, filter: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilterOrder(_ reader: BufferReader) -> Update? {
            var _1: [Int32]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateDialogFilterOrder(order: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogFilters(_ reader: BufferReader) -> Update? {
            return Api.Update.updateDialogFilters
        }
        public static func parse_updateDialogPinned(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogPinned(flags: _1!, folderId: _2, peer: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDialogUnreadMark(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateDialogUnreadMark(flags: _1!, peer: _2!, savedPeerId: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updateDraftMessage(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _5: Api.DraftMessage?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.DraftMessage
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateDraftMessage(flags: _1!, peer: _2!, topMsgId: _3, savedPeerId: _4, draft: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditChannelMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEditMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEditMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedChatTyping(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateEncryptedChatTyping(chatId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryptedMessagesRead(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateEncryptedMessagesRead(chatId: _1!, maxDate: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateEncryption(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedChat?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedChat
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateEncryption(chat: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateFavedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateFavedStickers
        }
        public static func parse_updateFolderPeers(_ reader: BufferReader) -> Update? {
            var _1: [Api.FolderPeer]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.FolderPeer.self)
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateFolderPeers(folderPeers: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGeoLiveViewed(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGeoLiveViewed(peer: _1!, msgId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCall(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt64() }
            var _3: Api.GroupCall?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.GroupCall
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCall(flags: _1!, chatId: _2, call: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallChainBlocks(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateGroupCallChainBlocks(call: _1!, subChainId: _2!, blocks: _3!, nextOffset: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallConnection(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DataJSON?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DataJSON
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateGroupCallConnection(flags: _1!, params: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateGroupCallParticipants(_ reader: BufferReader) -> Update? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Api.GroupCallParticipant]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.GroupCallParticipant.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateGroupCallParticipants(call: _1!, participants: _2!, version: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateInlineBotCallbackQuery(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Api.InputBotInlineMessageID?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.InputBotInlineMessageID
            }
            var _5: Int64?
            _5 = reader.readInt64()
            var _6: Buffer?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseBytes(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateInlineBotCallbackQuery(flags: _1!, queryId: _2!, userId: _3!, msgId: _4!, chatInstance: _5!, data: _6, gameShortName: _7)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPack(_ reader: BufferReader) -> Update? {
            var _1: Api.LangPackDifference?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.LangPackDifference
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPack(difference: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLangPackTooLong(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateLangPackTooLong(langCode: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateLoginToken(_ reader: BufferReader) -> Update? {
            return Api.Update.updateLoginToken
        }
        public static func parse_updateMessageExtendedMedia(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Api.MessageExtendedMedia]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageExtendedMedia.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateMessageExtendedMedia(peer: _1!, msgId: _2!, extendedMedia: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessageID(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateMessageID(id: _1!, randomId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePoll(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.Poll?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Poll
            } }
            var _4: Api.PollResults?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PollResults
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePoll(flags: _1!, pollId: _2!, poll: _3, results: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessagePollVote(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Buffer]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1255641564, elementType: Buffer.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateMessagePollVote(pollId: _1!, peer: _2!, options: _3!, qts: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMessageReactions(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt32() }
            var _5: Api.Peer?
            if Int(_1!) & Int(1 << 1) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _6: Api.MessageReactions?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.MessageReactions
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateMessageReactions(flags: _1!, peer: _2!, msgId: _3!, topMsgId: _4, savedPeerId: _5, reactions: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateMoveStickerSetToTop(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateMoveStickerSetToTop(flags: _1!, stickerset: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewAuthorization(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateNewAuthorization(flags: _1!, hash: _2!, date: _3, device: _4, location: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewChannelMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewChannelMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewEncryptedMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.EncryptedMessage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.EncryptedMessage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNewEncryptedMessage(message: _1!, qts: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateNewMessage(message: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewQuickReply(_ reader: BufferReader) -> Update? {
            var _1: Api.QuickReply?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.QuickReply
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewQuickReply(quickReply: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewScheduledMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewScheduledMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewStickerSet(_ reader: BufferReader) -> Update? {
            var _1: Api.messages.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.messages.StickerSet
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateNewStickerSet(stickerset: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNewStoryReaction(_ reader: BufferReader) -> Update? {
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
                return Api.Update.updateNewStoryReaction(storyId: _1!, peer: _2!, reaction: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateNotifySettings(_ reader: BufferReader) -> Update? {
            var _1: Api.NotifyPeer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.NotifyPeer
            }
            var _2: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateNotifySettings(peer: _1!, notifySettings: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePaidReactionPrivacy(_ reader: BufferReader) -> Update? {
            var _1: Api.PaidReactionPrivacy?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PaidReactionPrivacy
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePaidReactionPrivacy(private: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerBlocked(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerBlocked(flags: _1!, peerId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerHistoryTTL(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePeerHistoryTTL(flags: _1!, peer: _2!, ttlPeriod: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerLocated(_ reader: BufferReader) -> Update? {
            var _1: [Api.PeerLocated]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PeerLocated.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePeerLocated(peers: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerSettings(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePeerSettings(peer: _1!, settings: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePeerWallpaper(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Api.WallPaper?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.WallPaper
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePeerWallpaper(flags: _1!, peer: _2!, wallpaper: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePendingJoinRequests(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: [Int64]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePendingJoinRequests(peer: _1!, requestsPending: _2!, recentRequesters: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCall(_ reader: BufferReader) -> Update? {
            var _1: Api.PhoneCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PhoneCall
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updatePhoneCall(phoneCall: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePhoneCallSignalingData(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Buffer?
            _2 = parseBytes(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePhoneCallSignalingData(phoneCallId: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedChannelMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
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
                return Api.Update.updatePinnedChannelMessages(flags: _1!, channelId: _2!, messages: _3!, pts: _4!, ptsCount: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedDialogs(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: [Api.DialogPeer]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updatePinnedDialogs(flags: _1!, folderId: _2, order: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedMessages(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: [Int32]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
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
                return Api.Update.updatePinnedMessages(flags: _1!, peer: _2!, messages: _3!, pts: _4!, ptsCount: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePinnedSavedDialogs(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Api.DialogPeer]?
            if Int(_1!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DialogPeer.self)
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePinnedSavedDialogs(flags: _1!, order: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePrivacy(_ reader: BufferReader) -> Update? {
            var _1: Api.PrivacyKey?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.PrivacyKey
            }
            var _2: [Api.PrivacyRule]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PrivacyRule.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updatePrivacy(key: _1!, rules: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatePtsChanged(_ reader: BufferReader) -> Update? {
            return Api.Update.updatePtsChanged
        }
        public static func parse_updateQuickReplies(_ reader: BufferReader) -> Update? {
            var _1: [Api.QuickReply]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.QuickReply.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateQuickReplies(quickReplies: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateQuickReplyMessage(_ reader: BufferReader) -> Update? {
            var _1: Api.Message?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Message
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateQuickReplyMessage(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelDiscussionInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt64() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelDiscussionInbox(flags: _1!, channelId: _2!, topMsgId: _3!, readMaxId: _4!, broadcastId: _5, broadcastPost: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelDiscussionOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadChannelDiscussionOutbox(channelId: _1!, topMsgId: _2!, readMaxId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateReadChannelInbox(flags: _1!, folderId: _2, channelId: _3!, maxId: _4!, stillUnreadCount: _5!, pts: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadChannelOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateReadChannelOutbox(channelId: _1!, maxId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadFeaturedEmojiStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedEmojiStickers
        }
        public static func parse_updateReadFeaturedStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateReadFeaturedStickers
        }
        public static func parse_updateReadHistoryInbox(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Api.Peer?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.Update.updateReadHistoryInbox(flags: _1!, folderId: _2, peer: _3!, maxId: _4!, stillUnreadCount: _5!, pts: _6!, ptsCount: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadHistoryOutbox(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateReadHistoryOutbox(peer: _1!, maxId: _2!, pts: _3!, ptsCount: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMessagesContents(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int32]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: -1471112230, elementType: Int32.self)
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateReadMessagesContents(flags: _1!, messages: _2!, pts: _3!, ptsCount: _4!, date: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMonoForumInbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadMonoForumInbox(channelId: _1!, savedPeerId: _2!, readMaxId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadMonoForumOutbox(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateReadMonoForumOutbox(channelId: _1!, savedPeerId: _2!, readMaxId: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateReadStories(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateReadStories(peer: _1!, maxId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateRecentEmojiStatuses(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentEmojiStatuses
        }
        public static func parse_updateRecentReactions(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentReactions
        }
        public static func parse_updateRecentStickers(_ reader: BufferReader) -> Update? {
            return Api.Update.updateRecentStickers
        }
        public static func parse_updateSavedDialogPinned(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.DialogPeer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.DialogPeer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateSavedDialogPinned(flags: _1!, peer: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateSavedGifs(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedGifs
        }
        public static func parse_updateSavedReactionTags(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedReactionTags
        }
        public static func parse_updateSavedRingtones(_ reader: BufferReader) -> Update? {
            return Api.Update.updateSavedRingtones
        }
        public static func parse_updateSentPhoneCode(_ reader: BufferReader) -> Update? {
            var _1: Api.auth.SentCode?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.auth.SentCode
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateSentPhoneCode(sentCode: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateSentStoryReaction(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Reaction?
            if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Reaction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateSentStoryReaction(peer: _1!, storyId: _2!, reaction: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateServiceNotification(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_2 = reader.readInt32() }
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.MessageMedia?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            }
            var _6: [Api.MessageEntity]?
            if let _ = reader.readInt32() {
                _6 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 1) == 0) || _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Update.updateServiceNotification(flags: _1!, inboxDate: _2, type: _3!, message: _4!, media: _5!, entities: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateSmsJob(_ reader: BufferReader) -> Update? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateSmsJob(jobId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarsBalance(_ reader: BufferReader) -> Update? {
            var _1: Api.StarsAmount?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStarsBalance(balance: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStarsRevenueStatus(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StarsRevenueStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsRevenueStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStarsRevenueStatus(peer: _1!, status: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStickerSets(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStickerSets(flags: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStickerSetsOrder(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStickerSetsOrder(flags: _1!, order: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStoriesStealthMode(_ reader: BufferReader) -> Update? {
            var _1: Api.StoriesStealthMode?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StoriesStealthMode
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateStoriesStealthMode(stealthMode: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStory(_ reader: BufferReader) -> Update? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _2: Api.StoryItem?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StoryItem
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStory(peer: _1!, story: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateStoryID(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateStoryID(id: _1!, randomId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateTheme(_ reader: BufferReader) -> Update? {
            var _1: Api.Theme?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Theme
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateTheme(theme: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateTranscribedAudio(_ reader: BufferReader) -> Update? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.Update.updateTranscribedAudio(flags: _1!, peer: _2!, msgId: _3!, transcriptionId: _4!, text: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUser(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateUser(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserEmojiStatus(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.EmojiStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserEmojiStatus(userId: _1!, emojiStatus: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserName(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.Username]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.Update.updateUserName(userId: _1!, firstName: _2!, lastName: _3!, usernames: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserPhone(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserPhone(userId: _1!, phone: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserStatus(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.UserStatus?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.UserStatus
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserStatus(userId: _1!, status: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateUserTyping(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Api.SendMessageAction?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SendMessageAction
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Update.updateUserTyping(userId: _1!, action: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebPage(_ reader: BufferReader) -> Update? {
            var _1: Api.WebPage?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WebPage
            }
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int32?
            _3 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Update.updateWebPage(webpage: _1!, pts: _2!, ptsCount: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateWebViewResultSent(_ reader: BufferReader) -> Update? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.Update.updateWebViewResultSent(queryId: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
