import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Display
import AccountContext
import ContextUI
import TooltipUI

public enum ChatLoadingMessageSubject {
    case generic
    case pinnedMessage
}

public enum ChatFinishMediaRecordingAction {
    case dismiss
    case preview
    case pause
    case send(viewOnce: Bool)
}

public final class ChatPanelInterfaceInteractionStatuses {
    public let editingMessage: Signal<Float?, NoError>
    public let startingBot: Signal<Bool, NoError>
    public let unblockingPeer: Signal<Bool, NoError>
    public let searching: Signal<Bool, NoError>
    public let loadingMessage: Signal<ChatLoadingMessageSubject?, NoError>
    public let inlineSearch: Signal<Bool, NoError>
    
    public init(editingMessage: Signal<Float?, NoError>, startingBot: Signal<Bool, NoError>, unblockingPeer: Signal<Bool, NoError>, searching: Signal<Bool, NoError>, loadingMessage: Signal<ChatLoadingMessageSubject?, NoError>, inlineSearch: Signal<Bool, NoError>) {
        self.editingMessage = editingMessage
        self.startingBot = startingBot
        self.unblockingPeer = unblockingPeer
        self.searching = searching
        self.loadingMessage = loadingMessage
        self.inlineSearch = inlineSearch
    }
}

public enum ChatPanelSearchNavigationAction {
    case earlier
    case later
    case index(Int)
}

public enum ChatPanelRestrictionInfoSubject {
    case mediaRecording
    case stickers
    case premiumVoiceMessages
}

public enum ChatPanelRestrictionInfoDisplayType {
    case tooltip
    case alert
}

public enum ChatTranslationDisplayType {
    case original
    case translated
}

public final class ChatPanelInterfaceInteraction {
    public let setupReplyMessage: (MessageId?, @escaping (ContainedViewLayoutTransition, @escaping () -> Void) -> Void) -> Void
    public let setupEditMessage: (MessageId?, @escaping (ContainedViewLayoutTransition) -> Void) -> Void
    public let beginMessageSelection: ([MessageId], @escaping (ContainedViewLayoutTransition) -> Void) -> Void
    public let cancelMessageSelection: (ContainedViewLayoutTransition) -> Void
    public let deleteSelectedMessages: () -> Void
    public let reportSelectedMessages: () -> Void
    public let reportMessages: ([Message], ContextControllerProtocol?) -> Void
    public let blockMessageAuthor: (Message, ContextControllerProtocol?) -> Void
    public let deleteMessages: ([Message], ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void
    public let forwardSelectedMessages: () -> Void
    public let forwardCurrentForwardMessages: () -> Void
    public let forwardMessages: ([Message]) -> Void
    public let updateForwardOptionsState: ((ChatInterfaceForwardOptionsState) -> ChatInterfaceForwardOptionsState) -> Void
    public let presentForwardOptions: (ASDisplayNode) -> Void
    public let presentReplyOptions: (ASDisplayNode) -> Void
    public let presentLinkOptions: (ASDisplayNode) -> Void
    public let shareSelectedMessages: () -> Void
    public let updateTextInputStateAndMode: (@escaping (ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) -> Void
    public let updateInputModeAndDismissedButtonKeyboardMessageId: ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void
    public let openStickers: () -> Void
    public let editMessage: () -> Void
    public let beginMessageSearch: (ChatSearchDomain, String) -> Void
    public let dismissMessageSearch: () -> Void
    public let updateMessageSearch: (String) -> Void
    public let navigateMessageSearch: (ChatPanelSearchNavigationAction) -> Void
    public let openSearchResults: () -> Void
    public let openCalendarSearch: () -> Void
    public let toggleMembersSearch: (Bool) -> Void
    public let navigateToMessage: (MessageId, Bool, Bool, ChatLoadingMessageSubject) -> Void
    public let navigateToChat: (PeerId) -> Void
    public let navigateToProfile: (PeerId) -> Void
    public let openPeerInfo: () -> Void
    public let togglePeerNotifications: () -> Void
    public let sendContextResult: (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect) -> Bool
    public let sendBotCommand: (Peer, String) -> Void
    public let sendShortcut: (Int32) -> Void
    public let openEditShortcuts: () -> Void
    public let sendBotStart: (String?) -> Void
    public let botSwitchChatWithPayload: (PeerId, String) -> Void
    public let beginMediaRecording: (Bool) -> Void
    public let finishMediaRecording: (ChatFinishMediaRecordingAction) -> Void
    public let stopMediaRecording: () -> Void
    public let lockMediaRecording: () -> Void
    public let resumeMediaRecording: () -> Void
    public let deleteRecordedMedia: () -> Void
    public let sendRecordedMedia: (Bool, Bool) -> Void
    public let displayRestrictedInfo: (ChatPanelRestrictionInfoSubject, ChatPanelRestrictionInfoDisplayType) -> Void
    public let displayVideoUnmuteTip: (CGPoint?) -> Void
    public let switchMediaRecordingMode: () -> Void
    public let setupMessageAutoremoveTimeout: () -> Void
    public let sendSticker: (FileMediaReference, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool
    public let unblockPeer: () -> Void
    public let pinMessage: (MessageId, ContextControllerProtocol?) -> Void
    public let unpinMessage: (MessageId, Bool, ContextControllerProtocol?) -> Void
    public let unpinAllMessages: () -> Void
    public let openPinnedList: (MessageId) -> Void
    public let shareAccountContact: () -> Void
    public let reportPeer: () -> Void
    public let presentPeerContact: () -> Void
    public let dismissReportPeer: () -> Void
    public let deleteChat: () -> Void
    public let beginCall: (Bool) -> Void
    public let toggleMessageStickerStarred: (MessageId) -> Void
    public let presentController: (ViewController, Any?) -> Void
    public let presentControllerInCurrent: (ViewController, Any?) -> Void
    public let getNavigationController: () -> NavigationController?
    public let presentGlobalOverlayController: (ViewController, Any?) -> Void
    public let navigateFeed: () -> Void
    public let openGrouping: () -> Void
    public let toggleSilentPost: () -> Void
    public let requestUnvoteInMessage: (MessageId) -> Void
    public let requestStopPollInMessage: (MessageId) -> Void
    public let updateInputLanguage: (@escaping (String?) -> String?) -> Void
    public let unarchiveChat: () -> Void
    public let openLinkEditing: () -> Void
    public let displaySlowmodeTooltip: (UIView, CGRect) -> Void
    public let displaySendMessageOptions: (ASDisplayNode, ContextGesture) -> Void
    public let openScheduledMessages: () -> Void
    public let displaySearchResultsTooltip: (ASDisplayNode, CGRect) -> Void
    public let openPeersNearby: () -> Void
    public let unarchivePeer: () -> Void
    public let scrollToTop: () -> Void
    public let viewReplies: (MessageId?, ChatReplyThreadMessage) -> Void
    public let activatePinnedListPreview: (ASDisplayNode, ContextGesture) -> Void
    public let editMessageMedia: (MessageId, Bool) -> Void
    public let joinGroupCall: (CachedChannelData.ActiveCall) -> Void
    public let presentInviteMembers: () -> Void
    public let presentGigagroupHelp: () -> Void
    public let openSuggestPost: () -> Void
    public let updateShowCommands: ((Bool) -> Bool) -> Void
    public let updateShowSendAsPeers: ((Bool) -> Bool) -> Void
    public let openInviteRequests: () -> Void
    public let openSendAsPeer: (ASDisplayNode, ContextGesture?) -> Void
    public let presentChatRequestAdminInfo: () -> Void
    public let displayCopyProtectionTip: (ASDisplayNode, Bool) -> Void
    public let openWebView: (String, String, Bool, ChatOpenWebViewSource) -> Void
    public let updateShowWebView: ((Bool) -> Bool) -> Void
    public let insertText: (NSAttributedString) -> Void
    public let backwardsDeleteText: () -> Void
    public let restartTopic: () -> Void
    public let toggleTranslation: (ChatTranslationDisplayType) -> Void
    public let changeTranslationLanguage: (String) -> Void
    public let addDoNotTranslateLanguage: (String) -> Void
    public let hideTranslationPanel: () -> Void
    public let openPremiumGift: () -> Void
    public let openPremiumRequiredForMessaging: () -> Void
    public let openStarsPurchase: (Int64?) -> Void
    public let openMessagePayment: () -> Void
    public let updateHistoryFilter: ((ChatPresentationInterfaceState.HistoryFilter?) -> ChatPresentationInterfaceState.HistoryFilter?) -> Void
    public let updateChatLocationThread: (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void
    public let toggleChatSidebarMode: () -> Void
    public let updateDisplayHistoryFilterAsList: (Bool) -> Void
    public let openBoostToUnrestrict: () -> Void
    public let updateRecordingTrimRange: (Double, Double, Bool, Bool) -> Void
    public let dismissAllTooltips: () -> Void
    public let requestLayout: (ContainedViewLayoutTransition) -> Void
    public let chatController: () -> ViewController?
    public let statuses: ChatPanelInterfaceInteractionStatuses?
    
    public init(
        setupReplyMessage: @escaping (MessageId?, @escaping (ContainedViewLayoutTransition, @escaping () -> Void) -> Void) -> Void,
        setupEditMessage: @escaping (MessageId?, @escaping (ContainedViewLayoutTransition) -> Void) -> Void,
        beginMessageSelection: @escaping ([MessageId], @escaping (ContainedViewLayoutTransition) -> Void) -> Void,
        cancelMessageSelection: @escaping (ContainedViewLayoutTransition) -> Void,
        deleteSelectedMessages: @escaping () -> Void,
        reportSelectedMessages: @escaping () -> Void,
        reportMessages: @escaping ([Message], ContextControllerProtocol?) -> Void,
        blockMessageAuthor: @escaping (Message, ContextControllerProtocol?) -> Void,
        deleteMessages: @escaping ([Message], ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void,
        forwardSelectedMessages: @escaping () -> Void,
        forwardCurrentForwardMessages: @escaping () -> Void,
        forwardMessages: @escaping ([Message]) -> Void,
        updateForwardOptionsState: @escaping ((ChatInterfaceForwardOptionsState) -> ChatInterfaceForwardOptionsState) -> Void,
        presentForwardOptions: @escaping (ASDisplayNode) -> Void,
        presentReplyOptions: @escaping (ASDisplayNode) -> Void,
        presentLinkOptions: @escaping (ASDisplayNode) -> Void,
        shareSelectedMessages: @escaping () -> Void,
        updateTextInputStateAndMode: @escaping ((ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) -> Void,
        updateInputModeAndDismissedButtonKeyboardMessageId: @escaping ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void,
        openStickers: @escaping () -> Void,
        editMessage: @escaping () -> Void,
        beginMessageSearch: @escaping (ChatSearchDomain, String) -> Void,
        dismissMessageSearch: @escaping () -> Void,
        updateMessageSearch: @escaping (String) -> Void,
        openSearchResults: @escaping () -> Void,
        navigateMessageSearch: @escaping (ChatPanelSearchNavigationAction) -> Void,
        openCalendarSearch: @escaping () -> Void,
        toggleMembersSearch: @escaping (Bool) -> Void,
        navigateToMessage: @escaping (MessageId, Bool, Bool, ChatLoadingMessageSubject) -> Void,
        navigateToChat: @escaping (PeerId) -> Void,
        navigateToProfile: @escaping (PeerId) -> Void,
        openPeerInfo: @escaping () -> Void,
        togglePeerNotifications: @escaping () -> Void,
        sendContextResult: @escaping (ChatContextResultCollection, ChatContextResult, ASDisplayNode, CGRect) -> Bool,
        sendBotCommand: @escaping (Peer, String) -> Void,
        sendShortcut: @escaping (Int32) -> Void,
        openEditShortcuts: @escaping () -> Void,
        sendBotStart: @escaping (String?) -> Void,
        botSwitchChatWithPayload: @escaping (PeerId, String) -> Void,
        beginMediaRecording: @escaping (Bool) -> Void,
        finishMediaRecording: @escaping (ChatFinishMediaRecordingAction) -> Void,
        stopMediaRecording: @escaping () -> Void,
        lockMediaRecording: @escaping () -> Void,
        resumeMediaRecording: @escaping () -> Void,
        deleteRecordedMedia: @escaping () -> Void,
        sendRecordedMedia: @escaping (Bool, Bool) -> Void,
        displayRestrictedInfo: @escaping (ChatPanelRestrictionInfoSubject, ChatPanelRestrictionInfoDisplayType) -> Void,
        displayVideoUnmuteTip: @escaping (CGPoint?) -> Void,
        switchMediaRecordingMode: @escaping () -> Void,
        setupMessageAutoremoveTimeout: @escaping () -> Void,
        sendSticker: @escaping (FileMediaReference, Bool, UIView, CGRect, CALayer?, [ItemCollectionId]) -> Bool,
        unblockPeer: @escaping () -> Void,
        pinMessage: @escaping (MessageId, ContextControllerProtocol?) -> Void,
        unpinMessage: @escaping (MessageId, Bool, ContextControllerProtocol?) -> Void,
        unpinAllMessages: @escaping () -> Void,
        openPinnedList: @escaping (MessageId) -> Void,
        shareAccountContact: @escaping () -> Void,
        reportPeer: @escaping () -> Void,
        presentPeerContact: @escaping () -> Void,
        dismissReportPeer: @escaping () -> Void,
        deleteChat: @escaping () -> Void,
        beginCall: @escaping (Bool) -> Void,
        toggleMessageStickerStarred: @escaping (MessageId) -> Void,
        presentController: @escaping (ViewController, Any?) -> Void,
        presentControllerInCurrent: @escaping (ViewController, Any?) -> Void,
        getNavigationController: @escaping () -> NavigationController?,
        presentGlobalOverlayController: @escaping (ViewController, Any?) -> Void,
        navigateFeed: @escaping () -> Void,
        openGrouping: @escaping () -> Void,
        toggleSilentPost: @escaping () -> Void,
        requestUnvoteInMessage: @escaping (MessageId) -> Void,
        requestStopPollInMessage: @escaping (MessageId) -> Void,
        updateInputLanguage: @escaping ((String?) -> String?) -> Void,
        unarchiveChat: @escaping () -> Void,
        openLinkEditing: @escaping () -> Void,
        displaySlowmodeTooltip: @escaping (UIView, CGRect) -> Void,
        displaySendMessageOptions: @escaping (ASDisplayNode, ContextGesture) -> Void,
        openScheduledMessages: @escaping () -> Void,
        openPeersNearby: @escaping () -> Void,
        displaySearchResultsTooltip: @escaping (ASDisplayNode, CGRect) -> Void,
        unarchivePeer: @escaping () -> Void,
        scrollToTop: @escaping () -> Void,
        viewReplies: @escaping (MessageId?, ChatReplyThreadMessage) -> Void,
        activatePinnedListPreview: @escaping (ASDisplayNode, ContextGesture) -> Void,
        joinGroupCall: @escaping (CachedChannelData.ActiveCall) -> Void,
        presentInviteMembers: @escaping () -> Void,
        presentGigagroupHelp: @escaping () -> Void,
        openSuggestPost: @escaping () -> Void,
        editMessageMedia: @escaping (MessageId, Bool) -> Void,
        updateShowCommands: @escaping ((Bool) -> Bool) -> Void,
        updateShowSendAsPeers: @escaping ((Bool) -> Bool) -> Void,
        openInviteRequests: @escaping () -> Void,
        openSendAsPeer: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        presentChatRequestAdminInfo: @escaping () -> Void,
        displayCopyProtectionTip: @escaping (ASDisplayNode, Bool) -> Void,
        openWebView: @escaping (String, String, Bool, ChatOpenWebViewSource) -> Void,
        updateShowWebView: @escaping ((Bool) -> Bool) -> Void,
        insertText: @escaping (NSAttributedString) -> Void,
        backwardsDeleteText: @escaping () -> Void,
        restartTopic: @escaping () -> Void,
        toggleTranslation:  @escaping (ChatTranslationDisplayType) -> Void,
        changeTranslationLanguage: @escaping (String) -> Void,
        addDoNotTranslateLanguage:  @escaping (String) -> Void,
        hideTranslationPanel:  @escaping () -> Void,
        openPremiumGift: @escaping () -> Void,
        openPremiumRequiredForMessaging: @escaping () -> Void,
        openStarsPurchase: @escaping (Int64?) -> Void,
        openMessagePayment: @escaping () -> Void,
        openBoostToUnrestrict: @escaping () -> Void,
        updateRecordingTrimRange: @escaping (Double, Double, Bool, Bool) -> Void,
        dismissAllTooltips: @escaping () -> Void,
        updateHistoryFilter: @escaping ((ChatPresentationInterfaceState.HistoryFilter?) -> ChatPresentationInterfaceState.HistoryFilter?) -> Void,
        updateChatLocationThread: @escaping (Int64?, ChatControllerAnimateInnerChatSwitchDirection?) -> Void,
        toggleChatSidebarMode: @escaping () -> Void,
        updateDisplayHistoryFilterAsList: @escaping (Bool) -> Void,
        requestLayout: @escaping (ContainedViewLayoutTransition) -> Void,
        chatController: @escaping () -> ViewController?,
        statuses: ChatPanelInterfaceInteractionStatuses?
    ) {
        self.setupReplyMessage = setupReplyMessage
        self.setupEditMessage = setupEditMessage
        self.beginMessageSelection = beginMessageSelection
        self.cancelMessageSelection = cancelMessageSelection
        self.deleteSelectedMessages = deleteSelectedMessages
        self.reportSelectedMessages = reportSelectedMessages
        self.reportMessages = reportMessages
        self.blockMessageAuthor = blockMessageAuthor
        self.deleteMessages = deleteMessages
        self.forwardSelectedMessages = forwardSelectedMessages
        self.forwardCurrentForwardMessages = forwardCurrentForwardMessages
        self.forwardMessages = forwardMessages
        self.updateForwardOptionsState = updateForwardOptionsState
        self.presentForwardOptions = presentForwardOptions
        self.presentReplyOptions = presentReplyOptions
        self.presentLinkOptions = presentLinkOptions
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
        self.navigateToProfile = navigateToProfile
        self.openPeerInfo = openPeerInfo
        self.togglePeerNotifications = togglePeerNotifications
        self.sendContextResult = sendContextResult
        self.sendBotCommand = sendBotCommand
        self.sendShortcut = sendShortcut
        self.openEditShortcuts = openEditShortcuts
        self.sendBotStart = sendBotStart
        self.botSwitchChatWithPayload = botSwitchChatWithPayload
        self.beginMediaRecording = beginMediaRecording
        self.finishMediaRecording = finishMediaRecording
        self.stopMediaRecording = stopMediaRecording
        self.lockMediaRecording = lockMediaRecording
        self.resumeMediaRecording = resumeMediaRecording
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
        self.unpinAllMessages = unpinAllMessages
        self.openPinnedList = openPinnedList
        self.shareAccountContact = shareAccountContact
        self.reportPeer = reportPeer
        self.presentPeerContact = presentPeerContact
        self.dismissReportPeer = dismissReportPeer
        self.deleteChat = deleteChat
        self.beginCall = beginCall
        self.toggleMessageStickerStarred = toggleMessageStickerStarred
        self.presentController = presentController
        self.presentControllerInCurrent = presentControllerInCurrent
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
        self.displaySlowmodeTooltip = displaySlowmodeTooltip
        self.displaySendMessageOptions = displaySendMessageOptions
        self.openScheduledMessages = openScheduledMessages
        self.openPeersNearby = openPeersNearby
        self.displaySearchResultsTooltip = displaySearchResultsTooltip
        self.unarchivePeer = unarchivePeer
        self.scrollToTop = scrollToTop
        self.viewReplies = viewReplies
        self.activatePinnedListPreview = activatePinnedListPreview
        self.editMessageMedia = editMessageMedia
        self.joinGroupCall = joinGroupCall
        self.presentInviteMembers = presentInviteMembers
        self.presentGigagroupHelp = presentGigagroupHelp
        self.openSuggestPost = openSuggestPost
        self.updateShowCommands = updateShowCommands
        self.updateShowSendAsPeers = updateShowSendAsPeers
        self.openInviteRequests = openInviteRequests
        self.openSendAsPeer = openSendAsPeer
        self.presentChatRequestAdminInfo = presentChatRequestAdminInfo
        self.displayCopyProtectionTip = displayCopyProtectionTip
        self.openWebView = openWebView
        self.updateShowWebView = updateShowWebView
        self.insertText = insertText
        self.backwardsDeleteText = backwardsDeleteText
        self.restartTopic = restartTopic
        self.toggleTranslation = toggleTranslation
        self.changeTranslationLanguage = changeTranslationLanguage
        self.addDoNotTranslateLanguage = addDoNotTranslateLanguage
        self.hideTranslationPanel = hideTranslationPanel
        self.openPremiumGift = openPremiumGift
        self.openPremiumRequiredForMessaging = openPremiumRequiredForMessaging
        self.openStarsPurchase = openStarsPurchase
        self.openMessagePayment = openMessagePayment
        self.openBoostToUnrestrict = openBoostToUnrestrict
        self.updateRecordingTrimRange = updateRecordingTrimRange
        self.dismissAllTooltips = dismissAllTooltips
        self.updateHistoryFilter = updateHistoryFilter
        self.updateChatLocationThread = updateChatLocationThread
        self.toggleChatSidebarMode = toggleChatSidebarMode
        self.updateDisplayHistoryFilterAsList = updateDisplayHistoryFilterAsList
        self.requestLayout = requestLayout

        self.chatController = chatController
        self.statuses = statuses
    }
    
    public convenience init(
        updateTextInputStateAndMode: @escaping ((ChatTextInputState, ChatInputMode) -> (ChatTextInputState, ChatInputMode)) -> Void,
        updateInputModeAndDismissedButtonKeyboardMessageId: @escaping ((ChatPresentationInterfaceState) -> (ChatInputMode, MessageId?)) -> Void,
        openLinkEditing: @escaping () -> Void
    ) {
        self.init(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, cancelMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { _ in
        }, presentForwardOptions: { _ in
        }, presentReplyOptions: { _ in
        }, presentLinkOptions: { _ in
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: updateTextInputStateAndMode, updateInputModeAndDismissedButtonKeyboardMessageId: updateInputModeAndDismissedButtonKeyboardMessageId, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _, _, _, _ in
        }, navigateToChat: { _ in
        }, navigateToProfile: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendShortcut: { _ in
        }, openEditShortcuts: {
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, resumeMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _, _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _, _ in
        }, unpinMessage: { _, _, _ in
        }, unpinAllMessages: {
        }, openPinnedList: { _ in
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: { _ in
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: openLinkEditing,
        displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { _, _ in
        }, openScheduledMessages: {
        }, openPeersNearby: {
        }, displaySearchResultsTooltip: { _, _ in
        }, unarchivePeer: {
        }, scrollToTop: {
        }, viewReplies: { _, _ in
        }, activatePinnedListPreview: { _, _ in
        }, joinGroupCall: { _ in
        }, presentInviteMembers: {
        }, presentGigagroupHelp: {
        }, openSuggestPost: {
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer:  { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, openWebView: { _, _, _, _ in
        }, updateShowWebView: { _ in
        }, insertText: { _ in
        }, backwardsDeleteText: {
        }, restartTopic: {
        }, toggleTranslation: { _ in
        }, changeTranslationLanguage: { _ in
        }, addDoNotTranslateLanguage: { _ in
        }, hideTranslationPanel: {
        }, openPremiumGift: {
        }, openPremiumRequiredForMessaging: {
        }, openStarsPurchase: { _ in
        }, openMessagePayment: {
        }, openBoostToUnrestrict: {
        }, updateRecordingTrimRange: { _, _, _, _ in
        }, dismissAllTooltips: {
        }, updateHistoryFilter: { _ in
        }, updateChatLocationThread: { _, _ in
        }, toggleChatSidebarMode: {
        }, updateDisplayHistoryFilterAsList: { _ in
        }, requestLayout: { _ in
        }, chatController: {
            return nil
        }, statuses: nil)
    }
}
