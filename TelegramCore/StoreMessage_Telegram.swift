import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public func tagsForStoreMessage(media: [Media], textEntities: [MessageTextEntity]?) -> MessageTags {
    var tags = MessageTags()
    for attachment in media {
        if let _ = attachment as? TelegramMediaImage {
            tags.insert(.PhotoOrVideo)
        } else if let file = attachment as? TelegramMediaFile {
            var refinedTag: MessageTags?
            inner: for attribute in file.attributes {
                switch attribute {
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            refinedTag = .VoiceOrInstantVideo
                        } else {
                            refinedTag = .PhotoOrVideo
                        }
                        break inner
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            refinedTag = .VoiceOrInstantVideo
                        } else {
                            refinedTag = .Music
                        }
                        break inner
                    default:
                        break
                }
            }
            if let refinedTag = refinedTag {
                tags.insert(refinedTag)
            } else {
                tags.insert(.File)
            }
        } else if let webpage = attachment as? TelegramMediaWebpage, case .Loaded = webpage.content {
            tags.insert(.WebPage)
        }
    }
    if let textEntities = textEntities, !textEntities.isEmpty && !tags.contains(.WebPage) {
        for entity in textEntities {
            switch entity.type {
                case .Url, .Email:
                    tags.insert(.WebPage)
                default:
                    break
            }
        }
    }
    return tags
}

extension Api.Message {
    var peerId: PeerId? {
        switch self {
            case let .message(flags, _, fromId, toId, _, _, _, _, _, _, _, _, _, _):
                switch toId {
                    case let .peerUser(userId):
                        return PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                    case let .peerChat(chatId):
                        return PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .peerChannel(channelId):
                        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                }
            case .messageEmpty:
                return nil
            case let .messageService(flags, _, fromId, toId, _, _, _):
                switch toId {
                    case let .peerUser(userId):
                        return PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                    case let .peerChat(chatId):
                        return PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .peerChannel(channelId):
                        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                }
        }
    }
    
    var peerIds: [PeerId] {
        switch self {
            case let .message(flags, _, fromId, toId, fwdFrom, viaBotId, _, _, _, media, _, entities, _, _):
                let peerId: PeerId
                switch toId {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                }
                
                var result = [peerId]
                
                if let fromId = fromId, PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId) != peerId {
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId))
                }
            
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(_, fromId, _, channelId, _):
                            if let channelId = channelId {
                                result.append(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
                            }
                            if let fromId = fromId {
                                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId))
                            }
                    }
                }
                
                if let viaBotId = viaBotId {
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: viaBotId))
                }
                
                if let media = media {
                    switch media {
                        case let .messageMediaContact(_, _, _, userId):
                            if userId != 0 {
                                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))
                            }
                        default:
                            break
                    }
                }
                
                if let entities = entities {
                    for entity in entities {
                        switch entity {
                            case let .messageEntityMentionName(_, _, userId):
                                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))
                            default:
                                break
                        }
                    }
                }
                
                return result
            case .messageEmpty:
                return []
            case let .messageService(flags, _, fromId, toId, _, _, action):
                let peerId: PeerId
                switch toId {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                }
                var result = [peerId]
                
                if let fromId = fromId, PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId) != peerId {
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId))
                }
                
                switch action {
                    case .messageActionChannelCreate, .messageActionChatDeletePhoto, .messageActionChatEditPhoto, .messageActionChatEditTitle, .messageActionEmpty, .messageActionPinMessage, .messageActionHistoryClear, .messageActionHistoryClear, .messageActionGameScore:
                        break
                    case let .messageActionChannelMigrateFrom(_, chatId):
                        result.append(PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId))
                    case let .messageActionChatAddUser(users):
                        for id in users {
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: id))
                        }
                    case let .messageActionChatCreate(_, users):
                        for id in users {
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: id))
                        }
                    case let .messageActionChatDeleteUser(userId):
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))
                    case let .messageActionChatJoinedByLink(inviterId):
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId))
                    case let .messageActionChatMigrateTo(channelId):
                        result.append(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
                    case let .messageActionPhoneCall(flags, callId, reason, duration):
                        break
                    case let .messageActionPaymentSent(currency, totalAmount):
                        break
                    case .messageActionPaymentSentMe:
                        break
                }
            
                return result
        }
    }
    
    var associatedMessageIds: [MessageId]? {
        switch self {
            case let .message(flags, _, fromId, toId, _, _, replyToMsgId, _, _, _, _, _, _, _):
                if let replyToMsgId = replyToMsgId {
                    let peerId: PeerId
                        switch toId {
                        case let .peerUser(userId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                        case let .peerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .peerChannel(channelId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                    }
                    
                    return [MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)]
                }
            case .messageEmpty:
                break
            case let .messageService(flags, _, fromId, toId, replyToMsgId, _, _):
                if let replyToMsgId = replyToMsgId {
                    let peerId: PeerId
                    switch toId {
                        case let .peerUser(userId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                        case let .peerChat(chatId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        case let .peerChannel(channelId):
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                    }
                    
                    return [MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)]
                }
        }
        return nil
    }
}

func textAndMediaFromApiMedia(_ media: Api.MessageMedia?) -> (String?, Media?) {
    if let media = media {
        switch media {
            case let .messageMediaPhoto(photo, caption):
                if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                    return (caption, mediaImage)
                }
                break
            case let .messageMediaContact(phoneNumber, firstName, lastName, userId):
                let contactPeerId: PeerId? = userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                let mediaContact = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: contactPeerId)
                return (nil, mediaContact)
            case let .messageMediaGeo(geo):
                let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil)
                return (nil, mediaMap)
            case let .messageMediaVenue(geo, title, address, provider, venueId):
                let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId)
                return (nil, mediaMap)
            case let .messageMediaDocument(document, caption):
                if let mediaFile = telegramMediaFileFromApiDocument(document) {
                    return (caption, mediaFile)
                }
            case let .messageMediaWebPage(webpage):
                if let mediaWebpage = telegramMediaWebpageFromApiWebpage(webpage) {
                    return (nil, mediaWebpage)
                }
            case .messageMediaUnsupported:
                return (nil, TelegramMediaUnsupported())
            case .messageMediaEmpty:
                break
            case let .messageMediaGame(game):
                return (nil, TelegramMediaGame(apiGame: game))
            case let .messageMediaInvoice(flags, title, description, photo, receiptMsgId, currency, totalAmount, startParam):
                break
        }
    }
    
    return (nil, nil)
}

func messageTextEntitiesFromApiEntities(_ entities: [Api.MessageEntity]) -> [MessageTextEntity] {
    var result: [MessageTextEntity] = []
    for entity in entities {
        switch entity {
            case .messageEntityUnknown, .inputMessageEntityMentionName:
                break
            case let .messageEntityMention(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Mention))
            case let .messageEntityHashtag(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
            case let .messageEntityBotCommand(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BotCommand))
            case let .messageEntityUrl(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Url))
            case let .messageEntityEmail(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Email))
            case let .messageEntityBold(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Bold))
            case let .messageEntityItalic(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Italic))
            case let .messageEntityCode(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Code))
            case let .messageEntityPre(offset, length, _):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre))
            case let .messageEntityTextUrl(offset, length, url):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextUrl(url: url)))
            case let .messageEntityMentionName(offset, length, userId):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextMention(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId))))
        }
    }
    return result
}

extension StoreMessage {
    convenience init?(apiMessage: Api.Message) {
        switch apiMessage {
            case let .message(flags, id, fromId, toId, fwdFrom, viaBotId, replyToMsgId, date, message, media, replyMarkup, entities, views, editDate):
                let peerId: PeerId
                var authorId: PeerId?
                switch toId {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                }
                
                var forwardInfo: StoreMessageForwardInfo?
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(_, fromId, date, channelId, channelPost):
                            var authorId: PeerId?
                            var sourceId: PeerId?
                            var sourceMessageId: MessageId?
                            
                            if let fromId = fromId {
                                authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                            }
                            if let channelId = channelId {
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                                sourceId = peerId
                                
                                if let channelPost = channelPost {
                                    sourceMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: channelPost)
                                }
                            }
                        
                            if let authorId = authorId {
                                forwardInfo = StoreMessageForwardInfo(authorId: authorId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date)
                            } else if let sourceId = sourceId {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceId, sourceId: nil, sourceMessageId: sourceMessageId, date: date)
                            }
                    }
                }
                
                var messageText = message
                var medias: [Media] = []
                var attributes: [MessageAttribute] = []
                
                if let media = media {
                    let (mediaText, mediaValue) = textAndMediaFromApiMedia(media)
                    if let mediaText = mediaText {
                        messageText = mediaText
                    }
                    if let mediaValue = mediaValue {
                        medias.append(mediaValue)
                    }
                }
                
                for case let file as TelegramMediaFile in medias {
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                        if file.isVoice {
                            attributes.append(ConsumableContentMessageAttribute(consumed: (flags & (1 << 5)) == 0))
                            break
                        }
                    }
                }
                
                if let viaBotId = viaBotId {
                    attributes.append(InlineBotMessageAttribute(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: viaBotId)))
                }
                
                if let replyToMsgId = replyToMsgId {
                    attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)))
                }
                
                if let views = views {
                    attributes.append(ViewCountMessageAttribute(count: Int(views)))
                }
                
                if let editDate = editDate {
                    attributes.append(EditedMessageAttribute(date: editDate))
                }
                
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if let entities = entities, !entities.isEmpty {
                    let attribute = TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities))
                    entitiesAttribute = attribute
                    attributes.append(attribute)
                }
                
                var storeFlags = StoreMessageFlags()
                
                if let replyMarkup = replyMarkup {
                    let parsedReplyMarkup = ReplyMarkupMessageAttribute(apiMarkup: replyMarkup)
                    attributes.append(parsedReplyMarkup)
                    if !parsedReplyMarkup.flags.contains(.inline) {
                        storeFlags.insert(.TopIndexable)
                    }
                }
                
                if (flags & (1 << 1)) == 0 {
                    storeFlags.insert(.Incoming)
                }
                if (flags & (1 << 4)) != 0 {
                    storeFlags.insert(.Personal)
                }
                
                self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), globallyUniqueId: nil, timestamp: date, flags: storeFlags, tags: tagsForStoreMessage(media: medias, textEntities: entitiesAttribute?.entities), forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: medias)
            case .messageEmpty:
                return nil
            case let .messageService(flags, id, fromId, toId, replyToMsgId, date, action):
                let peerId: PeerId
                var authorId: PeerId?
                switch toId {
                    case let .peerUser(userId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: (flags & Int32(2)) != 0 ? userId : (fromId ?? userId))
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                        if let fromId = fromId {
                            authorId = PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId)
                        } else {
                            authorId = peerId
                        }
                }
                
                var attributes: [MessageAttribute] = []
                if let replyToMsgId = replyToMsgId {
                    attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)))
                }
                
                var storeFlags = StoreMessageFlags()
                if (flags & 2) == 0 {
                    let _ = storeFlags.insert(.Incoming)
                }
                
                if (flags & (1 << 4)) != 0 {
                    let _ = storeFlags.insert(.Personal)
                }
                
                var media: [Media] = []
                if let action = telegramMediaActionFromApiAction(action) {
                    media.append(action)
                }
                
                self.init(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), globallyUniqueId: nil, timestamp: date, flags: storeFlags, tags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: attributes, media: media)
            }
    }
}
