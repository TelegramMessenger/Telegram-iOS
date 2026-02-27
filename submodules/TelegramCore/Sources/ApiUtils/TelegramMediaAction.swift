import Foundation
import Postbox
import TelegramApi


func telegramMediaActionFromApiAction(_ action: Api.MessageAction) -> TelegramMediaAction? {
    switch action {
    case let .messageActionChannelCreate(messageActionChannelCreateData):
        let title = messageActionChannelCreateData.title
        return TelegramMediaAction(action: .groupCreated(title: title))
    case let .messageActionChannelMigrateFrom(messageActionChannelMigrateFromData):
        let (title, chatId) = (messageActionChannelMigrateFromData.title, messageActionChannelMigrateFromData.chatId)
        return TelegramMediaAction(action: .channelMigratedFromGroup(title: title, groupId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))))
    case let .messageActionChatAddUser(messageActionChatAddUserData):
        let users = messageActionChatAddUserData.users
        return TelegramMediaAction(action: .addedMembers(peerIds: users.map({ PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) })))
    case let .messageActionChatCreate(messageActionChatCreateData):
        let title = messageActionChatCreateData.title
        return TelegramMediaAction(action: .groupCreated(title: title))
    case .messageActionChatDeletePhoto:
        return TelegramMediaAction(action: .photoUpdated(image: nil))
    case let .messageActionChatDeleteUser(messageActionChatDeleteUserData):
        let userId = messageActionChatDeleteUserData.userId
        return TelegramMediaAction(action: .removedMembers(peerIds: [PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))]))
    case let .messageActionChatEditPhoto(messageActionChatEditPhotoData):
        let photo = messageActionChatEditPhotoData.photo
        return TelegramMediaAction(action: .photoUpdated(image: telegramMediaImageFromApiPhoto(photo)))
    case let .messageActionChatEditTitle(messageActionChatEditTitleData):
        let title = messageActionChatEditTitleData.title
        return TelegramMediaAction(action: .titleUpdated(title: title))
    case let .messageActionChatJoinedByLink(messageActionChatJoinedByLinkData):
        let inviterId = messageActionChatJoinedByLinkData.inviterId
        return TelegramMediaAction(action: .joinedByLink(inviter: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(inviterId))))
    case let .messageActionChatMigrateTo(messageActionChatMigrateToData):
        let channelId = messageActionChatMigrateToData.channelId
        return TelegramMediaAction(action: .groupMigratedToChannel(channelId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId))))
    case .messageActionHistoryClear:
        return TelegramMediaAction(action: .historyCleared)
    case .messageActionPinMessage:
        return TelegramMediaAction(action: .pinnedMessageUpdated)
    case let .messageActionGameScore(messageActionGameScoreData):
        let (gameId, score) = (messageActionGameScoreData.gameId, messageActionGameScoreData.score)
        return TelegramMediaAction(action: .gameScore(gameId: gameId, score: score))
    case let .messageActionPhoneCall(messageActionPhoneCallData):
        let (flags, callId, reason, duration) = (messageActionPhoneCallData.flags, messageActionPhoneCallData.callId, messageActionPhoneCallData.reason, messageActionPhoneCallData.duration)
        var discardReason: PhoneCallDiscardReason?
        if let reason = reason {
            discardReason = PhoneCallDiscardReason(apiReason: reason)
        }
        let isVideo = (flags & (1 << 2)) != 0
        return TelegramMediaAction(action: .phoneCall(callId: callId, discardReason: discardReason, duration: duration, isVideo: isVideo))
    case .messageActionEmpty:
        return nil
    case let .messageActionPaymentSent(messageActionPaymentSentData):
        let (flags, currency, totalAmount, invoiceSlug, subscriptionUntilDate) = (messageActionPaymentSentData.flags, messageActionPaymentSentData.currency, messageActionPaymentSentData.totalAmount, messageActionPaymentSentData.invoiceSlug, messageActionPaymentSentData.subscriptionUntilDate)
        let _ = subscriptionUntilDate
        let isRecurringInit = (flags & (1 << 2)) != 0
        let isRecurringUsed = (flags & (1 << 3)) != 0
        return TelegramMediaAction(action: .paymentSent(currency: currency, totalAmount: totalAmount, invoiceSlug: invoiceSlug, isRecurringInit: isRecurringInit, isRecurringUsed: isRecurringUsed))
    case .messageActionPaymentSentMe:
        return nil
    case .messageActionScreenshotTaken:
        return TelegramMediaAction(action: .historyScreenshot)
    case let .messageActionCustomAction(messageActionCustomActionData):
        let message = messageActionCustomActionData.message
        return TelegramMediaAction(action: .customText(text: message, entities: [], additionalAttributes: nil))
    case let .messageActionBotAllowed(messageActionBotAllowedData):
        let (flags, domain, app) = (messageActionBotAllowedData.flags, messageActionBotAllowedData.domain, messageActionBotAllowedData.app)
        if let domain = domain {
            return TelegramMediaAction(action: .botDomainAccessGranted(domain: domain))
        } else {
            var appName: String?
            if case let .botApp(botAppData) = app {
                let appNameValue = botAppData.title
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
    case let .messageActionSecureValuesSent(messageActionSecureValuesSentData):
        let types = messageActionSecureValuesSentData.types
        return TelegramMediaAction(action: .botSentSecureValues(types: types.map(SentSecureValueType.init)))
    case .messageActionContactSignUp:
        return TelegramMediaAction(action: .peerJoined)
    case let .messageActionGeoProximityReached(messageActionGeoProximityReachedData):
        let (fromId, toId, distance) = (messageActionGeoProximityReachedData.fromId, messageActionGeoProximityReachedData.toId, messageActionGeoProximityReachedData.distance)
        return TelegramMediaAction(action: .geoProximityReached(from: fromId.peerId, to: toId.peerId, distance: distance))
    case let .messageActionGroupCall(messageActionGroupCallData):
        let (call, duration) = (messageActionGroupCallData.call, messageActionGroupCallData.duration)
        switch call {
        case let .inputGroupCall(inputGroupCallData):
            let (id, accessHash) = (inputGroupCallData.id, inputGroupCallData.accessHash)
            return TelegramMediaAction(action: .groupPhoneCall(callId: id, accessHash: accessHash, scheduleDate: nil, duration: duration))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionInviteToGroupCall(messageActionInviteToGroupCallData):
        let (call, userIds) = (messageActionInviteToGroupCallData.call, messageActionInviteToGroupCallData.users)
        switch call {
        case let .inputGroupCall(inputGroupCallData):
            let (id, accessHash) = (inputGroupCallData.id, inputGroupCallData.accessHash)
            return TelegramMediaAction(action: .inviteToGroupPhoneCall(callId: id, accessHash: accessHash, peerIds: userIds.map { userId in
                PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            }))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionSetMessagesTTL(messageActionSetMessagesTTLData):
        let (period, autoSettingFrom) = (messageActionSetMessagesTTLData.period, messageActionSetMessagesTTLData.autoSettingFrom)
        return TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(period: period, autoSettingSource: autoSettingFrom.flatMap { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }))
    case let .messageActionGroupCallScheduled(messageActionGroupCallScheduledData):
        let (call, scheduleDate) = (messageActionGroupCallScheduledData.call, messageActionGroupCallScheduledData.scheduleDate)
        switch call {
        case let .inputGroupCall(inputGroupCallData):
            let (id, accessHash) = (inputGroupCallData.id, inputGroupCallData.accessHash)
            return TelegramMediaAction(action: .groupPhoneCall(callId: id, accessHash: accessHash, scheduleDate: scheduleDate, duration: nil))
        case .inputGroupCallSlug, .inputGroupCallInviteMessage:
            return nil
        }
    case let .messageActionSetChatTheme(messageActionSetChatThemeData):
        let chatTheme = messageActionSetChatThemeData.theme
        if let chatTheme = ChatTheme(apiChatTheme: chatTheme) {
            return TelegramMediaAction(action: .setChatTheme(chatTheme: chatTheme))
        } else {
            return nil
        }
    case .messageActionChatJoinedByRequest:
        return TelegramMediaAction(action: .joinedByRequest)
    case let .messageActionWebViewDataSentMe(messageActionWebViewDataSentMeData):
        let text = messageActionWebViewDataSentMeData.text
        return TelegramMediaAction(action: .webViewData(text))
    case let .messageActionWebViewDataSent(messageActionWebViewDataSentData):
        let text = messageActionWebViewDataSentData.text
        return TelegramMediaAction(action: .webViewData(text))
    case let .messageActionGiftPremium(messageActionGiftPremiumData):
        let (currency, amount, days, cryptoCurrency, cryptoAmount, message) = (messageActionGiftPremiumData.currency, messageActionGiftPremiumData.amount, messageActionGiftPremiumData.days, messageActionGiftPremiumData.cryptoCurrency, messageActionGiftPremiumData.cryptoAmount, messageActionGiftPremiumData.message)
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textWithEntitiesData):
            let (textValue, entitiesValue) = (textWithEntitiesData.text, textWithEntitiesData.entities)
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        return TelegramMediaAction(action: .giftPremium(currency: currency, amount: amount, days: days, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, text: text, entities: entities))
    case let .messageActionGiftStars(messageActionGiftStarsData):
        let (currency, amount, stars, cryptoCurrency, cryptoAmount, transactionId) = (messageActionGiftStarsData.currency, messageActionGiftStarsData.amount, messageActionGiftStarsData.stars, messageActionGiftStarsData.cryptoCurrency, messageActionGiftStarsData.cryptoAmount, messageActionGiftStarsData.transactionId)
        return TelegramMediaAction(action: .giftStars(currency: currency, amount: amount, count: stars, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, transactionId: transactionId))
    case let .messageActionTopicCreate(messageActionTopicCreateData):
        let (title, iconColor, iconEmojiId) = (messageActionTopicCreateData.title, messageActionTopicCreateData.iconColor, messageActionTopicCreateData.iconEmojiId)
        return TelegramMediaAction(action: .topicCreated(title: title, iconColor: iconColor, iconFileId: iconEmojiId))
    case let .messageActionTopicEdit(messageActionTopicEditData):
        let (flags, title, iconEmojiId, closed, hidden) = (messageActionTopicEditData.flags, messageActionTopicEditData.title, messageActionTopicEditData.iconEmojiId, messageActionTopicEditData.closed, messageActionTopicEditData.hidden)
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
    case let .messageActionSuggestProfilePhoto(messageActionSuggestProfilePhotoData):
        let photo = messageActionSuggestProfilePhotoData.photo
        return TelegramMediaAction(action: .suggestedProfilePhoto(image: telegramMediaImageFromApiPhoto(photo)))
    case let .messageActionRequestedPeer(messageActionRequestedPeerData):
        let (buttonId, peers) = (messageActionRequestedPeerData.buttonId, messageActionRequestedPeerData.peers)
        return TelegramMediaAction(action: .requestedPeer(buttonId: buttonId, peerIds: peers.map { $0.peerId }))
    case let .messageActionRequestedPeerSentMe(messageActionRequestedPeerSentMeData):
        let buttonId = messageActionRequestedPeerSentMeData.buttonId
        return TelegramMediaAction(action: .requestedPeer(buttonId: buttonId, peerIds: []))
    case let .messageActionSetChatWallPaper(messageActionSetChatWallPaperData):
        let (flags, wallpaper) = (messageActionSetChatWallPaperData.flags, messageActionSetChatWallPaperData.wallpaper)
        if (flags & (1 << 0)) != 0 {
            return TelegramMediaAction(action: .setSameChatWallpaper(wallpaper: TelegramWallpaper(apiWallpaper: wallpaper)))
        } else {
            return TelegramMediaAction(action: .setChatWallpaper(wallpaper: TelegramWallpaper(apiWallpaper: wallpaper), forBoth: (flags & (1 << 1)) != 0))
        }
    case let .messageActionGiftCode(messageActionGiftCodeData):
        let (flags, boostPeer, days, slug, currency, amount, cryptoCurrency, cryptoAmount, message) = (messageActionGiftCodeData.flags, messageActionGiftCodeData.boostPeer, messageActionGiftCodeData.days, messageActionGiftCodeData.slug, messageActionGiftCodeData.currency, messageActionGiftCodeData.amount, messageActionGiftCodeData.cryptoCurrency, messageActionGiftCodeData.cryptoAmount, messageActionGiftCodeData.message)
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textWithEntitiesData):
            let (textValue, entitiesValue) = (textWithEntitiesData.text, textWithEntitiesData.entities)
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        return TelegramMediaAction(action: .giftCode(slug: slug, fromGiveaway: (flags & (1 << 0)) != 0, isUnclaimed: (flags & (1 << 5)) != 0, boostPeerId: boostPeer?.peerId, months: days, currency: currency, amount: amount, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, text: text, entities: entities))
    case let .messageActionGiveawayLaunch(messageActionGiveawayLaunchData):
        return TelegramMediaAction(action: .giveawayLaunched(stars: messageActionGiveawayLaunchData.stars))
    case let .messageActionGiveawayResults(messageActionGiveawayResultsData):
        let (flags, winners, unclaimed) = (messageActionGiveawayResultsData.flags, messageActionGiveawayResultsData.winnersCount, messageActionGiveawayResultsData.unclaimedCount)
        return TelegramMediaAction(action: .giveawayResults(winners: winners, unclaimed: unclaimed, stars: (flags & (1 << 0)) != 0))
    case let .messageActionBoostApply(messageActionBoostApplyData):
        let boosts = messageActionBoostApplyData.boosts
        return TelegramMediaAction(action: .boostsApplied(boosts: boosts))
    case let .messageActionPaymentRefunded(messageActionPaymentRefundedData):
        let (peer, currency, totalAmount, payload, charge) = (messageActionPaymentRefundedData.peer, messageActionPaymentRefundedData.currency, messageActionPaymentRefundedData.totalAmount, messageActionPaymentRefundedData.payload, messageActionPaymentRefundedData.charge)
        let transactionId: String
        switch charge {
        case let .paymentCharge(paymentChargeData):
            let id = paymentChargeData.id
            transactionId = id
        }
        return TelegramMediaAction(action: .paymentRefunded(peerId: peer.peerId, currency: currency, totalAmount: totalAmount, payload: payload?.makeData(), transactionId: transactionId))
    case let .messageActionPrizeStars(messageActionPrizeStarsData):
        let (flags, stars, transactionId, boostPeer, giveawayMsgId) = (messageActionPrizeStarsData.flags, messageActionPrizeStarsData.stars, messageActionPrizeStarsData.transactionId, messageActionPrizeStarsData.boostPeer, messageActionPrizeStarsData.giveawayMsgId)
        return TelegramMediaAction(action: .prizeStars(amount: stars, isUnclaimed: (flags & (1 << 2)) != 0, boostPeerId: boostPeer.peerId, transactionId: transactionId, giveawayMessageId: MessageId(peerId: boostPeer.peerId, namespace: Namespaces.Message.Cloud, id: giveawayMsgId)))
    case let .messageActionStarGift(messageActionStarGiftData):
        let (flags, apiGift, message, convertStars, upgradeMessageId, upgradeStars, fromId, peer, savedId, prepaidUpgradeHash, giftMessageId, toId, number) = (messageActionStarGiftData.flags, messageActionStarGiftData.gift, messageActionStarGiftData.message, messageActionStarGiftData.convertStars, messageActionStarGiftData.upgradeMsgId, messageActionStarGiftData.upgradeStars, messageActionStarGiftData.fromId, messageActionStarGiftData.peer, messageActionStarGiftData.savedId, messageActionStarGiftData.prepaidUpgradeHash, messageActionStarGiftData.giftMsgId, messageActionStarGiftData.toId, messageActionStarGiftData.giftNum)
        let text: String?
        let entities: [MessageTextEntity]?
        switch message {
        case let .textWithEntities(textWithEntitiesData):
            let (textValue, entitiesValue) = (textWithEntitiesData.text, textWithEntitiesData.entities)
            text = textValue
            entities = messageTextEntitiesFromApiEntities(entitiesValue)
        default:
            text = nil
            entities = nil
        }
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGift(gift: gift, convertStars: convertStars, text: text, entities: entities, nameHidden: (flags & (1 << 0)) != 0, savedToProfile: (flags & (1 << 2)) != 0, converted: (flags & (1 << 3)) != 0, upgraded: (flags & (1 << 5)) != 0, canUpgrade: (flags & (1 << 10)) != 0, upgradeStars: upgradeStars, isRefunded: (flags & (1 << 9)) != 0, isPrepaidUpgrade: (flags & (1 << 13)) != 0, upgradeMessageId: upgradeMessageId, peerId: peer?.peerId, senderId: fromId?.peerId, savedId: savedId, prepaidUpgradeHash: prepaidUpgradeHash, giftMessageId: giftMessageId, upgradeSeparate: (flags & (1 << 16)) != 0, isAuctionAcquired: (flags & (1 << 17)) != 0, toPeerId: toId?.peerId, number: number))
    case let .messageActionStarGiftUnique(messageActionStarGiftUniqueData):
        let (flags, apiGift, canExportAt, transferStars, fromId, peer, savedId, resaleAmount, canTransferDate, canResaleDate, dropOriginalDetailsStars, canCraftAt) = (messageActionStarGiftUniqueData.flags, messageActionStarGiftUniqueData.gift, messageActionStarGiftUniqueData.canExportAt, messageActionStarGiftUniqueData.transferStars, messageActionStarGiftUniqueData.fromId, messageActionStarGiftUniqueData.peer, messageActionStarGiftUniqueData.savedId, messageActionStarGiftUniqueData.resaleAmount, messageActionStarGiftUniqueData.canTransferAt, messageActionStarGiftUniqueData.canResellAt, messageActionStarGiftUniqueData.dropOriginalDetailsStars, messageActionStarGiftUniqueData.canCraftAt)
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGiftUnique(gift: gift, isUpgrade: (flags & (1 << 0)) != 0, isTransferred: (flags & (1 << 1)) != 0, savedToProfile: (flags & (1 << 2)) != 0, canExportDate: canExportAt, transferStars: transferStars, isRefunded: (flags & (1 << 5)) != 0, isPrepaidUpgrade: (flags & (1 << 11)) != 0, peerId: peer?.peerId, senderId: fromId?.peerId, savedId: savedId, resaleAmount: resaleAmount.flatMap { CurrencyAmount(apiAmount: $0) }, canTransferDate: canTransferDate, canResaleDate: canResaleDate, dropOriginalDetailsStars: dropOriginalDetailsStars, assigned: (flags & (1 << 13)) != 0, fromOffer: (flags & (1 << 14)) != 0, canCraftAt: canCraftAt, isCrafted: (flags & (1 << 16)) != 0))
    case let .messageActionPaidMessagesRefunded(messageActionPaidMessagesRefundedData):
        let (count, stars) = (messageActionPaidMessagesRefundedData.count, messageActionPaidMessagesRefundedData.stars)
        return TelegramMediaAction(action: .paidMessagesRefunded(count: count, stars: stars))
    case let .messageActionPaidMessagesPrice(messageActionPaidMessagesPriceData):
        let (flags, stars) = (messageActionPaidMessagesPriceData.flags, messageActionPaidMessagesPriceData.stars)
        let broadcastMessagesAllowed = (flags & (1 << 0)) != 0
        return TelegramMediaAction(action: .paidMessagesPriceEdited(stars: stars, broadcastMessagesAllowed: broadcastMessagesAllowed))
    case let .messageActionConferenceCall(messageActionConferenceCallData):
        let (flags, callId, duration, otherParticipants) = (messageActionConferenceCallData.flags, messageActionConferenceCallData.callId, messageActionConferenceCallData.duration, messageActionConferenceCallData.otherParticipants)
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
    case let .messageActionTodoCompletions(messageActionTodoCompletionsData):
        let (completed, incompleted) = (messageActionTodoCompletionsData.completed, messageActionTodoCompletionsData.incompleted)
        return TelegramMediaAction(action: .todoCompletions(completed: completed, incompleted: incompleted))
    case let .messageActionTodoAppendTasks(messageActionTodoAppendTasksData):
        let list = messageActionTodoAppendTasksData.list
        return TelegramMediaAction(action: .todoAppendTasks(list.map { TelegramMediaTodo.Item(apiItem: $0) }))
    case let .messageActionSuggestedPostApproval(messageActionSuggestedPostApprovalData):
        let (flags, rejectComment, scheduleDate, starsAmount) = (messageActionSuggestedPostApprovalData.flags, messageActionSuggestedPostApprovalData.rejectComment, messageActionSuggestedPostApprovalData.scheduleDate, messageActionSuggestedPostApprovalData.price)
        let status: TelegramMediaActionType.SuggestedPostApprovalStatus
        if (flags & (1 << 0)) != 0 {
            let reason: TelegramMediaActionType.SuggestedPostApprovalStatus.RejectionReason
            if (flags & (1 << 1)) != 0 {
                let balanceNeeded: CurrencyAmount
                switch starsAmount {
                case .none:
                    balanceNeeded = CurrencyAmount(amount: .zero, currency: .stars)
                case let .starsAmount(starsAmountData):
                    let (amount, nanos) = (starsAmountData.amount, starsAmountData.nanos)
                    balanceNeeded = CurrencyAmount(amount: StarsAmount(value: amount, nanos: nanos), currency: .stars)
                case let .starsTonAmount(starsTonAmountData):
                    let amount = starsTonAmountData.amount
                    balanceNeeded = CurrencyAmount(amount: StarsAmount(value: amount, nanos: 0), currency: .ton)
                }
                reason = .lowBalance(balanceNeeded: balanceNeeded)
            } else {
                reason = .generic
            }
            status = .rejected(reason: reason, comment: rejectComment)
        } else if (flags & (1 << 1)) != 0 {
            let amountValue: CurrencyAmount
            switch starsAmount {
            case .none:
                amountValue = CurrencyAmount(amount: .zero, currency: .stars)
            case let .starsAmount(starsAmountData):
                let (amount, nanos) = (starsAmountData.amount, starsAmountData.nanos)
                amountValue = CurrencyAmount(amount: StarsAmount(value: amount, nanos: nanos), currency: .stars)
            case let .starsTonAmount(starsTonAmountData):
                let amount = starsTonAmountData.amount
                amountValue = CurrencyAmount(amount: StarsAmount(value: amount, nanos: 0), currency: .ton)
            }
            status = .rejected(reason: .lowBalance(balanceNeeded: amountValue), comment: nil)
        } else {
            status = .approved(timestamp: scheduleDate, amount: starsAmount.flatMap(CurrencyAmount.init(apiAmount:)))
        }
        return TelegramMediaAction(action: .suggestedPostApprovalStatus(status: status))
    case let .messageActionGiftTon(messageActionGiftTonData):
        let (currency, amount, cryptoCurrency, cryptoAmount, transactionId) = (messageActionGiftTonData.currency, messageActionGiftTonData.amount, messageActionGiftTonData.cryptoCurrency, messageActionGiftTonData.cryptoAmount, messageActionGiftTonData.transactionId)
        return TelegramMediaAction(action: .giftTon(currency: currency, amount: amount, cryptoCurrency: cryptoCurrency, cryptoAmount: cryptoAmount, transactionId: transactionId))
    case let .messageActionSuggestedPostSuccess(messageActionSuggestedPostSuccessData):
        let price = messageActionSuggestedPostSuccessData.price
        return TelegramMediaAction(action: .suggestedPostSuccess(amount: CurrencyAmount(apiAmount: price)))
    case let .messageActionSuggestedPostRefund(messageActionSuggestedPostRefundData):
        let flags = messageActionSuggestedPostRefundData.flags
        return TelegramMediaAction(action: .suggestedPostRefund(TelegramMediaActionType.SuggestedPostRefund(isUserInitiated: (flags & (1 << 0)) != 0)))
    case let .messageActionSuggestBirthday(messageActionSuggestBirthdayData):
        let birthday = messageActionSuggestBirthdayData.birthday
        return TelegramMediaAction(action: .suggestedBirthday(TelegramBirthday(apiBirthday: birthday)))
        
    case let .messageActionStarGiftPurchaseOffer(messageActionStarGiftPurchaseOfferData):
        let (flags, apiGift, price, expiresAt) = (messageActionStarGiftPurchaseOfferData.flags, messageActionStarGiftPurchaseOfferData.gift, messageActionStarGiftPurchaseOfferData.price, messageActionStarGiftPurchaseOfferData.expiresAt)
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGiftPurchaseOffer(gift: gift, amount: CurrencyAmount(apiAmount: price), expireDate: expiresAt, isAccepted: (flags & (1 << 0)) != 0, isDeclined: (flags & (1 << 1)) != 0))
    case let .messageActionStarGiftPurchaseOfferDeclined(messageActionStarGiftPurchaseOfferDeclinedData):
        let (flags, apiGift, price) = (messageActionStarGiftPurchaseOfferDeclinedData.flags, messageActionStarGiftPurchaseOfferDeclinedData.gift, messageActionStarGiftPurchaseOfferDeclinedData.price)
        guard let gift = StarGift(apiStarGift: apiGift) else {
            return nil
        }
        return TelegramMediaAction(action: .starGiftPurchaseOfferDeclined(gift: gift, amount: CurrencyAmount(apiAmount: price), hasExpired: (flags & (1 << 0)) != 0))
    case let .messageActionNewCreatorPending(messageActionNewCreatorPending):
        return TelegramMediaAction(action: .groupCreatorChange(TelegramMediaActionType.GroupCreatorChange(
            kind: .pending,
            targetPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(messageActionNewCreatorPending.newCreatorId))
        )))
    case let .messageActionChangeCreator(messageActionChangeCreator):
        return TelegramMediaAction(action: .groupCreatorChange(TelegramMediaActionType.GroupCreatorChange(
            kind: .applied,
            targetPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(messageActionChangeCreator.newCreatorId))
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
