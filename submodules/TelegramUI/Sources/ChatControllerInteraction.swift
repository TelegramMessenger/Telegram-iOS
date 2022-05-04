import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import Display
import TelegramUIPreferences
import AccountContext
import TextSelectionNode
import ContextUI
import ChatInterfaceState
import UndoUI
import TelegramPresentationData
import ChatPresentationInterfaceState

struct ChatInterfaceHighlightedState: Equatable {
    let messageStableId: UInt32
    
    static func ==(lhs: ChatInterfaceHighlightedState, rhs: ChatInterfaceHighlightedState) -> Bool {
        return lhs.messageStableId == rhs.messageStableId
    }
}

struct ChatInterfaceStickerSettings: Equatable {
    let loopAnimatedStickers: Bool
    
    public init(loopAnimatedStickers: Bool) {
        self.loopAnimatedStickers = loopAnimatedStickers
    }
    
    public init(stickerSettings: StickerSettings) {
        self.loopAnimatedStickers = stickerSettings.loopAnimatedStickers
    }
    
    static func ==(lhs: ChatInterfaceStickerSettings, rhs: ChatInterfaceStickerSettings) -> Bool {
        return lhs.loopAnimatedStickers == rhs.loopAnimatedStickers
    }
}

struct ChatInterfacePollActionState: Equatable {
    var pollMessageIdsInProgress: [MessageId: [Data]] = [:]
}

public enum ChatControllerInteractionSwipeAction {
    case none
    case reply
}

public enum ChatControllerInteractionReaction {
    case `default`
    case reaction(String)
}

public final class ChatControllerInteraction {
    let openMessage: (Message, ChatControllerInteractionOpenMessageMode) -> Bool
    let openPeer: (PeerId?, ChatControllerInteractionNavigateToPeer, MessageReference?, Peer?) -> Void
    let openPeerMention: (String) -> Void
    let openMessageContextMenu: (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void
    let updateMessageReaction: (Message, ChatControllerInteractionReaction) -> Void
    let openMessageReactionContextMenu: (Message, ContextExtractedContentContainingNode, ContextGesture?, String) -> Void
    let activateMessagePinch: (PinchSourceContainerNode) -> Void
    let openMessageContextActions: (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let navigateToMessageStandalone: (MessageId) -> Void
    let tapMessage: ((Message) -> Void)?
    let clickThroughMessage: () -> Void
    let toggleMessagesSelection: ([MessageId], Bool) -> Void
    let sendCurrentMessage: (Bool) -> Void
    let sendMessage: (String) -> Void
    let sendSticker: (FileMediaReference, Bool, Bool, String?, Bool, ASDisplayNode, CGRect) -> Bool
    let sendGif: (FileMediaReference, ASDisplayNode, CGRect, Bool, Bool) -> Bool
    let sendBotContextResultAsGif: (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect, Bool) -> Bool
    let requestMessageActionCallback: (MessageId, MemoryBuffer?, Bool, Bool) -> Void
    let requestMessageActionUrlAuth: (String, MessageActionUrlSubject) -> Void
    let activateSwitchInline: (PeerId?, String) -> Void
    let openUrl: (String, Bool, Bool?, Message?) -> Void
    let shareCurrentLocation: () -> Void
    let shareAccountContact: () -> Void
    let sendBotCommand: (MessageId?, String) -> Void
    let openInstantPage: (Message, ChatMessageItemAssociatedData?) -> Void
    let openWallpaper: (Message) -> Void
    let openTheme: (Message) -> Void
    let openHashtag: (String?, String) -> Void
    let updateInputState: ((ChatTextInputState) -> ChatTextInputState) -> Void
    let updateInputMode: ((ChatInputMode) -> ChatInputMode) -> Void
    let openMessageShareMenu: (MessageId) -> Void
    let presentController: (ViewController, Any?) -> Void
    let presentControllerInCurrent: (ViewController, Any?) -> Void
    let navigationController: () -> NavigationController?
    let chatControllerNode: () -> ASDisplayNode?
    let presentGlobalOverlayController: (ViewController, Any?) -> Void
    let callPeer: (PeerId, Bool) -> Void
    let longTap: (ChatControllerInteractionLongTapAction, Message?) -> Void
    let openCheckoutOrReceipt: (MessageId) -> Void
    let openSearch: () -> Void
    let setupReply: (MessageId) -> Void
    let canSetupReply: (Message) -> ChatControllerInteractionSwipeAction
    let navigateToFirstDateMessage: (Int32, Bool) -> Void
    let requestRedeliveryOfFailedMessages: (MessageId) -> Void
    let addContact: (String) -> Void
    let rateCall: (Message, CallId, Bool) -> Void
    let requestSelectMessagePollOptions: (MessageId, [Data]) -> Void
    let requestOpenMessagePollResults: (MessageId, MediaId) -> Void
    let openAppStorePage: () -> Void
    let displayMessageTooltip: (MessageId, String, ASDisplayNode?, CGRect?) -> Void
    let seekToTimecode: (Message, Double, Bool) -> Void
    let scheduleCurrentMessage: () -> Void
    let sendScheduledMessagesNow: ([MessageId]) -> Void
    let editScheduledMessagesTime: ([MessageId]) -> Void
    let performTextSelectionAction: (UInt32, NSAttributedString, TextSelectionAction) -> Void
    let displayImportedMessageTooltip: (ASDisplayNode) -> Void
    let displaySwipeToReplyHint: () -> Void
    let dismissReplyMarkupMessage: (Message) -> Void
    let openMessagePollResults: (MessageId, Data) -> Void
    let openPollCreation: (Bool?) -> Void
    let displayPollSolution: (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void
    let displayPsa: (String, ASDisplayNode) -> Void
    let displayDiceTooltip: (TelegramMediaDice) -> Void
    let animateDiceSuccess: (Bool) -> Void
    let openPeerContextMenu: (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void
    let openMessageReplies: (MessageId, Bool, Bool) -> Void
    let openReplyThreadOriginalMessage: (Message) -> Void
    let openMessageStats: (MessageId) -> Void
    let editMessageMedia: (MessageId, Bool) -> Void
    let copyText: (String) -> Void
    let displayUndo: (UndoOverlayContent) -> Void
    let isAnimatingMessage: (UInt32) -> Bool
    let getMessageTransitionNode: () -> ChatMessageTransitionNode?
    let updateChoosingSticker: (Bool) -> Void
    let commitEmojiInteraction: (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void
    let openLargeEmojiInfo: (String, String?, TelegramMediaFile) -> Void
    let openJoinLink: (String) -> Void
    let openWebView: (String, String, Bool, Bool) -> Void
    
    let requestMessageUpdate: (MessageId) -> Void
    let cancelInteractiveKeyboardGestures: () -> Void
    
    var canPlayMedia: Bool = false
    var hiddenMedia: [MessageId: [Media]] = [:]
    var selectionState: ChatInterfaceSelectionState?
    var highlightedState: ChatInterfaceHighlightedState?
    var contextHighlightedState: ChatInterfaceHighlightedState?
    var automaticMediaDownloadSettings: MediaAutoDownloadSettings
    var pollActionState: ChatInterfacePollActionState
    var currentPollMessageWithTooltip: MessageId?
    var currentPsaMessageWithTooltip: MessageId?
    var stickerSettings: ChatInterfaceStickerSettings
    var searchTextHighightState: (String, [MessageIndex])?
    var seenOneTimeAnimatedMedia = Set<MessageId>()
    var currentMessageWithLoadingReplyThread: MessageId?
    var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    let presentationContext: ChatPresentationContext
    
    init(
        openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Bool,
        openPeer: @escaping (PeerId?, ChatControllerInteractionNavigateToPeer, MessageReference?, Peer?) -> Void,
        openPeerMention: @escaping (String) -> Void,
        openMessageContextMenu: @escaping (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void,
        openMessageReactionContextMenu: @escaping (Message, ContextExtractedContentContainingNode, ContextGesture?, String) -> Void,
        updateMessageReaction: @escaping (Message, ChatControllerInteractionReaction) -> Void,
        activateMessagePinch: @escaping (PinchSourceContainerNode) -> Void,
        openMessageContextActions: @escaping (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        navigateToMessage: @escaping (MessageId, MessageId) -> Void,
        navigateToMessageStandalone: @escaping (MessageId) -> Void,
        tapMessage: ((Message) -> Void)?,
        clickThroughMessage: @escaping () -> Void,
        toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void,
        sendCurrentMessage: @escaping (Bool) -> Void,
        sendMessage: @escaping (String) -> Void,
        sendSticker: @escaping (FileMediaReference, Bool, Bool, String?, Bool, ASDisplayNode, CGRect) -> Bool,
        sendGif: @escaping (FileMediaReference, ASDisplayNode, CGRect, Bool, Bool) -> Bool,
        sendBotContextResultAsGif: @escaping (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect, Bool) -> Bool,
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
        performTextSelectionAction: @escaping (UInt32, NSAttributedString, TextSelectionAction) -> Void,
        displayImportedMessageTooltip: @escaping (ASDisplayNode) -> Void,
        displaySwipeToReplyHint: @escaping () -> Void,
        dismissReplyMarkupMessage: @escaping (Message) -> Void,
        openMessagePollResults: @escaping (MessageId, Data) -> Void,
        openPollCreation: @escaping (Bool?) -> Void,
        displayPollSolution: @escaping (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void,
        displayPsa: @escaping (String, ASDisplayNode) -> Void,
        displayDiceTooltip: @escaping (TelegramMediaDice) -> Void,
        animateDiceSuccess: @escaping (Bool) -> Void,
        openPeerContextMenu: @escaping (Peer, MessageId?, ASDisplayNode, CGRect, ContextGesture?) -> Void,
        openMessageReplies: @escaping (MessageId, Bool, Bool) -> Void,
        openReplyThreadOriginalMessage: @escaping (Message) -> Void,
        openMessageStats: @escaping (MessageId) -> Void,
        editMessageMedia: @escaping (MessageId, Bool) -> Void,
        copyText: @escaping (String) -> Void,
        displayUndo: @escaping (UndoOverlayContent) -> Void,
        isAnimatingMessage: @escaping (UInt32) -> Bool,
        getMessageTransitionNode: @escaping () -> ChatMessageTransitionNode?,
        updateChoosingSticker: @escaping (Bool) -> Void,
        commitEmojiInteraction: @escaping (MessageId, String, EmojiInteraction, TelegramMediaFile) -> Void,
        openLargeEmojiInfo: @escaping (String, String?, TelegramMediaFile) -> Void,
        openJoinLink: @escaping (String) -> Void,
        openWebView: @escaping (String, String, Bool, Bool) -> Void,
        requestMessageUpdate: @escaping (MessageId) -> Void,
        cancelInteractiveKeyboardGestures: @escaping () -> Void,
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
        self.tapMessage = tapMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessagesSelection = toggleMessagesSelection
        self.sendCurrentMessage = sendCurrentMessage
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
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
        self.requestMessageUpdate = requestMessageUpdate
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        
        self.pollActionState = pollActionState
        self.stickerSettings = stickerSettings

        self.presentationContext = presentationContext
    }
    
    static var `default`: ChatControllerInteraction {
        return ChatControllerInteraction(openMessage: { _, _ in
        return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _, _ in }, openMessageReactionContextMenu: { _, _, _, _ in
        }, updateMessageReaction: { _, _ in }, activateMessagePinch: { _ in }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _ in }, navigateToMessageStandalone: { _ in }, tapMessage: nil, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _, _, _, _ in return false }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _ in return false }, requestMessageActionCallback: { _, _, _, _ in }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in }, presentControllerInCurrent: { _, _ in }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _ in
        }, openPeerContextMenu: { _, _, _, _, _ in
        }, openMessageReplies: { _, _, _ in
        }, openReplyThreadOriginalMessage: { _ in
        }, openMessageStats: { _ in
        }, editMessageMedia: { _, _ in
        }, copyText: { _ in
        }, displayUndo: { _ in
        }, isAnimatingMessage: { _ in
            return false
        }, getMessageTransitionNode: {
            return nil
        }, updateChoosingSticker: { _ in
        }, commitEmojiInteraction: { _, _, _, _ in  
        }, openLargeEmojiInfo: { _, _, _ in
        }, openJoinLink: { _ in
        }, openWebView: { _, _, _, _ in
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(),
        stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false),
        presentationContext: ChatPresentationContext(backgroundNode: nil)
        )
    }
}
