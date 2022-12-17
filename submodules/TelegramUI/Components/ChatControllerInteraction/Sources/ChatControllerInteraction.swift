import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import Display
import TelegramUIPreferences
import AccountContext
import TextSelectionNode
import ContextUI
import ChatInterfaceState
import UndoUI
import TelegramPresentationData
import ChatPresentationInterfaceState
import TextFormat
import WallpaperBackgroundNode
import AnimationCache
import MultiAnimationRenderer

public struct ChatInterfaceHighlightedState: Equatable {
    public let messageStableId: UInt32
    
    public init(messageStableId: UInt32) {
        self.messageStableId = messageStableId
    }
    
    public static func ==(lhs: ChatInterfaceHighlightedState, rhs: ChatInterfaceHighlightedState) -> Bool {
        return lhs.messageStableId == rhs.messageStableId
    }
}

public struct ChatInterfacePollActionState: Equatable {
    public var pollMessageIdsInProgress: [MessageId: [Data]] = [:]
    
    public init(pollMessageIdsInProgress: [MessageId: [Data]] = [:]) {
        self.pollMessageIdsInProgress = pollMessageIdsInProgress
    }
}

public enum ChatControllerInteractionSwipeAction {
    case none
    case reply
}

public enum ChatControllerInteractionReaction {
    case `default`
    case reaction(MessageReaction.Reaction)
}

public struct UnreadMessageRangeKey: Hashable {
    public var peerId: PeerId
    public var namespace: MessageId.Namespace
    
    public init(peerId: PeerId, namespace: MessageId.Namespace) {
        self.peerId = peerId
        self.namespace = namespace
    }
}

public class ChatPresentationContext {
    public weak var backgroundNode: WallpaperBackgroundNode?
    public let animationCache: AnimationCache
    public let animationRenderer: MultiAnimationRenderer

    public init(context: AccountContext, backgroundNode: WallpaperBackgroundNode?) {
        self.backgroundNode = backgroundNode
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
    }
}

public protocol ChatMessageTransitionProtocol: ASDisplayNode {
    
}

public final class ChatControllerInteraction {
    public enum OpenPeerSource {
        case `default`
        case reaction
        case groupParticipant
    }
    
    public let openMessage: (Message, ChatControllerInteractionOpenMessageMode) -> Bool
    public let openPeer: (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void
    public let openPeerMention: (String) -> Void
    public let openMessageContextMenu: (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void
    public let updateMessageReaction: (Message, ChatControllerInteractionReaction) -> Void
    public let openMessageReactionContextMenu: (Message, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void
    public let activateMessagePinch: (PinchSourceContainerNode) -> Void
    public let openMessageContextActions: (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let navigateToMessage: (MessageId, MessageId) -> Void
    public let navigateToMessageStandalone: (MessageId) -> Void
    public let navigateToThreadMessage: (PeerId, Int64, MessageId?) -> Void
    public let tapMessage: ((Message) -> Void)?
    public let clickThroughMessage: () -> Void
    public let toggleMessagesSelection: ([MessageId], Bool) -> Void
    public let sendCurrentMessage: (Bool) -> Void
    public let sendMessage: (String) -> Void
    public let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool
    public let sendEmoji: (String, ChatTextInputTextCustomEmojiAttribute) -> Void
    public let sendGif: (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool
    public let sendBotContextResultAsGif: (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool) -> Bool
    public let requestMessageActionCallback: (MessageId, MemoryBuffer?, Bool, Bool) -> Void
    public let requestMessageActionUrlAuth: (String, MessageActionUrlSubject) -> Void
    public let activateSwitchInline: (PeerId?, String) -> Void
    public let openUrl: (String, Bool, Bool?, Message?) -> Void
    public let shareCurrentLocation: () -> Void
    public let shareAccountContact: () -> Void
    public let sendBotCommand: (MessageId?, String) -> Void
    public let openInstantPage: (Message, ChatMessageItemAssociatedData?) -> Void
    public let openWallpaper: (Message) -> Void
    public let openTheme: (Message) -> Void
    public let openHashtag: (String?, String) -> Void
    public let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    public let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    public let openMessageShareMenu: (MessageId) -> Void
    public let presentController: (ViewController, Any?) -> Void
    public let presentControllerInCurrent: (ViewController, Any?) -> Void
    public let navigationController: () -> NavigationController?
    public let chatControllerNode: () -> ASDisplayNode?
    public let presentGlobalOverlayController: (ViewController, Any?) -> Void
    public let callPeer: (PeerId, Bool) -> Void
    public let longTap: (ChatControllerInteractionLongTapAction, Message?) -> Void
    public let openCheckoutOrReceipt: (MessageId) -> Void
    public let openSearch: () -> Void
    public let setupReply: (MessageId) -> Void
    public let canSetupReply: (Message) -> ChatControllerInteractionSwipeAction
    public let navigateToFirstDateMessage: (Int32, Bool) -> Void
    public let requestRedeliveryOfFailedMessages: (MessageId) -> Void
    public let addContact: (String) -> Void
    public let rateCall: (Message, CallId, Bool) -> Void
    public let requestSelectMessagePollOptions: (MessageId, [Data]) -> Void
    public let requestOpenMessagePollResults: (MessageId, MediaId) -> Void
    public let openAppStorePage: () -> Void
    public let displayMessageTooltip: (MessageId, String, ASDisplayNode?, CGRect?) -> Void
    public let seekToTimecode: (Message, Double, Bool) -> Void
    public let scheduleCurrentMessage: () -> Void
    public let sendScheduledMessagesNow: ([MessageId]) -> Void
    public let editScheduledMessagesTime: ([MessageId]) -> Void
    public let performTextSelectionAction: (Bool, NSAttributedString, TextSelectionAction) -> Void
    public let displayImportedMessageTooltip: (ASDisplayNode) -> Void
    public let displaySwipeToReplyHint: () -> Void
    public let dismissReplyMarkupMessage: (Message) -> Void
    public let openMessagePollResults: (MessageId, Data) -> Void
    public let openPollCreation: (Bool?) -> Void
    public let displayPollSolution: (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void
    public let displayPsa: (String, ASDisplayNode) -> Void
    public let displayDiceTooltip: (TelegramMediaDice) -> Void
    public let animateDiceSuccess: (Bool, Bool) -> Void
    public let displayPremiumStickerTooltip: (TelegramMediaFile, Message) -> Void
    public let displayEmojiPackTooltip: (TelegramMediaFile, Message) -> Void
    public let openPeerContextMenu: (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void
    public let openMessageReplies: (MessageId, Bool, Bool) -> Void
    public let openReplyThreadOriginalMessage: (Message) -> Void
    public let openMessageStats: (MessageId) -> Void
    public let editMessageMedia: (MessageId, Bool) -> Void
    public let copyText: (String) -> Void
    public let displayUndo: (UndoOverlayContent) -> Void
    public let isAnimatingMessage: (UInt32) -> Bool
    public let getMessageTransitionNode: () -> ChatMessageTransitionProtocol?
    public let updateChoosingSticker: (Bool) -> Void
    public let commitEmojiInteraction: (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void
    public let openLargeEmojiInfo: (String, String?, TelegramMediaFile) -> Void
    public let openJoinLink: (String) -> Void
    public let openWebView: (String, String, Bool, Bool) -> Void
    public let activateAdAction: (EngineMessage.Id) -> Void
    
    public let requestMessageUpdate: (MessageId, Bool) -> Void
    public let cancelInteractiveKeyboardGestures: () -> Void
    public let dismissTextInput: () -> Void
    public let scrollToMessageId: (MessageIndex) -> Void
    
    public var canPlayMedia: Bool = false
    public var hiddenMedia: [MessageId: [Media]] = [:]
    public var expandedTranslationMessageStableIds: Set<UInt32> = Set()
    public var selectionState: ChatInterfaceSelectionState?
    public var highlightedState: ChatInterfaceHighlightedState?
    public var contextHighlightedState: ChatInterfaceHighlightedState?
    public var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    public var pollActionState: ChatInterfacePollActionState
    public var currentPollMessageWithTooltip: MessageId?
    public var currentPsaMessageWithTooltip: MessageId?
    public var stickerSettings: ChatInterfaceStickerSettings
    public var searchTextHighightState: (String, [MessageIndex])?
    public var unreadMessageRange: [UnreadMessageRangeKey: Range<MessageId.Id>] = [:]
    public var seenOneTimeAnimatedMedia = Set<MessageId>()
    public var currentMessageWithLoadingReplyThread: MessageId?
    public var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    public let presentationContext: ChatPresentationContext
    public var playNextOutgoingGift: Bool = false
    
    public init(
        openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Bool,
        openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer, MessageReference?, OpenPeerSource) -> Void,
        openPeerMention: @escaping (String) -> Void,
        openMessageContextMenu: @escaping (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?, CGPoint?) -> Void,
        openMessageReactionContextMenu: @escaping (Message, ContextExtractedContentContainingView, ContextGesture?, MessageReaction.Reaction) -> Void,
        updateMessageReaction: @escaping (Message, ChatControllerInteractionReaction) -> Void,
        activateMessagePinch: @escaping (PinchSourceContainerNode) -> Void,
        openMessageContextActions: @escaping (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        navigateToMessage: @escaping (MessageId, MessageId) -> Void,
        navigateToMessageStandalone: @escaping (MessageId) -> Void,
        navigateToThreadMessage: @escaping (PeerId, Int64, MessageId?) -> Void,
        tapMessage: ((Message) -> Void)?,
        clickThroughMessage: @escaping () -> Void,
        toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void,
        sendCurrentMessage: @escaping (Bool) -> Void,
        sendMessage: @escaping (String) -> Void,
        sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool,
        sendEmoji: @escaping (String, ChatTextInputTextCustomEmojiAttribute) -> Void,
        sendGif: @escaping (FileMediaReference, UIView, CGRect, Bool, Bool) -> Bool,
        sendBotContextResultAsGif: @escaping (ChatContextResultCollection, ChatContextResult, UIView, CGRect, Bool) -> Bool,
        requestMessageActionCallback: @escaping (MessageId, MemoryBuffer?, Bool, Bool) -> Void,
        requestMessageActionUrlAuth: @escaping (String, MessageActionUrlSubject) -> Void,
        activateSwitchInline: @escaping (PeerId?, String) -> Void,
        openUrl: @escaping (String, Bool, Bool?, Message?) -> Void,
        shareCurrentLocation: @escaping () -> Void,
        shareAccountContact: @escaping () -> Void,
        sendBotCommand: @escaping (MessageId?, String) -> Void,
        openInstantPage: @escaping (Message, ChatMessageItemAssociatedData?) -> Void,
        openWallpaper: @escaping (Message) -> Void,
        openTheme: @escaping (Message) -> Void,
        openHashtag: @escaping (String?, String) -> Void,
        updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void,
        updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void,
        openMessageShareMenu: @escaping (MessageId) -> Void,
        presentController: @escaping (ViewController, Any?) -> Void,
        presentControllerInCurrent: @escaping (ViewController, Any?) -> Void,
        navigationController: @escaping () -> NavigationController?,
        chatControllerNode: @escaping () -> ASDisplayNode?,
        presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void,
        callPeer: @escaping (PeerId, Bool) -> Void,
        longTap: @escaping (ChatControllerInteractionLongTapAction, Message?) -> Void,
        openCheckoutOrReceipt: @escaping (MessageId) -> Void,
        openSearch: @escaping () -> Void,
        setupReply: @escaping (MessageId) -> Void,
        canSetupReply: @escaping (Message) -> ChatControllerInteractionSwipeAction,
        navigateToFirstDateMessage: @escaping(Int32, Bool) ->Void,
        requestRedeliveryOfFailedMessages: @escaping (MessageId) -> Void,
        addContact: @escaping (String) -> Void,
        rateCall: @escaping (Message, CallId, Bool) -> Void,
        requestSelectMessagePollOptions: @escaping (MessageId, [Data]) -> Void,
        requestOpenMessagePollResults: @escaping (MessageId, MediaId) -> Void,
        openAppStorePage: @escaping () -> Void,
        displayMessageTooltip: @escaping (MessageId, String, ASDisplayNode?, CGRect?) -> Void,
        seekToTimecode: @escaping (Message, Double, Bool) -> Void,
        scheduleCurrentMessage: @escaping () -> Void,
        sendScheduledMessagesNow: @escaping ([MessageId]) -> Void,
        editScheduledMessagesTime: @escaping ([MessageId]) -> Void,
        performTextSelectionAction: @escaping (Bool, NSAttributedString, TextSelectionAction) -> Void,
        displayImportedMessageTooltip: @escaping (ASDisplayNode) -> Void,
        displaySwipeToReplyHint: @escaping () -> Void,
        dismissReplyMarkupMessage: @escaping (Message) -> Void,
        openMessagePollResults: @escaping (MessageId, Data) -> Void,
        openPollCreation: @escaping (Bool?) -> Void,
        displayPollSolution: @escaping (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void,
        displayPsa: @escaping (String, ASDisplayNode) -> Void,
        displayDiceTooltip: @escaping (TelegramMediaDice) -> Void,
        animateDiceSuccess: @escaping (Bool, Bool) -> Void,
        displayPremiumStickerTooltip: @escaping (TelegramMediaFile, Message) -> Void,
        displayEmojiPackTooltip: @escaping (TelegramMediaFile, Message) -> Void,
        openPeerContextMenu: @escaping (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        openMessageReplies: @escaping (MessageId, Bool, Bool) -> Void,
        openReplyThreadOriginalMessage: @escaping (Message) -> Void,
        openMessageStats: @escaping (MessageId) -> Void,
        editMessageMedia: @escaping (MessageId, Bool) -> Void,
        copyText: @escaping (String) -> Void,
        displayUndo: @escaping (UndoOverlayContent) -> Void,
        isAnimatingMessage: @escaping (UInt32) -> Bool,
        getMessageTransitionNode: @escaping () -> ChatMessageTransitionProtocol?,
        updateChoosingSticker: @escaping (Bool) -> Void,
        commitEmojiInteraction: @escaping (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void,
        openLargeEmojiInfo: @escaping (String, String?, TelegramMediaFile) -> Void,
        openJoinLink: @escaping (String) -> Void,
        openWebView: @escaping (String, String, Bool, Bool) -> Void,
        activateAdAction: @escaping (EngineMessage.Id) -> Void,
        requestMessageUpdate: @escaping (MessageId, Bool) -> Void,
        cancelInteractiveKeyboardGestures: @escaping () -> Void,
        dismissTextInput: @escaping () -> Void,
        scrollToMessageId: @escaping (MessageIndex) -> Void,
        automaticMediaDownloadSettings: MediaAutoDownloadSettings,
        pollActionState: ChatInterfacePollActionState,
        stickerSettings: ChatInterfaceStickerSettings,
        presentationContext: ChatPresentationContext
    ) {
        self.openMessage = openMessage
        self.openPeer = openPeer
        self.openPeerMention = openPeerMention
        self.openMessageContextMenu = openMessageContextMenu
        self.openMessageReactionContextMenu = openMessageReactionContextMenu
        self.updateMessageReaction = updateMessageReaction
        self.activateMessagePinch = activateMessagePinch
        self.openMessageContextActions = openMessageContextActions
        self.navigateToMessage = navigateToMessage
        self.navigateToMessageStandalone = navigateToMessageStandalone
        self.navigateToThreadMessage = navigateToThreadMessage
        self.tapMessage = tapMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessagesSelection = toggleMessagesSelection
        self.sendCurrentMessage = sendCurrentMessage
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
        self.sendEmoji = sendEmoji
        self.sendGif = sendGif
        self.sendBotContextResultAsGif = sendBotContextResultAsGif
        self.requestMessageActionCallback = requestMessageActionCallback
        self.requestMessageActionUrlAuth = requestMessageActionUrlAuth
        self.activateSwitchInline = activateSwitchInline
        self.openUrl = openUrl
        self.shareCurrentLocation = shareCurrentLocation
        self.shareAccountContact = shareAccountContact
        self.sendBotCommand = sendBotCommand
        self.openInstantPage = openInstantPage
        self.openWallpaper = openWallpaper
        self.openTheme = openTheme
        self.openHashtag = openHashtag
        self.updateInputState = updateInputState
        self.updateInputMode = updateInputMode
        self.openMessageShareMenu = openMessageShareMenu
        self.presentController = presentController
        self.presentControllerInCurrent = presentControllerInCurrent
        self.navigationController = navigationController
        self.chatControllerNode = chatControllerNode
        self.presentGlobalOverlayController = presentGlobalOverlayController
        self.callPeer = callPeer
        self.longTap = longTap
        self.openCheckoutOrReceipt = openCheckoutOrReceipt
        self.openSearch = openSearch
        self.setupReply = setupReply
        self.canSetupReply = canSetupReply
        self.navigateToFirstDateMessage = navigateToFirstDateMessage
        self.requestRedeliveryOfFailedMessages = requestRedeliveryOfFailedMessages
        self.addContact = addContact
        self.rateCall = rateCall
        self.requestSelectMessagePollOptions = requestSelectMessagePollOptions
        self.requestOpenMessagePollResults = requestOpenMessagePollResults
        self.openPollCreation = openPollCreation
        self.displayPollSolution = displayPollSolution
        self.displayPsa = displayPsa
        self.openAppStorePage = openAppStorePage
        self.displayMessageTooltip = displayMessageTooltip
        self.seekToTimecode = seekToTimecode
        self.scheduleCurrentMessage = scheduleCurrentMessage
        self.sendScheduledMessagesNow = sendScheduledMessagesNow
        self.editScheduledMessagesTime = editScheduledMessagesTime
        self.performTextSelectionAction = performTextSelectionAction
        self.displayImportedMessageTooltip = displayImportedMessageTooltip
        self.displaySwipeToReplyHint = displaySwipeToReplyHint
        self.dismissReplyMarkupMessage = dismissReplyMarkupMessage
        self.openMessagePollResults = openMessagePollResults
        self.displayDiceTooltip = displayDiceTooltip
        self.animateDiceSuccess = animateDiceSuccess
        self.displayPremiumStickerTooltip = displayPremiumStickerTooltip
        self.displayEmojiPackTooltip = displayEmojiPackTooltip
        self.openPeerContextMenu = openPeerContextMenu
        self.openMessageReplies = openMessageReplies
        self.openReplyThreadOriginalMessage = openReplyThreadOriginalMessage
        self.openMessageStats = openMessageStats
        self.editMessageMedia = editMessageMedia
        self.copyText = copyText
        self.displayUndo = displayUndo
        self.isAnimatingMessage = isAnimatingMessage
        self.getMessageTransitionNode = getMessageTransitionNode
        self.updateChoosingSticker = updateChoosingSticker
        self.commitEmojiInteraction = commitEmojiInteraction
        self.openLargeEmojiInfo = openLargeEmojiInfo
        self.openJoinLink = openJoinLink
        self.openWebView = openWebView
        self.activateAdAction = activateAdAction
        self.requestMessageUpdate = requestMessageUpdate
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        self.dismissTextInput = dismissTextInput
        self.scrollToMessageId = scrollToMessageId
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        
        self.pollActionState = pollActionState
        self.stickerSettings = stickerSettings

        self.presentationContext = presentationContext
    }
}
