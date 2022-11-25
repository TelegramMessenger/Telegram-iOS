import Foundation
import Postbox
import TelegramApi


public func tagsForStoreMessage(incoming: Bool, attributes: [MessageAttribute], media: [Media], textEntities: [MessageTextEntity]?, isPinned: Bool) -> (MessageTags, GlobalMessageTags) {
    var isSecret = false
    var isUnconsumedPersonalMention = false
    var hasUnseenReactions = false
    for attribute in attributes {
        if let timerAttribute = attribute as? AutoclearTimeoutMessageAttribute {
            if timerAttribute.timeout > 0 && timerAttribute.timeout <= 60 {
                isSecret = true
            }
        } else if let timerAttribute = attribute as? AutoremoveTimeoutMessageAttribute {
            if timerAttribute.timeout > 0 && timerAttribute.timeout <= 60 {
                isSecret = true
            }
        } else if let mentionAttribute = attribute as? ConsumablePersonalMentionMessageAttribute {
            if !mentionAttribute.consumed {
                isUnconsumedPersonalMention = true
            }
        } else if let attribute = attribute as? ReactionsMessageAttribute, attribute.hasUnseen {
            hasUnseenReactions = true
        }
    }
    
    var tags = MessageTags()
    var globalTags = GlobalMessageTags()
    
    if isUnconsumedPersonalMention {
        tags.insert(.unseenPersonalMessage)
    }
    if hasUnseenReactions {
        tags.insert(.unseenReaction)
    }
    
    if isPinned {
        tags.insert(.pinned)
    }
    
    for attachment in media {
        if let _ = attachment as? TelegramMediaImage {
            if !isSecret {
                tags.insert(.photoOrVideo)
                tags.insert(.photo)
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
                                refinedTag = [.photoOrVideo, .video]
                            } else {
                                refinedTag = nil
                            }
                        }
                    case let .Audio(isVoice, _, _, _, _):
                        if isVoice {
                            refinedTag = .voiceOrInstantVideo
                        } else {
                            if file.isInstantVideo {
                                refinedTag = .voiceOrInstantVideo
                            } else {
                                refinedTag = .music
                            }
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
                refinedTag = .gif
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
                case let .phoneCall(_, discardReason, _, _):
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
        case let .message(_, _, _, messagePeerId, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            let chatPeerId = messagePeerId
            return chatPeerId.peerId
        case let .messageEmpty(_, _, peerId):
            if let peerId = peerId {
                return peerId.peerId
            } else {
                return nil
            }
        case let .messageService(_, _, _, chatPeerId, _, _, _, _):
            return chatPeerId.peerId
    }
}

func apiMessagePeerIds(_ message: Api.Message) -> [PeerId] {
    switch message {
        case let .message(_, _, fromId, chatPeerId, fwdHeader, viaBotId, _, _, _, media, _, entities, _, _, _, _, _, _, _, _, _):
            let peerId: PeerId = chatPeerId.peerId
            
            var result = [peerId]
            
            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
        
            if let fwdHeader = fwdHeader {
                switch fwdHeader {
                    case let .messageFwdHeader(_, fromId, _, _, _, _, savedFromPeer, _, _):
                        if let fromId = fromId {
                            result.append(fromId.peerId)
                        }
                        if let savedFromPeer = savedFromPeer {
                            result.append(savedFromPeer.peerId)
                        }
                }
            }
            
            if let viaBotId = viaBotId {
                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(viaBotId)))
            }
            
            if let media = media {
                switch media {
                    case let .messageMediaContact(_, _, _, _, userId):
                        if userId != 0 {
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                        }
                    default:
                        break
                }
            }
            
            if let entities = entities {
                for entity in entities {
                    switch entity {
                        case let .messageEntityMentionName(_, _, userId):
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                        default:
                            break
                    }
                }
            }
            
            return result
        case .messageEmpty:
            return []
        case let .messageService(_, _, fromId, chatPeerId, _, _, action, _):
            let peerId: PeerId = chatPeerId.peerId
            var result = [peerId]
            
            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
            
            switch action {
            case .messageActionChannelCreate, .messageActionChatDeletePhoto, .messageActionChatEditPhoto, .messageActionChatEditTitle, .messageActionEmpty, .messageActionPinMessage, .messageActionHistoryClear, .messageActionGameScore, .messageActionPaymentSent, .messageActionPaymentSentMe, .messageActionPhoneCall, .messageActionScreenshotTaken, .messageActionCustomAction, .messageActionBotAllowed, .messageActionSecureValuesSent, .messageActionSecureValuesSentMe, .messageActionContactSignUp, .messageActionGroupCall, .messageActionSetMessagesTTL, .messageActionGroupCallScheduled, .messageActionSetChatTheme, .messageActionChatJoinedByRequest, .messageActionWebViewDataSent, .messageActionWebViewDataSentMe, .messageActionGiftPremium, .messageActionTopicCreate, .messageActionTopicEdit:
                    break
                case let .messageActionChannelMigrateFrom(_, chatId):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)))
                case let .messageActionChatAddUser(users):
                    for id in users {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
                case let .messageActionChatCreate(_, users):
                    for id in users {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
                case let .messageActionChatDeleteUser(userId):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                case let .messageActionChatJoinedByLink(inviterId):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId)))
                case let .messageActionChatMigrateTo(channelId):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
                case let .messageActionGeoProximityReached(fromId, toId, _):
                    result.append(fromId.peerId)
                    result.append(toId.peerId)
                case let .messageActionInviteToGroupCall(_, userIds):
                    for id in userIds {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
            }
        
            return result
    }
}

func apiMessageAssociatedMessageIds(_ message: Api.Message) -> [MessageId]? {
    switch message {
        case let .message(_, _, _, chatPeerId, _, _, replyTo, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            if let replyTo = replyTo {
                let peerId: PeerId = chatPeerId.peerId
                
                switch replyTo {
                case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, _):
                    return [MessageId(peerId: replyToPeerId?.peerId ?? peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)]
                }
            }
        case .messageEmpty:
            break
        case let .messageService(_, _, _, chatPeerId, replyHeader, _, _, _):
            if let replyHeader = replyHeader {
                switch replyHeader {
                case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, _):
                    return [MessageId(peerId: replyToPeerId?.peerId ?? chatPeerId.peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)]
                }
            }
    }
    return nil
}

func textMediaAndExpirationTimerFromApiMedia(_ media: Api.MessageMedia?, _ peerId: PeerId) -> (Media?, Int32?, Bool?) {
    if let media = media {
        switch media {
        case let .messageMediaPhoto(_, photo, ttlSeconds):
            if let photo = photo {
                if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                    return (mediaImage, ttlSeconds, nil)
                }
            } else {
                return (TelegramMediaExpiredContent(data: .image), nil, nil)
            }
        case let .messageMediaContact(phoneNumber, firstName, lastName, vcard, userId):
            let contactPeerId: PeerId? = userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            let mediaContact = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: contactPeerId, vCardData: vcard.isEmpty ? nil : vcard)
            return (mediaContact, nil, nil)
        case let .messageMediaGeo(geo):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil)
        case let .messageMediaVenue(geo, title, address, provider, venueId, venueType):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil)
        case let .messageMediaGeoLive(_, geo, heading, period, proximityNotificationRadius):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: period, liveProximityNotificationRadius: proximityNotificationRadius, heading: heading)
            return (mediaMap, nil, nil)
        case let .messageMediaDocument(flags, document, ttlSeconds):
            if let document = document {
                if let mediaFile = telegramMediaFileFromApiDocument(document) {
                    return (mediaFile, ttlSeconds, (flags & (1 << 3)) != 0)
                }
            } else {
                return (TelegramMediaExpiredContent(data: .file), nil, nil)
            }
        case let .messageMediaWebPage(webpage):
            if let mediaWebpage = telegramMediaWebpageFromApiWebpage(webpage, url: nil) {
                return (mediaWebpage, nil, nil)
            }
        case .messageMediaUnsupported:
            return (TelegramMediaUnsupported(), nil, nil)
        case .messageMediaEmpty:
            break
        case let .messageMediaGame(game):
            return (TelegramMediaGame(apiGame: game), nil, nil)
        case let .messageMediaInvoice(flags, title, description, photo, receiptMsgId, currency, totalAmount, startParam, apiExtendedMedia):
            var parsedFlags = TelegramMediaInvoiceFlags()
            if (flags & (1 << 3)) != 0 {
                parsedFlags.insert(.isTest)
            }
            if (flags & (1 << 1)) != 0 {
                parsedFlags.insert(.shippingAddressRequested)
            }
            
            let extendedMedia: TelegramExtendedMedia?
            if let apiExtendedMedia = apiExtendedMedia {
                switch apiExtendedMedia {
                    case let .messageExtendedMediaPreview(_, width, height, thumb, videoDuration):
                        var dimensions: PixelDimensions?
                        if let width = width, let height = height {
                            dimensions = PixelDimensions(width: width, height: height)
                        }
                        var immediateThumbnailData: Data?
                        if let thumb = thumb, case let .photoStrippedSize(_, bytes) = thumb {
                            immediateThumbnailData = bytes.makeData()
                        }
                        extendedMedia = .preview(dimensions: dimensions, immediateThumbnailData: immediateThumbnailData, videoDuration: videoDuration)
                    case let .messageExtendedMedia(apiMedia):
                        let (media, _, _) = textMediaAndExpirationTimerFromApiMedia(apiMedia, peerId)
                        if let media = media {
                            extendedMedia = .full(media: media)
                        } else {
                            extendedMedia = nil
                        }
                }
            } else {
                extendedMedia = nil
            }
            
            return (TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: receiptMsgId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }, currency: currency, totalAmount: totalAmount, startParam: startParam, extendedMedia: extendedMedia, flags: parsedFlags, version: TelegramMediaInvoice.lastVersion), nil, nil)
        case let .messageMediaPoll(poll, results):
            switch poll {
            case let .poll(id, flags, question, answers, closePeriod, _):
                let publicity: TelegramMediaPollPublicity
                if (flags & (1 << 1)) != 0 {
                    publicity = .public
                } else {
                    publicity = .anonymous
                }
                let kind: TelegramMediaPollKind
                if (flags & (1 << 3)) != 0 {
                    kind = .quiz
                } else {
                    kind = .poll(multipleAnswers: (flags & (1 << 2)) != 0)
                }
                return (TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), publicity: publicity, kind: kind, text: question, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod), nil, nil)
            }
        case let .messageMediaDice(value, emoticon):
            return (TelegramMediaDice(emoji: emoticon, value: value), nil, nil)
        }
    }
    
    return (nil, nil, nil)
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
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextMention(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))))
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
        case let .messageEntityBankCard(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BankCard))
        case let .messageEntitySpoiler(offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Spoiler))
        case let .messageEntityCustomEmoji(offset, length, documentId):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .CustomEmoji(stickerPack: nil, fileId: documentId)))
        }
    }
    return result
}

extension StoreMessage {
    convenience init?(apiMessage: Api.Message, namespace: MessageId.Namespace = Namespaces.Message.Cloud) {
        switch apiMessage {
            case let .message(flags, id, fromId, chatPeerId, fwdFrom, viaBotId, replyTo, date, message, media, replyMarkup, entities, views, forwards, replies, editDate, postAuthor, groupingId, reactions, restrictionReason, ttlPeriod):
                let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
                
                let peerId: PeerId
                var authorId: PeerId?
                switch chatPeerId {
                    case .peerUser:
                        peerId = chatPeerId.peerId
                        authorId = resolvedFromId
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        authorId = resolvedFromId
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        authorId = resolvedFromId
                }
                
                var attributes: [MessageAttribute] = []
                
                var threadId: Int64?
                if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, replyToTopId):
                        let replyPeerId = replyToPeerId?.peerId ?? peerId
                        if let replyToTopId = replyToTopId {
                            let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                            threadMessageId = threadIdValue
                            if replyPeerId == peerId {
                                threadId = makeMessageThreadId(threadIdValue)
                            }
                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                            threadMessageId = threadIdValue
                            threadId = makeMessageThreadId(threadIdValue)
                        }
                        attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId))
                    }
                }
                
                var forwardInfo: StoreMessageForwardInfo?
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(flags, fromId, fromName, date, channelPost, postAuthor, savedFromPeer, savedFromMsgId, psaType):
                            var forwardInfoFlags: MessageForwardInfo.Flags = []
                            let isImported = (flags & (1 << 7)) != 0
                            if isImported {
                                forwardInfoFlags.insert(.isImported)
                            }
                            
                            var authorId: PeerId?
                            var sourceId: PeerId?
                            var sourceMessageId: MessageId?
                            
                            if let fromId = fromId {
                                switch fromId {
                                case .peerChannel:
                                    let peerId = fromId.peerId
                                    sourceId = peerId
                                    
                                    if let channelPost = channelPost {
                                        sourceMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: channelPost)
                                    }
                                default:
                                    authorId = fromId.peerId
                                }
                            }
                            
                            if let savedFromPeer = savedFromPeer, let savedFromMsgId = savedFromMsgId {
                                let peerId: PeerId = savedFromPeer.peerId
                                let messageId: MessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: savedFromMsgId)
                                attributes.append(SourceReferenceMessageAttribute(messageId: messageId))
                            }
                        
                            if let authorId = authorId {
                                forwardInfo = StoreMessageForwardInfo(authorId: authorId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor, psaType: psaType, flags: forwardInfoFlags)
                            } else if let sourceId = sourceId {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor, psaType: psaType, flags: forwardInfoFlags)
                            } else if let postAuthor = postAuthor ?? fromName {
                                forwardInfo = StoreMessageForwardInfo(authorId: nil, sourceId: nil, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor, psaType: psaType, flags: forwardInfoFlags)
                            }
                    }
                }
                
                let messageText = message
                var medias: [Media] = []
                
                var consumableContent: (Bool, Bool)? = nil
                
                if let media = media {
                    let (mediaValue, expirationTimer, nonPremium) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                    if let mediaValue = mediaValue {
                        medias.append(mediaValue)
                    
                        if let expirationTimer = expirationTimer, expirationTimer > 0 {
                            attributes.append(AutoclearTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                            
                            consumableContent = (true, false)
                        }
                        
                        if let nonPremium = nonPremium, nonPremium {
                            attributes.append(NonPremiumMessageAttribute())
                        }
                    }
                }
                
                if let ttlPeriod = ttlPeriod {
                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttlPeriod, countdownBeginTime: date))
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
                    attributes.append(InlineBotMessageAttribute(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(viaBotId)), title: nil))
                }
                
                if namespace != Namespaces.Message.ScheduledCloud {
                    if let views = views {
                        attributes.append(ViewCountMessageAttribute(count: Int(views)))
                    }
                    
                    if let forwards = forwards {
                        attributes.append(ForwardCountMessageAttribute(count: Int(forwards)))
                    }
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
            
                if let reactions = reactions {
                    attributes.append(ReactionsMessageAttribute(apiReactions: reactions))
                }
                
                if let replies = replies {
                    let recentRepliersPeerIds: [PeerId]?
                    switch replies {
                    case let .messageReplies(_, repliesCount, _, recentRepliers, channelId, maxId, readMaxId):
                        if let recentRepliers = recentRepliers {
                            recentRepliersPeerIds = recentRepliers.map { $0.peerId }
                        } else {
                            recentRepliersPeerIds = nil
                        }
                        
                        let commentsPeerId = channelId.flatMap { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }
                        
                        attributes.append(ReplyThreadMessageAttribute(count: repliesCount, latestUsers: recentRepliersPeerIds ?? [], commentsPeerId: commentsPeerId, maxMessageId: maxId, maxReadMessageId: readMaxId))
                    }
                }
                
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
            
                if (flags & (1 << 26)) != 0 {
                    storeFlags.insert(.CopyProtected)
                }
            
                if (flags & (1 << 27)) != 0 {
                    storeFlags.insert(.IsForumTopic)
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
                
                let isPinned = (flags & (1 << 24)) != 0
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: storeFlags.contains(.Incoming), attributes: attributes, media: medias, textEntities: entitiesAttribute?.entities, isPinned: isPinned)
                
                storeFlags.insert(.CanBeGroupedIntoFeed)
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: groupingId, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: medias)
            case .messageEmpty:
                return nil
            case let .messageService(flags, id, fromId, chatPeerId, replyTo, date, action, ttlPeriod):
                let peerId: PeerId = chatPeerId.peerId
                let authorId: PeerId? = fromId?.peerId ?? chatPeerId.peerId
                
                var attributes: [MessageAttribute] = []
                
                var threadId: Int64?
                if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, replyToTopId):
                        let replyPeerId = replyToPeerId?.peerId ?? peerId
                        if let replyToTopId = replyToTopId {
                            let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                            threadMessageId = threadIdValue
                            if replyPeerId == peerId {
                                threadId = makeMessageThreadId(threadIdValue)
                            }
                        } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                            threadMessageId = threadIdValue
                            threadId = makeMessageThreadId(threadIdValue)
                        }
                        switch action {
                        case .messageActionTopicEdit:
                            threadId = Int64(replyToMsgId)
                        default:
                            break
                        }
                        attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId))
                    }
                } else {
                    switch action {
                    case .messageActionTopicCreate:
                        threadId = Int64(id)
                    default:
                        break
                    }
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
                
                var media: [Media] = []
                if let action = telegramMediaActionFromApiAction(action) {
                    media.append(action)
                }
                
                if let ttlPeriod = ttlPeriod {
                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttlPeriod, countdownBeginTime: date))
                }
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: storeFlags.contains(.Incoming), attributes: attributes, media: media, textEntities: nil, isPinned: false)
                
                storeFlags.insert(.CanBeGroupedIntoFeed)
                
                if (flags & (1 << 18)) != 0 {
                    storeFlags.insert(.WasScheduled)
                }
            
                if (flags & (1 << 26)) != 0 {
                    storeFlags.insert(.CopyProtected)
                }
            
                if (flags & (1 << 27)) != 0 {
                    storeFlags.insert(.IsForumTopic)
                }
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: attributes, media: media)
            }
    }
}
