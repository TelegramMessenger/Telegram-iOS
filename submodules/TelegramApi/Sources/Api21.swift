public extension Api {
    indirect enum Updates: TypeConstructorDescription {
        case updateShort(update: Api.Update, date: Int32)
        case updateShortChatMessage(flags: Int32, id: Int32, fromId: Int64, chatId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updateShortMessage(flags: Int32, id: Int32, userId: Int64, message: String, pts: Int32, ptsCount: Int32, date: Int32, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updateShortSentMessage(flags: Int32, id: Int32, pts: Int32, ptsCount: Int32, date: Int32, media: Api.MessageMedia?, entities: [Api.MessageEntity]?, ttlPeriod: Int32?)
        case updates(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seq: Int32)
        case updatesCombined(updates: [Api.Update], users: [Api.User], chats: [Api.Chat], date: Int32, seqStart: Int32, seq: Int32)
        case updatesTooLong
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .updateShort(let update, let date):
                    if boxed {
                        buffer.appendInt32(2027216577)
                    }
                    update.serialize(buffer, true)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
                case .updateShortChatMessage(let flags, let id, let fromId, let chatId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyTo, let entities, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(1299050149)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(fromId, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt64(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .updateShortMessage(let flags, let id, let userId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyTo, let entities, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(826001400)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt64(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .updateShortSentMessage(let flags, let id, let pts, let ptsCount, let date, let media, let entities, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(-1877614335)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    serializeInt32(pts, buffer: buffer, boxed: false)
                    serializeInt32(ptsCount, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .updates(let updates, let users, let chats, let date, let seq):
                    if boxed {
                        buffer.appendInt32(1957577280)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(updates.count))
                    for item in updates {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .updatesCombined(let updates, let users, let chats, let date, let seqStart, let seq):
                    if boxed {
                        buffer.appendInt32(1918567619)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(updates.count))
                    for item in updates {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        item.serialize(buffer, true)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(chats.count))
                    for item in chats {
                        item.serialize(buffer, true)
                    }
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeInt32(seqStart, buffer: buffer, boxed: false)
                    serializeInt32(seq, buffer: buffer, boxed: false)
                    break
                case .updatesTooLong:
                    if boxed {
                        buffer.appendInt32(-484987010)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .updateShort(let update, let date):
                return ("updateShort", [("update", String(describing: update)), ("date", String(describing: date))])
                case .updateShortChatMessage(let flags, let id, let fromId, let chatId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyTo, let entities, let ttlPeriod):
                return ("updateShortChatMessage", [("flags", String(describing: flags)), ("id", String(describing: id)), ("fromId", String(describing: fromId)), ("chatId", String(describing: chatId)), ("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount)), ("date", String(describing: date)), ("fwdFrom", String(describing: fwdFrom)), ("viaBotId", String(describing: viaBotId)), ("replyTo", String(describing: replyTo)), ("entities", String(describing: entities)), ("ttlPeriod", String(describing: ttlPeriod))])
                case .updateShortMessage(let flags, let id, let userId, let message, let pts, let ptsCount, let date, let fwdFrom, let viaBotId, let replyTo, let entities, let ttlPeriod):
                return ("updateShortMessage", [("flags", String(describing: flags)), ("id", String(describing: id)), ("userId", String(describing: userId)), ("message", String(describing: message)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount)), ("date", String(describing: date)), ("fwdFrom", String(describing: fwdFrom)), ("viaBotId", String(describing: viaBotId)), ("replyTo", String(describing: replyTo)), ("entities", String(describing: entities)), ("ttlPeriod", String(describing: ttlPeriod))])
                case .updateShortSentMessage(let flags, let id, let pts, let ptsCount, let date, let media, let entities, let ttlPeriod):
                return ("updateShortSentMessage", [("flags", String(describing: flags)), ("id", String(describing: id)), ("pts", String(describing: pts)), ("ptsCount", String(describing: ptsCount)), ("date", String(describing: date)), ("media", String(describing: media)), ("entities", String(describing: entities)), ("ttlPeriod", String(describing: ttlPeriod))])
                case .updates(let updates, let users, let chats, let date, let seq):
                return ("updates", [("updates", String(describing: updates)), ("users", String(describing: users)), ("chats", String(describing: chats)), ("date", String(describing: date)), ("seq", String(describing: seq))])
                case .updatesCombined(let updates, let users, let chats, let date, let seqStart, let seq):
                return ("updatesCombined", [("updates", String(describing: updates)), ("users", String(describing: users)), ("chats", String(describing: chats)), ("date", String(describing: date)), ("seqStart", String(describing: seqStart)), ("seq", String(describing: seq))])
                case .updatesTooLong:
                return ("updatesTooLong", [])
    }
    }
    
        public static func parse_updateShort(_ reader: BufferReader) -> Updates? {
            var _1: Api.Update?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Update
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Updates.updateShort(update: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortChatMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            _4 = reader.readInt64()
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _10: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt64() }
            var _11: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_13 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 2) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 3) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 25) == 0) || _13 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 {
                return Api.Updates.updateShortChatMessage(flags: _1!, id: _2!, fromId: _3!, chatId: _4!, message: _5!, pts: _6!, ptsCount: _7!, date: _8!, fwdFrom: _9, viaBotId: _10, replyTo: _11, entities: _12, ttlPeriod: _13)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortMessage(_ reader: BufferReader) -> Updates? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _8 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _9: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {_9 = reader.readInt64() }
            var _10: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _11: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _11 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _12: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_12 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 11) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 3) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 7) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 25) == 0) || _12 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 {
                return Api.Updates.updateShortMessage(flags: _1!, id: _2!, userId: _3!, message: _4!, pts: _5!, ptsCount: _6!, date: _7!, fwdFrom: _8, viaBotId: _9, replyTo: _10, entities: _11, ttlPeriod: _12)
            }
            else {
                return nil
            }
        }
        public static func parse_updateShortSentMessage(_ reader: BufferReader) -> Updates? {
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
            var _6: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _7: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _7 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 9) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 7) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 25) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Updates.updateShortSentMessage(flags: _1!, id: _2!, pts: _3!, ptsCount: _4!, date: _5!, media: _6, entities: _7, ttlPeriod: _8)
            }
            else {
                return nil
            }
        }
        public static func parse_updates(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
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
                return Api.Updates.updates(updates: _1!, users: _2!, chats: _3!, date: _4!, seq: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatesCombined(_ reader: BufferReader) -> Updates? {
            var _1: [Api.Update]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Update.self)
            }
            var _2: [Api.User]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 0, elementType: Api.User.self)
            }
            var _3: [Api.Chat]?
            if let _ = reader.readInt32() {
                _3 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Chat.self)
            }
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Int32?
            _6 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.Updates.updatesCombined(updates: _1!, users: _2!, chats: _3!, date: _4!, seqStart: _5!, seq: _6!)
            }
            else {
                return nil
            }
        }
        public static func parse_updatesTooLong(_ reader: BufferReader) -> Updates? {
            return Api.Updates.updatesTooLong
        }
    
    }
}
public extension Api {
    enum UrlAuthResult: TypeConstructorDescription {
        case urlAuthResultAccepted(url: String)
        case urlAuthResultDefault
        case urlAuthResultRequest(flags: Int32, bot: Api.User, domain: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .urlAuthResultAccepted(let url):
                    if boxed {
                        buffer.appendInt32(-1886646706)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    break
                case .urlAuthResultDefault:
                    if boxed {
                        buffer.appendInt32(-1445536993)
                    }
                    
                    break
                case .urlAuthResultRequest(let flags, let bot, let domain):
                    if boxed {
                        buffer.appendInt32(-1831650802)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    bot.serialize(buffer, true)
                    serializeString(domain, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .urlAuthResultAccepted(let url):
                return ("urlAuthResultAccepted", [("url", String(describing: url))])
                case .urlAuthResultDefault:
                return ("urlAuthResultDefault", [])
                case .urlAuthResultRequest(let flags, let bot, let domain):
                return ("urlAuthResultRequest", [("flags", String(describing: flags)), ("bot", String(describing: bot)), ("domain", String(describing: domain))])
    }
    }
    
        public static func parse_urlAuthResultAccepted(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.UrlAuthResult.urlAuthResultAccepted(url: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_urlAuthResultDefault(_ reader: BufferReader) -> UrlAuthResult? {
            return Api.UrlAuthResult.urlAuthResultDefault
        }
        public static func parse_urlAuthResultRequest(_ reader: BufferReader) -> UrlAuthResult? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.User?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.User
            }
            var _3: String?
            _3 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.UrlAuthResult.urlAuthResultRequest(flags: _1!, bot: _2!, domain: _3!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum User: TypeConstructorDescription {
        case user(flags: Int32, flags2: Int32, id: Int64, accessHash: Int64?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: Api.UserProfilePhoto?, status: Api.UserStatus?, botInfoVersion: Int32?, restrictionReason: [Api.RestrictionReason]?, botInlinePlaceholder: String?, langCode: String?, emojiStatus: Api.EmojiStatus?, usernames: [Api.Username]?)
        case userEmpty(id: Int64)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .user(let flags, let flags2, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder, let langCode, let emojiStatus, let usernames):
                    if boxed {
                        buffer.appendInt32(-1885878744)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(flags2, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(accessHash!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(firstName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(lastName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(username!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeString(phone!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {status!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(botInfoVersion!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 18) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 19) != 0 {serializeString(botInlinePlaceholder!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 22) != 0 {serializeString(langCode!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 30) != 0 {emojiStatus!.serialize(buffer, true)}
                    if Int(flags2) & Int(1 << 0) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(usernames!.count))
                    for item in usernames! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .userEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-742634630)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .user(let flags, let flags2, let id, let accessHash, let firstName, let lastName, let username, let phone, let photo, let status, let botInfoVersion, let restrictionReason, let botInlinePlaceholder, let langCode, let emojiStatus, let usernames):
                return ("user", [("flags", String(describing: flags)), ("flags2", String(describing: flags2)), ("id", String(describing: id)), ("accessHash", String(describing: accessHash)), ("firstName", String(describing: firstName)), ("lastName", String(describing: lastName)), ("username", String(describing: username)), ("phone", String(describing: phone)), ("photo", String(describing: photo)), ("status", String(describing: status)), ("botInfoVersion", String(describing: botInfoVersion)), ("restrictionReason", String(describing: restrictionReason)), ("botInlinePlaceholder", String(describing: botInlinePlaceholder)), ("langCode", String(describing: langCode)), ("emojiStatus", String(describing: emojiStatus)), ("usernames", String(describing: usernames))])
                case .userEmpty(let id):
                return ("userEmpty", [("id", String(describing: id))])
    }
    }
    
        public static func parse_user(_ reader: BufferReader) -> User? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt64() }
            var _5: String?
            if Int(_1!) & Int(1 << 1) != 0 {_5 = parseString(reader) }
            var _6: String?
            if Int(_1!) & Int(1 << 2) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 3) != 0 {_7 = parseString(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 4) != 0 {_8 = parseString(reader) }
            var _9: Api.UserProfilePhoto?
            if Int(_1!) & Int(1 << 5) != 0 {if let signature = reader.readInt32() {
                _9 = Api.parse(reader, signature: signature) as? Api.UserProfilePhoto
            } }
            var _10: Api.UserStatus?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.UserStatus
            } }
            var _11: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_11 = reader.readInt32() }
            var _12: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 18) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _13: String?
            if Int(_1!) & Int(1 << 19) != 0 {_13 = parseString(reader) }
            var _14: String?
            if Int(_1!) & Int(1 << 22) != 0 {_14 = parseString(reader) }
            var _15: Api.EmojiStatus?
            if Int(_1!) & Int(1 << 30) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.EmojiStatus
            } }
            var _16: [Api.Username]?
            if Int(_2!) & Int(1 << 0) != 0 {if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.Username.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 1) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 2) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 4) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 5) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 6) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 14) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 18) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 19) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 22) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 30) == 0) || _15 != nil
            let _c16 = (Int(_2!) & Int(1 << 0) == 0) || _16 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 {
                return Api.User.user(flags: _1!, flags2: _2!, id: _3!, accessHash: _4, firstName: _5, lastName: _6, username: _7, phone: _8, photo: _9, status: _10, botInfoVersion: _11, restrictionReason: _12, botInlinePlaceholder: _13, langCode: _14, emojiStatus: _15, usernames: _16)
            }
            else {
                return nil
            }
        }
        public static func parse_userEmpty(_ reader: BufferReader) -> User? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.User.userEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum UserFull: TypeConstructorDescription {
        case userFull(flags: Int32, id: Int64, about: String?, settings: Api.PeerSettings, profilePhoto: Api.Photo?, notifySettings: Api.PeerNotifySettings, botInfo: Api.BotInfo?, pinnedMsgId: Int32?, commonChatsCount: Int32, folderId: Int32?, ttlPeriod: Int32?, themeEmoticon: String?, privateForwardName: String?, botGroupAdminRights: Api.ChatAdminRights?, botBroadcastAdminRights: Api.ChatAdminRights?, premiumGifts: [Api.PremiumGiftOption]?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userFull(let flags, let id, let about, let settings, let profilePhoto, let notifySettings, let botInfo, let pinnedMsgId, let commonChatsCount, let folderId, let ttlPeriod, let themeEmoticon, let privateForwardName, let botGroupAdminRights, let botBroadcastAdminRights, let premiumGifts):
                    if boxed {
                        buffer.appendInt32(-994968513)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(about!, buffer: buffer, boxed: false)}
                    settings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {profilePhoto!.serialize(buffer, true)}
                    notifySettings.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {botInfo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(pinnedMsgId!, buffer: buffer, boxed: false)}
                    serializeInt32(commonChatsCount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt32(folderId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 14) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeString(themeEmoticon!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(privateForwardName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {botGroupAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 18) != 0 {botBroadcastAdminRights!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 19) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(premiumGifts!.count))
                    for item in premiumGifts! {
                        item.serialize(buffer, true)
                    }}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userFull(let flags, let id, let about, let settings, let profilePhoto, let notifySettings, let botInfo, let pinnedMsgId, let commonChatsCount, let folderId, let ttlPeriod, let themeEmoticon, let privateForwardName, let botGroupAdminRights, let botBroadcastAdminRights, let premiumGifts):
                return ("userFull", [("flags", String(describing: flags)), ("id", String(describing: id)), ("about", String(describing: about)), ("settings", String(describing: settings)), ("profilePhoto", String(describing: profilePhoto)), ("notifySettings", String(describing: notifySettings)), ("botInfo", String(describing: botInfo)), ("pinnedMsgId", String(describing: pinnedMsgId)), ("commonChatsCount", String(describing: commonChatsCount)), ("folderId", String(describing: folderId)), ("ttlPeriod", String(describing: ttlPeriod)), ("themeEmoticon", String(describing: themeEmoticon)), ("privateForwardName", String(describing: privateForwardName)), ("botGroupAdminRights", String(describing: botGroupAdminRights)), ("botBroadcastAdminRights", String(describing: botBroadcastAdminRights)), ("premiumGifts", String(describing: premiumGifts))])
    }
    }
    
        public static func parse_userFull(_ reader: BufferReader) -> UserFull? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseString(reader) }
            var _4: Api.PeerSettings?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.PeerSettings
            }
            var _5: Api.Photo?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _6: Api.PeerNotifySettings?
            if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.PeerNotifySettings
            }
            var _7: Api.BotInfo?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.BotInfo
            } }
            var _8: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_8 = reader.readInt32() }
            var _9: Int32?
            _9 = reader.readInt32()
            var _10: Int32?
            if Int(_1!) & Int(1 << 11) != 0 {_10 = reader.readInt32() }
            var _11: Int32?
            if Int(_1!) & Int(1 << 14) != 0 {_11 = reader.readInt32() }
            var _12: String?
            if Int(_1!) & Int(1 << 15) != 0 {_12 = parseString(reader) }
            var _13: String?
            if Int(_1!) & Int(1 << 16) != 0 {_13 = parseString(reader) }
            var _14: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 17) != 0 {if let signature = reader.readInt32() {
                _14 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _15: Api.ChatAdminRights?
            if Int(_1!) & Int(1 << 18) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.ChatAdminRights
            } }
            var _16: [Api.PremiumGiftOption]?
            if Int(_1!) & Int(1 << 19) != 0 {if let _ = reader.readInt32() {
                _16 = Api.parseVector(reader, elementSignature: 0, elementType: Api.PremiumGiftOption.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 6) == 0) || _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 11) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 14) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 15) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 16) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 17) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 18) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 19) == 0) || _16 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 {
                return Api.UserFull.userFull(flags: _1!, id: _2!, about: _3, settings: _4!, profilePhoto: _5, notifySettings: _6!, botInfo: _7, pinnedMsgId: _8, commonChatsCount: _9!, folderId: _10, ttlPeriod: _11, themeEmoticon: _12, privateForwardName: _13, botGroupAdminRights: _14, botBroadcastAdminRights: _15, premiumGifts: _16)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum UserProfilePhoto: TypeConstructorDescription {
        case userProfilePhoto(flags: Int32, photoId: Int64, strippedThumb: Buffer?, dcId: Int32)
        case userProfilePhotoEmpty
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userProfilePhoto(let flags, let photoId, let strippedThumb, let dcId):
                    if boxed {
                        buffer.appendInt32(-2100168954)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(photoId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 1) != 0 {serializeBytes(strippedThumb!, buffer: buffer, boxed: false)}
                    serializeInt32(dcId, buffer: buffer, boxed: false)
                    break
                case .userProfilePhotoEmpty:
                    if boxed {
                        buffer.appendInt32(1326562017)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userProfilePhoto(let flags, let photoId, let strippedThumb, let dcId):
                return ("userProfilePhoto", [("flags", String(describing: flags)), ("photoId", String(describing: photoId)), ("strippedThumb", String(describing: strippedThumb)), ("dcId", String(describing: dcId))])
                case .userProfilePhotoEmpty:
                return ("userProfilePhotoEmpty", [])
    }
    }
    
        public static func parse_userProfilePhoto(_ reader: BufferReader) -> UserProfilePhoto? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Buffer?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = parseBytes(reader) }
            var _4: Int32?
            _4 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.UserProfilePhoto.userProfilePhoto(flags: _1!, photoId: _2!, strippedThumb: _3, dcId: _4!)
            }
            else {
                return nil
            }
        }
        public static func parse_userProfilePhotoEmpty(_ reader: BufferReader) -> UserProfilePhoto? {
            return Api.UserProfilePhoto.userProfilePhotoEmpty
        }
    
    }
}
public extension Api {
    enum UserStatus: TypeConstructorDescription {
        case userStatusEmpty
        case userStatusLastMonth
        case userStatusLastWeek
        case userStatusOffline(wasOnline: Int32)
        case userStatusOnline(expires: Int32)
        case userStatusRecently
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .userStatusEmpty:
                    if boxed {
                        buffer.appendInt32(164646985)
                    }
                    
                    break
                case .userStatusLastMonth:
                    if boxed {
                        buffer.appendInt32(2011940674)
                    }
                    
                    break
                case .userStatusLastWeek:
                    if boxed {
                        buffer.appendInt32(129960444)
                    }
                    
                    break
                case .userStatusOffline(let wasOnline):
                    if boxed {
                        buffer.appendInt32(9203775)
                    }
                    serializeInt32(wasOnline, buffer: buffer, boxed: false)
                    break
                case .userStatusOnline(let expires):
                    if boxed {
                        buffer.appendInt32(-306628279)
                    }
                    serializeInt32(expires, buffer: buffer, boxed: false)
                    break
                case .userStatusRecently:
                    if boxed {
                        buffer.appendInt32(-496024847)
                    }
                    
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .userStatusEmpty:
                return ("userStatusEmpty", [])
                case .userStatusLastMonth:
                return ("userStatusLastMonth", [])
                case .userStatusLastWeek:
                return ("userStatusLastWeek", [])
                case .userStatusOffline(let wasOnline):
                return ("userStatusOffline", [("wasOnline", String(describing: wasOnline))])
                case .userStatusOnline(let expires):
                return ("userStatusOnline", [("expires", String(describing: expires))])
                case .userStatusRecently:
                return ("userStatusRecently", [])
    }
    }
    
        public static func parse_userStatusEmpty(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusEmpty
        }
        public static func parse_userStatusLastMonth(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusLastMonth
        }
        public static func parse_userStatusLastWeek(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusLastWeek
        }
        public static func parse_userStatusOffline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOffline(wasOnline: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusOnline(_ reader: BufferReader) -> UserStatus? {
            var _1: Int32?
            _1 = reader.readInt32()
            let _c1 = _1 != nil
            if _c1 {
                return Api.UserStatus.userStatusOnline(expires: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_userStatusRecently(_ reader: BufferReader) -> UserStatus? {
            return Api.UserStatus.userStatusRecently
        }
    
    }
}
public extension Api {
    enum Username: TypeConstructorDescription {
        case username(flags: Int32, username: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .username(let flags, let username):
                    if boxed {
                        buffer.appendInt32(-1274595769)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(username, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .username(let flags, let username):
                return ("username", [("flags", String(describing: flags)), ("username", String(describing: username))])
    }
    }
    
        public static func parse_username(_ reader: BufferReader) -> Username? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.Username.username(flags: _1!, username: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum VideoSize: TypeConstructorDescription {
        case videoSize(flags: Int32, type: String, w: Int32, h: Int32, size: Int32, videoStartTs: Double?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .videoSize(let flags, let type, let w, let h, let size, let videoStartTs):
                    if boxed {
                        buffer.appendInt32(-567037804)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(type, buffer: buffer, boxed: false)
                    serializeInt32(w, buffer: buffer, boxed: false)
                    serializeInt32(h, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeDouble(videoStartTs!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .videoSize(let flags, let type, let w, let h, let size, let videoStartTs):
                return ("videoSize", [("flags", String(describing: flags)), ("type", String(describing: type)), ("w", String(describing: w)), ("h", String(describing: h)), ("size", String(describing: size)), ("videoStartTs", String(describing: videoStartTs))])
    }
    }
    
        public static func parse_videoSize(_ reader: BufferReader) -> VideoSize? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: Double?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readDouble() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.VideoSize.videoSize(flags: _1!, type: _2!, w: _3!, h: _4!, size: _5!, videoStartTs: _6)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WallPaper: TypeConstructorDescription {
        case wallPaper(id: Int64, flags: Int32, accessHash: Int64, slug: String, document: Api.Document, settings: Api.WallPaperSettings?)
        case wallPaperNoFile(id: Int64, flags: Int32, settings: Api.WallPaperSettings?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPaper(let id, let flags, let accessHash, let slug, let document, let settings):
                    if boxed {
                        buffer.appendInt32(-1539849235)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeString(slug, buffer: buffer, boxed: false)
                    document.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {settings!.serialize(buffer, true)}
                    break
                case .wallPaperNoFile(let id, let flags, let settings):
                    if boxed {
                        buffer.appendInt32(-528465642)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 2) != 0 {settings!.serialize(buffer, true)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPaper(let id, let flags, let accessHash, let slug, let document, let settings):
                return ("wallPaper", [("id", String(describing: id)), ("flags", String(describing: flags)), ("accessHash", String(describing: accessHash)), ("slug", String(describing: slug)), ("document", String(describing: document)), ("settings", String(describing: settings))])
                case .wallPaperNoFile(let id, let flags, let settings):
                return ("wallPaperNoFile", [("id", String(describing: id)), ("flags", String(describing: flags)), ("settings", String(describing: settings))])
    }
    }
    
        public static func parse_wallPaper(_ reader: BufferReader) -> WallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            _4 = parseString(reader)
            var _5: Api.Document?
            if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Document
            }
            var _6: Api.WallPaperSettings?
            if Int(_2!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _6 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_2!) & Int(1 << 2) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.WallPaper.wallPaper(id: _1!, flags: _2!, accessHash: _3!, slug: _4!, document: _5!, settings: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_wallPaperNoFile(_ reader: BufferReader) -> WallPaper? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.WallPaperSettings?
            if Int(_2!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.WallPaperSettings
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_2!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.WallPaper.wallPaperNoFile(id: _1!, flags: _2!, settings: _3)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WallPaperSettings: TypeConstructorDescription {
        case wallPaperSettings(flags: Int32, backgroundColor: Int32?, secondBackgroundColor: Int32?, thirdBackgroundColor: Int32?, fourthBackgroundColor: Int32?, intensity: Int32?, rotation: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .wallPaperSettings(let flags, let backgroundColor, let secondBackgroundColor, let thirdBackgroundColor, let fourthBackgroundColor, let intensity, let rotation):
                    if boxed {
                        buffer.appendInt32(499236004)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(backgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(secondBackgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeInt32(thirdBackgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(fourthBackgroundColor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeInt32(intensity!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {serializeInt32(rotation!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .wallPaperSettings(let flags, let backgroundColor, let secondBackgroundColor, let thirdBackgroundColor, let fourthBackgroundColor, let intensity, let rotation):
                return ("wallPaperSettings", [("flags", String(describing: flags)), ("backgroundColor", String(describing: backgroundColor)), ("secondBackgroundColor", String(describing: secondBackgroundColor)), ("thirdBackgroundColor", String(describing: thirdBackgroundColor)), ("fourthBackgroundColor", String(describing: fourthBackgroundColor)), ("intensity", String(describing: intensity)), ("rotation", String(describing: rotation))])
    }
    }
    
        public static func parse_wallPaperSettings(_ reader: BufferReader) -> WallPaperSettings? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            var _3: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_3 = reader.readInt32() }
            var _4: Int32?
            if Int(_1!) & Int(1 << 5) != 0 {_4 = reader.readInt32() }
            var _5: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_5 = reader.readInt32() }
            var _6: Int32?
            if Int(_1!) & Int(1 << 3) != 0 {_6 = reader.readInt32() }
            var _7: Int32?
            if Int(_1!) & Int(1 << 4) != 0 {_7 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 4) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 5) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 6) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 3) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 4) == 0) || _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.WallPaperSettings.wallPaperSettings(flags: _1!, backgroundColor: _2, secondBackgroundColor: _3, thirdBackgroundColor: _4, fourthBackgroundColor: _5, intensity: _6, rotation: _7)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebAuthorization: TypeConstructorDescription {
        case webAuthorization(hash: Int64, botId: Int64, domain: String, browser: String, platform: String, dateCreated: Int32, dateActive: Int32, ip: String, region: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webAuthorization(let hash, let botId, let domain, let browser, let platform, let dateCreated, let dateActive, let ip, let region):
                    if boxed {
                        buffer.appendInt32(-1493633966)
                    }
                    serializeInt64(hash, buffer: buffer, boxed: false)
                    serializeInt64(botId, buffer: buffer, boxed: false)
                    serializeString(domain, buffer: buffer, boxed: false)
                    serializeString(browser, buffer: buffer, boxed: false)
                    serializeString(platform, buffer: buffer, boxed: false)
                    serializeInt32(dateCreated, buffer: buffer, boxed: false)
                    serializeInt32(dateActive, buffer: buffer, boxed: false)
                    serializeString(ip, buffer: buffer, boxed: false)
                    serializeString(region, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webAuthorization(let hash, let botId, let domain, let browser, let platform, let dateCreated, let dateActive, let ip, let region):
                return ("webAuthorization", [("hash", String(describing: hash)), ("botId", String(describing: botId)), ("domain", String(describing: domain)), ("browser", String(describing: browser)), ("platform", String(describing: platform)), ("dateCreated", String(describing: dateCreated)), ("dateActive", String(describing: dateActive)), ("ip", String(describing: ip)), ("region", String(describing: region))])
    }
    }
    
        public static func parse_webAuthorization(_ reader: BufferReader) -> WebAuthorization? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: String?
            _5 = parseString(reader)
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Int32?
            _7 = reader.readInt32()
            var _8: String?
            _8 = parseString(reader)
            var _9: String?
            _9 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 {
                return Api.WebAuthorization.webAuthorization(hash: _1!, botId: _2!, domain: _3!, browser: _4!, platform: _5!, dateCreated: _6!, dateActive: _7!, ip: _8!, region: _9!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebDocument: TypeConstructorDescription {
        case webDocument(url: String, accessHash: Int64, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
        case webDocumentNoProxy(url: String, size: Int32, mimeType: String, attributes: [Api.DocumentAttribute])
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webDocument(let url, let accessHash, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(475467473)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt64(accessHash, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
                case .webDocumentNoProxy(let url, let size, let mimeType, let attributes):
                    if boxed {
                        buffer.appendInt32(-104284986)
                    }
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeInt32(size, buffer: buffer, boxed: false)
                    serializeString(mimeType, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes.count))
                    for item in attributes {
                        item.serialize(buffer, true)
                    }
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webDocument(let url, let accessHash, let size, let mimeType, let attributes):
                return ("webDocument", [("url", String(describing: url)), ("accessHash", String(describing: accessHash)), ("size", String(describing: size)), ("mimeType", String(describing: mimeType)), ("attributes", String(describing: attributes))])
                case .webDocumentNoProxy(let url, let size, let mimeType, let attributes):
                return ("webDocumentNoProxy", [("url", String(describing: url)), ("size", String(describing: size)), ("mimeType", String(describing: mimeType)), ("attributes", String(describing: attributes))])
    }
    }
    
        public static func parse_webDocument(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: String?
            _4 = parseString(reader)
            var _5: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _5 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.WebDocument.webDocument(url: _1!, accessHash: _2!, size: _3!, mimeType: _4!, attributes: _5!)
            }
            else {
                return nil
            }
        }
        public static func parse_webDocumentNoProxy(_ reader: BufferReader) -> WebDocument? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: String?
            _3 = parseString(reader)
            var _4: [Api.DocumentAttribute]?
            if let _ = reader.readInt32() {
                _4 = Api.parseVector(reader, elementSignature: 0, elementType: Api.DocumentAttribute.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.WebDocument.webDocumentNoProxy(url: _1!, size: _2!, mimeType: _3!, attributes: _4!)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum WebPage: TypeConstructorDescription {
        case webPage(flags: Int32, id: Int64, url: String, displayUrl: String, hash: Int32, type: String?, siteName: String?, title: String?, description: String?, photo: Api.Photo?, embedUrl: String?, embedType: String?, embedWidth: Int32?, embedHeight: Int32?, duration: Int32?, author: String?, document: Api.Document?, cachedPage: Api.Page?, attributes: [Api.WebPageAttribute]?)
        case webPageEmpty(id: Int64)
        case webPageNotModified(flags: Int32, cachedPageViews: Int32?)
        case webPagePending(id: Int64, date: Int32)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document, let cachedPage, let attributes):
                    if boxed {
                        buffer.appendInt32(-392411726)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeString(url, buffer: buffer, boxed: false)
                    serializeString(displayUrl, buffer: buffer, boxed: false)
                    serializeInt32(hash, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(type!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(siteName!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {serializeString(description!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 4) != 0 {photo!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(embedUrl!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 5) != 0 {serializeString(embedType!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedWidth!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 6) != 0 {serializeInt32(embedHeight!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 7) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 8) != 0 {serializeString(author!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 9) != 0 {document!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 10) != 0 {cachedPage!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 12) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(attributes!.count))
                    for item in attributes! {
                        item.serialize(buffer, true)
                    }}
                    break
                case .webPageEmpty(let id):
                    if boxed {
                        buffer.appendInt32(-350980120)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    break
                case .webPageNotModified(let flags, let cachedPageViews):
                    if boxed {
                        buffer.appendInt32(1930545681)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(cachedPageViews!, buffer: buffer, boxed: false)}
                    break
                case .webPagePending(let id, let date):
                    if boxed {
                        buffer.appendInt32(-981018084)
                    }
                    serializeInt64(id, buffer: buffer, boxed: false)
                    serializeInt32(date, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .webPage(let flags, let id, let url, let displayUrl, let hash, let type, let siteName, let title, let description, let photo, let embedUrl, let embedType, let embedWidth, let embedHeight, let duration, let author, let document, let cachedPage, let attributes):
                return ("webPage", [("flags", String(describing: flags)), ("id", String(describing: id)), ("url", String(describing: url)), ("displayUrl", String(describing: displayUrl)), ("hash", String(describing: hash)), ("type", String(describing: type)), ("siteName", String(describing: siteName)), ("title", String(describing: title)), ("description", String(describing: description)), ("photo", String(describing: photo)), ("embedUrl", String(describing: embedUrl)), ("embedType", String(describing: embedType)), ("embedWidth", String(describing: embedWidth)), ("embedHeight", String(describing: embedHeight)), ("duration", String(describing: duration)), ("author", String(describing: author)), ("document", String(describing: document)), ("cachedPage", String(describing: cachedPage)), ("attributes", String(describing: attributes))])
                case .webPageEmpty(let id):
                return ("webPageEmpty", [("id", String(describing: id))])
                case .webPageNotModified(let flags, let cachedPageViews):
                return ("webPageNotModified", [("flags", String(describing: flags)), ("cachedPageViews", String(describing: cachedPageViews))])
                case .webPagePending(let id, let date):
                return ("webPagePending", [("id", String(describing: id)), ("date", String(describing: date))])
    }
    }
    
        public static func parse_webPage(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: String?
            _3 = parseString(reader)
            var _4: String?
            _4 = parseString(reader)
            var _5: Int32?
            _5 = reader.readInt32()
            var _6: String?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = parseString(reader) }
            var _7: String?
            if Int(_1!) & Int(1 << 1) != 0 {_7 = parseString(reader) }
            var _8: String?
            if Int(_1!) & Int(1 << 2) != 0 {_8 = parseString(reader) }
            var _9: String?
            if Int(_1!) & Int(1 << 3) != 0 {_9 = parseString(reader) }
            var _10: Api.Photo?
            if Int(_1!) & Int(1 << 4) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.Photo
            } }
            var _11: String?
            if Int(_1!) & Int(1 << 5) != 0 {_11 = parseString(reader) }
            var _12: String?
            if Int(_1!) & Int(1 << 5) != 0 {_12 = parseString(reader) }
            var _13: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 6) != 0 {_14 = reader.readInt32() }
            var _15: Int32?
            if Int(_1!) & Int(1 << 7) != 0 {_15 = reader.readInt32() }
            var _16: String?
            if Int(_1!) & Int(1 << 8) != 0 {_16 = parseString(reader) }
            var _17: Api.Document?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _17 = Api.parse(reader, signature: signature) as? Api.Document
            } }
            var _18: Api.Page?
            if Int(_1!) & Int(1 << 10) != 0 {if let signature = reader.readInt32() {
                _18 = Api.parse(reader, signature: signature) as? Api.Page
            } }
            var _19: [Api.WebPageAttribute]?
            if Int(_1!) & Int(1 << 12) != 0 {if let _ = reader.readInt32() {
                _19 = Api.parseVector(reader, elementSignature: 0, elementType: Api.WebPageAttribute.self)
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 1) == 0) || _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 2) == 0) || _8 != nil
            let _c9 = (Int(_1!) & Int(1 << 3) == 0) || _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 4) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 5) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 5) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 6) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 6) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 7) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 8) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 9) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 10) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 12) == 0) || _19 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 {
                return Api.WebPage.webPage(flags: _1!, id: _2!, url: _3!, displayUrl: _4!, hash: _5!, type: _6, siteName: _7, title: _8, description: _9, photo: _10, embedUrl: _11, embedType: _12, embedWidth: _13, embedHeight: _14, duration: _15, author: _16, document: _17, cachedPage: _18, attributes: _19)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageEmpty(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.WebPage.webPageEmpty(id: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_webPageNotModified(_ reader: BufferReader) -> WebPage? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            if _c1 && _c2 {
                return Api.WebPage.webPageNotModified(flags: _1!, cachedPageViews: _2)
            }
            else {
                return nil
            }
        }
        public static func parse_webPagePending(_ reader: BufferReader) -> WebPage? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.WebPage.webPagePending(id: _1!, date: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
