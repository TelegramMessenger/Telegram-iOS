//
//  MessageSendOptions.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Options to be used when a message is sent
public struct MessageSendOptions: Codable, Equatable, Hashable {

    /// Pass true to allow the message to ignore regular broadcast limits for a small fee; for bots only
    public let allowPaidBroadcast: Bool

    /// Pass true to disable notification for the message
    public let disableNotification: Bool

    /// Identifier of the effect to apply to the message; pass 0 if none; applicable only to sendMessage, sendMessageAlbum in private chats and forwardMessages with one message to private chats
    public let effectId: TdInt64

    /// Pass true if the message is sent from the background
    public let fromBackground: Bool

    /// Pass true to get a fake message instead of actually sending them
    public let onlyPreview: Bool

    /// The number of Telegram Stars the user agreed to pay to send the messages
    public let paidMessageStarCount: Int64

    /// Pass true if the content of the message must be protected from forwarding and saving; for bots only
    public let protectContent: Bool

    /// Message scheduling state; pass null to send message immediately. Messages sent to a secret chat, to a chat with paid messages, to a channel direct messages chat, live location messages and self-destructing messages can't be scheduled
    public let schedulingState: MessageSchedulingState?

    /// Non-persistent identifier, which will be returned back in messageSendingStatePending object and can be used to match sent messages and corresponding updateNewMessage updates
    public let sendingId: Int

    /// Information about the suggested post; pass null if none. For messages to channel direct messages chat only. Applicable only to sendMessage and addOffer
    public let suggestedPostInfo: InputSuggestedPostInfo?

    /// Pass true if the user explicitly chosen a sticker or a custom emoji from an installed sticker set; applicable only to sendMessage and sendMessageAlbum
    public let updateOrderOfInstalledStickerSets: Bool


    public init(
        allowPaidBroadcast: Bool,
        disableNotification: Bool,
        effectId: TdInt64,
        fromBackground: Bool,
        onlyPreview: Bool,
        paidMessageStarCount: Int64,
        protectContent: Bool,
        schedulingState: MessageSchedulingState?,
        sendingId: Int,
        suggestedPostInfo: InputSuggestedPostInfo?,
        updateOrderOfInstalledStickerSets: Bool
    ) {
        self.allowPaidBroadcast = allowPaidBroadcast
        self.disableNotification = disableNotification
        self.effectId = effectId
        self.fromBackground = fromBackground
        self.onlyPreview = onlyPreview
        self.paidMessageStarCount = paidMessageStarCount
        self.protectContent = protectContent
        self.schedulingState = schedulingState
        self.sendingId = sendingId
        self.suggestedPostInfo = suggestedPostInfo
        self.updateOrderOfInstalledStickerSets = updateOrderOfInstalledStickerSets
    }
}

