import Foundation
import Postbox
import TelegramApi


public func tagsForStoreMessage(incoming: Bool, attributes: [MessageAttribute], media: [Media], textEntities: [MessageTextEntity]?, isPinned: Bool) -> (MessageTags, GlobalMessageTags) {
    var isSecret = false
    var isUnconsumedPersonalMention = false
    var hasUnseenReactions = false
    for attribute in attributes {
        if let timerAttribute = attribute as? AutoclearTimeoutMessageAttribute {
            if timerAttribute.timeout > 0 && (timerAttribute.timeout <= 60 || timerAttribute.timeout == viewOnceTimeout) {
                isSecret = true
            }
        } else if let timerAttribute = attribute as? AutoremoveTimeoutMessageAttribute {
            if timerAttribute.timeout > 0 && (timerAttribute.timeout <= 60 || timerAttribute.timeout == viewOnceTimeout) {
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
                    case let .Video(_, _, flags, _, _, _):
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
            case let .conferenceCall(conferenceCall):
                globalTags.insert(.Calls)
                if incoming, conferenceCall.flags.contains(.isMissed) {
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
                case .Url, .TextUrl, .Email:
                    if media.isEmpty || !(media.first is TelegramMediaWebpage) {
                        tags.insert(.webPage)
                    }
                default:
                    break
            }
        }
    }
    
    return (tags, globalTags)
}

func apiMessagePeerId(_ messsage: Api.Message) -> PeerId? {
    switch messsage {
        case let .message(messageData):
            let chatPeerId = messageData.peerId
            return chatPeerId.peerId
        case let .messageEmpty(messageEmptyData):
            let (_, _, peerId) = (messageEmptyData.flags, messageEmptyData.id, messageEmptyData.peerId)
            if let peerId = peerId {
                return peerId.peerId
            } else {
                return nil
            }
        case let .messageService(messageServiceData):
            let chatPeerId = messageServiceData.peerId
            return chatPeerId.peerId
    }
}

func apiMessagePeerIds(_ message: Api.Message) -> [PeerId] {
    switch message {
        case let .message(messageData):
            let (fromId, chatPeerId, savedPeerId, fwdHeader, viaBotId, viaBusinessBotId, replyTo, media, entities) = (messageData.fromId, messageData.peerId, messageData.savedPeerId, messageData.fwdFrom, messageData.viaBotId, messageData.viaBusinessBotId, messageData.replyTo, messageData.media, messageData.entities)
            let peerId: PeerId = chatPeerId.peerId

            var result = [peerId]

            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
        
            if let fwdHeader = fwdHeader {
                switch fwdHeader {
                    case let .messageFwdHeader(messageFwdHeaderData):
                        let (fromId, savedFromPeer, savedFromId) = (messageFwdHeaderData.fromId, messageFwdHeaderData.savedFromPeer, messageFwdHeaderData.savedFromId)
                        if let fromId = fromId {
                            result.append(fromId.peerId)
                        }
                        if let savedFromPeer = savedFromPeer {
                            result.append(savedFromPeer.peerId)
                        }
                        if let savedFromId = savedFromId {
                            result.append(savedFromId.peerId)
                        }
                }
            }
            
            if let viaBotId = viaBotId {
                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(viaBotId)))
            }
            if let viaBusinessBotId {
                result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(viaBusinessBotId)))
            }
        
            if let savedPeerId = savedPeerId {
                result.append(savedPeerId.peerId)
            }
            
            if let media = media {
                switch media {
                    case let .messageMediaContact(messageMediaContactData):
                        let userId = messageMediaContactData.userId
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
                        case let .messageEntityMentionName(messageEntityMentionNameData):
                            let userId = messageEntityMentionNameData.userId
                            result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                        default:
                            break
                    }
                }
            }
        
            if let replyTo = replyTo {
                switch replyTo {
                case let .messageReplyStoryHeader(messageReplyStoryHeaderData):
                    let peer = messageReplyStoryHeaderData.peer
                    let storyPeerId = peer.peerId
                    if !result.contains(storyPeerId) {
                        result.append(storyPeerId)
                    }
                default:
                    break
                }
            }
            
            return result
        case .messageEmpty:
            return []
        case let .messageService(messageServiceData):
            let (fromId, chatPeerId, savedPeerId, action) = (messageServiceData.fromId, messageServiceData.peerId, messageServiceData.savedPeerId, messageServiceData.action)
            let peerId: PeerId = chatPeerId.peerId
            var result = [peerId]

            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId

            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
            if let savedPeerId, resolvedFromId != savedPeerId.peerId {
                result.append(savedPeerId.peerId)
            }
            
            switch action {
            case .messageActionChannelCreate, .messageActionChatDeletePhoto, .messageActionChatEditPhoto, .messageActionChatEditTitle, .messageActionEmpty, .messageActionPinMessage, .messageActionHistoryClear, .messageActionGameScore, .messageActionPaymentSent, .messageActionPaymentSentMe, .messageActionPhoneCall, .messageActionScreenshotTaken, .messageActionCustomAction, .messageActionBotAllowed, .messageActionSecureValuesSent, .messageActionSecureValuesSentMe, .messageActionContactSignUp, .messageActionGroupCall, .messageActionSetMessagesTTL, .messageActionGroupCallScheduled, .messageActionSetChatTheme, .messageActionChatJoinedByRequest, .messageActionWebViewDataSent, .messageActionWebViewDataSentMe, .messageActionGiftPremium, .messageActionGiftStars, .messageActionTopicCreate, .messageActionTopicEdit, .messageActionSuggestProfilePhoto, .messageActionSetChatWallPaper, .messageActionGiveawayLaunch, .messageActionGiveawayResults, .messageActionBoostApply, .messageActionRequestedPeerSentMe, .messageActionStarGift, .messageActionStarGiftUnique, .messageActionPaidMessagesRefunded, .messageActionPaidMessagesPrice, .messageActionTodoCompletions, .messageActionTodoAppendTasks, .messageActionSuggestedPostApproval, .messageActionGiftTon, .messageActionSuggestedPostSuccess, .messageActionSuggestedPostRefund, .messageActionSuggestBirthday, .messageActionStarGiftPurchaseOffer, .messageActionStarGiftPurchaseOfferDeclined:
                    break
                case let .messageActionChannelMigrateFrom(messageActionChannelMigrateFromData):
                    let chatId = messageActionChannelMigrateFromData.chatId
                    result.append(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId)))
                case let .messageActionChatAddUser(messageActionChatAddUserData):
                    let users = messageActionChatAddUserData.users
                    for id in users {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
                case let .messageActionChatCreate(messageActionChatCreateData):
                    let users = messageActionChatCreateData.users
                    for id in users {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
                case let .messageActionChatDeleteUser(messageActionChatDeleteUserData):
                    let userId = messageActionChatDeleteUserData.userId
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))
                case let .messageActionChatJoinedByLink(messageActionChatJoinedByLinkData):
                    let inviterId = messageActionChatJoinedByLinkData.inviterId
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId)))
                case let .messageActionChatMigrateTo(messageActionChatMigrateToData):
                    let channelId = messageActionChatMigrateToData.channelId
                    result.append(PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)))
                case let .messageActionGeoProximityReached(messageActionGeoProximityReachedData):
                    let (fromId, toId) = (messageActionGeoProximityReachedData.fromId, messageActionGeoProximityReachedData.toId)
                    result.append(fromId.peerId)
                    result.append(toId.peerId)
                case let .messageActionInviteToGroupCall(messageActionInviteToGroupCallData):
                    let userIds = messageActionInviteToGroupCallData.users
                    for id in userIds {
                        result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id)))
                    }
                case let .messageActionRequestedPeer(messageActionRequestedPeerData):
                    let peers = messageActionRequestedPeerData.peers
                    result.append(contentsOf: peers.map(\.peerId))
                case let .messageActionGiftCode(messageActionGiftCodeData):
                    let boostPeer = messageActionGiftCodeData.boostPeer
                    if let boostPeer = boostPeer {
                        result.append(boostPeer.peerId)
                    }
                case let .messageActionPrizeStars(messageActionPrizeStarsData):
                    let boostPeer = messageActionPrizeStarsData.boostPeer
                    result.append(boostPeer.peerId)
                case let .messageActionPaymentRefunded(messageActionPaymentRefundedData):
                    let peer = messageActionPaymentRefundedData.peer
                    result.append(peer.peerId)
                case let .messageActionConferenceCall(messageActionConferenceCallData):
                    let otherParticipants = messageActionConferenceCallData.otherParticipants
                    if let otherParticipants {
                        result.append(contentsOf: otherParticipants.map(\.peerId))
                    }
                case let .messageActionNewCreatorPending(messageActionNewCreatorPending):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(messageActionNewCreatorPending.newCreatorId)))
                case let .messageActionChangeCreator(messageActionChangeCreator):
                    result.append(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(messageActionChangeCreator.newCreatorId)))
            }
        
            return result
    }
}

func apiMessageAssociatedMessageIds(_ message: Api.Message) -> (replyIds: ReferencedReplyMessageIds, generalIds: [MessageId])? {
    switch message {
        case let .message(messageData):
            let (id, chatPeerId, replyTo) = (messageData.id, messageData.peerId, messageData.replyTo)
            if let replyTo = replyTo {
                let peerId: PeerId = chatPeerId.peerId

                switch replyTo {
                case let .messageReplyHeader(messageReplyHeaderData):
                    let (replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset, todoItemId) = (messageReplyHeaderData.replyToMsgId, messageReplyHeaderData.replyToPeerId, messageReplyHeaderData.replyFrom, messageReplyHeaderData.replyMedia, messageReplyHeaderData.replyToTopId, messageReplyHeaderData.quoteText, messageReplyHeaderData.quoteEntities, messageReplyHeaderData.quoteOffset, messageReplyHeaderData.todoItemId)
                    let _ = replyHeader
                    let _ = replyMedia
                    let _ = replyToTopId
                    let _ = quoteText
                    let _ = quoteEntities
                    let _ = quoteOffset
                    let _ = todoItemId

                    if let replyToMsgId = replyToMsgId {
                        let targetId = MessageId(peerId: replyToPeerId?.peerId ?? peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                        var replyIds = ReferencedReplyMessageIds()
                        replyIds.add(sourceId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), targetId: targetId)
                        return (replyIds, [])
                    }
                case .messageReplyStoryHeader:
                    break
                }
            }
        case .messageEmpty:
            break
        case let .messageService(messageServiceData):
            let (id, chatPeerId, replyHeader) = (messageServiceData.id, messageServiceData.peerId, messageServiceData.replyTo)
            if let replyHeader = replyHeader {
                switch replyHeader {
                case let .messageReplyHeader(messageReplyHeaderData):
                    let (replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset, todoItemId) = (messageReplyHeaderData.replyToMsgId, messageReplyHeaderData.replyToPeerId, messageReplyHeaderData.replyFrom, messageReplyHeaderData.replyMedia, messageReplyHeaderData.replyToTopId, messageReplyHeaderData.quoteText, messageReplyHeaderData.quoteEntities, messageReplyHeaderData.quoteOffset, messageReplyHeaderData.todoItemId)
                    let _ = replyHeader
                    let _ = replyMedia
                    let _ = replyToTopId
                    let _ = quoteText
                    let _ = quoteEntities
                    let _ = quoteOffset
                    let _ = todoItemId

                    if let replyToMsgId = replyToMsgId {
                        let targetId = MessageId(peerId: replyToPeerId?.peerId ?? chatPeerId.peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                        var replyIds = ReferencedReplyMessageIds()
                        replyIds.add(sourceId: MessageId(peerId: chatPeerId.peerId, namespace: Namespaces.Message.Cloud, id: id), targetId: targetId)
                        return (replyIds, [])
                    }
                case .messageReplyStoryHeader:
                    break
                }
            }
    }
    return nil
}

struct ParsedMessageWebpageAttributes {
    var forceLargeMedia: Bool?
    var isManuallyAdded: Bool
    var isSafe: Bool
}

func textMediaAndExpirationTimerFromApiMedia(_ media: Api.MessageMedia?, _ peerId: PeerId) -> (media: Media?, expirationTimer: Int32?, nonPremium: Bool?, hasSpoiler: Bool?, webpageAttributes: ParsedMessageWebpageAttributes?, videoTimestamp: Int32?) {
    if let media = media {
        switch media {
        case let .messageMediaPhoto(messageMediaPhotoData):
            let (flags, photo, ttlSeconds) = (messageMediaPhotoData.flags, messageMediaPhotoData.photo, messageMediaPhotoData.ttlSeconds)
            if let photo = photo {
                if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                    return (mediaImage, ttlSeconds, nil, (flags & (1 << 3)) != 0, nil, nil)
                }
            } else {
                return (TelegramMediaExpiredContent(data: .image), nil, nil, nil, nil, nil)
            }
        case let .messageMediaContact(messageMediaContactData):
            let (phoneNumber, firstName, lastName, vcard, userId) = (messageMediaContactData.phoneNumber, messageMediaContactData.firstName, messageMediaContactData.lastName, messageMediaContactData.vcard, messageMediaContactData.userId)
            let contactPeerId: PeerId? = userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            let mediaContact = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: contactPeerId, vCardData: vcard.isEmpty ? nil : vcard)
            return (mediaContact, nil, nil, nil, nil, nil)
        case let .messageMediaGeo(messageMediaGeoData):
            let geo = messageMediaGeoData.geo
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaVenue(messageMediaVenueData):
            let (geo, title, address, provider, venueId, venueType) = (messageMediaVenueData.geo, messageMediaVenueData.title, messageMediaVenueData.address, messageMediaVenueData.provider, messageMediaVenueData.venueId, messageMediaVenueData.venueType)
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaGeoLive(messageMediaGeoLiveData):
            let (geo, heading, period, proximityNotificationRadius) = (messageMediaGeoLiveData.geo, messageMediaGeoLiveData.heading, messageMediaGeoLiveData.period, messageMediaGeoLiveData.proximityNotificationRadius)
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: period, liveProximityNotificationRadius: proximityNotificationRadius, heading: heading)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaDocument(messageMediaDocumentData):
            let (flags, document, altDocuments, coverPhoto, videoTimestamp, ttlSeconds) = (messageMediaDocumentData.flags, messageMediaDocumentData.document, messageMediaDocumentData.altDocuments, messageMediaDocumentData.videoCover, messageMediaDocumentData.videoTimestamp, messageMediaDocumentData.ttlSeconds)
            if let document = document {
                if let mediaFile = telegramMediaFileFromApiDocument(document, altDocuments: altDocuments, videoCover: coverPhoto) {
                    return (mediaFile, ttlSeconds, (flags & (1 << 3)) != 0, (flags & (1 << 4)) != 0, nil, videoTimestamp)
                }
            } else {
                var data: TelegramMediaExpiredContentData
                if (flags & (1 << 7)) != 0 {
                    data = .videoMessage
                } else if (flags & (1 << 8)) != 0 {
                    data = .voiceMessage
                } else {
                    data = .file
                }
                return (TelegramMediaExpiredContent(data: data), nil, nil, nil, nil, nil)
            }
        case let .messageMediaWebPage(messageMediaWebPageData):
            let (flags, webpage) = (messageMediaWebPageData.flags, messageMediaWebPageData.webpage)
            if let mediaWebpage = telegramMediaWebpageFromApiWebpage(webpage) {
                var webpageForceLargeMedia: Bool?
                if (flags & (1 << 0)) != 0 {
                    webpageForceLargeMedia = true
                } else if (flags & (1 << 1)) != 0 {
                    webpageForceLargeMedia = false
                }

                return (mediaWebpage, nil, nil, nil, ParsedMessageWebpageAttributes(
                    forceLargeMedia: webpageForceLargeMedia,
                    isManuallyAdded: (flags & (1 << 3)) != 0,
                    isSafe: (flags & (1 << 4)) != 0
                ), nil)
            }
        case .messageMediaUnsupported:
            return (TelegramMediaUnsupported(), nil, nil, nil, nil, nil)
        case .messageMediaEmpty:
            break
        case let .messageMediaGame(messageMediaGameData):
            let game = messageMediaGameData.game
            return (TelegramMediaGame(apiGame: game), nil, nil, nil, nil, nil)
        case let .messageMediaInvoice(messageMediaInvoiceData):
            let (flags, title, description, photo, receiptMsgId, currency, totalAmount, startParam, apiExtendedMedia) = (messageMediaInvoiceData.flags, messageMediaInvoiceData.title, messageMediaInvoiceData.description, messageMediaInvoiceData.photo, messageMediaInvoiceData.receiptMsgId, messageMediaInvoiceData.currency, messageMediaInvoiceData.totalAmount, messageMediaInvoiceData.startParam, messageMediaInvoiceData.extendedMedia)
            var parsedFlags = TelegramMediaInvoiceFlags()
            if (flags & (1 << 3)) != 0 {
                parsedFlags.insert(.isTest)
            }
            if (flags & (1 << 1)) != 0 {
                parsedFlags.insert(.shippingAddressRequested)
            }
            return (TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: receiptMsgId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }, currency: currency, totalAmount: totalAmount, startParam: startParam, extendedMedia: apiExtendedMedia.flatMap({ TelegramExtendedMedia(apiExtendedMedia: $0, peerId: peerId) }), subscriptionPeriod: nil, flags: parsedFlags, version: TelegramMediaInvoice.lastVersion), nil, nil, nil, nil, nil)
        case let .messageMediaPoll(messageMediaPollData):
            let (poll, results) = (messageMediaPollData.poll, messageMediaPollData.results)
            switch poll {
            case let .poll(pollData):
                let (id, flags, question, answers, closePeriod, _) = (pollData.id, pollData.flags, pollData.question, pollData.answers, pollData.closePeriod, pollData.closeDate)
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
                
                let questionText: String
                let questionEntities: [MessageTextEntity]
                switch question {
                case let .textWithEntities(textWithEntitiesData):
                    let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                    questionText = text
                    questionEntities = messageTextEntitiesFromApiEntities(entities)
                }
                
                return (TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), publicity: publicity, kind: kind, text: questionText, textEntities: questionEntities, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod), nil, nil, nil, nil, nil)
            }
        case let .messageMediaToDo(messageMediaToDoData):
            let (todo, completions) = (messageMediaToDoData.todo, messageMediaToDoData.completions)
            switch todo {
            case let .todoList(todoListData):
                let (apiFlags, title, list) = (todoListData.flags, todoListData.title, todoListData.list)
                var flags: TelegramMediaTodo.Flags = []
                if (apiFlags & (1 << 0)) != 0 {
                    flags.insert(.othersCanAppend)
                }
                if (apiFlags & (1 << 1)) != 0 {
                    flags.insert(.othersCanComplete)
                }

                let todoText: String
                let todoEntities: [MessageTextEntity]
                switch title {
                case let .textWithEntities(textWithEntitiesData):
                    let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                    todoText = text
                    todoEntities = messageTextEntitiesFromApiEntities(entities)
                }
                var todoCompletions: [TelegramMediaTodo.Completion] = []
                if let completions {
                    todoCompletions = completions.map(TelegramMediaTodo.Completion.init(apiCompletion:))
                }
                return (TelegramMediaTodo(flags: flags, text: todoText, textEntities: todoEntities, items: list.map(TelegramMediaTodo.Item.init(apiItem:)), completions: todoCompletions), nil, nil, nil, nil, nil)
            }
        case let .messageMediaDice(messageMediaDiceData):
            let (value, emoticon, apiGameOutcome) = (messageMediaDiceData.value, messageMediaDiceData.emoticon, messageMediaDiceData.gameOutcome)
            var gameOutcome: TelegramMediaDice.GameOutcome?
            var tonAmount: Int64?
            switch apiGameOutcome {
            case let .emojiGameOutcome(emojiGameOutcomeData):
                let (seed, stakeTonAmount, outcomeTonAmount) = (emojiGameOutcomeData.seed, emojiGameOutcomeData.stakeTonAmount, emojiGameOutcomeData.tonAmount)
                gameOutcome = TelegramMediaDice.GameOutcome(seed: seed.makeData(), tonAmount: outcomeTonAmount)
                tonAmount = stakeTonAmount
            default:
                break
            }
            return (TelegramMediaDice(emoji: emoticon, tonAmount: tonAmount, value: value, gameOutcome: gameOutcome), nil, nil, nil, nil, nil)
        case let .messageMediaStory(messageMediaStoryData):
            let (flags, peerId, id) = (messageMediaStoryData.flags, messageMediaStoryData.peer, messageMediaStoryData.id)
            let isMention = (flags & (1 << 1)) != 0
            return (TelegramMediaStory(storyId: StoryId(peerId: peerId.peerId, id: id), isMention: isMention), nil, nil, nil, nil, nil)
        case let .messageMediaGiveaway(messageMediaGiveawayData):
            let (apiFlags, channels, countries, prizeDescription, quantity, months, stars, untilDate) = (messageMediaGiveawayData.flags, messageMediaGiveawayData.channels, messageMediaGiveawayData.countriesIso2, messageMediaGiveawayData.prizeDescription, messageMediaGiveawayData.quantity, messageMediaGiveawayData.months, messageMediaGiveawayData.stars, messageMediaGiveawayData.untilDate)
            var flags: TelegramMediaGiveaway.Flags = []
            if (apiFlags & (1 << 0)) != 0 {
                flags.insert(.onlyNewSubscribers)
            }
            let prize: TelegramMediaGiveaway.Prize
            if let months {
                prize = .premium(months: months)
            } else if let stars {
                prize = .stars(amount: stars)
            } else {
                return (nil, nil, nil, nil, nil, nil)
            }
            return (TelegramMediaGiveaway(flags: flags, channelPeerIds: channels.map { PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value($0)) }, countries: countries ?? [], quantity: quantity, prize: prize, untilDate: untilDate, prizeDescription: prizeDescription), nil, nil, nil, nil, nil)
        case let .messageMediaGiveawayResults(messageMediaGiveawayResultsData):
            let (apiFlags, channelId, additionalPeersCount, launchMsgId, winnersCount, unclaimedCount, winners, months, stars, prizeDescription, untilDate) = (messageMediaGiveawayResultsData.flags, messageMediaGiveawayResultsData.channelId, messageMediaGiveawayResultsData.additionalPeersCount, messageMediaGiveawayResultsData.launchMsgId, messageMediaGiveawayResultsData.winnersCount, messageMediaGiveawayResultsData.unclaimedCount, messageMediaGiveawayResultsData.winners, messageMediaGiveawayResultsData.months, messageMediaGiveawayResultsData.stars, messageMediaGiveawayResultsData.prizeDescription, messageMediaGiveawayResultsData.untilDate)
            var flags: TelegramMediaGiveawayResults.Flags = []
            if (apiFlags & (1 << 0)) != 0 {
                flags.insert(.onlyNewSubscribers)
            }
            if (apiFlags & (1 << 2)) != 0 {
                flags.insert(.refunded)
            }
            let prize: TelegramMediaGiveawayResults.Prize
            if let months {
                prize = .premium(months: months)
            } else if let stars {
                prize = .stars(amount: stars)
            } else {
                return (nil, nil, nil, nil, nil, nil)
            }
            return (TelegramMediaGiveawayResults(flags: flags, launchMessageId: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: launchMsgId), additionalChannelsCount: additionalPeersCount ?? 0, winnersPeerIds: winners.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }, winnersCount: winnersCount, unclaimedCount: unclaimedCount, prize: prize, untilDate: untilDate, prizeDescription: prizeDescription), nil, nil, nil, nil, nil)
        case let .messageMediaPaidMedia(messageMediaPaidMediaData):
            let (starsAmount, apiExtendedMedia) = (messageMediaPaidMediaData.starsAmount, messageMediaPaidMediaData.extendedMedia)
            return (TelegramMediaPaidContent(amount: starsAmount, extendedMedia: apiExtendedMedia.compactMap({ TelegramExtendedMedia(apiExtendedMedia: $0, peerId: peerId) })), nil, nil, nil, nil, nil)
        case let .messageMediaVideoStream(messageMediaVideoStreamData):
            let (flags, call) = (messageMediaVideoStreamData.flags, messageMediaVideoStreamData.call)
            if let call = GroupCallReference(call) {
                let kind: TelegramMediaLiveStream.Kind
                if (flags & (1 << 0)) != 0 {
                    kind = .rtmp
                } else {
                    kind = .rtc
                }
                return (TelegramMediaLiveStream(call: call, kind: kind), nil, nil, nil, nil, nil)
            }
        }
    }
    
    return (nil, nil, nil, nil, nil, nil)
}

func mediaAreaFromApiMediaArea(_ mediaArea: Api.MediaArea) -> MediaArea? {
    func coodinatesFromApiMediaAreaCoordinates(_ coordinates: Api.MediaAreaCoordinates) -> MediaArea.Coordinates {
        switch coordinates {
        case let .mediaAreaCoordinates(mediaAreaCoordinatesData):
            let (_, x, y, width, height, rotation, radius) = (mediaAreaCoordinatesData.flags, mediaAreaCoordinatesData.x, mediaAreaCoordinatesData.y, mediaAreaCoordinatesData.w, mediaAreaCoordinatesData.h, mediaAreaCoordinatesData.rotation, mediaAreaCoordinatesData.radius)
            return MediaArea.Coordinates(x: x, y: y, width: width, height: height, rotation: rotation, cornerRadius: radius)
        }
    }
    switch mediaArea {
    case .inputMediaAreaChannelPost:
        return nil
    case .inputMediaAreaVenue:
        return nil
    case let .mediaAreaGeoPoint(mediaAreaGeoPointData):
        let (_, coordinates, geo, address) = (mediaAreaGeoPointData.flags, mediaAreaGeoPointData.coordinates, mediaAreaGeoPointData.geo, mediaAreaGeoPointData.address)
        let latitude: Double
        let longitude: Double
        switch geo {
        case let .geoPoint(geoPointData):
            let (_, long, lat, _, _) = (geoPointData.flags, geoPointData.long, geoPointData.lat, geoPointData.accessHash, geoPointData.accuracyRadius)
            latitude = lat
            longitude = long
        case .geoPointEmpty:
            latitude = 0.0
            longitude = 0.0
        }

        var mappedAddress: MapGeoAddress?
        if let address {
            switch address {
            case let .geoPointAddress(geoPointAddressData):
                let (_, countryIso2, state, city, street) = (geoPointAddressData.flags, geoPointAddressData.countryIso2, geoPointAddressData.state, geoPointAddressData.city, geoPointAddressData.street)
                mappedAddress = MapGeoAddress(
                    country: countryIso2,
                    state: state,
                    city: city,
                    street: street
                )
            }
        }

        return .venue(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), venue: MediaArea.Venue(
            latitude: latitude,
            longitude: longitude,
            venue: nil,
            address: mappedAddress,
            queryId: nil,
            resultId: nil
        ))
    case let .mediaAreaVenue(mediaAreaVenueData):
        let (coordinates, geo, title, address, provider, venueId, venueType) = (mediaAreaVenueData.coordinates, mediaAreaVenueData.geo, mediaAreaVenueData.title, mediaAreaVenueData.address, mediaAreaVenueData.provider, mediaAreaVenueData.venueId, mediaAreaVenueData.venueType)
        let latitude: Double
        let longitude: Double
        switch geo {
        case let .geoPoint(geoPointData):
            let (_, long, lat, _, _) = (geoPointData.flags, geoPointData.long, geoPointData.lat, geoPointData.accessHash, geoPointData.accuracyRadius)
            latitude = lat
            longitude = long
        case .geoPointEmpty:
            latitude = 0.0
            longitude = 0.0
        }
        return .venue(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), venue: MediaArea.Venue(latitude: latitude, longitude: longitude, venue: MapVenue(title: title, address: address, provider: provider, id: venueId, type: venueType), address: nil, queryId: nil, resultId: nil))
    case let .mediaAreaSuggestedReaction(mediaAreaSuggestedReactionData):
        let (flags, coordinates, reaction) = (mediaAreaSuggestedReactionData.flags, mediaAreaSuggestedReactionData.coordinates, mediaAreaSuggestedReactionData.reaction)
        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
            var parsedFlags = MediaArea.ReactionFlags()
            if (flags & (1 << 0)) != 0 {
                parsedFlags.insert(.isDark)
            }
            if (flags & (1 << 1)) != 0 {
                parsedFlags.insert(.isFlipped)
            }
            return .reaction(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), reaction: reaction, flags: parsedFlags)
        } else {
            return nil
        }
    case let .mediaAreaUrl(mediaAreaUrlData):
        let (coordinates, url) = (mediaAreaUrlData.coordinates, mediaAreaUrlData.url)
        return .link(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), url: url)
    case let .mediaAreaChannelPost(mediaAreaChannelPostData):
        let (coordinates, channelId, messageId) = (mediaAreaChannelPostData.coordinates, mediaAreaChannelPostData.channelId, mediaAreaChannelPostData.msgId)
        return .channelMessage(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), messageId: EngineMessage.Id(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: messageId))
    case let .mediaAreaWeather(mediaAreaWeatherData):
        let (coordinates, emoji, temperatureC, color) = (mediaAreaWeatherData.coordinates, mediaAreaWeatherData.emoji, mediaAreaWeatherData.temperatureC, mediaAreaWeatherData.color)
        return .weather(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), emoji: emoji, temperature: temperatureC, color: color)
    case let .mediaAreaStarGift(mediaAreaStarGiftData):
        let (coordinates, slug) = (mediaAreaStarGiftData.coordinates, mediaAreaStarGiftData.slug)
        return .starGift(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), slug: slug)
    }
}

func apiMediaAreasFromMediaAreas(_ mediaAreas: [MediaArea], transaction: Transaction?) -> [Api.MediaArea] {
    var apiMediaAreas: [Api.MediaArea] = []
    for area in mediaAreas {
        let coordinates = area.coordinates
        var flags: Int32 = 0
        if let _ = coordinates.cornerRadius {
            flags |= (1 << 0)
        }
        let inputCoordinates = Api.MediaAreaCoordinates.mediaAreaCoordinates(.init(flags: flags, x: coordinates.x, y: coordinates.y, w: coordinates.width, h: coordinates.height, rotation: coordinates.rotation, radius: coordinates.cornerRadius))
        switch area {
        case let .venue(_, venue):
            if let queryId = venue.queryId, let resultId = venue.resultId {
                apiMediaAreas.append(.inputMediaAreaVenue(.init(coordinates: inputCoordinates, queryId: queryId, resultId: resultId)))
            } else if let venueInfo = venue.venue {
                apiMediaAreas.append(.mediaAreaVenue(.init(coordinates: inputCoordinates, geo: .geoPoint(.init(flags: 0, long: venue.longitude, lat: venue.latitude, accessHash: 0, accuracyRadius: nil)), title: venueInfo.title, address: venueInfo.address ?? "", provider: venueInfo.provider ?? "", venueId: venueInfo.id ?? "", venueType: venueInfo.type ?? "")))
            } else {
                var flags: Int32 = 0
                var inputAddress: Api.GeoPointAddress?
                if let address = venue.address {
                    var addressFlags: Int32 = 0
                    if let _ = address.state {
                        addressFlags |= (1 << 0)
                    }
                    if let _ = address.city {
                        addressFlags |= (1 << 1)
                    }
                    if let _ = address.street {
                        addressFlags |= (1 << 2)
                    }
                    inputAddress = .geoPointAddress(.init(flags: addressFlags, countryIso2: address.country, state: address.state, city: address.city, street: address.street))
                    flags |= (1 << 0)
                }
                apiMediaAreas.append(.mediaAreaGeoPoint(.init(flags: flags, coordinates: inputCoordinates, geo: .geoPoint(.init(flags: 0, long: venue.longitude, lat: venue.latitude, accessHash: 0, accuracyRadius: nil)), address: inputAddress)))
            }
        case let .reaction(_, reaction, flags):
            var apiFlags: Int32 = 0
            if flags.contains(.isDark) {
                apiFlags |= (1 << 0)
            }
            if flags.contains(.isFlipped) {
                apiFlags |= (1 << 1)
            }
            apiMediaAreas.append(.mediaAreaSuggestedReaction(.init(flags: apiFlags, coordinates: inputCoordinates, reaction: reaction.apiReaction)))
        case let .channelMessage(_, messageId):
            if let transaction, let peer = transaction.getPeer(messageId.peerId), let inputChannel = apiInputChannel(peer) {
                apiMediaAreas.append(.inputMediaAreaChannelPost(.init(coordinates: inputCoordinates, channel: inputChannel, msgId: messageId.id)))
            }
        case let .link(_, url):
            apiMediaAreas.append(.mediaAreaUrl(.init(coordinates: inputCoordinates, url: url)))
        case let .weather(_, emoji, temperature, color):
            apiMediaAreas.append(.mediaAreaWeather(.init(coordinates: inputCoordinates, emoji: emoji, temperatureC: temperature, color: color)))
        case let .starGift(_, slug):
            apiMediaAreas.append(.mediaAreaStarGift(.init(coordinates: inputCoordinates, slug: slug)))
        }
    }
    return apiMediaAreas
}


func messageTextEntitiesFromApiEntities(_ entities: [Api.MessageEntity]) -> [MessageTextEntity] {
    var result: [MessageTextEntity] = []
    for entity in entities {
        switch entity {
        case .messageEntityUnknown, .inputMessageEntityMentionName:
            break
        case let .messageEntityMention(messageEntityMentionData):
            let (offset, length) = (messageEntityMentionData.offset, messageEntityMentionData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Mention))
        case let .messageEntityHashtag(messageEntityHashtagData):
            let (offset, length) = (messageEntityHashtagData.offset, messageEntityHashtagData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
        case let .messageEntityBotCommand(messageEntityBotCommandData):
            let (offset, length) = (messageEntityBotCommandData.offset, messageEntityBotCommandData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BotCommand))
        case let .messageEntityUrl(messageEntityUrlData):
            let (offset, length) = (messageEntityUrlData.offset, messageEntityUrlData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Url))
        case let .messageEntityEmail(messageEntityEmailData):
            let (offset, length) = (messageEntityEmailData.offset, messageEntityEmailData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Email))
        case let .messageEntityBold(messageEntityBoldData):
            let (offset, length) = (messageEntityBoldData.offset, messageEntityBoldData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Bold))
        case let .messageEntityItalic(messageEntityItalicData):
            let (offset, length) = (messageEntityItalicData.offset, messageEntityItalicData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Italic))
        case let .messageEntityCode(messageEntityCodeData):
            let (offset, length) = (messageEntityCodeData.offset, messageEntityCodeData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Code))
        case let .messageEntityPre(messageEntityPreData):
            let (offset, length, language) = (messageEntityPreData.offset, messageEntityPreData.length, messageEntityPreData.language)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre(language: language)))
        case let .messageEntityTextUrl(messageEntityTextUrlData):
            let (offset, length, url) = (messageEntityTextUrlData.offset, messageEntityTextUrlData.length, messageEntityTextUrlData.url)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextUrl(url: url)))
        case let .messageEntityMentionName(messageEntityMentionNameData):
            let (offset, length, userId) = (messageEntityMentionNameData.offset, messageEntityMentionNameData.length, messageEntityMentionNameData.userId)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .TextMention(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)))))
        case let .messageEntityPhone(messageEntityPhoneData):
            let (offset, length) = (messageEntityPhoneData.offset, messageEntityPhoneData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .PhoneNumber))
        case let .messageEntityCashtag(messageEntityCashtagData):
            let (offset, length) = (messageEntityCashtagData.offset, messageEntityCashtagData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Hashtag))
        case let .messageEntityUnderline(messageEntityUnderlineData):
            let (offset, length) = (messageEntityUnderlineData.offset, messageEntityUnderlineData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Underline))
        case let .messageEntityStrike(messageEntityStrikeData):
            let (offset, length) = (messageEntityStrikeData.offset, messageEntityStrikeData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Strikethrough))
        case let .messageEntityBlockquote(messageEntityBlockquoteData):
            let (flags, offset, length) = (messageEntityBlockquoteData.flags, messageEntityBlockquoteData.offset, messageEntityBlockquoteData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BlockQuote(isCollapsed: (flags & (1 << 0)) != 0)))
        case let .messageEntityBankCard(messageEntityBankCardData):
            let (offset, length) = (messageEntityBankCardData.offset, messageEntityBankCardData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BankCard))
        case let .messageEntitySpoiler(messageEntitySpoilerData):
            let (offset, length) = (messageEntitySpoilerData.offset, messageEntitySpoilerData.length)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Spoiler))
        case let .messageEntityCustomEmoji(messageEntityCustomEmojiData):
            let (offset, length, documentId) = (messageEntityCustomEmojiData.offset, messageEntityCustomEmojiData.length, messageEntityCustomEmojiData.documentId)
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .CustomEmoji(stickerPack: nil, fileId: documentId)))
        }
    }
    return result
}

extension StoreMessage {
    convenience init?(apiMessage: Api.Message, accountPeerId: PeerId, peerIsForum: Bool, namespace: MessageId.Namespace = Namespaces.Message.Cloud) {
        switch apiMessage {
            case let .message(messageData):
                let (flags, flags2, id, fromId, boosts, chatPeerId, savedPeerId, fwdFrom, viaBotId, viaBusinessBotId, replyTo, date, message, media, replyMarkup, entities, views, forwards, replies, editDate, postAuthor, groupingId, reactions, restrictionReason, ttlPeriod, quickReplyShortcutId, messageEffectId, factCheck, reportDeliveryUntilDate, paidMessageStars, suggestedPost, scheduledRepeatPeriod, summaryFromLanguage) = (messageData.flags, messageData.flags2, messageData.id, messageData.fromId, messageData.fromBoostsApplied, messageData.peerId, messageData.savedPeerId, messageData.fwdFrom, messageData.viaBotId, messageData.viaBusinessBotId, messageData.replyTo, messageData.date, messageData.message, messageData.media, messageData.replyMarkup, messageData.entities, messageData.views, messageData.forwards, messageData.replies, messageData.editDate, messageData.postAuthor, messageData.groupedId, messageData.reactions, messageData.restrictionReason, messageData.ttlPeriod, messageData.quickReplyShortcutId, messageData.effect, messageData.factcheck, messageData.reportDeliveryUntilDate, messageData.paidMessageStars, messageData.suggestedPost, messageData.scheduleRepeatPeriod, messageData.summaryFromLanguage)
                var attributes: [MessageAttribute] = []

                if (flags2 & (1 << 4)) != 0 {
                    attributes.append(PendingProcessingMessageAttribute(approximateCompletionTime: date))
                }

                let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
                var namespace = namespace
                if quickReplyShortcutId != nil {
                    namespace = Namespaces.Message.QuickReplyCloud
                }
                
                let peerId: PeerId
                var authorId: PeerId?
                switch chatPeerId {
                    case .peerUser:
                        peerId = chatPeerId.peerId
                        authorId = resolvedFromId
                    case let .peerChat(peerChatData):
                        let chatId = peerChatData.chatId
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        authorId = resolvedFromId
                    case let .peerChannel(peerChannelData):
                        let channelId = peerChannelData.channelId
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        authorId = resolvedFromId
                }
                
                var threadId: Int64?
                if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(messageReplyHeaderData):
                        let (innerFlags, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset, todoItemId) = (messageReplyHeaderData.flags, messageReplyHeaderData.replyToMsgId, messageReplyHeaderData.replyToPeerId, messageReplyHeaderData.replyFrom, messageReplyHeaderData.replyMedia, messageReplyHeaderData.replyToTopId, messageReplyHeaderData.quoteText, messageReplyHeaderData.quoteEntities, messageReplyHeaderData.quoteOffset, messageReplyHeaderData.todoItemId)
                        let isForumTopic = (innerFlags & (1 << 3)) != 0
                        
                        var quote: EngineMessageReplyQuote?
                        let isQuote = (innerFlags & (1 << 9)) != 0
                        
                        if quoteText != nil || replyMedia != nil {
                            quote = EngineMessageReplyQuote(text: quoteText ?? "", offset: quoteOffset.flatMap(Int.init), entities: messageTextEntitiesFromApiEntities(quoteEntities ?? []), media: textMediaAndExpirationTimerFromApiMedia(replyMedia, peerId).media)
                        }
                        
                        if let replyToMsgId = replyToMsgId {
                            let replyPeerId = replyToPeerId?.peerId ?? peerId
                            if let replyToTopId {
                                if peerIsForum {
                                    if isForumTopic {
                                        let threadIdValue = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                                        threadMessageId = threadIdValue
                                        threadId = Int64(threadIdValue.id)
                                    }
                                } else {
                                    if peerId.namespace == Namespaces.Peer.CloudChannel {
                                        let threadIdValue = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                                        threadMessageId = threadIdValue
                                        threadId = Int64(threadIdValue.id)
                                    } else {
                                        let threadIdValue = MessageId(peerId: replyToPeerId?.peerId ?? peerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                                        threadMessageId = threadIdValue
                                        threadId = Int64(threadIdValue.id)
                                    }
                                }
                            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                let threadIdValue = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                                
                                if peerIsForum {
                                    if isForumTopic {
                                        threadMessageId = threadIdValue
                                        threadId = Int64(threadIdValue.id)
                                    }
                                } else {
                                    threadMessageId = threadIdValue
                                    threadId = Int64(threadIdValue.id)
                                }
                            } else if peerId.namespace == Namespaces.Peer.CloudUser, peerIsForum {
                                //TODO:release
                                if isForumTopic {
                                    let threadIdValue = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                                    
                                    threadMessageId = threadIdValue
                                    threadId = Int64(threadIdValue.id)
                                }
                            }
                            attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId, quote: quote, isQuote: isQuote, todoItemId: todoItemId))
                        }
                        if let replyHeader = replyHeader {
                            attributes.append(QuotedReplyMessageAttribute(apiHeader: replyHeader, quote: quote, isQuote: isQuote))
                        }
                    case let .messageReplyStoryHeader(messageReplyStoryHeaderData):
                        let (peer, storyId) = (messageReplyStoryHeaderData.peer, messageReplyStoryHeaderData.storyId)
                        attributes.append(ReplyStoryAttribute(storyId: StoryId(peerId: peer.peerId, id: storyId)))
                    }
                }

                if threadId == nil && peerId.namespace == Namespaces.Peer.CloudChannel {
                    threadId = 1
                }

                var forwardInfo: StoreMessageForwardInfo?
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(messageFwdHeaderData):
                            let (flags, fromId, fromName, date, channelPost, postAuthor, savedFromPeer, savedFromMsgId, savedFromId, savedFromName, savedDate, psaType) = (messageFwdHeaderData.flags, messageFwdHeaderData.fromId, messageFwdHeaderData.fromName, messageFwdHeaderData.date, messageFwdHeaderData.channelPost, messageFwdHeaderData.postAuthor, messageFwdHeaderData.savedFromPeer, messageFwdHeaderData.savedFromMsgId, messageFwdHeaderData.savedFromId, messageFwdHeaderData.savedFromName, messageFwdHeaderData.savedDate, messageFwdHeaderData.psaType)
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

                            let originalOutgoing = (flags & (1 << 11)) != 0

                            if let savedFromPeer = savedFromPeer, let savedFromMsgId = savedFromMsgId {
                                let peerId: PeerId = savedFromPeer.peerId
                                let messageId: MessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: savedFromMsgId)
                                attributes.append(SourceReferenceMessageAttribute(messageId: messageId))
                            }
                            if savedFromId != nil || savedFromName != nil || savedDate != nil || originalOutgoing {
                                attributes.append(SourceAuthorInfoMessageAttribute(originalAuthor: savedFromId?.peerId, originalAuthorName: savedFromName, orignalDate: savedDate, originalOutgoing: originalOutgoing))
                            }

                            if let authorId = authorId {
                                forwardInfo = StoreMessageForwardInfo(authorId: authorId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor,  psaType: psaType, flags: forwardInfoFlags)
                            } else if let sourceId = sourceId {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor, psaType: psaType, flags: forwardInfoFlags)
                            } else if let postAuthor = postAuthor ?? fromName {
                                forwardInfo = StoreMessageForwardInfo(authorId: nil, sourceId: nil, sourceMessageId: sourceMessageId, date: date, authorSignature: postAuthor, psaType: psaType, flags: forwardInfoFlags)
                            }
                    }
                }
            
                if let savedPeerId {
                    threadId = savedPeerId.peerId.toInt64()
                }
            
                if let quickReplyShortcutId {
                    threadId = Int64(quickReplyShortcutId)
                }
                
                let messageText = message
                var medias: [Media] = []
                
                var consumableContent: (Bool, Bool)? = nil
                
                if let media = media {
                    let (mediaValue, expirationTimer, nonPremium, hasSpoiler, webpageAttributes, videoTimestamp) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
                    if let mediaValue = mediaValue {
                        medias.append(mediaValue)
                    
                        if let expirationTimer = expirationTimer, expirationTimer > 0 {
                            attributes.append(AutoclearTimeoutMessageAttribute(timeout: expirationTimer, countdownBeginTime: nil))
                            consumableContent = (true, false)
                        }
                        
                        if let nonPremium = nonPremium, nonPremium {
                            attributes.append(NonPremiumMessageAttribute())
                        }
                        
                        if let hasSpoiler = hasSpoiler, hasSpoiler {
                            attributes.append(MediaSpoilerMessageAttribute())
                        }
                        
                        if let videoTimestamp {
                            attributes.append(ForwardVideoTimestampAttribute(timestamp: videoTimestamp))
                        }
                        
                        if mediaValue is TelegramMediaWebpage {
                            let leadingPreview = (flags & (1 << 27)) != 0
                            
                            if let webpageAttributes = webpageAttributes {
                                attributes.append(WebpagePreviewMessageAttribute(leadingPreview: leadingPreview, forceLargeMedia: webpageAttributes.forceLargeMedia, isManuallyAdded: webpageAttributes.isManuallyAdded, isSafe: webpageAttributes.isSafe))
                            }
                        }
                        
                        let leadingPreview = (flags & (1 << 27)) != 0
                        if leadingPreview {
                            attributes.append(InvertMediaMessageAttribute())
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
            
                if let viaBusinessBotId {
                    attributes.append(InlineBusinessBotMessageAttribute(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(viaBusinessBotId)), title: nil))
                }
                
                if !Namespaces.Message.allNonRegular.contains(namespace) {
                    if let views = views {
                        attributes.append(ViewCountMessageAttribute(count: Int(views)))
                    }
                    
                    if let forwards = forwards {
                        attributes.append(ForwardCountMessageAttribute(count: Int(forwards)))
                    }
                }
            
                if namespace == Namespaces.Message.Cloud {
                    if let boosts = boosts {
                        attributes.append(BoostCountMessageAttribute(count: Int(boosts)))
                    }
                }
                
                if let editDate = editDate {
                    attributes.append(EditedMessageAttribute(date: editDate, isHidden: (flags & (1 << 21)) != 0))
                }
                
                if let reportDeliveryUntilDate {
                    attributes.append(ReportDeliveryMessageAttribute(untilDate: reportDeliveryUntilDate, isReported: false))
                }
            
                if let paidMessageStars {
                    attributes.append(PaidStarsMessageAttribute(stars: StarsAmount(value: paidMessageStars, nanos: 0), postponeSending: false))
                }
            
                if let scheduledRepeatPeriod {
                    attributes.append(ScheduledRepeatAttribute(repeatPeriod: scheduledRepeatPeriod))
                }
            
                if let summaryFromLanguage {
                    attributes.append(SummarizationMessageAttribute(fromLang: summaryFromLanguage))
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
                
                if (flags & (1 << 19)) != 0 {
                    attributes.append(ContentRequiresValidationMessageAttribute())
                }
            
                if let reactions = reactions {
                    attributes.append(ReactionsMessageAttribute(apiReactions: reactions))
                }
                
                if let replies = replies {
                    let recentRepliersPeerIds: [PeerId]?
                    switch replies {
                    case let .messageReplies(messageRepliesData):
                        let (repliesCount, recentRepliers, channelId, maxId, readMaxId) = (messageRepliesData.replies, messageRepliesData.recentRepliers, messageRepliesData.channelId, messageRepliesData.maxId, messageRepliesData.readMaxId)
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
            
                if let messageEffectId {
                    attributes.append(EffectMessageAttribute(id: messageEffectId))
                }
            
                if let factCheck {
                    switch factCheck {
                    case let .factCheck(factCheckData):
                        let (_, country, text, hash) = (factCheckData.flags, factCheckData.country, factCheckData.text, factCheckData.hash)
                        let content: FactCheckMessageAttribute.Content
                        if let text, let country {
                            switch text {
                            case let .textWithEntities(textWithEntitiesData):
                                let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                                content = .Loaded(text: text, entities: messageTextEntitiesFromApiEntities(entities), country: country)
                            }
                        } else {
                            content = .Pending
                        }
                        attributes.append(FactCheckMessageAttribute(content: content, hash: hash))
                    }
                }
            
                if let suggestedPost {
                    attributes.append(SuggestedPostMessageAttribute(apiSuggestedPost: suggestedPost))
                }
            
                if (flags2 & (1 << 8)) != 0 || (flags2 & (1 << 9)) != 0 {
                    attributes.append(PublishedSuggestedPostMessageAttribute(currency: (flags2 & (1 << 8)) != 0 ? .stars : .ton))
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
                
                if (flags & (1 << 4)) != 0 || (flags & (1 << 13)) != 0 || (flags2 & (1 << 1)) != 0 {
                    var notificationFlags: NotificationInfoMessageAttributeFlags = []
                    if (flags & (1 << 4)) != 0 {
                        notificationFlags.insert(.personal)
                        let notConsumed = (flags & (1 << 5)) != 0
                        attributes.append(ConsumablePersonalMentionMessageAttribute(consumed: !notConsumed, pending: false))
                    }
                    if (flags & (1 << 13)) != 0 {
                        notificationFlags.insert(.muted)
                    }
                    if (flags2 & (1 << 1)) != 0 {
                        notificationFlags.insert(.automaticMessage)
                    }
                    attributes.append(NotificationInfoMessageAttribute(flags: notificationFlags))
                }
                
                let isPinned = (flags & (1 << 24)) != 0
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: storeFlags.contains(.Incoming), attributes: attributes, media: medias, textEntities: entitiesAttribute?.entities, isPinned: isPinned)
                
                storeFlags.insert(.CanBeGroupedIntoFeed)
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: groupingId, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: medias)
            case .messageEmpty:
                return nil
            case let .messageService(messageServiceData):
                let (flags, id, fromId, chatPeerId, savedPeerId, replyTo, date, action, reactions, ttlPeriod) = (messageServiceData.flags, messageServiceData.id, messageServiceData.fromId, messageServiceData.peerId, messageServiceData.savedPeerId, messageServiceData.replyTo, messageServiceData.date, messageServiceData.action, messageServiceData.reactions, messageServiceData.ttlPeriod)
                let peerId: PeerId = chatPeerId.peerId
                let authorId: PeerId? = fromId?.peerId ?? chatPeerId.peerId

                var attributes: [MessageAttribute] = []

                var threadId: Int64?
                if let savedPeerId {
                    threadId = savedPeerId.peerId.toInt64()
                    
                    if chatPeerId.peerId.namespace == Namespaces.Peer.CloudChannel, let replyTo {
                        switch replyTo {
                        case let .messageReplyHeader(messageReplyHeaderData):
                            let (innerFlags, replyToMsgId, replyToPeerId, replyHeader, replyMedia, quoteText, quoteEntities, quoteOffset, todoItemId) = (messageReplyHeaderData.flags, messageReplyHeaderData.replyToMsgId, messageReplyHeaderData.replyToPeerId, messageReplyHeaderData.replyFrom, messageReplyHeaderData.replyMedia, messageReplyHeaderData.quoteText, messageReplyHeaderData.quoteEntities, messageReplyHeaderData.quoteOffset, messageReplyHeaderData.todoItemId)
                            var quote: EngineMessageReplyQuote?
                            let isQuote = (innerFlags & (1 << 9)) != 0
                            if quoteText != nil || replyMedia != nil {
                                quote = EngineMessageReplyQuote(text: quoteText ?? "", offset: quoteOffset.flatMap(Int.init), entities: messageTextEntitiesFromApiEntities(quoteEntities ?? []), media: textMediaAndExpirationTimerFromApiMedia(replyMedia, peerId).media)
                            }

                            if let replyToMsgId = replyToMsgId {
                                let replyPeerId = replyToPeerId?.peerId ?? peerId
                                attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: nil, quote: quote, isQuote: isQuote, todoItemId: todoItemId))
                            } else if let replyHeader = replyHeader {
                                attributes.append(QuotedReplyMessageAttribute(apiHeader: replyHeader, quote: quote, isQuote: isQuote))
                            }
                        case let .messageReplyStoryHeader(messageReplyStoryHeaderData):
                            let (peer, storyId) = (messageReplyStoryHeaderData.peer, messageReplyStoryHeaderData.storyId)
                            attributes.append(ReplyStoryAttribute(storyId: StoryId(peerId: peer.peerId, id: storyId)))
                        }
                    }
                } else if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(messageReplyHeaderData):
                        let (innerFlags, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset, todoItemId) = (messageReplyHeaderData.flags, messageReplyHeaderData.replyToMsgId, messageReplyHeaderData.replyToPeerId, messageReplyHeaderData.replyFrom, messageReplyHeaderData.replyMedia, messageReplyHeaderData.replyToTopId, messageReplyHeaderData.quoteText, messageReplyHeaderData.quoteEntities, messageReplyHeaderData.quoteOffset, messageReplyHeaderData.todoItemId)
                        var quote: EngineMessageReplyQuote?
                        let isQuote = (innerFlags & (1 << 9)) != 0
                        if quoteText != nil || replyMedia != nil {
                            quote = EngineMessageReplyQuote(text: quoteText ?? "", offset: quoteOffset.flatMap(Int.init), entities: messageTextEntitiesFromApiEntities(quoteEntities ?? []), media: textMediaAndExpirationTimerFromApiMedia(replyMedia, peerId).media)
                        }
                        
                        if let replyToMsgId = replyToMsgId {
                            let replyPeerId = replyToPeerId?.peerId ?? peerId
                            if let replyToTopId = replyToTopId {
                                let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToTopId)
                                threadMessageId = threadIdValue
                                if replyPeerId == peerId {
                                    threadId = Int64(threadIdValue.id)
                                }
                            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                let threadIdValue = MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId)
                                threadMessageId = threadIdValue
                                threadId = Int64(threadIdValue.id)
                            }
                            switch action {
                            case .messageActionTopicEdit:
                                threadId = Int64(replyToMsgId)
                            default:
                                break
                            }
                            attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId, quote: quote, isQuote: isQuote, todoItemId: todoItemId))
                        } else if let replyHeader = replyHeader {
                            attributes.append(QuotedReplyMessageAttribute(apiHeader: replyHeader, quote: quote, isQuote: isQuote))
                        }
                    case let .messageReplyStoryHeader(messageReplyStoryHeaderData):
                        let (peer, storyId) = (messageReplyStoryHeaderData.peer, messageReplyStoryHeaderData.storyId)
                        attributes.append(ReplyStoryAttribute(storyId: StoryId(peerId: peer.peerId, id: storyId)))
                    }
                } else {
                    switch action {
                    case .messageActionTopicCreate:
                        threadId = Int64(id)
                    default:
                        break
                    }
                }
            
                if threadId == nil && peerId.namespace == Namespaces.Peer.CloudChannel {
                    threadId = 1
                }
                
                if (flags & (1 << 19)) != 0 {
                    attributes.append(ContentRequiresValidationMessageAttribute())
                }
            
                if let reactions = reactions {
                    attributes.append(ReactionsMessageAttribute(apiReactions: reactions))
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
            
                if (flags & (1 << 9)) != 0 {
                    storeFlags.insert(.ReactionsArePossible)
                }
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: attributes, media: media)
            }
    }
}
