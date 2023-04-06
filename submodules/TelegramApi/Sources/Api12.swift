public extension Api {
    indirect enum Message: TypeConstructorDescription {
        case message(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, fwdFrom: Api.MessageFwdHeader?, viaBotId: Int64?, replyTo: Api.MessageReplyHeader?, date: Int32, message: String, media: Api.MessageMedia?, replyMarkup: Api.ReplyMarkup?, entities: [Api.MessageEntity]?, views: Int32?, forwards: Int32?, replies: Api.MessageReplies?, editDate: Int32?, postAuthor: String?, groupedId: Int64?, reactions: Api.MessageReactions?, restrictionReason: [Api.RestrictionReason]?, ttlPeriod: Int32?)
        case messageEmpty(flags: Int32, id: Int32, peerId: Api.Peer?)
        case messageService(flags: Int32, id: Int32, fromId: Api.Peer?, peerId: Api.Peer, replyTo: Api.MessageReplyHeader?, date: Int32, action: Api.MessageAction, ttlPeriod: Int32?)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .message(let flags, let id, let fromId, let peerId, let fwdFrom, let viaBotId, let replyTo, let date, let message, let media, let replyMarkup, let entities, let views, let forwards, let replies, let editDate, let postAuthor, let groupedId, let reactions, let restrictionReason, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(940666592)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {fromId!.serialize(buffer, true)}
                    peerId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 2) != 0 {fwdFrom!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 11) != 0 {serializeInt64(viaBotId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    serializeString(message, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 9) != 0 {media!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 6) != 0 {replyMarkup!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 7) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(entities!.count))
                    for item in entities! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(views!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 10) != 0 {serializeInt32(forwards!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 23) != 0 {replies!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 15) != 0 {serializeInt32(editDate!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 16) != 0 {serializeString(postAuthor!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 17) != 0 {serializeInt64(groupedId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 20) != 0 {reactions!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 22) != 0 {buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(restrictionReason!.count))
                    for item in restrictionReason! {
                        item.serialize(buffer, true)
                    }}
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
                case .messageEmpty(let flags, let id, let peerId):
                    if boxed {
                        buffer.appendInt32(-1868117372)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {peerId!.serialize(buffer, true)}
                    break
                case .messageService(let flags, let id, let fromId, let peerId, let replyTo, let date, let action, let ttlPeriod):
                    if boxed {
                        buffer.appendInt32(721967202)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(id, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 8) != 0 {fromId!.serialize(buffer, true)}
                    peerId.serialize(buffer, true)
                    if Int(flags) & Int(1 << 3) != 0 {replyTo!.serialize(buffer, true)}
                    serializeInt32(date, buffer: buffer, boxed: false)
                    action.serialize(buffer, true)
                    if Int(flags) & Int(1 << 25) != 0 {serializeInt32(ttlPeriod!, buffer: buffer, boxed: false)}
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .message(let flags, let id, let fromId, let peerId, let fwdFrom, let viaBotId, let replyTo, let date, let message, let media, let replyMarkup, let entities, let views, let forwards, let replies, let editDate, let postAuthor, let groupedId, let reactions, let restrictionReason, let ttlPeriod):
                return ("message", [("flags", flags as Any), ("id", id as Any), ("fromId", fromId as Any), ("peerId", peerId as Any), ("fwdFrom", fwdFrom as Any), ("viaBotId", viaBotId as Any), ("replyTo", replyTo as Any), ("date", date as Any), ("message", message as Any), ("media", media as Any), ("replyMarkup", replyMarkup as Any), ("entities", entities as Any), ("views", views as Any), ("forwards", forwards as Any), ("replies", replies as Any), ("editDate", editDate as Any), ("postAuthor", postAuthor as Any), ("groupedId", groupedId as Any), ("reactions", reactions as Any), ("restrictionReason", restrictionReason as Any), ("ttlPeriod", ttlPeriod as Any)])
                case .messageEmpty(let flags, let id, let peerId):
                return ("messageEmpty", [("flags", flags as Any), ("id", id as Any), ("peerId", peerId as Any)])
                case .messageService(let flags, let id, let fromId, let peerId, let replyTo, let date, let action, let ttlPeriod):
                return ("messageService", [("flags", flags as Any), ("id", id as Any), ("fromId", fromId as Any), ("peerId", peerId as Any), ("replyTo", replyTo as Any), ("date", date as Any), ("action", action as Any), ("ttlPeriod", ttlPeriod as Any)])
    }
    }
    
        public static func parse_message(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.MessageFwdHeader?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageFwdHeader
            } }
            var _6: Int64?
            if Int(_1!) & Int(1 << 11) != 0 {_6 = reader.readInt64() }
            var _7: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _8: Int32?
            _8 = reader.readInt32()
            var _9: String?
            _9 = parseString(reader)
            var _10: Api.MessageMedia?
            if Int(_1!) & Int(1 << 9) != 0 {if let signature = reader.readInt32() {
                _10 = Api.parse(reader, signature: signature) as? Api.MessageMedia
            } }
            var _11: Api.ReplyMarkup?
            if Int(_1!) & Int(1 << 6) != 0 {if let signature = reader.readInt32() {
                _11 = Api.parse(reader, signature: signature) as? Api.ReplyMarkup
            } }
            var _12: [Api.MessageEntity]?
            if Int(_1!) & Int(1 << 7) != 0 {if let _ = reader.readInt32() {
                _12 = Api.parseVector(reader, elementSignature: 0, elementType: Api.MessageEntity.self)
            } }
            var _13: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_13 = reader.readInt32() }
            var _14: Int32?
            if Int(_1!) & Int(1 << 10) != 0 {_14 = reader.readInt32() }
            var _15: Api.MessageReplies?
            if Int(_1!) & Int(1 << 23) != 0 {if let signature = reader.readInt32() {
                _15 = Api.parse(reader, signature: signature) as? Api.MessageReplies
            } }
            var _16: Int32?
            if Int(_1!) & Int(1 << 15) != 0 {_16 = reader.readInt32() }
            var _17: String?
            if Int(_1!) & Int(1 << 16) != 0 {_17 = parseString(reader) }
            var _18: Int64?
            if Int(_1!) & Int(1 << 17) != 0 {_18 = reader.readInt64() }
            var _19: Api.MessageReactions?
            if Int(_1!) & Int(1 << 20) != 0 {if let signature = reader.readInt32() {
                _19 = Api.parse(reader, signature: signature) as? Api.MessageReactions
            } }
            var _20: [Api.RestrictionReason]?
            if Int(_1!) & Int(1 << 22) != 0 {if let _ = reader.readInt32() {
                _20 = Api.parseVector(reader, elementSignature: 0, elementType: Api.RestrictionReason.self)
            } }
            var _21: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_21 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 2) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 11) == 0) || _6 != nil
            let _c7 = (Int(_1!) & Int(1 << 3) == 0) || _7 != nil
            let _c8 = _8 != nil
            let _c9 = _9 != nil
            let _c10 = (Int(_1!) & Int(1 << 9) == 0) || _10 != nil
            let _c11 = (Int(_1!) & Int(1 << 6) == 0) || _11 != nil
            let _c12 = (Int(_1!) & Int(1 << 7) == 0) || _12 != nil
            let _c13 = (Int(_1!) & Int(1 << 10) == 0) || _13 != nil
            let _c14 = (Int(_1!) & Int(1 << 10) == 0) || _14 != nil
            let _c15 = (Int(_1!) & Int(1 << 23) == 0) || _15 != nil
            let _c16 = (Int(_1!) & Int(1 << 15) == 0) || _16 != nil
            let _c17 = (Int(_1!) & Int(1 << 16) == 0) || _17 != nil
            let _c18 = (Int(_1!) & Int(1 << 17) == 0) || _18 != nil
            let _c19 = (Int(_1!) & Int(1 << 20) == 0) || _19 != nil
            let _c20 = (Int(_1!) & Int(1 << 22) == 0) || _20 != nil
            let _c21 = (Int(_1!) & Int(1 << 25) == 0) || _21 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 && _c9 && _c10 && _c11 && _c12 && _c13 && _c14 && _c15 && _c16 && _c17 && _c18 && _c19 && _c20 && _c21 {
                return Api.Message.message(flags: _1!, id: _2!, fromId: _3, peerId: _4!, fwdFrom: _5, viaBotId: _6, replyTo: _7, date: _8!, message: _9!, media: _10, replyMarkup: _11, entities: _12, views: _13, forwards: _14, replies: _15, editDate: _16, postAuthor: _17, groupedId: _18, reactions: _19, restrictionReason: _20, ttlPeriod: _21)
            }
            else {
                return nil
            }
        }
        public static func parse_messageEmpty(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.Message.messageEmpty(flags: _1!, id: _2!, peerId: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageService(_ reader: BufferReader) -> Message? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Api.Peer?
            if Int(_1!) & Int(1 << 8) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.Peer
            } }
            var _4: Api.Peer?
            if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            var _5: Api.MessageReplyHeader?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.MessageReplyHeader
            } }
            var _6: Int32?
            _6 = reader.readInt32()
            var _7: Api.MessageAction?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.MessageAction
            }
            var _8: Int32?
            if Int(_1!) & Int(1 << 25) != 0 {_8 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 8) == 0) || _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            let _c6 = _6 != nil
            let _c7 = _7 != nil
            let _c8 = (Int(_1!) & Int(1 << 25) == 0) || _8 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 && _c8 {
                return Api.Message.messageService(flags: _1!, id: _2!, fromId: _3, peerId: _4!, replyTo: _5, date: _6!, action: _7!, ttlPeriod: _8)
            }
            else {
                return nil
            }
        }
    
    }
}
public extension Api {
    enum MessageAction: TypeConstructorDescription {
        case messageActionBotAllowed(flags: Int32, domain: String?, app: Api.BotApp?)
        case messageActionChannelCreate(title: String)
        case messageActionChannelMigrateFrom(title: String, chatId: Int64)
        case messageActionChatAddUser(users: [Int64])
        case messageActionChatCreate(title: String, users: [Int64])
        case messageActionChatDeletePhoto
        case messageActionChatDeleteUser(userId: Int64)
        case messageActionChatEditPhoto(photo: Api.Photo)
        case messageActionChatEditTitle(title: String)
        case messageActionChatJoinedByLink(inviterId: Int64)
        case messageActionChatJoinedByRequest
        case messageActionChatMigrateTo(channelId: Int64)
        case messageActionContactSignUp
        case messageActionCustomAction(message: String)
        case messageActionEmpty
        case messageActionGameScore(gameId: Int64, score: Int32)
        case messageActionGeoProximityReached(fromId: Api.Peer, toId: Api.Peer, distance: Int32)
        case messageActionGiftPremium(flags: Int32, currency: String, amount: Int64, months: Int32, cryptoCurrency: String?, cryptoAmount: Int64?)
        case messageActionGroupCall(flags: Int32, call: Api.InputGroupCall, duration: Int32?)
        case messageActionGroupCallScheduled(call: Api.InputGroupCall, scheduleDate: Int32)
        case messageActionHistoryClear
        case messageActionInviteToGroupCall(call: Api.InputGroupCall, users: [Int64])
        case messageActionPaymentSent(flags: Int32, currency: String, totalAmount: Int64, invoiceSlug: String?)
        case messageActionPaymentSentMe(flags: Int32, currency: String, totalAmount: Int64, payload: Buffer, info: Api.PaymentRequestedInfo?, shippingOptionId: String?, charge: Api.PaymentCharge)
        case messageActionPhoneCall(flags: Int32, callId: Int64, reason: Api.PhoneCallDiscardReason?, duration: Int32?)
        case messageActionPinMessage
        case messageActionRequestedPeer(buttonId: Int32, peer: Api.Peer)
        case messageActionScreenshotTaken
        case messageActionSecureValuesSent(types: [Api.SecureValueType])
        case messageActionSecureValuesSentMe(values: [Api.SecureValue], credentials: Api.SecureCredentialsEncrypted)
        case messageActionSetChatTheme(emoticon: String)
        case messageActionSetChatWallPaper(wallpaper: Api.WallPaper)
        case messageActionSetMessagesTTL(flags: Int32, period: Int32, autoSettingFrom: Int64?)
        case messageActionSetSameChatWallPaper(wallpaper: Api.WallPaper)
        case messageActionSuggestProfilePhoto(photo: Api.Photo)
        case messageActionTopicCreate(flags: Int32, title: String, iconColor: Int32, iconEmojiId: Int64?)
        case messageActionTopicEdit(flags: Int32, title: String?, iconEmojiId: Int64?, closed: Api.Bool?, hidden: Api.Bool?)
        case messageActionWebViewDataSent(text: String)
        case messageActionWebViewDataSentMe(text: String, data: String)
    
    public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {
    switch self {
                case .messageActionBotAllowed(let flags, let domain, let app):
                    if boxed {
                        buffer.appendInt32(-988359047)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(domain!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {app!.serialize(buffer, true)}
                    break
                case .messageActionChannelCreate(let title):
                    if boxed {
                        buffer.appendInt32(-1781355374)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChannelMigrateFrom(let title, let chatId):
                    if boxed {
                        buffer.appendInt32(-365344535)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt64(chatId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatAddUser(let users):
                    if boxed {
                        buffer.appendInt32(365886720)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatCreate(let title, let users):
                    if boxed {
                        buffer.appendInt32(-1119368275)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionChatDeletePhoto:
                    if boxed {
                        buffer.appendInt32(-1780220945)
                    }
                    
                    break
                case .messageActionChatDeleteUser(let userId):
                    if boxed {
                        buffer.appendInt32(-1539362612)
                    }
                    serializeInt64(userId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatEditPhoto(let photo):
                    if boxed {
                        buffer.appendInt32(2144015272)
                    }
                    photo.serialize(buffer, true)
                    break
                case .messageActionChatEditTitle(let title):
                    if boxed {
                        buffer.appendInt32(-1247687078)
                    }
                    serializeString(title, buffer: buffer, boxed: false)
                    break
                case .messageActionChatJoinedByLink(let inviterId):
                    if boxed {
                        buffer.appendInt32(51520707)
                    }
                    serializeInt64(inviterId, buffer: buffer, boxed: false)
                    break
                case .messageActionChatJoinedByRequest:
                    if boxed {
                        buffer.appendInt32(-339958837)
                    }
                    
                    break
                case .messageActionChatMigrateTo(let channelId):
                    if boxed {
                        buffer.appendInt32(-519864430)
                    }
                    serializeInt64(channelId, buffer: buffer, boxed: false)
                    break
                case .messageActionContactSignUp:
                    if boxed {
                        buffer.appendInt32(-202219658)
                    }
                    
                    break
                case .messageActionCustomAction(let message):
                    if boxed {
                        buffer.appendInt32(-85549226)
                    }
                    serializeString(message, buffer: buffer, boxed: false)
                    break
                case .messageActionEmpty:
                    if boxed {
                        buffer.appendInt32(-1230047312)
                    }
                    
                    break
                case .messageActionGameScore(let gameId, let score):
                    if boxed {
                        buffer.appendInt32(-1834538890)
                    }
                    serializeInt64(gameId, buffer: buffer, boxed: false)
                    serializeInt32(score, buffer: buffer, boxed: false)
                    break
                case .messageActionGeoProximityReached(let fromId, let toId, let distance):
                    if boxed {
                        buffer.appendInt32(-1730095465)
                    }
                    fromId.serialize(buffer, true)
                    toId.serialize(buffer, true)
                    serializeInt32(distance, buffer: buffer, boxed: false)
                    break
                case .messageActionGiftPremium(let flags, let currency, let amount, let months, let cryptoCurrency, let cryptoAmount):
                    if boxed {
                        buffer.appendInt32(-935499028)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(amount, buffer: buffer, boxed: false)
                    serializeInt32(months, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(cryptoCurrency!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(cryptoAmount!, buffer: buffer, boxed: false)}
                    break
                case .messageActionGroupCall(let flags, let call, let duration):
                    if boxed {
                        buffer.appendInt32(2047704898)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    call.serialize(buffer, true)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
                case .messageActionGroupCallScheduled(let call, let scheduleDate):
                    if boxed {
                        buffer.appendInt32(-1281329567)
                    }
                    call.serialize(buffer, true)
                    serializeInt32(scheduleDate, buffer: buffer, boxed: false)
                    break
                case .messageActionHistoryClear:
                    if boxed {
                        buffer.appendInt32(-1615153660)
                    }
                    
                    break
                case .messageActionInviteToGroupCall(let call, let users):
                    if boxed {
                        buffer.appendInt32(1345295095)
                    }
                    call.serialize(buffer, true)
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(users.count))
                    for item in users {
                        serializeInt64(item, buffer: buffer, boxed: false)
                    }
                    break
                case .messageActionPaymentSent(let flags, let currency, let totalAmount, let invoiceSlug):
                    if boxed {
                        buffer.appendInt32(-1776926890)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(invoiceSlug!, buffer: buffer, boxed: false)}
                    break
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                    if boxed {
                        buffer.appendInt32(-1892568281)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(currency, buffer: buffer, boxed: false)
                    serializeInt64(totalAmount, buffer: buffer, boxed: false)
                    serializeBytes(payload, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {info!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeString(shippingOptionId!, buffer: buffer, boxed: false)}
                    charge.serialize(buffer, true)
                    break
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                    if boxed {
                        buffer.appendInt32(-2132731265)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt64(callId, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {reason!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt32(duration!, buffer: buffer, boxed: false)}
                    break
                case .messageActionPinMessage:
                    if boxed {
                        buffer.appendInt32(-1799538451)
                    }
                    
                    break
                case .messageActionRequestedPeer(let buttonId, let peer):
                    if boxed {
                        buffer.appendInt32(-25742243)
                    }
                    serializeInt32(buttonId, buffer: buffer, boxed: false)
                    peer.serialize(buffer, true)
                    break
                case .messageActionScreenshotTaken:
                    if boxed {
                        buffer.appendInt32(1200788123)
                    }
                    
                    break
                case .messageActionSecureValuesSent(let types):
                    if boxed {
                        buffer.appendInt32(-648257196)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(types.count))
                    for item in types {
                        item.serialize(buffer, true)
                    }
                    break
                case .messageActionSecureValuesSentMe(let values, let credentials):
                    if boxed {
                        buffer.appendInt32(455635795)
                    }
                    buffer.appendInt32(481674261)
                    buffer.appendInt32(Int32(values.count))
                    for item in values {
                        item.serialize(buffer, true)
                    }
                    credentials.serialize(buffer, true)
                    break
                case .messageActionSetChatTheme(let emoticon):
                    if boxed {
                        buffer.appendInt32(-1434950843)
                    }
                    serializeString(emoticon, buffer: buffer, boxed: false)
                    break
                case .messageActionSetChatWallPaper(let wallpaper):
                    if boxed {
                        buffer.appendInt32(-1136350937)
                    }
                    wallpaper.serialize(buffer, true)
                    break
                case .messageActionSetMessagesTTL(let flags, let period, let autoSettingFrom):
                    if boxed {
                        buffer.appendInt32(1007897979)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeInt32(period, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(autoSettingFrom!, buffer: buffer, boxed: false)}
                    break
                case .messageActionSetSameChatWallPaper(let wallpaper):
                    if boxed {
                        buffer.appendInt32(-1065845395)
                    }
                    wallpaper.serialize(buffer, true)
                    break
                case .messageActionSuggestProfilePhoto(let photo):
                    if boxed {
                        buffer.appendInt32(1474192222)
                    }
                    photo.serialize(buffer, true)
                    break
                case .messageActionTopicCreate(let flags, let title, let iconColor, let iconEmojiId):
                    if boxed {
                        buffer.appendInt32(228168278)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    serializeString(title, buffer: buffer, boxed: false)
                    serializeInt32(iconColor, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    break
                case .messageActionTopicEdit(let flags, let title, let iconEmojiId, let closed, let hidden):
                    if boxed {
                        buffer.appendInt32(-1064024032)
                    }
                    serializeInt32(flags, buffer: buffer, boxed: false)
                    if Int(flags) & Int(1 << 0) != 0 {serializeString(title!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 1) != 0 {serializeInt64(iconEmojiId!, buffer: buffer, boxed: false)}
                    if Int(flags) & Int(1 << 2) != 0 {closed!.serialize(buffer, true)}
                    if Int(flags) & Int(1 << 3) != 0 {hidden!.serialize(buffer, true)}
                    break
                case .messageActionWebViewDataSent(let text):
                    if boxed {
                        buffer.appendInt32(-1262252875)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    break
                case .messageActionWebViewDataSentMe(let text, let data):
                    if boxed {
                        buffer.appendInt32(1205698681)
                    }
                    serializeString(text, buffer: buffer, boxed: false)
                    serializeString(data, buffer: buffer, boxed: false)
                    break
    }
    }
    
    public func descriptionFields() -> (String, [(String, Any)]) {
        switch self {
                case .messageActionBotAllowed(let flags, let domain, let app):
                return ("messageActionBotAllowed", [("flags", flags as Any), ("domain", domain as Any), ("app", app as Any)])
                case .messageActionChannelCreate(let title):
                return ("messageActionChannelCreate", [("title", title as Any)])
                case .messageActionChannelMigrateFrom(let title, let chatId):
                return ("messageActionChannelMigrateFrom", [("title", title as Any), ("chatId", chatId as Any)])
                case .messageActionChatAddUser(let users):
                return ("messageActionChatAddUser", [("users", users as Any)])
                case .messageActionChatCreate(let title, let users):
                return ("messageActionChatCreate", [("title", title as Any), ("users", users as Any)])
                case .messageActionChatDeletePhoto:
                return ("messageActionChatDeletePhoto", [])
                case .messageActionChatDeleteUser(let userId):
                return ("messageActionChatDeleteUser", [("userId", userId as Any)])
                case .messageActionChatEditPhoto(let photo):
                return ("messageActionChatEditPhoto", [("photo", photo as Any)])
                case .messageActionChatEditTitle(let title):
                return ("messageActionChatEditTitle", [("title", title as Any)])
                case .messageActionChatJoinedByLink(let inviterId):
                return ("messageActionChatJoinedByLink", [("inviterId", inviterId as Any)])
                case .messageActionChatJoinedByRequest:
                return ("messageActionChatJoinedByRequest", [])
                case .messageActionChatMigrateTo(let channelId):
                return ("messageActionChatMigrateTo", [("channelId", channelId as Any)])
                case .messageActionContactSignUp:
                return ("messageActionContactSignUp", [])
                case .messageActionCustomAction(let message):
                return ("messageActionCustomAction", [("message", message as Any)])
                case .messageActionEmpty:
                return ("messageActionEmpty", [])
                case .messageActionGameScore(let gameId, let score):
                return ("messageActionGameScore", [("gameId", gameId as Any), ("score", score as Any)])
                case .messageActionGeoProximityReached(let fromId, let toId, let distance):
                return ("messageActionGeoProximityReached", [("fromId", fromId as Any), ("toId", toId as Any), ("distance", distance as Any)])
                case .messageActionGiftPremium(let flags, let currency, let amount, let months, let cryptoCurrency, let cryptoAmount):
                return ("messageActionGiftPremium", [("flags", flags as Any), ("currency", currency as Any), ("amount", amount as Any), ("months", months as Any), ("cryptoCurrency", cryptoCurrency as Any), ("cryptoAmount", cryptoAmount as Any)])
                case .messageActionGroupCall(let flags, let call, let duration):
                return ("messageActionGroupCall", [("flags", flags as Any), ("call", call as Any), ("duration", duration as Any)])
                case .messageActionGroupCallScheduled(let call, let scheduleDate):
                return ("messageActionGroupCallScheduled", [("call", call as Any), ("scheduleDate", scheduleDate as Any)])
                case .messageActionHistoryClear:
                return ("messageActionHistoryClear", [])
                case .messageActionInviteToGroupCall(let call, let users):
                return ("messageActionInviteToGroupCall", [("call", call as Any), ("users", users as Any)])
                case .messageActionPaymentSent(let flags, let currency, let totalAmount, let invoiceSlug):
                return ("messageActionPaymentSent", [("flags", flags as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("invoiceSlug", invoiceSlug as Any)])
                case .messageActionPaymentSentMe(let flags, let currency, let totalAmount, let payload, let info, let shippingOptionId, let charge):
                return ("messageActionPaymentSentMe", [("flags", flags as Any), ("currency", currency as Any), ("totalAmount", totalAmount as Any), ("payload", payload as Any), ("info", info as Any), ("shippingOptionId", shippingOptionId as Any), ("charge", charge as Any)])
                case .messageActionPhoneCall(let flags, let callId, let reason, let duration):
                return ("messageActionPhoneCall", [("flags", flags as Any), ("callId", callId as Any), ("reason", reason as Any), ("duration", duration as Any)])
                case .messageActionPinMessage:
                return ("messageActionPinMessage", [])
                case .messageActionRequestedPeer(let buttonId, let peer):
                return ("messageActionRequestedPeer", [("buttonId", buttonId as Any), ("peer", peer as Any)])
                case .messageActionScreenshotTaken:
                return ("messageActionScreenshotTaken", [])
                case .messageActionSecureValuesSent(let types):
                return ("messageActionSecureValuesSent", [("types", types as Any)])
                case .messageActionSecureValuesSentMe(let values, let credentials):
                return ("messageActionSecureValuesSentMe", [("values", values as Any), ("credentials", credentials as Any)])
                case .messageActionSetChatTheme(let emoticon):
                return ("messageActionSetChatTheme", [("emoticon", emoticon as Any)])
                case .messageActionSetChatWallPaper(let wallpaper):
                return ("messageActionSetChatWallPaper", [("wallpaper", wallpaper as Any)])
                case .messageActionSetMessagesTTL(let flags, let period, let autoSettingFrom):
                return ("messageActionSetMessagesTTL", [("flags", flags as Any), ("period", period as Any), ("autoSettingFrom", autoSettingFrom as Any)])
                case .messageActionSetSameChatWallPaper(let wallpaper):
                return ("messageActionSetSameChatWallPaper", [("wallpaper", wallpaper as Any)])
                case .messageActionSuggestProfilePhoto(let photo):
                return ("messageActionSuggestProfilePhoto", [("photo", photo as Any)])
                case .messageActionTopicCreate(let flags, let title, let iconColor, let iconEmojiId):
                return ("messageActionTopicCreate", [("flags", flags as Any), ("title", title as Any), ("iconColor", iconColor as Any), ("iconEmojiId", iconEmojiId as Any)])
                case .messageActionTopicEdit(let flags, let title, let iconEmojiId, let closed, let hidden):
                return ("messageActionTopicEdit", [("flags", flags as Any), ("title", title as Any), ("iconEmojiId", iconEmojiId as Any), ("closed", closed as Any), ("hidden", hidden as Any)])
                case .messageActionWebViewDataSent(let text):
                return ("messageActionWebViewDataSent", [("text", text as Any)])
                case .messageActionWebViewDataSentMe(let text, let data):
                return ("messageActionWebViewDataSentMe", [("text", text as Any), ("data", data as Any)])
    }
    }
    
        public static func parse_messageActionBotAllowed(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Api.BotApp?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.BotApp
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 2) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionBotAllowed(flags: _1!, domain: _2, app: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChannelCreate(title: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChannelMigrateFrom(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: Int64?
            _2 = reader.readInt64()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChannelMigrateFrom(title: _1!, chatId: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatAddUser(_ reader: BufferReader) -> MessageAction? {
            var _1: [Int64]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatAddUser(users: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionChatCreate(title: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatDeletePhoto(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatDeletePhoto
        }
        public static func parse_messageActionChatDeleteUser(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatDeleteUser(userId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditPhoto(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditPhoto(photo: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatEditTitle(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatEditTitle(title: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByLink(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatJoinedByLink(inviterId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionChatJoinedByRequest(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionChatJoinedByRequest
        }
        public static func parse_messageActionChatMigrateTo(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionChatMigrateTo(channelId: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionContactSignUp(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionContactSignUp
        }
        public static func parse_messageActionCustomAction(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionCustomAction(message: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionEmpty(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionEmpty
        }
        public static func parse_messageActionGameScore(_ reader: BufferReader) -> MessageAction? {
            var _1: Int64?
            _1 = reader.readInt64()
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGameScore(gameId: _1!, score: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGeoProximityReached(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Peer?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Peer
            }
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
                return Api.MessageAction.messageActionGeoProximityReached(fromId: _1!, toId: _2!, distance: _3!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGiftPremium(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: Int32?
            _4 = reader.readInt32()
            var _5: String?
            if Int(_1!) & Int(1 << 0) != 0 {_5 = parseString(reader) }
            var _6: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_6 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 0) == 0) || _6 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 {
                return Api.MessageAction.messageActionGiftPremium(flags: _1!, currency: _2!, amount: _3!, months: _4!, cryptoCurrency: _5, cryptoAmount: _6)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _3: Int32?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionGroupCall(flags: _1!, call: _2!, duration: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionGroupCallScheduled(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: Int32?
            _2 = reader.readInt32()
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionGroupCallScheduled(call: _1!, scheduleDate: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionHistoryClear(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionHistoryClear
        }
        public static func parse_messageActionInviteToGroupCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.InputGroupCall?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.InputGroupCall
            }
            var _2: [Int64]?
            if let _ = reader.readInt32() {
                _2 = Api.parseVector(reader, elementSignature: 570911930, elementType: Int64.self)
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionInviteToGroupCall(call: _1!, users: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSent(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int64?
            _3 = reader.readInt64()
            var _4: String?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = parseString(reader) }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionPaymentSent(flags: _1!, currency: _2!, totalAmount: _3!, invoiceSlug: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPaymentSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
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
            var _7: Api.PaymentCharge?
            if let signature = reader.readInt32() {
                _7 = Api.parse(reader, signature: signature) as? Api.PaymentCharge
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 0) == 0) || _5 != nil
            let _c6 = (Int(_1!) & Int(1 << 1) == 0) || _6 != nil
            let _c7 = _7 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 && _c6 && _c7 {
                return Api.MessageAction.messageActionPaymentSentMe(flags: _1!, currency: _2!, totalAmount: _3!, payload: _4!, info: _5, shippingOptionId: _6, charge: _7!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPhoneCall(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int64?
            _2 = reader.readInt64()
            var _3: Api.PhoneCallDiscardReason?
            if Int(_1!) & Int(1 << 0) != 0 {if let signature = reader.readInt32() {
                _3 = Api.parse(reader, signature: signature) as? Api.PhoneCallDiscardReason
            } }
            var _4: Int32?
            if Int(_1!) & Int(1 << 1) != 0 {_4 = reader.readInt32() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 1) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionPhoneCall(flags: _1!, callId: _2!, reason: _3, duration: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionPinMessage(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionPinMessage
        }
        public static func parse_messageActionRequestedPeer(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Api.Peer?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.Peer
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionRequestedPeer(buttonId: _1!, peer: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionScreenshotTaken(_ reader: BufferReader) -> MessageAction? {
            return Api.MessageAction.messageActionScreenshotTaken
        }
        public static func parse_messageActionSecureValuesSent(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValueType]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValueType.self)
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSecureValuesSent(types: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSecureValuesSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: [Api.SecureValue]?
            if let _ = reader.readInt32() {
                _1 = Api.parseVector(reader, elementSignature: 0, elementType: Api.SecureValue.self)
            }
            var _2: Api.SecureCredentialsEncrypted?
            if let signature = reader.readInt32() {
                _2 = Api.parse(reader, signature: signature) as? Api.SecureCredentialsEncrypted
            }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionSecureValuesSentMe(values: _1!, credentials: _2!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetChatTheme(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetChatTheme(emoticon: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetChatWallPaper(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.WallPaper?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetChatWallPaper(wallpaper: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetMessagesTTL(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: Int32?
            _2 = reader.readInt32()
            var _3: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_3 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 0) == 0) || _3 != nil
            if _c1 && _c2 && _c3 {
                return Api.MessageAction.messageActionSetMessagesTTL(flags: _1!, period: _2!, autoSettingFrom: _3)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSetSameChatWallPaper(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.WallPaper?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.WallPaper
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSetSameChatWallPaper(wallpaper: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionSuggestProfilePhoto(_ reader: BufferReader) -> MessageAction? {
            var _1: Api.Photo?
            if let signature = reader.readInt32() {
                _1 = Api.parse(reader, signature: signature) as? Api.Photo
            }
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionSuggestProfilePhoto(photo: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTopicCreate(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            _2 = parseString(reader)
            var _3: Int32?
            _3 = reader.readInt32()
            var _4: Int64?
            if Int(_1!) & Int(1 << 0) != 0 {_4 = reader.readInt64() }
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            let _c3 = _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 0) == 0) || _4 != nil
            if _c1 && _c2 && _c3 && _c4 {
                return Api.MessageAction.messageActionTopicCreate(flags: _1!, title: _2!, iconColor: _3!, iconEmojiId: _4)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionTopicEdit(_ reader: BufferReader) -> MessageAction? {
            var _1: Int32?
            _1 = reader.readInt32()
            var _2: String?
            if Int(_1!) & Int(1 << 0) != 0 {_2 = parseString(reader) }
            var _3: Int64?
            if Int(_1!) & Int(1 << 1) != 0 {_3 = reader.readInt64() }
            var _4: Api.Bool?
            if Int(_1!) & Int(1 << 2) != 0 {if let signature = reader.readInt32() {
                _4 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            var _5: Api.Bool?
            if Int(_1!) & Int(1 << 3) != 0 {if let signature = reader.readInt32() {
                _5 = Api.parse(reader, signature: signature) as? Api.Bool
            } }
            let _c1 = _1 != nil
            let _c2 = (Int(_1!) & Int(1 << 0) == 0) || _2 != nil
            let _c3 = (Int(_1!) & Int(1 << 1) == 0) || _3 != nil
            let _c4 = (Int(_1!) & Int(1 << 2) == 0) || _4 != nil
            let _c5 = (Int(_1!) & Int(1 << 3) == 0) || _5 != nil
            if _c1 && _c2 && _c3 && _c4 && _c5 {
                return Api.MessageAction.messageActionTopicEdit(flags: _1!, title: _2, iconEmojiId: _3, closed: _4, hidden: _5)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSent(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            let _c1 = _1 != nil
            if _c1 {
                return Api.MessageAction.messageActionWebViewDataSent(text: _1!)
            }
            else {
                return nil
            }
        }
        public static func parse_messageActionWebViewDataSentMe(_ reader: BufferReader) -> MessageAction? {
            var _1: String?
            _1 = parseString(reader)
            var _2: String?
            _2 = parseString(reader)
            let _c1 = _1 != nil
            let _c2 = _2 != nil
            if _c1 && _c2 {
                return Api.MessageAction.messageActionWebViewDataSentMe(text: _1!, data: _2!)
            }
            else {
                return nil
            }
        }
    
    }
}
