import Foundation
import Postbox
import TelegramApi


func telegramMediaActionFromApiAction(_ action: Api.MessageAction) -> TelegramMediaAction? {
    switch action {
    case let .messageActionChannelCreate(title):
        return TelegramMediaAction(action: .groupCreated(title: title))
    case let .messageActionChannelMigrateFrom(title, chatId):
        return TelegramMediaAction(action: .channelMigratedFromGroup(title: title, groupId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))))
    case let .messageActionChatAddUser(users):
        return TelegramMediaAction(action: .addedMembers(peerIds: users.map({ PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) })))
    case let .messageActionChatCreate(title, _):
        return TelegramMediaAction(action: .groupCreated(title: title))
    case .messageActionChatDeletePhoto:
        return TelegramMediaAction(action: .photoUpdated(image: nil))
    case let .messageActionChatDeleteUser(userId):
        return TelegramMediaAction(action: .removedMembers(peerIds: [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]))
    case let .messageActionChatEditPhoto(photo):
        return TelegramMediaAction(action: .photoUpdated(image: telegramMediaImageFromApiPhoto(photo)))
    case let .messageActionChatEditTitle(title):
        return TelegramMediaAction(action: .titleUpdated(title: title))
    case let .messageActionChatJoinedByLink(inviterId):
        return TelegramMediaAction(action: .joinedByLink(inviter: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))))
    case let .messageActionChatMigrateTo(channelId):
        return TelegramMediaAction(action: .groupMigratedToChannel(channelId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))))
    case .messageActionHistoryClear:
        return TelegramMediaAction(action: .historyCleared)
    case .messageActionPinMessage:
        return TelegramMediaAction(action: .pinnedMessageUpdated)
    case let .messageActionGameScore(gameId, score):
        return TelegramMediaAction(action: .gameScore(gameId: gameId, score: score))
    case let .messageActionPhoneCall(flags, callId, reason, duration):
        var discardReason: PhoneCallDiscardReason?
        if let reason = reason {
            discardReason = PhoneCallDiscardReason(apiReason: reason)
        }
        let isVideo = (flags & (1 << 2)) != 0
        return TelegramMediaAction(action: .phoneCall(callId: callId, discardReason: discardReason, duration: duration, isVideo: isVideo))
    case .messageActionEmpty:
        return nil
    case let .messageActionPaymentSent(flags, currency, totalAmount, invoiceSlug, subscriptionUntilDate):
        let _ = subscriptionUntilDate
        let isRecurringInit = (flags & (1 << 2)) != 0
        let isRecurringUsed = (flags & (1 << 3)) != 0
        return TelegramMediaAction(action: .paymentSent(currency: currency, totalAmount: totalAmount, invoiceSlug: invoiceSlug, isRecurringInit: isRecurringInit, isRecurringUsed: isRecurringUsed))
    case .messageActionPaymentSentMe:
        return nil
    case .messageActionScreenshotTaken:
        return TelegramMediaAction(action: .historyScreenshot)
    case let .messageActionCustomAction(message):
        return TelegramMediaAction(action: .customText(text: message, entities: [], additionalAttributes: nil))
    case let .messageActionBotAllowed(flags, domain, app):
        if let domain = domain {
            return TelegramMediaAction(action: .botDomainAccessGranted(domain: domain))
        } else {
            var appName: String?
            if case let .botApp(_, _, _, _, appNameValue, _, _, _, _) = app {
                appName = appNameValue
            }
            var type: BotSendMessageAccessGrantedType?
            if (flags & (1 << 1)) != 0 {
                type = .attachMenu
            }
            if (flags & (1 << 3)) != 0 {
                type = .request
            }
            return TelegramMediaAction(action: .botAppAccessGranted(appName: appName, type: type))
        }
    case .messageActionSecureValuesSentMe:
        return nil
    case let .messageActionSecureValuesSent(types):
        return TelegramMediaAction(action: .botSentSecureValues(types: types.map(SentSecureValueType.init)))
    case .messageActionContactSignUp:
        return TelegramMediaAction(action: .peerJoined)
    case let .messageActionGeoProximityReached(fromId, toId, distance):
        return TelegramMediaAction(action: .geoProximityReached(from: fromId.peerId, to: toId.peerId, distance: distance))
    case let .messageActionGroupCall(_, call, duration):
        switch call {
        case let .inputGroupCall(id, accessHash):
            return TelegramMediaAction(action: .groupPhoneCall(callId: id, accessHash: accessHash, scheduleDate: nil, duration: duration))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionInviteToGroupCall(call, userIds):
        switch call {
        case let .inputGroupCall(id, accessHash):
            return TelegramMediaAction(action: .inviteToGroupPhoneCall(callId: id, accessHash: accessHash, peerIds: userIds.map { userId in
                PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            }))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionSetMessagesTTL(_, period, autoSettingFrom):
        return TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(period: period, autoSettingSource: autoSettingFrom.flatMap { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }))
    case let .messageActionGroupCallScheduled(call, scheduleDate):
        switch call {
        case let .inputGroupCall(id, accessHash):
            return TelegramMediaAction(action: .groupPhoneCall(callId: id, accessHash: accessHash, scheduleDate: scheduleDate, duration: nil))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionSetChatTheme(emoji):
        return TelegramMediaAction(action: .setChatTheme(emoji: emoji))
    case .messageActionChatJoinedByRequest:
        return TelegramMediaAction(action: .joinedByRequest)
    case let .messageActionWebViewDataSentMe(text, _), let .messageActionWebViewDataSent(text):
        return TelegramMediaAction(action: .webViewData(text))
    case let .messageActionGiftPremium(_, currency, amount, months, cryptoCurrency, cryptoAmount, message):
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textValue, entitiesValue):
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        return TelegramMediaAction(action: .giftPremium(currency: currency, amount: amount, months: months, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, text: text, entities: entities))
    case let .messageActionGiftStars(_, currency, amount, stars, cryptoCurrency, cryptoAmount, transactionId):
        return TelegramMediaAction(action: .giftStars(currency: currency, amount: amount, count: stars, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, transactionId: transactionId))
    case let .messageActionTopicCreate(_, title, iconColor, iconEmojiId):
        return TelegramMediaAction(action: .topicCreated(title: title, iconColor: iconColor, iconFileId: iconEmojiId))
    case let .messageActionTopicEdit(flags, title, iconEmojiId, closed, hidden):
        var components: [TelegramMediaActionType.ForumTopicEditComponent] = []
        if let title = title {
            components.append(.title(title))
        }
        if (flags & (1 << 1)) != 0 {
            components.append(.iconFileId(iconEmojiId == 0 ? nil : iconEmojiId))
        }
        if let closed = closed {
            components.append(.isClosed(closed == .boolTrue))
        }
        if let hidden = hidden {
            components.append(.isHidden(hidden == .boolTrue))
        }
        return TelegramMediaAction(action: .topicEdited(components: components))
    case let .messageActionSuggestProfilePhoto(photo):
        return TelegramMediaAction(action: .suggestedProfilePhoto(image: telegramMediaImageFromApiPhoto(photo)))
    case let .messageActionRequestedPeer(buttonId, peers):
        return TelegramMediaAction(action: .requestedPeer(buttonId: buttonId, peerIds: peers.map { $0.peerId }))
    case let .messageActionRequestedPeerSentMe(buttonId, _):
        return TelegramMediaAction(action: .requestedPeer(buttonId: buttonId, peerIds: []))
    case let .messageActionSetChatWallPaper(flags, wallpaper):
        if (flags & (1 << 0)) != 0 {
            return TelegramMediaAction(action: .setSameChatWallpaper(wallpaper: TelegramWallpaper(apiWallpaper: wallpaper)))
        } else {
            return TelegramMediaAction(action: .setChatWallpaper(wallpaper: TelegramWallpaper(apiWallpaper: wallpaper), forBoth: (flags & (1 << 1)) != 0))
        }
    case let .messageActionGiftCode(flags, boostPeer, months, slug, currency, amount, cryptoCurrency, cryptoAmount, message):
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textValue, entitiesValue):
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        return TelegramMediaAction(action: .giftCode(slug: slug, fromGiveaway: (flags & (1 << 0)) != 0, isUnclaimed: (flags & (1 << 5)) != 0, boostPeerId: boostPeer?.peerId, months: months, currency: currency, amount: amount, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, text: text, entities: entities))
    case let .messageActionGiveawayLaunch(_, stars):
        return TelegramMediaAction(action: .giveawayLaunched(stars: stars))
    case let .messageActionGiveawayResults(flags, winners, unclaimed):
        return TelegramMediaAction(action: .giveawayResults(winners: winners, unclaimed: unclaimed, stars: (flags & (1 << 0)) != 0))
    case let .messageActionBoostApply(boosts):
        return TelegramMediaAction(action: .boostsApplied(boosts: boosts))
    case let .messageActionPaymentRefunded(_, peer, currency, totalAmount, payload, charge):
        let transactionId: String
        switch charge {
        case let .paymentCharge(id, _):
            transactionId = id
        }
        return TelegramMediaAction(action: .paymentRefunded(peerId: peer.peerId, currency: currency, totalAmount: totalAmount, payload: payload?.makeData(), transactionId: transactionId))
    case let .messageActionPrizeStars(flags, stars, transactionId, boostPeer, giveawayMsgId):
        return TelegramMediaAction(action: .prizeStars(amount: stars, isUnclaimed: (flags & (1 << 2)) != 0, boostPeerId: boostPeer.peerId, transactionId: transactionId, giveawayMessageId: MessageId(peerId: boostPeer.peerId, namespace: Namespaces.Message.Cloud, id: giveawayMsgId)))
    case let .messageActionStarGift(flags, apiGift, message, convertStars, upgradeMessageId, upgradeStars, fromId, peer, savedId):
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textValue, entitiesValue):
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGift(gift: gift, convertStars: convertStars, text: text, entities: entities, nameHidden: (flags & (1 << 0)) != 0, savedToProfile: (flags & (1 << 2)) != 0, converted: (flags & (1 << 3)) != 0, upgraded: (flags & (1 << 5)) != 0, canUpgrade: (flags & (1 << 10)) != 0, upgradeStars: upgradeStars, isRefunded: (flags & (1 << 9)) != 0, upgradeMessageId: upgradeMessageId, peerId: peer?.peerId, senderId: fromId?.peerId, savedId: savedId))
    case let .messageActionStarGiftUnique(flags, apiGift, canExportAt, transferStars, fromId, peer, savedId, resaleStars, canTransferDate, canResaleDate):
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGiftUnique(gift: gift, isUpgrade: (flags & (1 << 0)) != 0, isTransferred: (flags & (1 << 1)) != 0, savedToProfile: (flags & (1 << 2)) != 0, canExportDate: canExportAt, transferStars: transferStars, isRefunded: (flags & (1 << 5)) != 0, peerId: peer?.peerId, senderId: fromId?.peerId, savedId: savedId, resaleStars: resaleStars, canTransferDate: canTransferDate, canResaleDate: canResaleDate))
    case let .messageActionPaidMessagesRefunded(count, stars):
        return TelegramMediaAction(action: .paidMessagesRefunded(count: count, stars: stars))
    case let .messageActionPaidMessagesPrice(flags, stars):
        let broadcastMessagesAllowed = (flags & (1 << 0)) != 0
        return TelegramMediaAction(action: .paidMessagesPriceEdited(stars: stars, broadcastMessagesAllowed: broadcastMessagesAllowed))
    case let .messageActionConferenceCall(flags, callId, duration, otherParticipants):
        let isMissed = (flags & (1 << 0)) != 0
        let isActive = (flags & (1 << 1)) != 0
        let isVideo = (flags & (1 << 4)) != 0

        var mappedFlags = TelegramMediaActionType.ConferenceCall.Flags()
        if isMissed {
            mappedFlags.insert(.isMissed)
        }
        if isActive {
            mappedFlags.insert(.isActive)
        }
        if isVideo {
            mappedFlags.insert(.isVideo)
        }

        return TelegramMediaAction(action: .conferenceCall(TelegramMediaActionType.ConferenceCall(
            callId: callId,
            duration: duration,
            flags: mappedFlags,
            otherParticipants: otherParticipants.flatMap({ return $0.map(\.peerId) }) ?? []
        )))
    }
}

extension PhoneCallDiscardReason {
    init(apiReason: Api.PhoneCallDiscardReason) {
        switch apiReason {
        case .phoneCallDiscardReasonBusy:
            self = .busy
        case .phoneCallDiscardReasonDisconnect:
            self = .disconnect
        case .phoneCallDiscardReasonHangup:
            self = .hangup
        case .phoneCallDiscardReasonMissed:
            self = .missed
        case .phoneCallDiscardReasonMigrateConferenceCall:
            self = .hangup
        }
    }
}

extension SentSecureValueType {
    init(apiType: Api.SecureValueType) {
        switch apiType {
            case .secureValueTypePersonalDetails:
                self = .personalDetails
            case .secureValueTypePassport:
                self = .passport
            case .secureValueTypeDriverLicense:
                self = .driversLicense
            case .secureValueTypeIdentityCard:
                self = .idCard
            case .secureValueTypeAddress:
                self = .address
            case .secureValueTypeBankStatement:
                self = .bankStatement
            case .secureValueTypeUtilityBill:
                self = .utilityBill
            case .secureValueTypeRentalAgreement:
                self = .rentalAgreement
            case .secureValueTypePhone:
                self = .phone
            case .secureValueTypeEmail:
                self = .email
            case .secureValueTypeInternalPassport:
                self = .internalPassport
            case .secureValueTypePassportRegistration:
                self = .passportRegistration
            case .secureValueTypeTemporaryRegistration:
                self = .temporaryRegistration
        }
    }
}
