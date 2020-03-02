import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import Display
import AccountContext
import ContextUI

public enum ChatFinishMediaRecordingAction {
    case dismiss
    case preview
    case send
}

final class ChatPanelInterfaceInteractionStatuses {
    let editingMessage: Signal<Float?, NoError>
    let startingBot: Signal<Bool, NoError>
    let unblockingPeer: Signal<Bool, NoError>
    let searching: Signal<Bool, NoError>
    let loadingMessage: Signal<Bool, NoError>
    
    init(editingMessage: Signal<Float?, NoError>, startingBot: Signal<Bool, NoError>, unblockingPeer: Signal<Bool, NoError>, searching: Signal<Bool, NoError>, loadingMessage: Signal<Bool, NoError>) {
        self.editingMessage = editingMessage
        self.startingBot = startingBot
        self.unblockingPeer = unblockingPeer
        self.searching = searching
        self.loadingMessage = loadingMessage
    }
}

enum ChatPanelSearchNavigationAction {
    case earlier
    case later
    case index(Int)
}

enum ChatPanelRestrictionInfoSubject {
    case mediaRecording
    case stickers
}

enum ChatPanelRestrictionInfoDisplayType {
    case tooltip
    case alert
}

final class ChatPanelInterfaceInteraction {
    let setupReplyMessage: (MessageId, @escaping (ContainedViewLayoutTransition) -> Void) -> Void
    let setupEditMessage: (MessageId?, @escaping (ContainedViewLayoutTransition) -> Void) -> Void
    let beginMessageSelection: ([MessageId], @escaping (ContainedViewLayoutTransition) -> Void) -> Void
    let deleteSelectedMessages: () -> Void
    let reportSelectedMessages: () -> Void
    let reportMessages: ([Message], ContextController?) -> Void
    let deleteMessages: ([Message], ContextController?, @escaping (ContextMenuActionResult) -> Void) -> Void
    let forwardSelectedMessages: () -> Void
    let forwardCurrentForwardMessages: () -> Void
    let forwardMessages: ([Message]) -> Void
    let shareSelectedMessages: () -> Void
    let updateTextInputStateAndMode: (@escaping (ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) -> Void
    let updateInputModeAndDismissedButtonKeyboardMessageId: ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void
    let openStickers: () -> Void
    let editMessage: () -> Void
    let beginMessageSearch: (ChatSearchDomain, String) -> Void
    let dismissMessageSearch: () -> Void
    let updateMessageSearch: (String) -> Void
    let navigateMessageSearch: (ChatPanelSearchNavigationAction) -> Void
    let openSearchResults: () -> Void
    let openCalendarSearch: () -> Void
    let toggleMembersSearch: (Bool) -> Void
    let navigateToMessage: (MessageId) -> Void
    let navigateToChat: (PeerId) -> Void
    let openPeerInfo: () -> Void
    let togglePeerNotifications: () -> Void
    let sendContextResult: (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect) -> Bool
    let sendBotCommand: (Peer, String) -> Void
    let sendBotStart: (String?) -> Void
    let botSwitchChatWithPayload: (PeerId, String) -> Void
    let beginMediaRecording: (Bool) -> Void
    let finishMediaRecording: (ChatFinishMediaRecordingAction) -> Void
    let stopMediaRecording: () -> Void
    let lockMediaRecording: () -> Void
    let deleteRecordedMedia: () -> Void
    let sendRecordedMedia: () -> Void
    let displayRestrictedInfo: (ChatPanelRestrictionInfoSubject, ChatPanelRestrictionInfoDisplayType) -> Void
    let displayVideoUnmuteTip: (CGPoint?) -> Void
    let switchMediaRecordingMode: () -> Void
    let setupMessageAutoremoveTimeout: () -> Void
    let sendSticker: (FileMediaReference, ASDisplayNode, CGRect) -> Bool
    let unblockPeer: () -> Void
    let pinMessage: (MessageId) -> Void
    let unpinMessage: () -> Void
    let shareAccountContact: () -> Void
    let reportPeer: () -> Void
    let presentPeerContact: () -> Void
    let dismissReportPeer: () -> Void
    let deleteChat: () -> Void
    let beginCall: () -> Void
    let toggleMessageStickerStarred: (MessageId) -> Void
    let presentController: (ViewController, Any?) -> Void
    let getNavigationController: () -> NavigationController?
    let presentGlobalOverlayController: (ViewController, Any?) -> Void
    let navigateFeed: () -> Void
    let openGrouping: () -> Void
    let toggleSilentPost: () -> Void
    let requestUnvoteInMessage: (MessageId) -> Void
    let requestStopPollInMessage: (MessageId) -> Void
    let updateInputLanguage: (@escaping (String?) -> String?) -> Void
    let unarchiveChat: () -> Void
    let openLinkEditing: () -> Void
    let reportPeerIrrelevantGeoLocation: () -> Void
    let displaySlowmodeTooltip: (ASDisplayNode, CGRect) -> Void
    let displaySendMessageOptions: (ASDisplayNode, ContextGesture) -> Void
    let openScheduledMessages: () -> Void
    let displaySearchResultsTooltip: (ASDisplayNode, CGRect) -> Void
    let statuses: ChatPanelInterfaceInteractionStatuses?
    
    init(setupReplyMessage: @escaping (MessageId, @escaping (ContainedViewLayoutTransition) -> Void) -> Void, setupEditMessage: @escaping (MessageId?, @escaping (ContainedViewLayoutTransition) -> Void) -> Void, beginMessageSelection: @escaping ([MessageId], @escaping (ContainedViewLayoutTransition) -> Void) -> Void, deleteSelectedMessages: @escaping () -> Void, reportSelectedMessages: @escaping () -> Void, reportMessages: @escaping ([Message], ContextController?) -> Void, deleteMessages: @escaping ([Message], ContextController?, @escaping (ContextMenuActionResult) -> Void) -> Void, forwardSelectedMessages: @escaping () -> Void, forwardCurrentForwardMessages: @escaping () -> Void, forwardMessages: @escaping ([Message]) -> Void, shareSelectedMessages: @escaping () -> Void, updateTextInputStateAndMode: @escaping ((ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) -> Void, updateInputModeAndDismissedButtonKeyboardMessageId: @escaping ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void, openStickers: @escaping () -> Void, editMessage: @escaping () -> Void, beginMessageSearch: @escaping (ChatSearchDomain, String) -> Void, dismissMessageSearch: @escaping () -> Void, updateMessageSearch: @escaping (String) -> Void, openSearchResults: @escaping () -> Void, navigateMessageSearch: @escaping (ChatPanelSearchNavigationAction) -> Void, openCalendarSearch: @escaping () -> Void, toggleMembersSearch: @escaping (Bool) -> Void, navigateToMessage: @escaping (MessageId) -> Void, navigateToChat: @escaping (PeerId) -> Void, openPeerInfo: @escaping () -> Void, togglePeerNotifications: @escaping () -> Void, sendContextResult: @escaping (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect) -> Bool, sendBotCommand: @escaping (Peer, String) -> Void, sendBotStart: @escaping (String?) -> Void, botSwitchChatWithPayload: @escaping (PeerId, String) -> Void, beginMediaRecording: @escaping (Bool) -> Void, finishMediaRecording: @escaping (ChatFinishMediaRecordingAction) -> Void, stopMediaRecording: @escaping () -> Void, lockMediaRecording: @escaping () -> Void, deleteRecordedMedia: @escaping () -> Void, sendRecordedMedia: @escaping () -> Void, displayRestrictedInfo: @escaping (ChatPanelRestrictionInfoSubject, ChatPanelRestrictionInfoDisplayType) -> Void, displayVideoUnmuteTip: @escaping (CGPoint?) -> Void, switchMediaRecordingMode: @escaping () -> Void, setupMessageAutoremoveTimeout: @escaping () -> Void, sendSticker: @escaping (FileMediaReference, ASDisplayNode, CGRect) -> Bool, unblockPeer: @escaping () -> Void, pinMessage: @escaping (MessageId) -> Void, unpinMessage: @escaping () -> Void, shareAccountContact: @escaping () -> Void, reportPeer: @escaping () -> Void, presentPeerContact: @escaping () -> Void, dismissReportPeer: @escaping () -> Void, deleteChat: @escaping () -> Void, beginCall: @escaping () -> Void, toggleMessageStickerStarred: @escaping (MessageId) -> Void, presentController: @escaping (ViewController, Any?) -> Void, getNavigationController: @escaping () -> NavigationController?, presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void, navigateFeed: @escaping () -> Void, openGrouping: @escaping () -> Void, toggleSilentPost: @escaping () -> Void, requestUnvoteInMessage: @escaping (MessageId) -> Void, requestStopPollInMessage: @escaping (MessageId) -> Void, updateInputLanguage: @escaping ((String?) -> String?) -> Void, unarchiveChat: @escaping () -> Void, openLinkEditing: @escaping () -> Void, reportPeerIrrelevantGeoLocation: @escaping () -> Void, displaySlowmodeTooltip: @escaping (ASDisplayNode, CGRect) -> Void, displaySendMessageOptions: @escaping (ASDisplayNode, ContextGesture) -> Void, openScheduledMessages: @escaping () -> Void, displaySearchResultsTooltip: @escaping (ASDisplayNode, CGRect) -> Void, statuses: ChatPanelInterfaceInteractionStatuses?) {
        self.setupReplyMessage = setupReplyMessage
        self.setupEditMessage = setupEditMessage
        self.beginMessageSelection = beginMessageSelection
        self.deleteSelectedMessages = deleteSelectedMessages
        self.reportSelectedMessages = reportSelectedMessages
        self.reportMessages = reportMessages
        self.deleteMessages = deleteMessages
        self.forwardSelectedMessages = forwardSelectedMessages
        self.forwardCurrentForwardMessages = forwardCurrentForwardMessages
        self.forwardMessages = forwardMessages
        self.shareSelectedMessages = shareSelectedMessages
        self.updateTextInputStateAndMode = updateTextInputStateAndMode
        self.updateInputModeAndDismissedButtonKeyboardMessageId = updateInputModeAndDismissedButtonKeyboardMessageId
        self.openStickers = openStickers
        self.editMessage = editMessage
        self.beginMessageSearch = beginMessageSearch
        self.dismissMessageSearch = dismissMessageSearch
        self.updateMessageSearch = updateMessageSearch
        self.openSearchResults = openSearchResults
        self.navigateMessageSearch = navigateMessageSearch
        self.openCalendarSearch = openCalendarSearch
        self.toggleMembersSearch = toggleMembersSearch
        self.navigateToMessage = navigateToMessage
        self.navigateToChat = navigateToChat
        self.openPeerInfo = openPeerInfo
        self.togglePeerNotifications = togglePeerNotifications
        self.sendContextResult = sendContextResult
        self.sendBotCommand = sendBotCommand
        self.sendBotStart = sendBotStart
        self.botSwitchChatWithPayload = botSwitchChatWithPayload
        self.beginMediaRecording = beginMediaRecording
        self.finishMediaRecording = finishMediaRecording
        self.stopMediaRecording = stopMediaRecording
        self.lockMediaRecording = lockMediaRecording
        self.deleteRecordedMedia = deleteRecordedMedia
        self.sendRecordedMedia = sendRecordedMedia
        self.displayRestrictedInfo = displayRestrictedInfo
        self.displayVideoUnmuteTip = displayVideoUnmuteTip
        self.switchMediaRecordingMode = switchMediaRecordingMode
        self.setupMessageAutoremoveTimeout = setupMessageAutoremoveTimeout
        self.sendSticker = sendSticker
        self.unblockPeer = unblockPeer
        self.pinMessage = pinMessage
        self.unpinMessage = unpinMessage
        self.shareAccountContact = shareAccountContact
        self.reportPeer = reportPeer
        self.presentPeerContact = presentPeerContact
        self.dismissReportPeer = dismissReportPeer
        self.deleteChat = deleteChat
        self.beginCall = beginCall
        self.toggleMessageStickerStarred = toggleMessageStickerStarred
        self.presentController = presentController
        self.getNavigationController = getNavigationController
        self.presentGlobalOverlayController = presentGlobalOverlayController
        self.navigateFeed = navigateFeed
        self.openGrouping = openGrouping
        self.toggleSilentPost = toggleSilentPost
        self.requestUnvoteInMessage = requestUnvoteInMessage
        self.requestStopPollInMessage = requestStopPollInMessage
        self.updateInputLanguage = updateInputLanguage
        self.unarchiveChat = unarchiveChat
        self.openLinkEditing = openLinkEditing
        self.reportPeerIrrelevantGeoLocation = reportPeerIrrelevantGeoLocation
        self.displaySlowmodeTooltip = displaySlowmodeTooltip
        self.displaySendMessageOptions = displaySendMessageOptions
        self.openScheduledMessages = openScheduledMessages
        self.displaySearchResultsTooltip = displaySearchResultsTooltip
        self.statuses = statuses
    }
}
