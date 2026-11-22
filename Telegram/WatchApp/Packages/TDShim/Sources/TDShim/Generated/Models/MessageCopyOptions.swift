//
//  MessageCopyOptions.swift
//  tl2swift
//
//  Generated automatically. Any changes will be lost!
//  Based on TDLib 1.8.64-49b3bcbb-49b3bcbb
//  https://github.com/tdlib/td/tree/49b3bcbb
//

import Foundation


/// Options to be used when a message content is copied without reference to the original sender. Service messages, messages with messageInvoice, messagePaidMedia, messageGiveaway, or messageGiveawayWinners content can't be copied
public struct MessageCopyOptions: Codable, Equatable, Hashable {

    /// New message caption; pass null to copy message without caption. Ignored if replace_caption is false
    public let newCaption: FormattedText?

    /// True, if new caption must be shown above the media; otherwise, new caption must be shown below the media; not supported in secret chats. Ignored if replace_caption is false
    public let newShowCaptionAboveMedia: Bool

    /// True, if media caption of the message copy needs to be replaced. Ignored if send_copy is false
    public let replaceCaption: Bool

    /// True, if content of the message needs to be copied without reference to the original sender. Always true if the message is forwarded to a secret chat or is local. Use messageProperties.can_be_copied and messageProperties.can_be_copied_to_secret_chat to check whether the message is suitable
    public let sendCopy: Bool


    public init(
        newCaption: FormattedText?,
        newShowCaptionAboveMedia: Bool,
        replaceCaption: Bool,
        sendCopy: Bool
    ) {
        self.newCaption = newCaption
        self.newShowCaptionAboveMedia = newShowCaptionAboveMedia
        self.replaceCaption = replaceCaption
        self.sendCopy = sendCopy
    }
}

