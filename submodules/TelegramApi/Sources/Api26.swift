public extension Api {
    enum StickerSetCovered: TypeConstructorDescription {
        case stickerSetCovered(set: Api.StickerSet, cover: Api.Document)
        case stickerSetFullCovered(set: Api.StickerSet, packs: [Api.StickerPack], keywords: [Api.StickerKeyword], documents: [Api.Document])
        case stickerSetMultiCovered(set: Api.StickerSet, covers: [Api.Document])
        case stickerSetNoCovered(set: Api.StickerSet)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .stickerSetCovered(let set, let cover):
                    if boxed {
                        buffer.appendInt32(1678812626)
                    }
                    set.serialize(buffer, true)
                    cover.serialize(buffer, true)
                    break
                case .stickerSetFullCovered(let set, let packs, let keywords, let documents):
                    if boxed {
                        buffer.appendInt32(1087454222)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(packs.count))
                    for item in packs {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(keywords.count))
                    for item in keywords {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(documents.count))
                    for item in documents {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetMultiCovered(let set, let covers):
                    if boxed {
                        buffer.appendInt32(872932635)
                    }
                    set.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(covers.count))
                    for item in covers {
                        item.serialize(buffer, true)
                    }
                    break
                case .stickerSetNoCovered(let set):
                    if boxed {
                        buffer.appendInt32(2008112412)
                    }
                    set.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .stickerSetCovered(let set, let cover):
                return ("stickerSetCovered", [("set", set as Any), ("cover", cover as Any)])
                case .stickerSetFullCovered(let set, let packs, let keywords, let documents):
                return ("stickerSetFullCovered", [("set", set as Any), ("packs", packs as Any), ("keywords", keywords as Any), ("documents", documents as Any)])
                case .stickerSetMultiCovered(let set, let covers):
                return ("stickerSetMultiCovered", [("set", set as Any), ("covers", covers as Any)])
                case .stickerSetNoCovered(let set):
                return ("stickerSetNoCovered", [("set", set as Any)])
    }
    }
    
        public static func parse_stickerSetCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: Api.Document?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Document
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetCovered(set: _1!, cover: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetFullCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.StickerPack]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerPack.self)
            }
            var _3: [Api.StickerKeyword]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.StickerKeyword.self)
            }
            var _4: [Api.Document]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.StickerSetCovered.stickerSetFullCovered(set: _1!, packs: _2!, keywords: _3!, documents: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetMultiCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            var _2: [Api.Document]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Document.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.StickerSetCovered.stickerSetMultiCovered(set: _1!, covers: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_stickerSetNoCovered(_ reader: BufferReader) -> StickerSetCovered? {
            var _1: Api.StickerSet?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.StickerSet
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.StickerSetCovered.stickerSetNoCovered(set: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
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
    enum SuggestedPost: TypeConstructorDescription {
        case suggestedPost(flags: Int32, price: Api.StarsAmount?, scheduleDate: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .suggestedPost(let flags, let price, let scheduleDate):
                    if boxed {
                        buffer.appendInt32(244201445)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 3) != 0 {price!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(scheduleDate!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .suggestedPost(let flags, let price, let scheduleDate):
                return ("suggestedPost", [("flags", flags as Any), ("price", price as Any), ("scheduleDate", scheduleDate as Any)])
    }
    }
    
        public static func parse_suggestedPost(_ reader: BufferReader) -> SuggestedPost? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.StarsAmount?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.StarsAmount
            } }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 3) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.SuggestedPost.suggestedPost(flags: _1!, price: _2, scheduleDate: _3)
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
    enum TodoCompletion: TypeConstructorDescription {
        case todoCompletion(id: Int32, completedBy: Int64, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .todoCompletion(let id, let completedBy, let date):
                    if boxed {
                        buffer.appendInt32(1287725239)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(completedBy, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .todoCompletion(let id, let completedBy, let date):
                return ("todoCompletion", [("id", id as Any), ("completedBy", completedBy as Any), ("date", date as Any)])
    }
    }
    
        public static func parse_todoCompletion(_ reader: BufferReader) -> TodoCompletion? {
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
                return Api.TodoCompletion.todoCompletion(id: _1!, completedBy: _2!, date: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TodoItem: TypeConstructorDescription {
        case todoItem(id: Int32, title: Api.TextWithEntities)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .todoItem(let id, let title):
                    if boxed {
                        buffer.appendInt32(-878074577)
                    }
                    serializeInt32(id, buffer: buffer, boxed: false)
                    title.serialize(buffer, true)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .todoItem(let id, let title):
                return ("todoItem", [("id", id as Any), ("title", title as Any)])
    }
    }
    
        public static func parse_todoItem(_ reader: BufferReader) -> TodoItem? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.TodoItem.todoItem(id: _1!, title: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum TodoList: TypeConstructorDescription {
        case todoList(flags: Int32, title: Api.TextWithEntities, list: [Api.TodoItem])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .todoList(let flags, let title, let list):
                    if boxed {
                        buffer.appendInt32(1236871718)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    title.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(list.count))
                    for item in list {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .todoList(let flags, let title, let list):
                return ("todoList", [("flags", flags as Any), ("title", title as Any), ("list", list as Any)])
    }
    }
    
        public static func parse_todoList(_ reader: BufferReader) -> TodoList? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.TextWithEntities?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.TextWithEntities
            }
            var _3: [Api.TodoItem]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.TodoItem.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.TodoList.todoList(flags: _1!, title: _2!, list: _3!)
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
