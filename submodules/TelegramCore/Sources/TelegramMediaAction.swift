import Foundation
import Postbox
import TelegramApi

import SyncCore

func telegramMediaActionFromApiAction(_ action: Api.MessageAction) -> TelegramMediaAction? {
    switch action {
        case let .messageActionChannelCreate(title):
            return TelegramMediaAction(action: .groupCreated(title: title))
        case let .messageActionChannelMigrateFrom(title, chatId):
            return TelegramMediaAction(action: .channelMigratedFromGroup(title: title, groupId: PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)))
        case let .messageActionChatAddUser(users):
            return TelegramMediaAction(action: .addedMembers(peerIds: users.map({ PeerId(namespace: Namespaces.Peer.CloudUser, id: $0) })))
        case let .messageActionChatCreate(title, _):
            return TelegramMediaAction(action: .groupCreated(title: title))
        case .messageActionChatDeletePhoto:
            return TelegramMediaAction(action: .photoUpdated(image: nil))
        case let .messageActionChatDeleteUser(userId):
            return TelegramMediaAction(action: .removedMembers(peerIds: [PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)]))
        case let .messageActionChatEditPhoto(photo):
            return TelegramMediaAction(action: .photoUpdated(image: telegramMediaImageFromApiPhoto(photo)))
        case let .messageActionChatEditTitle(title):
            return TelegramMediaAction(action: .titleUpdated(title: title))
        case let .messageActionChatJoinedByLink(inviterId):
            return TelegramMediaAction(action: .joinedByLink(inviter: PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId)))
        case let .messageActionChatMigrateTo(channelId):
            return TelegramMediaAction(action: .groupMigratedToChannel(channelId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)))
        case .messageActionHistoryClear:
            return TelegramMediaAction(action: .historyCleared)
        case .messageActionPinMessage:
            return TelegramMediaAction(action: .pinnedMessageUpdated)
        case let .messageActionGameScore(gameId, score):
            return TelegramMediaAction(action: .gameScore(gameId: gameId, score: score))
        case let .messageActionPhoneCall(_, callId, reason, duration):
            var discardReason: PhoneCallDiscardReason?
            if let reason = reason {
                discardReason = PhoneCallDiscardReason(apiReason: reason)
            }
            return TelegramMediaAction(action: .phoneCall(callId: callId, discardReason: discardReason, duration: duration))
        case .messageActionEmpty:
            return nil
        case let .messageActionPaymentSent(currency, totalAmount):
            return TelegramMediaAction(action: .paymentSent(currency: currency, totalAmount: totalAmount))
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
