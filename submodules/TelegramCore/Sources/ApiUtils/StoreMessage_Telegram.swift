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
        case let .message(_, _, _, _, _, messagePeerId, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            let chatPeerId = messagePeerId
            return chatPeerId.peerId
        case let .messageEmpty(_, _, peerId):
            if let peerId = peerId {
                return peerId.peerId
            } else {
                return nil
            }
        case let .messageService(_, _, _, chatPeerId, _, _, _, _, _):
            return chatPeerId.peerId
    }
}

func apiMessagePeerIds(_ message: Api.Message) -> [PeerId] {
    switch message {
        case let .message(_, _, _, fromId, _, chatPeerId, savedPeerId, fwdHeader, viaBotId, viaBusinessBotId, replyTo, _, _, media, _, entities, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            let peerId: PeerId = chatPeerId.peerId
            
            var result = [peerId]
            
            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
        
            if let fwdHeader = fwdHeader {
                switch fwdHeader {
                    case let .messageFwdHeader(_, fromId, _, _, _, _, savedFromPeer, _, savedFromId, _, _, _):
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
        
            if let replyTo = replyTo {
                switch replyTo {
                case let .messageReplyStoryHeader(peer, _):
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
        case let .messageService(_, _, fromId, chatPeerId, _, _, action, _, _):
            let peerId: PeerId = chatPeerId.peerId
            var result = [peerId]
            
            let resolvedFromId = fromId?.peerId ?? chatPeerId.peerId
            
            if resolvedFromId != peerId {
                result.append(resolvedFromId)
            }
            
            switch action {
            case .messageActionChannelCreate, .messageActionChatDeletePhoto, .messageActionChatEditPhoto, .messageActionChatEditTitle, .messageActionEmpty, .messageActionPinMessage, .messageActionHistoryClear, .messageActionGameScore, .messageActionPaymentSent, .messageActionPaymentSentMe, .messageActionPhoneCall, .messageActionScreenshotTaken, .messageActionCustomAction, .messageActionBotAllowed, .messageActionSecureValuesSent, .messageActionSecureValuesSentMe, .messageActionContactSignUp, .messageActionGroupCall, .messageActionSetMessagesTTL, .messageActionGroupCallScheduled, .messageActionSetChatTheme, .messageActionChatJoinedByRequest, .messageActionWebViewDataSent, .messageActionWebViewDataSentMe, .messageActionGiftPremium, .messageActionGiftStars, .messageActionTopicCreate, .messageActionTopicEdit, .messageActionSuggestProfilePhoto, .messageActionSetChatWallPaper, .messageActionGiveawayLaunch, .messageActionGiveawayResults, .messageActionBoostApply, .messageActionRequestedPeerSentMe, .messageActionStarGift, .messageActionStarGiftUnique, .messageActionPaidMessagesRefunded, .messageActionPaidMessagesPrice:
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
                case let .messageActionRequestedPeer(_, peers):
                    result.append(contentsOf: peers.map(\.peerId))
                case let .messageActionGiftCode(_, boostPeer, _, _, _, _, _, _, _):
                    if let boostPeer = boostPeer {
                        result.append(boostPeer.peerId)
                    }
                case let .messageActionPrizeStars(_, _, _, boostPeer, _):
                    result.append(boostPeer.peerId)
                case let .messageActionPaymentRefunded(_, peer, _, _, _, _):
                    result.append(peer.peerId)
                case let .messageActionConferenceCall(_, _, _, otherParticipants):
                    if let otherParticipants {
                        result.append(contentsOf: otherParticipants.map(\.peerId))
                    }
            }
        
            return result
    }
}

func apiMessageAssociatedMessageIds(_ message: Api.Message) -> (replyIds: ReferencedReplyMessageIds, generalIds: [MessageId])? {
    switch message {
        case let .message(_, _, id, _, _, chatPeerId, _, _, _, _, replyTo, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
            if let replyTo = replyTo {
                let peerId: PeerId = chatPeerId.peerId
                
                switch replyTo {
                case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset):
                    let _ = replyHeader
                    let _ = replyMedia
                    let _ = replyToTopId
                    let _ = quoteText
                    let _ = quoteEntities
                    let _ = quoteOffset
                    
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
        case let .messageService(_, id, _, chatPeerId, replyHeader, _, _, _, _):
            if let replyHeader = replyHeader {
                switch replyHeader {
                case let .messageReplyHeader(_, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset):
                    let _ = replyHeader
                    let _ = replyMedia
                    let _ = replyToTopId
                    let _ = quoteText
                    let _ = quoteEntities
                    let _ = quoteOffset
                    
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
        case let .messageMediaPhoto(flags, photo, ttlSeconds):
            if let photo = photo {
                if let mediaImage = telegramMediaImageFromApiPhoto(photo) {
                    return (mediaImage, ttlSeconds, nil, (flags & (1 << 3)) != 0, nil, nil)
                }
            } else {
                return (TelegramMediaExpiredContent(data: .image), nil, nil, nil, nil, nil)
            }
        case let .messageMediaContact(phoneNumber, firstName, lastName, vcard, userId):
            let contactPeerId: PeerId? = userId == 0 ? nil : PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            let mediaContact = TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: contactPeerId, vCardData: vcard.isEmpty ? nil : vcard)
            return (mediaContact, nil, nil, nil, nil, nil)
        case let .messageMediaGeo(geo):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaVenue(geo, title, address, provider, venueId, venueType):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: title, address: address, provider: provider, venueId: venueId, venueType: venueType, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil, heading: nil)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaGeoLive(_, geo, heading, period, proximityNotificationRadius):
            let mediaMap = telegramMediaMapFromApiGeoPoint(geo, title: nil, address: nil, provider: nil, venueId: nil, venueType: nil, liveBroadcastingTimeout: period, liveProximityNotificationRadius: proximityNotificationRadius, heading: heading)
            return (mediaMap, nil, nil, nil, nil, nil)
        case let .messageMediaDocument(flags, document, altDocuments, coverPhoto, videoTimestamp, ttlSeconds):
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
        case let .messageMediaWebPage(flags, webpage):
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
        case let .messageMediaGame(game):
            return (TelegramMediaGame(apiGame: game), nil, nil, nil, nil, nil)
        case let .messageMediaInvoice(flags, title, description, photo, receiptMsgId, currency, totalAmount, startParam, apiExtendedMedia):
            var parsedFlags = TelegramMediaInvoiceFlags()
            if (flags & (1 << 3)) != 0 {
                parsedFlags.insert(.isTest)
            }
            if (flags & (1 << 1)) != 0 {
                parsedFlags.insert(.shippingAddressRequested)
            }
            return (TelegramMediaInvoice(title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init), receiptMessageId: receiptMsgId.flatMap { MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }, currency: currency, totalAmount: totalAmount, startParam: startParam, extendedMedia: apiExtendedMedia.flatMap({ TelegramExtendedMedia(apiExtendedMedia: $0, peerId: peerId) }), subscriptionPeriod: nil, flags: parsedFlags, version: TelegramMediaInvoice.lastVersion), nil, nil, nil, nil, nil)
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
                
                let questionText: String
                let questionEntities: [MessageTextEntity]
                switch question {
                case let .textWithEntities(text, entities):
                    questionText = text
                    questionEntities = messageTextEntitiesFromApiEntities(entities)
                }
                
                return (TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.CloudPoll, id: id), publicity: publicity, kind: kind, text: questionText, textEntities: questionEntities, options: answers.map(TelegramMediaPollOption.init(apiOption:)), correctAnswers: nil, results: TelegramMediaPollResults(apiResults: results), isClosed: (flags & (1 << 0)) != 0, deadlineTimeout: closePeriod), nil, nil, nil, nil, nil)
            }
        case let .messageMediaDice(value, emoticon):
            return (TelegramMediaDice(emoji: emoticon, value: value), nil, nil, nil, nil, nil)
        case let .messageMediaStory(flags, peerId, id, _):
            let isMention = (flags & (1 << 1)) != 0
            return (TelegramMediaStory(storyId: StoryId(peerId: peerId.peerId, id: id), isMention: isMention), nil, nil, nil, nil, nil)
        case let .messageMediaGiveaway(apiFlags, channels, countries, prizeDescription, quantity, months, stars, untilDate):
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
        case let .messageMediaGiveawayResults(apiFlags, channelId, additionalPeersCount, launchMsgId, winnersCount, unclaimedCount, winners, months, stars, prizeDescription, untilDate):
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
        case let .messageMediaPaidMedia(starsAmount, apiExtendedMedia):
            return (TelegramMediaPaidContent(amount: starsAmount, extendedMedia: apiExtendedMedia.compactMap({ TelegramExtendedMedia(apiExtendedMedia: $0, peerId: peerId) })), nil, nil, nil, nil, nil)
        }
    }
    
    return (nil, nil, nil, nil, nil, nil)
}

func mediaAreaFromApiMediaArea(_ mediaArea: Api.MediaArea) -> MediaArea? {
    func coodinatesFromApiMediaAreaCoordinates(_ coordinates: Api.MediaAreaCoordinates) -> MediaArea.Coordinates {
        switch coordinates {
        case let .mediaAreaCoordinates(_, x, y, width, height, rotation, radius):
            return MediaArea.Coordinates(x: x, y: y, width: width, height: height, rotation: rotation, cornerRadius: radius)
        }
    }
    switch mediaArea {
    case .inputMediaAreaChannelPost:
        return nil
    case .inputMediaAreaVenue:
        return nil
    case let .mediaAreaGeoPoint(_, coordinates, geo, address):
        let latitude: Double
        let longitude: Double
        switch geo {
        case let .geoPoint(_, long, lat, _, _):
            latitude = lat
            longitude = long
        case .geoPointEmpty:
            latitude = 0.0
            longitude = 0.0
        }
        
        var mappedAddress: MapGeoAddress?
        if let address {
            switch address {
            case let .geoPointAddress(_, countryIso2, state, city, street):
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
    case let .mediaAreaVenue(coordinates, geo, title, address, provider, venueId, venueType):
        let latitude: Double
        let longitude: Double
        switch geo {
        case let .geoPoint(_, long, lat, _, _):
            latitude = lat
            longitude = long
        case .geoPointEmpty:
            latitude = 0.0
            longitude = 0.0
        }
        return .venue(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), venue: MediaArea.Venue(latitude: latitude, longitude: longitude, venue: MapVenue(title: title, address: address, provider: provider, id: venueId, type: venueType), address: nil, queryId: nil, resultId: nil))
    case let .mediaAreaSuggestedReaction(flags, coordinates, reaction):
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
    case let .mediaAreaUrl(coordinates, url):
        return .link(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), url: url)
    case let .mediaAreaChannelPost(coordinates, channelId, messageId):
        return .channelMessage(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), messageId: EngineMessage.Id(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), namespace: Namespaces.Message.Cloud, id: messageId))
    case let .mediaAreaWeather(coordinates, emoji, temperatureC, color):
        return .weather(coordinates: coodinatesFromApiMediaAreaCoordinates(coordinates), emoji: emoji, temperature: temperatureC, color: color)
    case let .mediaAreaStarGift(coordinates, slug):
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
        let inputCoordinates = Api.MediaAreaCoordinates.mediaAreaCoordinates(flags: flags, x: coordinates.x, y: coordinates.y, w: coordinates.width, h: coordinates.height, rotation: coordinates.rotation, radius: coordinates.cornerRadius)
        switch area {
        case let .venue(_, venue):
            if let queryId = venue.queryId, let resultId = venue.resultId {
                apiMediaAreas.append(.inputMediaAreaVenue(coordinates: inputCoordinates, queryId: queryId, resultId: resultId))
            } else if let venueInfo = venue.venue {
                apiMediaAreas.append(.mediaAreaVenue(coordinates: inputCoordinates, geo: .geoPoint(flags: 0, long: venue.longitude, lat: venue.latitude, accessHash: 0, accuracyRadius: nil), title: venueInfo.title, address: venueInfo.address ?? "", provider: venueInfo.provider ?? "", venueId: venueInfo.id ?? "", venueType: venueInfo.type ?? ""))
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
                    inputAddress = .geoPointAddress(flags: addressFlags, countryIso2: address.country, state: address.state, city: address.city, street: address.street)
                    flags |= (1 << 0)
                }
                apiMediaAreas.append(.mediaAreaGeoPoint(flags: flags, coordinates: inputCoordinates, geo: .geoPoint(flags: 0, long: venue.longitude, lat: venue.latitude, accessHash: 0, accuracyRadius: nil), address: inputAddress))
            }
        case let .reaction(_, reaction, flags):
            var apiFlags: Int32 = 0
            if flags.contains(.isDark) {
                apiFlags |= (1 << 0)
            }
            if flags.contains(.isFlipped) {
                apiFlags |= (1 << 1)
            }
            apiMediaAreas.append(.mediaAreaSuggestedReaction(flags: apiFlags, coordinates: inputCoordinates, reaction: reaction.apiReaction))
        case let .channelMessage(_, messageId):
            if let transaction, let peer = transaction.getPeer(messageId.peerId), let inputChannel = apiInputChannel(peer) {
                apiMediaAreas.append(.inputMediaAreaChannelPost(coordinates: inputCoordinates, channel: inputChannel, msgId: messageId.id))
            }
        case let .link(_, url):
            apiMediaAreas.append(.mediaAreaUrl(coordinates: inputCoordinates, url: url))
        case let .weather(_, emoji, temperature, color):
            apiMediaAreas.append(.mediaAreaWeather(coordinates: inputCoordinates, emoji: emoji, temperatureC: temperature, color: color))
        case let .starGift(_, slug):
            apiMediaAreas.append(.mediaAreaStarGift(coordinates: inputCoordinates, slug: slug))
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
        case let .messageEntityPre(offset, length, language):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .Pre(language: language)))
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
        case let .messageEntityBlockquote(flags, offset, length):
            result.append(MessageTextEntity(range: Int(offset) ..< Int(offset + length), type: .BlockQuote(isCollapsed: (flags & (1 << 0)) != 0)))
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
    convenience init?(apiMessage: Api.Message, accountPeerId: PeerId, peerIsForum: Bool, namespace: MessageId.Namespace = Namespaces.Message.Cloud) {
        switch apiMessage {
            case let .message(flags, flags2, id, fromId, boosts, chatPeerId, savedPeerId, fwdFrom, viaBotId, viaBusinessBotId, replyTo, date, message, media, replyMarkup, entities, views, forwards, replies, editDate, postAuthor, groupingId, reactions, restrictionReason, ttlPeriod, quickReplyShortcutId, messageEffectId, factCheck, reportDeliveryUntilDate, paidMessageStars):
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
                    case let .peerChat(chatId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
                        authorId = resolvedFromId
                    case let .peerChannel(channelId):
                        peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))
                        authorId = resolvedFromId
                }
                
                var threadId: Int64?
                if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(innerFlags, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset):
                        let isForumTopic = (innerFlags & (1 << 3)) != 0
                        
                        var quote: EngineMessageReplyQuote?
                        let isQuote = (innerFlags & (1 << 9)) != 0
                        
                        if quoteText != nil || replyMedia != nil {
                            quote = EngineMessageReplyQuote(text: quoteText ?? "", offset: quoteOffset.flatMap(Int.init), entities: messageTextEntitiesFromApiEntities(quoteEntities ?? []), media: textMediaAndExpirationTimerFromApiMedia(replyMedia, peerId).media)
                        }
                        
                        if let replyToMsgId = replyToMsgId {
                            let replyPeerId = replyToPeerId?.peerId ?? peerId
                            if let replyToTopId = replyToTopId {
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
                            }
                            attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId, quote: quote, isQuote: isQuote))
                        }
                        if let replyHeader = replyHeader {
                            attributes.append(QuotedReplyMessageAttribute(apiHeader: replyHeader, quote: quote, isQuote: isQuote))
                        }
                    case let .messageReplyStoryHeader(peer, storyId):
                        attributes.append(ReplyStoryAttribute(storyId: StoryId(peerId: peer.peerId, id: storyId)))
                    }
                }
            
                if threadId == nil && peerId.namespace == Namespaces.Peer.CloudChannel {
                    threadId = 1
                }
                
                var forwardInfo: StoreMessageForwardInfo?
                if let fwdFrom = fwdFrom {
                    switch fwdFrom {
                        case let .messageFwdHeader(flags, fromId, fromName, date, channelPost, postAuthor, savedFromPeer, savedFromMsgId, savedFromId, savedFromName, savedDate, psaType):
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
            
                if let messageEffectId {
                    attributes.append(EffectMessageAttribute(id: messageEffectId))
                }
            
                if let factCheck {
                    switch factCheck {
                    case let .factCheck(_, country, text, hash):
                        let content: FactCheckMessageAttribute.Content
                        if let text, let country {
                            switch text {
                            case let .textWithEntities(text, entities):
                                content = .Loaded(text: text, entities: messageTextEntitiesFromApiEntities(entities), country: country)
                            }
                        } else {
                            content = .Pending
                        }
                        attributes.append(FactCheckMessageAttribute(content: content, hash: hash))
                    }
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
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: groupingId, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: medias)
            case .messageEmpty:
                return nil
            case let .messageService(flags, id, fromId, chatPeerId, replyTo, date, action, reactions, ttlPeriod):
                let peerId: PeerId = chatPeerId.peerId
                let authorId: PeerId? = fromId?.peerId ?? chatPeerId.peerId
                
                var attributes: [MessageAttribute] = []
                
                var threadId: Int64?
                if let replyTo = replyTo {
                    var threadMessageId: MessageId?
                    switch replyTo {
                    case let .messageReplyHeader(innerFlags, replyToMsgId, replyToPeerId, replyHeader, replyMedia, replyToTopId, quoteText, quoteEntities, quoteOffset):
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
                            attributes.append(ReplyMessageAttribute(messageId: MessageId(peerId: replyPeerId, namespace: Namespaces.Message.Cloud, id: replyToMsgId), threadMessageId: threadMessageId, quote: quote, isQuote: isQuote))
                        } else if let replyHeader = replyHeader {
                            attributes.append(QuotedReplyMessageAttribute(apiHeader: replyHeader, quote: quote, isQuote: isQuote))
                        }
                    case let .messageReplyStoryHeader(peer, storyId):
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
                
                if (flags & (1 << 17)) != 0 {
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
                
                self.init(id: MessageId(peerId: peerId, namespace: namespace, id: id), globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: date, flags: storeFlags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: nil, authorId: authorId, text: "", attributes: attributes, media: media)
            }
    }
}
