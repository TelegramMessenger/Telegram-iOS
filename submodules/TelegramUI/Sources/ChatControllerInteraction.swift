import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Display
import TelegramUIPreferences
import AccountContext
import TextSelectionNode
import ReactionSelectionNode
import ContextUI

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

public enum ChatControllerInteractionLongTapAction {
    case url(String)
    case mention(String)
    case peerMention(PeerId, String)
    case command(String)
    case hashtag(String)
    case timecode(Double, String)
    case bankCard(String)
}

struct ChatInterfacePollActionState: Equatable {
    var pollMessageIdsInProgress: [MessageId: [Data]] = [:]
}

public final class ChatControllerInteraction {
    let openMessage: (Message, ChatControllerInteractionOpenMessageMode) -> Bool
    let openPeer: (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void
    let openPeerMention: (String) -> Void
    let openMessageContextMenu: (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void
    let openMessageContextActions: (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void
    let navigateToMessage: (MessageId, MessageId) -> Void
    let tapMessage: ((Message) -> Void)?
    let clickThroughMessage: () -> Void
    let toggleMessagesSelection: ([MessageId], Bool) -> Void
    let sendCurrentMessage: (Bool) -> Void
    let sendMessage: (String) -> Void
    let sendSticker: (FileMediaReference, Bool, ASDisplayNode, CGRect) -> Bool
    let sendGif: (FileMediaReference, ASDisplayNode, CGRect) -> Bool
    let requestMessageActionCallback: (MessageId, MemoryBuffer?, Bool) -> Void
    let requestMessageActionUrlAuth: (String, MessageId, Int32) -> Void
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
    let navigationController: () -> NavigationController?
    let chatControllerNode: () -> ASDisplayNode?
    let reactionContainerNode: () -> ReactionSelectionParentNode?
    let presentGlobalOverlayController: (ViewController, Any?) -> Void
    let callPeer: (PeerId) -> Void
    let longTap: (ChatControllerInteractionLongTapAction, Message?) -> Void
    let openCheckoutOrReceipt: (MessageId) -> Void
    let openSearch: () -> Void
    let setupReply: (MessageId) -> Void
    let canSetupReply: (Message) -> Bool
    let navigateToFirstDateMessage: (Int32) -> Void
    let requestRedeliveryOfFailedMessages: (MessageId) -> Void
    let addContact: (String) -> Void
    let rateCall: (Message, CallId) -> Void
    let requestSelectMessagePollOptions: (MessageId, [Data]) -> Void
    let requestOpenMessagePollResults: (MessageId, MediaId) -> Void
    let openAppStorePage: () -> Void
    let displayMessageTooltip: (MessageId, String, ASDisplayNode?, CGRect?) -> Void
    let seekToTimecode: (Message, Double, Bool) -> Void
    let scheduleCurrentMessage: () -> Void
    let sendScheduledMessagesNow: ([MessageId]) -> Void
    let editScheduledMessagesTime: ([MessageId]) -> Void
    let performTextSelectionAction: (UInt32, NSAttributedString, TextSelectionAction) -> Void
    let updateMessageReaction: (MessageId, String?) -> Void
    let openMessageReactions: (MessageId) -> Void
    let displaySwipeToReplyHint: () -> Void
    let dismissReplyMarkupMessage: (Message) -> Void
    let openMessagePollResults: (MessageId, Data) -> Void
    let openPollCreation: (Bool?) -> Void
    let displayPollSolution: (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void
    let displayPsa: (String, ASDisplayNode) -> Void
    let displayDiceTooltip: (TelegramMediaDice) -> Void
    let animateDiceSuccess: () -> Void
    
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
    
    init(openMessage: @escaping (Message, ChatControllerInteractionOpenMessageMode) -> Bool, openPeer: @escaping (PeerId?, ChatControllerInteractionNavigateToPeer, Message?) -> Void, openPeerMention: @escaping (String) -> Void, openMessageContextMenu: @escaping (Message, Bool, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void, openMessageContextActions: @escaping (Message, ASDisplayNode, CGRect, ContextGesture?) -> Void, navigateToMessage: @escaping (MessageId, MessageId) -> Void, tapMessage: ((Message) -> Void)?, clickThroughMessage: @escaping () -> Void, toggleMessagesSelection: @escaping ([MessageId], Bool) -> Void, sendCurrentMessage: @escaping (Bool) -> Void, sendMessage: @escaping (String) -> Void, sendSticker: @escaping (FileMediaReference, Bool, ASDisplayNode, CGRect) -> Bool, sendGif: @escaping (FileMediaReference, ASDisplayNode, CGRect) -> Bool, requestMessageActionCallback: @escaping (MessageId, MemoryBuffer?, Bool) -> Void, requestMessageActionUrlAuth: @escaping (String, MessageId, Int32) -> Void, activateSwitchInline: @escaping (PeerId?, String) -> Void, openUrl: @escaping (String, Bool, Bool?, Message?) -> Void, shareCurrentLocation: @escaping () -> Void, shareAccountContact: @escaping () -> Void, sendBotCommand: @escaping (MessageId?, String) -> Void, openInstantPage: @escaping (Message, ChatMessageItemAssociatedData?) -> Void, openWallpaper: @escaping (Message) -> Void, openTheme: @escaping (Message) -> Void, openHashtag: @escaping (String?, String) -> Void, updateInputState: @escaping ((ChatTextInputState) -> ChatTextInputState) -> Void, updateInputMode: @escaping ((ChatInputMode) -> ChatInputMode) -> Void, openMessageShareMenu: @escaping (MessageId) -> Void, presentController: @escaping  (ViewController, Any?) -> Void, navigationController: @escaping () -> NavigationController?, chatControllerNode: @escaping () -> ASDisplayNode?, reactionContainerNode: @escaping () -> ReactionSelectionParentNode?, presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void, callPeer: @escaping (PeerId) -> Void, longTap: @escaping (ChatControllerInteractionLongTapAction, Message?) -> Void, openCheckoutOrReceipt: @escaping (MessageId) -> Void, openSearch: @escaping () -> Void, setupReply: @escaping (MessageId) -> Void, canSetupReply: @escaping (Message) -> Bool, navigateToFirstDateMessage: @escaping(Int32) ->Void, requestRedeliveryOfFailedMessages: @escaping (MessageId) -> Void, addContact: @escaping (String) -> Void, rateCall: @escaping (Message, CallId) -> Void, requestSelectMessagePollOptions: @escaping (MessageId, [Data]) -> Void, requestOpenMessagePollResults: @escaping (MessageId, MediaId) -> Void, openAppStorePage: @escaping () -> Void, displayMessageTooltip: @escaping (MessageId, String, ASDisplayNode?, CGRect?) -> Void, seekToTimecode: @escaping (Message, Double, Bool) -> Void, scheduleCurrentMessage: @escaping () -> Void, sendScheduledMessagesNow: @escaping ([MessageId]) -> Void, editScheduledMessagesTime: @escaping ([MessageId]) -> Void, performTextSelectionAction: @escaping (UInt32, NSAttributedString, TextSelectionAction) -> Void, updateMessageReaction: @escaping (MessageId, String?) -> Void, openMessageReactions: @escaping (MessageId) -> Void, displaySwipeToReplyHint: @escaping () -> Void, dismissReplyMarkupMessage: @escaping (Message) -> Void, openMessagePollResults: @escaping (MessageId, Data) -> Void, openPollCreation: @escaping (Bool?) -> Void, displayPollSolution: @escaping (TelegramMediaPollResults.Solution, ASDisplayNode) -> Void, displayPsa: @escaping (String, ASDisplayNode) -> Void, displayDiceTooltip: @escaping (TelegramMediaDice) -> Void, animateDiceSuccess: @escaping () -> Void, requestMessageUpdate: @escaping (MessageId) -> Void, cancelInteractiveKeyboardGestures: @escaping () -> Void, automaticMediaDownloadSettings: MediaAutoDownloadSettings, pollActionState: ChatInterfacePollActionState, stickerSettings: ChatInterfaceStickerSettings) {
        self.openMessage = openMessage
        self.openPeer = openPeer
        self.openPeerMention = openPeerMention
        self.openMessageContextMenu = openMessageContextMenu
        self.openMessageContextActions = openMessageContextActions
        self.navigateToMessage = navigateToMessage
        self.tapMessage = tapMessage
        self.clickThroughMessage = clickThroughMessage
        self.toggleMessagesSelection = toggleMessagesSelection
        self.sendCurrentMessage = sendCurrentMessage
        self.sendMessage = sendMessage
        self.sendSticker = sendSticker
        self.sendGif = sendGif
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
        self.navigationController = navigationController
        self.chatControllerNode = chatControllerNode
        self.reactionContainerNode = reactionContainerNode
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
        self.updateMessageReaction = updateMessageReaction
        self.openMessageReactions = openMessageReactions
        self.displaySwipeToReplyHint = displaySwipeToReplyHint
        self.dismissReplyMarkupMessage = dismissReplyMarkupMessage
        self.openMessagePollResults = openMessagePollResults
        self.displayDiceTooltip = displayDiceTooltip
        self.animateDiceSuccess = animateDiceSuccess
        
        self.requestMessageUpdate = requestMessageUpdate
        self.cancelInteractiveKeyboardGestures = cancelInteractiveKeyboardGestures
        
        self.automaticMediaDownloadSettings = automaticMediaDownloadSettings
        
        self.pollActionState = pollActionState
        self.stickerSettings = stickerSettings
    }
    
    static var `default`: ChatControllerInteraction {
        return ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _, _ in }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _ in }, tapMessage: nil, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _ in return false }, sendGif: { _, _, _ in return false }, requestMessageActionCallback: { _, _, _ in }, requestMessageActionUrlAuth: { _, _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, reactionContainerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, updateMessageReaction: { _, _ in
        }, openMessageReactions: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: {
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false))
    }
}
