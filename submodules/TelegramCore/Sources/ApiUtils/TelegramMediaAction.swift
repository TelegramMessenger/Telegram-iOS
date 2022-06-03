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
        case let .messageActionPaymentSent(flags, currency, totalAmount, invoiceSlug):
            let isRecurringInit = (flags & (1 << 2)) != 0
            let isRecurringUsed = (flags & (1 << 3)) != 0
            return TelegramMediaAction(action: .paymentSent(currency: currency, totalAmount: totalAmount, invoiceSlug: invoiceSlug, isRecurringInit: isRecurringInit, isRecurringUsed: isRecurringUsed))
        case .messageActionPaymentSentMe:
            return nil
        case .messageActionScreenshotTaken:
            return TelegramMediaAction(action: .historyScreenshot)
        case let .messageActionCustomAction(message):
            return TelegramMediaAction(action: .customText(text: message, entities: []))
        case let .messageActionBotAllowed(domain):
            return TelegramMediaAction(action: .botDomainAccessGranted(domain: domain))
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
            }
        case let .messageActionInviteToGroupCall(call, userIds):
            switch call {
            case let .inputGroupCall(id, accessHash):
                return TelegramMediaAction(action: .inviteToGroupPhoneCall(callId: id, accessHash: accessHash, peerIds: userIds.map { userId in
                    PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                }))
            }
        case let .messageActionSetMessagesTTL(period):
            return TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(period))
        case let .messageActionGroupCallScheduled(call, scheduleDate):
            switch call {
            case let .inputGroupCall(id, accessHash):
                return TelegramMediaAction(action: .groupPhoneCall(callId: id, accessHash: accessHash, scheduleDate: scheduleDate, duration: nil))
            }
        case let .messageActionSetChatTheme(emoji):
            return TelegramMediaAction(action: .setChatTheme(emoji: emoji))
        case .messageActionChatJoinedByRequest:
            return TelegramMediaAction(action: .joinedByRequest)
        case let .messageActionWebViewDataSentMe(text, _), let .messageActionWebViewDataSent(text):
            return TelegramMediaAction(action: .webViewData(text))
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
