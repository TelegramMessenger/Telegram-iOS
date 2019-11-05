import Foundation
import Postbox
import TelegramApi

import SyncCore

public func tagsForStoreMessage(incoming: Bool, attributes: [MessageAttribute], media: [Media], textEntities: [MessageTextEntity]?) -> (MessageTags, GlobalMessageTags) {
    var isSecret = false
    var isUnconsumedPersonalMention = false
    for attribute in attributes {
        if let timerAttribute = attribute as? AutoremoveTimeoutMessageAttribute {
            if timerAttribute.timeout > 0 && timerAttribute.timeout <= 60 {
                isSecret = true
            }
        } else if let mentionAttribute = attribute as? ConsumablePersonalMentionMessageAttribute {
            if !mentionAttribute.consumed {
                isUnconsumedPersonalMention = true
            }
        }
    }
    
    var tags = MessageTags()
    var globalTags = GlobalMessageTags()
    
    if isUnconsumedPersonalMention {
        tags.insert(.unseenPersonalMessage)
    }
    
    for attachment in media {
        if let _ = attachment as? TelegramMediaImage {
            if !isSecret {
                tags.insert(.photoOrVideo)
            }
        } else if let file = attachment as? TelegramMediaFile {
            var refinedTag: MessageTags? = .file
            var isAnimated = false
            inner: for attribute in file.attributes {
                switch attribute {
                    case let .Video(_, _, flags):
                        if flags.contains(.instantRoundVideo) {
                            refinedTag = .voiceOrInstantVideo
                        } else {
                            if !isSecret {
                                refinedTag = .photoOrVideo
                            } else {
                                refinedTag = nil
                            }
                        }
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            refinedTag = .voiceOrInstantVideo
                        } else {
                            refinedTag = .music
                        }
                        break inner
                    case .Sticker:
                        refinedTag = nil
                        break inner
                    case .Animated:
                        isAnimated = true
                    default:
                        break
                }
            }
            if isAnimated {
                refinedTag = nil
            }
            if file.isAnimatedSticker {
                refinedTag = nil
            }
            if let refinedTag = refinedTag {
                tags.insert(refinedTag)
            }
        } else if let webpage = attachment as? TelegramMediaWebpage, case .Loaded = webpage.content {
            tags.insert(.webPage)
        } else if let action = attachment as? TelegramMediaAction {
            switch action.action {
                case let .phoneCall(_, discardReason, _):
                    globalTags.insert(.Calls)
                    if incoming, let discardReason = discardReason, case .missed = discardReason {
                        globalTags.insert(.MissedCalls)
                    }
                default:
                    break
            }
        } else if let location = attachment as? TelegramMediaMap, location.liveBroadcastingTimeout != nil {
            tags.insert(.liveLocation)
        }
    }
    if let textEntities = textEntities, !textEntities.isEmpty && !tags.contains(.webPage) {
        for entity in textEntities {
            switch entity.type {
                case .Url, .Email:
                    if media.isEmpty || !(media.first is TelegramMediaWebpage) {
                        tags.insert(.webPage)
                    }
                default:
                    break
            }
        }
    }
    
    if !incoming {
        assert(true)
    }
    return (tags, globalTags)
}

func apiMessagePeerId(_ messsage: Api.Message) -> PeerId? {
    switch messsage {
        case let .message(message):
            let flags = message.flags
            let fromId = message.fromId
            let toId = message.toId
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

func apiMessagePeerIds(_ message: Api.Message) -> [PeerId] {
    switch message {
        case let .message(flags, _, fromId, toId, fwdHeader, viaBotId, _, _, _, media, _, entities, _, _, _, _, _):
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
        
            if let fwdHeader = fwdHeader {
                switch fwdHeader {
                    case let .messageFwdHeader(messageFwdHeader):
                        if let channelId = messageFwdHeader.channelId {
                            result.append(PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId))
                        }
                        if let fromId = messageFwdHeader.fromId {
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: fromId))
                        }
                        if let savedFromPeer = messageFwdHeader.savedFromPeer {
                            result.append(savedFromPeer.peerId)
                        }
                }
            }
            
            if let viaBotId = viaBotId {
                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: viaBotId))
            }
            
            if let media = media {
                switch media {
                    case let .messageMediaContact(_, _, _, _, userId):
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
                case .messageActionChannelCreate, .messageActionChatDeletePhoto, .messageActionChatEditPhoto, .messageActionChatEditTitle, .messageActionEmpty, .messageActionPinMessage, .messageActionHistoryClear, .messageActionGameScore, .messageActionPaymentSent, .messageActionPaymentSentMe, .messageActionPhoneCall, .messageActionScreenshotTaken, .messageActionCustomAction, .messageActionBotAllowed, .messageActionSecureValuesSent, .messageActionSecureValuesSentMe, .messageActionContactSignUp:
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
            }
        
            return result
    }
}

func apiMessageAssociatedMessageIds(_ message: Api.Message) -> [MessageId]? {
    switch message {
        case let .message(flags, _, fromId, toId, _, _, replyToMsgId, _, _, _, _, _, _, _, _, _, _):
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

func textMediaAndExpirationTimerFromApiMedia(_ media: Api.MessageMedia?, _ peerId:PeerId) -> (Media?, Int32?) {
    if let media = media {
        switch media {
            case let .messageMediaPhoto(_, photo, ttlSeconds):
                if let photo = photo {
                    if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                        return (mediaImage, ttlSeconds)
                    }
                } else {
                    return (TelegramMediaExpiredContent(data: .image), nil)
                }
            case let .messageMediaContact(phoneNumber, firstName, lastName, vcard, userId):
                let contactPeerId: PeerId? = userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                let mediaContact = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: contactPeerId, vCardData: vcard.isEmpty ? nil : vcard)
                return (mediaContact, nil)
            case let .messageMediaGeo(geo):
                let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: nil)
                return (mediaMap, nil)
            case let .messageMediaVenue(geo, title, address, provider, venueId, venueType):
                let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil)
                return (mediaMap, nil)
            case let .messageMediaGeoLive(geo, period):
                let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: period)
                return (mediaMap, nil)
            case let .messageMediaDocument(_, document, ttlSeconds):
                if let document = document {
                    if let mediaFile = telegramMediaFileFromApiDocument(document) {
                        return (mediaFile, ttlSeconds)
                    }
                } else {
                    return (TelegramMediaExpiredContent(data: .file), nil)
                }
            case let .messageMediaWebPage(webpage):
                if let mediaWebpage = telegramMediaWebpageFromApiWebpage(webpage, url: nil) {
                    return (mediaWebpage, nil)
                }
            case .messageMediaUnsupported:
                return (TelegramMediaUnsupported(), nil)
            case .messageMediaEmpty:
                break
            case let .messageMediaGame(game):
                return (TelegramMediaGame(apiGame: game), nil)
            case let .messageMediaInvoice(flags, title, description, photo, receiptMsgId, currency, totalAmount, startParam):
                var parsedFlags = TelegramMediaInvoiceFlags()
                if (flags & (1 << 3)) != 0 {
                    parsedFlags.insert(.isTest)
                }
                if (flags & (1 << 1)) != 0 {
                    parsedFlags.insert(.shippingAddressRequested)
                }
                return (TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: receiptMsgId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }, currency: currency, totalAmount: totalAmount, startParam: startParam, flags: parsedFlags), nil)
            case let .messageMediaPoll(poll, results):
                switch poll {
                    case let .poll(id, flags, question, answers):
                        return (TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), text: question, options: answers.map(TelegramMediaPollOption.init(apiOption:)), results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0), nil)
                }
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
            case let .messageEntityPhone(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .PhoneNumber))
            case let .messageEntityCashtag(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
            case let .messageEntityUnderline(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Underline))
            case let .messageEntityStrike(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Strikethrough))
            case let .messageEntityBlockquote(offset, length):
                result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BlockQuote))
        }
    }
    return result
}

extension StoreMessage {
    convenience init?(apiMessage: Api.Message, namespace: MessageId.Namespace = Namespaces.Message.Cloud) {
        switch apiMessage {
            case let .message(flags, id, fromId, toId, fwdFrom, viaBotId, replyToMsgId, date, message, media, replyMarkup, entities, views, editDate, postAuthor, groupingId, restrictionReason):
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
                
                var forwardInfo: StoreMessageForwardInfo?
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(_, fromId, fromName, date, channelId, channelPost, postAuthor, savedFromPeer, savedFromMsgId):
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
                            
                            if let savedFromPeer = savedFromPeer, let savedFromMsgId = savedFromMsgId {
                                let peerId: PeerId
                                switch savedFromPeer {
                                    case let .peerChannel(channelId):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
                                    case let .peerChat(chatId):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                                    case let .peerUser(userId):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                                }
                                let messageId: MessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: savedFromMsgId)
                                attributes.append(SourceReferenceMessageAttribute(messageId: messageId))
                            }
                        
                            if let authorId = authorId {
                                forwardInfo = StoreMessageForwardInfo(authorId: authorId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor)
                            } else if let sourceId = sourceId {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor)
                            } else if let postAuthor = postAuthor ?? fromName {
                                forwardInfo = StoreMessageForwardInfo(authorId: nil, sourceId: nil, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor)
                            }
                    }
                }
                
                let messageText = message
                var medias: [Media] = []
                
                var consumableContent: (Bool, Bool)? = nil
                
                if let media = media {
                    let (mediaValue, expirationTimer) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                    if let mediaValue = mediaValue {
                        medias.append(mediaValue)
                    
                        if let expirationTimer = expirationTimer, expirationTimer > 0 {
                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                            
                            consumableContent = (true, false)
                        }
                    }
                }
                
                if let postAuthor = postAuthor {
                    attributes.append(AuthorSignatureMessageAttribute(signature: postAuthor))
                }
                
                for case let file as TelegramMediaFile in medias {
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel {
                        if file.isVoice {
                            consumableContent = (true, (flags & (1 << 5)) == 0)
                            break
                        } else if file.isInstantVideo {
                            consumableContent = (true, (flags & (1 << 5)) == 0)
                            break
                        }
                    }
                }
                
                if let (value, consumed) = consumableContent, value {
                    attributes.append(ConsumableContentMessageAttribute(consumed: consumed))
                }
                
                if let viaBotId = viaBotId {
                    attributes.append(InlineBotMessageAttribute(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: viaBotId), title: nil))
                }
                
                if let replyToMsgId = replyToMsgId {
                    attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)))
                }
                
                if let views = views, namespace != Namespaces.Message.ScheduledCloud {
                    attributes.append(ViewCountMessageAttribute(count: Int(views)))
                }
                
                if let editDate = editDate {
                    attributes.append(EditedMessageAttribute(date: editDate, isHidden: (flags & (1 << 21)) != 0))
                }
                
                var entitiesAttribute: TextEntitiesMessageAttribute?
                if let entities = entities, !entities.isEmpty {
                    let attribute = TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities))
                    entitiesAttribute = attribute
                    attributes.append(attribute)
                } else {
                    var noEntities = false
                    loop: for media in medias {
                        switch media {
                            case _ as TelegramMediaContact,
                                 _ as TelegramMediaMap:
                                noEntities = true
                            break loop
                            default:
                                break
                        }
                    }
                    if !noEntities {
                        let attribute = TextEntitiesMessageAttribute(entities: [])
                        entitiesAttribute = attribute
                        attributes.append(attribute)
                    }
                }
                
                if (flags & (1 << 17)) != 0 {
                    attributes.append(ContentRequiresValidationMessageAttribute())
                }
                
                /*if let reactions = reactions {
                    attributes.append(ReactionsMessageAttribute(apiReactions: reactions))
                }*/
                
                if let restrictionReason = restrictionReason {
                    attributes.append(RestrictedContentMessageAttribute(rules: restrictionReason.map(RestrictionRule.init(apiReason:))))
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
                
                if (flags & (1 << 18)) != 0 {
                    storeFlags.insert(.WasScheduled)
                    storeFlags.insert(.CountedAsIncoming)
                }
                
                if (flags & (1 << 4)) != 0 || (flags & (1 << 13)) != 0 {
                    var notificationFlags: NotificationInfoMessageAttributeFlags = []
                    if (flags & (1 << 4)) != 0 {
                        notificationFlags.insert(.personal)
                        let notConsumed = (flags & (1 << 5)) != 0
                        attributes.append(ConsumablePersonalMentionMessageAttribute(consumed: !notConsumed, pending: false))
                    }
                    if (flags & (1 << 13)) != 0 {
                        notificationFlags.insert(.muted)
                    }
                    attributes.append(NotificationInfoMessageAttribute(flags: notificationFlags))
                }
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: storeFlags.contains(.Incoming), attributes: attributes, media: medias, textEntities: entitiesAttribute?.entities)
                
                storeFlags.insert(.CanBeGroupedIntoFeed)
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: groupingId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: medias)
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
                
                if (flags & (1 << 17)) != 0 {
                    attributes.append(ContentRequiresValidationMessageAttribute())
                }
                
                
                var storeFlags = StoreMessageFlags()
                if (flags & 2) == 0 {
                    let _ = storeFlags.insert(.Incoming)
                }
                
                if (flags & (1 << 4)) != 0 || (flags & (1 << 13)) != 0 {
                    var notificationFlags: NotificationInfoMessageAttributeFlags = []
                    if (flags & (1 << 4)) != 0 {
                        notificationFlags.insert(.personal)
                    }
                    if (flags & (1 << 13)) != 0 {
                        notificationFlags.insert(.muted)
                    }
                    attributes.append(NotificationInfoMessageAttribute(flags: notificationFlags))
                }
                
                var media: [Media] = []
                if let action = telegramMediaActionFromApiAction(action) {
                    media.append(action)
                }
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: storeFlags.contains(.Incoming), attributes: attributes, media: media, textEntities: nil)
                
                storeFlags.insert(.CanBeGroupedIntoFeed)
                
                if (flags & (1 << 18)) != 0 {
                    storeFlags.insert(.WasScheduled)
                }
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: nil, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: attributes, media: media)
            }
    }
}
