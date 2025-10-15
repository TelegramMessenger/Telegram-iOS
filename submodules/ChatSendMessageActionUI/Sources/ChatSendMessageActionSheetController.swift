import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContextUI
import TelegramCore
import TextFormat
import ReactionSelectionNode
import WallpaperBackgroundNode

public enum SendMessageActionSheetControllerParams {
    public final class SendMessage {
        public let isScheduledMessages: Bool
        public let mediaPreview: ChatSendMessageContextScreenMediaPreview?
        public let mediaCaptionIsAbove: (Bool, (Bool) -> Void)?
        public let messageEffect: (ChatSendMessageActionSheetControllerSendParameters.Effect?, (ChatSendMessageActionSheetControllerSendParameters.Effect?) -> Void)?
        public let attachment: Bool
        public let canSendWhenOnline: Bool
        public let forwardMessageIds: [EngineMessage.Id]
        public let canMakePaidContent: Bool
        public let currentPrice: Int64?
        public let hasTimers: Bool
        public let sendPaidMessageStars: StarsAmount?
        public let isMonoforum: Bool
        
        public init(
            isScheduledMessages: Bool,
            mediaPreview: ChatSendMessageContextScreenMediaPreview?,
            mediaCaptionIsAbove: (Bool, (Bool) -> Void)?,
            messageEffect: (ChatSendMessageActionSheetControllerSendParameters.Effect?, (ChatSendMessageActionSheetControllerSendParameters.Effect?) -> Void)?,
            attachment: Bool,
            canSendWhenOnline: Bool,
            forwardMessageIds: [EngineMessage.Id],
            canMakePaidContent: Bool,
            currentPrice: Int64?,
            hasTimers: Bool,
            sendPaidMessageStars: StarsAmount?,
            isMonoforum: Bool
        ) {
            self.isScheduledMessages = isScheduledMessages
            self.mediaPreview = mediaPreview
            self.mediaCaptionIsAbove = mediaCaptionIsAbove
            self.messageEffect = messageEffect
            self.attachment = attachment
            self.canSendWhenOnline = canSendWhenOnline
            self.forwardMessageIds = forwardMessageIds
            self.canMakePaidContent = canMakePaidContent
            self.currentPrice = currentPrice
            self.hasTimers = hasTimers
            self.sendPaidMessageStars = sendPaidMessageStars
            self.isMonoforum = isMonoforum
        }
    }
    
    public final class EditMessage {
        public let messages: [EngineMessage]
        public let mediaPreview: ChatSendMessageContextScreenMediaPreview?
        public let mediaCaptionIsAbove: (Bool, (Bool) -> Void)?
        
        public init(messages: [EngineMessage], mediaPreview: ChatSendMessageContextScreenMediaPreview?, mediaCaptionIsAbove: (Bool, (Bool) -> Void)?) {
            self.messages = messages
            self.mediaPreview = mediaPreview
            self.mediaCaptionIsAbove = mediaCaptionIsAbove
        }
    }
    
    case sendMessage(SendMessage)
    case editMessage(EditMessage)
}

public func makeChatSendMessageActionSheetController(
    initialData: ChatSendMessageContextScreen.InitialData,
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peerId: EnginePeer.Id?,
    params: SendMessageActionSheetControllerParams,
    hasEntityKeyboard: Bool,
    gesture: ContextGesture,
    sourceSendButton: ASDisplayNode,
    textInputView: UITextView,
    emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?,
    wallpaperBackgroundNode: WallpaperBackgroundNode? = nil,
    completion: @escaping () -> Void,
    sendMessage: @escaping (ChatSendMessageActionSheetController.SendMode, ChatSendMessageActionSheetController.SendParameters?) -> Void,
    schedule: @escaping (ChatSendMessageActionSheetController.SendParameters?) -> Void,
    editPrice: @escaping (Int64) -> Void,
    openPremiumPaywall: @escaping (ViewController) -> Void,
    reactionItems: [ReactionItem]? = nil,
    availableMessageEffects: AvailableMessageEffects? = nil,
    isPremium: Bool = false
) -> ChatSendMessageActionSheetController {
    return ChatSendMessageContextScreen(
        initialData: initialData,
        context: context,
        updatedPresentationData: updatedPresentationData,
        peerId: peerId,
        params: params,
        hasEntityKeyboard: hasEntityKeyboard,
        gesture: gesture,
        sourceSendButton: sourceSendButton,
        textInputView: textInputView,
        emojiViewProvider: emojiViewProvider,
        wallpaperBackgroundNode: wallpaperBackgroundNode,
        completion: completion,
        sendMessage: sendMessage,
        schedule: schedule,
        editPrice: editPrice,
        openPremiumPaywall: openPremiumPaywall,
        reactionItems: reactionItems,
        availableMessageEffects: availableMessageEffects,
        isPremium: isPremium
    )
}
